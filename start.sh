#!/usr/bin/env bash
# Serve DeepSeek-V4.1-Flash under rootless podman (or Docker) using the
# local-inference-lab vLLM image.
#
# The image's ds41-flash profile drifts from the measured serving
# configuration on two values (top_p 1.0 vs 0.95, probabilistic vs greedy
# draft sampling), so two native CLI overrides after the image pin the
# measured values. Defaults here reflect this project's own measurements; see
# README.md "Provenance and changes from the original recipe". DRY_RUN=1
# ./start.sh prints the launcher's resolved plan (--print-config) for auditing
# without touching the GPUs.
#
# RAM Engram is the default; disk is the option (ENGRAM_TABLE_MEMORY=disk).
# Nothing here switches modes silently.
#
# A bare ./start.sh boots the recipe defaults (MAX_MODEL_LEN=-1). For the
# Karmic Kraken comparison: MAX_MODEL_LEN=131072 ./start.sh
set -euo pipefail
RECIPE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

CONTAINER_NAME="${CONTAINER_NAME:-ds41}"
IMAGE_TAG="${IMAGE:-ghcr.io/local-inference-lab/vllm:karmic-kraken-beta}"
PORT="${PORT:-8000}"
BIND_ADDRESS="${BIND_ADDRESS:-0.0.0.0}"
MODEL_DIRECTORY="${MODEL_DIRECTORY:-$HOME/models/DeepSeek-V4.1-Flash}"
# CSF=1 serves the lossless FP4-CSF container instead of the original
# checkpoint. The LIL launcher detects the container's manifest.json and
# applies the mxfp4_csf quantization/load-format variant automatically.
CSF="${CSF:-0}"
CSF_DIRECTORY="${CSF_DIRECTORY:-/nvme1/models/DeepSeek-V4.1-Flash-1017-lossless-CSF}"
ENGRAM_TABLE_MEMORY="${ENGRAM_TABLE_MEMORY:-ram}"
MAX_MODEL_LEN="${MAX_MODEL_LEN:--1}"
MAX_NUM_SEQS="${MAX_NUM_SEQS:-32}"
MAX_NUM_BATCHED_TOKENS="${MAX_NUM_BATCHED_TOKENS:-4096}"
GPU_MEMORY_UTILIZATION="${GPU_MEMORY_UTILIZATION:-0.95}"
JIT_MONITOR_MODE="${JIT_MONITOR_MODE:-warn}"
STATE_DIRECTORY="${STATE_DIRECTORY:-$RECIPE_DIR/state}"
MEMORY_LIMIT="${MEMORY_LIMIT:-512g}"   # KK parity; empty disables the limit
READY_TIMEOUT="${READY_TIMEOUT:-3600}"
DRY_RUN="${DRY_RUN:-0}"

# NCCL transport environment for the TP4 cross-rank exchange, shared by the
# DRY_RUN plan, the P2P gate's transport check, and the server run, so the
# gate verifies exactly what the server will do.
#   NCCL_SOCKET_IFNAME=lo  single node; bootstrap over loopback
#   NCCL_P2P_LEVEL=PHB     every GPU pair on this board (Dell Precision 7865,
#                          AMD sWRX8/WRX80; all four cards hang off the CPU
#                          root complex) is PHB in NCCL's topology. Stock
#                          NCCL's default P2P level is PXB, so it rejects
#                          every pair and stages the TP4 allreduce through
#                          host shared memory ("via SHM/direct"). PHB admits
#                          the direct PCIe peer path ("via P2P/CUMEM").
NCCL_ENV_ARGS=(-e NCCL_SOCKET_IFNAME=lo -e NCCL_P2P_LEVEL=PHB)

# Optional B12X two-shot override. The profile default is "off"; this recipe
# ships 6 MiB, which covers the whole one-shot..DMA gap band (96 KiB..6 MiB)
# with the lossless single-rounding BF16 two-shot. Measured on this host:
# C8 verifier steps/s +4.8% vs off, other cells within noise
# (results/twoshot-AB.md). Outputs in the covered band are NOT byte-identical
# to ring-config runs (different fp32 accumulation order) - a re-baseline
# event for strict-hash comparisons, like changing TP width. Set TWOSHOT_MB=off
# to restore the profile default. Container env wins over the profile value in
# the launcher's layering; DRY_RUN=1 confirms the source.
TWOSHOT_MB="${TWOSHOT_MB-6}"
TWOSHOT_ARGS=()
if [[ "$TWOSHOT_MB" != off ]]; then
  [[ "$TWOSHOT_MB" =~ ^[0-9]+$ ]] && (( TWOSHOT_MB >= 1 && TWOSHOT_MB <= 8 )) || { echo "TWOSHOT_MB must be an integer MiB in 1..8, or off (the gap band spans 96KiB..6MiB)" >&2; exit 2; }
  TWOSHOT_ARGS=(-e "VLLM_PCIE_TWOSHOT_ALLREDUCE_MAX_SIZE=${TWOSHOT_MB}MB")
fi

# Optional fairness-gate override. The image's scheduler exposes
# prefill_compute_share: the fraction of model execution granted to prefill
# under contention; the profile default is 0.4 with schedule-interval 1.
# On this build the gauge reads 0.4 even for uncontended serial prefill, so
# standalone prefills may run at ~40% duty; whether that is the effective
# duty or the configured value is what the A/B measures.
#   SHARE=0.4|0.5|..|auto  sets PREFILL_COMPUTE_SHARE (launcher accepts
#                          "auto" or 0<v<1)
#   FAIRNESS=none          sets FAIRNESS_ENGINE=none, which DROPS the arg
#                          entirely and falls back to the engine default
#                          ("zero means disabled" per the metrics help)
SHARE_ARGS=()
if [[ -n "${SHARE:-}" ]]; then
  [[ "$SHARE" =~ ^(auto|[0-9](\.[0-9]+)?)$ ]] || { echo "SHARE must be auto or a fraction strictly between 0 and 1 (e.g. 0.5)" >&2; exit 2; }
  SHARE_ARGS+=(-e "PREFILL_COMPUTE_SHARE=${SHARE}")
fi
if [[ -n "${FAIRNESS:-}" ]]; then
  [[ "$FAIRNESS" == none ]] || { echo "FAIRNESS currently accepts only 'none' (drop the compute-share arg)" >&2; exit 2; }
  SHARE_ARGS+=(-e "FAIRNESS_ENGINE=none")
fi

if command -v podman >/dev/null 2>&1; then ENGINE=podman; else ENGINE=docker; fi
if ! command -v "$ENGINE" >/dev/null 2>&1; then
  echo "Neither podman nor docker is on PATH." >&2; exit 2
fi

# ------------------------------------------------------------------ checkpoint
# Two supported layouts:
#   flat  the original checkpoint (model.safetensors.index.json at the root)
#   csf   the lossless FP4-CSF container (manifest.json + metadata/ + tensors/)
# CSF=1 selects the CSF container path; the launcher derives the mxfp4_csf
# quantization and load-format from manifest.json.
case "$CSF" in
  0|1) ;;
  *) echo "CSF must be 0 or 1 (got: $CSF)" >&2; exit 2 ;;
esac
if [[ "$CSF" == 1 ]]; then
  MODEL_DIRECTORY="$CSF_DIRECTORY"
fi

CHECKPOINT_LAYOUT=""
if [[ -s "$MODEL_DIRECTORY/manifest.json" \
      && -s "$MODEL_DIRECTORY/metadata/model.safetensors.index.json" \
      && -d "$MODEL_DIRECTORY/tensors" ]]; then
  CHECKPOINT_LAYOUT=csf
elif [[ -s "$MODEL_DIRECTORY/model.safetensors.index.json" ]]; then
  CHECKPOINT_LAYOUT=flat
else
  echo "Checkpoint not found in $MODEL_DIRECTORY" >&2
  echo "Expected either model.safetensors.index.json (flat checkpoint) or" >&2
  echo "manifest.json + metadata/model.safetensors.index.json + tensors/ (CSF container)." >&2
  echo "Set MODEL_DIRECTORY, or use CSF=1 with CSF_DIRECTORY pointing at the CSF download." >&2
  exit 2
fi
if [[ "$CSF" == 1 && "$CHECKPOINT_LAYOUT" != csf ]]; then
  echo "CSF=1 but $MODEL_DIRECTORY is not a CSF container." >&2
  exit 2
fi

# ------------------------------------------------------------- engram placement
# ram: the two native Engram tables (~189 GiB) are mapped shared, prefaulted
# and mlocked, so every lookup is a memcpy. disk: O_DIRECT reads with a
# bounded cache. Both return identical row bytes; only the miss path differs.
case "$ENGRAM_TABLE_MEMORY" in
  ram|disk) ;;
  *) echo "ENGRAM_TABLE_MEMORY must be ram or disk (got: $ENGRAM_TABLE_MEMORY)" >&2; exit 2 ;;
esac

need_bytes="$(MODEL_DIRECTORY="$MODEL_DIRECTORY" CHECKPOINT_LAYOUT="$CHECKPOINT_LAYOUT" python3 - <<'PY'
import json, os, sys
from pathlib import Path
root = Path(os.environ['MODEL_DIRECTORY'])
layout = os.environ['CHECKPOINT_LAYOUT']
index_path = (root / 'metadata' / 'model.safetensors.index.json') if layout == 'csf' else (root / 'model.safetensors.index.json')
shard_root = (root / 'tensors') if layout == 'csf' else root
try:
    index = json.loads(index_path.read_text())['weight_map']
    shards = {index[f'layers.{n}.engram.embed.weight'] for n in (1, 14)}
    sizes = [(shard_root / s).stat().st_size for s in shards]
except FileNotFoundError as exc:
    print(f"Engram shard not present yet: {exc.filename}", file=sys.stderr)
    sys.exit(3)
except (KeyError, ValueError) as exc:
    print(f"Checkpoint index has no usable Engram entry: {exc}", file=sys.stderr)
    sys.exit(3)
print(sum(sizes) + 24 * 2**30)
PY
)" || { echo "Cannot size the Engram tables from the checkpoint index in $MODEL_DIRECTORY" >&2; exit 2; }

# The container's locked-memory ceiling is capped at the host user's
# RLIMIT_MEMLOCK hard limit: --ulimit memlock=-1:-1 (with IPC_LOCK) cannot raise
# it above that. A finite ceiling below need_bytes dooms the URING backend with
# "io_uring_register_buffers failed: Cannot allocate memory", so gate on it.
memlock_hard="$(python3 - <<'PY'
import resource
soft, hard = resource.getrlimit(resource.RLIMIT_MEMLOCK)
print("unlimited" if hard == -1 else hard)
PY
)"
if [[ "$ENGRAM_TABLE_MEMORY" == ram && "$memlock_hard" != "unlimited" ]] && (( memlock_hard < need_bytes )); then
  { echo "Refusing to start: RAM Engram needs ~$((need_bytes / 1073741824)) GiB of locked memory,"
    echo "but the host RLIMIT_MEMLOCK hard limit is $((memlock_hard / 1048576)) MiB."
    echo "The container inherits this ceiling; --ulimit memlock=-1:-1 cannot raise it."
    echo ""
    echo "Fix (as root): prlimit --memlock=unlimited:unlimited -- runuser -u $(id -un) -- bash"
    echo "then run this script from that shell (verify: ulimit -l = unlimited)."
    echo "Or restart with ENGRAM_TABLE_MEMORY=disk (much lower locked-memory need)." ; } >&2
  exit 2
fi

# The recipe's two native overrides, pinned so the image's drifted profile
# defaults cannot change the served parameters.
OVERRIDE_GEN='{"temperature":1.0,"top_p":0.95}'
OVERRIDE_SPEC='{"method":"dspark","attention_backend":"B12X","draft_sample_method":"greedy","rejection_sample_method":"standard","num_speculative_tokens":7,"draft_tensor_parallel_size":4,"enable_adaptive_verification":true,"adaptive_verification_cost_scale":1.0}'

# ----------------------------------------------------------------------- dry run
# Resolve the launch plan inside a throwaway container (no GPU device, no
# lifecycle, no port bind) and print it. The launcher verifies the image
# contract and the checkpoint identity before printing.
if [[ "$DRY_RUN" == 1 ]]; then
  echo "DRY_RUN=1: resolving the launch plan without starting the server" >&2
  mkdir -p "$STATE_DIRECTORY"
  "$ENGINE" run --rm \
    -e PROFILE=ds41-flash -e HARDWARE_PROFILE=rtx-pro-6000-pcie \
    -e MODEL=/model -e ENGRAM_TABLE_MEMORY="$ENGRAM_TABLE_MEMORY" \
    -e TP=4 -e DCP=1 -e PORT="$PORT" \
    -e MAX_MODEL_LEN="$MAX_MODEL_LEN" \
    -e MAX_NUM_SEQS="$MAX_NUM_SEQS" -e MAX_NUM_BATCHED_TOKENS="$MAX_NUM_BATCHED_TOKENS" \
    -e GPU_MEMORY_UTILIZATION="$GPU_MEMORY_UTILIZATION" -e JIT_MONITOR_MODE="$JIT_MONITOR_MODE" \
    -e HF_HUB_OFFLINE=1 "${NCCL_ENV_ARGS[@]}" "${TWOSHOT_ARGS[@]}" "${SHARE_ARGS[@]}" -e GLOO_SOCKET_IFNAME=lo \
    -v "$MODEL_DIRECTORY:/model:ro,z" \
    -v "$STATE_DIRECTORY:/cache:z" \
    "$IMAGE_TAG" \
    --print-config \
    --override-generation-config "$OVERRIDE_GEN" \
    --speculative-config "$OVERRIDE_SPEC"
  exit 0
fi

# ------------------------------------------------------------------ GPU naming
# Under CDI the entity name is what limits devices. The serving path is TP4,
# so the default asks for the whole set. Repeated --device flags stack; a
# comma list inside one value does not resolve. The CDI spec itself is
# regenerated on every start so it always matches the current hardware,
# enumeration and device nodes; callers that need a restricted set use GPU=,
# which selects CDI entities at run time.
ensure_cdi() {
  local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  local spec_dir="$config_home/cdi" spec dropin driver stage
  spec="$spec_dir/nvidia.yaml"
  dropin="$config_home/containers/containers.conf.d/99-ds41lil-cdi.conf"
  if ! command -v nvidia-ctk >/dev/null 2>&1; then
    echo "nvidia-ctk is required for podman GPU passthrough:" >&2
    echo "  dnf copr enable @ai-ml/nvidia-container-toolkit && dnf install nvidia-container-toolkit" >&2
    return 1
  fi
  mkdir -p "$spec_dir" "$config_home/containers/containers.conf.d" || return 1
  if [[ ! -f "$dropin" ]] && ! grep -qs "$spec_dir" "$config_home"/containers/containers.conf.d/*.conf; then
    printf '[engine]\ncdi_spec_dirs = ["/etc/cdi", "/var/run/cdi", "%s"]\n' "$spec_dir" >"$dropin"
    echo "Registered $spec_dir as a CDI spec directory" >&2
  fi
  driver="$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -n1 || true)"
  stage="$(mktemp -d "$config_home/.ds41lil-cdi-XXXXXX")" || return 1
  if nvidia-ctk --quiet cdi generate --output="$stage/nvidia.yaml" && [[ -s "$stage/nvidia.yaml" ]]; then
    mv -f "$stage/nvidia.yaml" "$spec"; rm -rf "$stage"
    echo "Regenerated $spec (driver ${driver:-unknown})" >&2
  else
    rm -rf "$stage"
    [[ -s "$spec" ]] || { echo "nvidia-ctk cdi generate failed and no spec exists yet." >&2; return 1; }
    echo "nvidia-ctk cdi generate failed; continuing with the existing $spec" >&2
  fi
}

GPU_ARGS=()
if [[ "$ENGINE" == podman ]]; then
  ensure_cdi || exit 2
  if [[ -z "${GPU:-}" || "${GPU}" == all ]]; then
    GPU_ARGS=(--device "nvidia.com/gpu=all"); gpu_count=4
  else
    gpu_count=0
    IFS=',' read -ra entities <<< "${GPU}"
    for entity in "${entities[@]}"; do
      [[ -n "$entity" ]] || { echo "GPU=\"${GPU}\" contains an empty entry" >&2; exit 2; }
      GPU_ARGS+=(--device "nvidia.com/gpu=${entity}"); gpu_count=$((gpu_count + 1))
    done
  fi
else
  GPU_ARGS=(--gpus all); gpu_count=4
fi
if (( gpu_count < 4 )); then
  echo "This serving path is TP4 and needs four cards; GPU=${GPU:-<default>} injects $gpu_count." >&2
  echo "Use GPU=all or GPU=0,1,2,3." >&2; exit 2
fi

# ----------------------------------------------------------------------- image
# Pulled here (before the P2P gate) so the gate's check container has the
# image. The gate runs before the lifecycle, so a failed gate does not stop
# the running container.
if ! "$ENGINE" image exists "$IMAGE_TAG" 2>/dev/null; then
  echo "Pulling $IMAGE_TAG" >&2
  "$ENGINE" pull "$IMAGE_TAG"
fi

# ------------------------------------------------------------------ P2P gate
# The TP4 cross-rank exchange runs on the direct PCIe peer path only if (a)
# CUDA peer access is available for every ordered GPU pair, (b) the fabric
# does not silently discard P2P posted writes, and (c) NCCL actually selects
# the P2P transport. On this platform (Dell Precision 7865, AMD
# sWRX8/WRX80) peer access is on by default, but the fabric silently discards
# P2P posted writes (no AER, no Xid) when ASPM L1 is enabled, which is the
# BIOS default. The boot must carry pcie_aspm=force so the policy resolves to
# [performance] (L1 disabled). Peer access alone is not enough: every GPU pair
# on this board is PHB in NCCL's topology (all four cards hang off the CPU
# root complex), and stock NCCL's default P2P level is PXB, so without
# NCCL_P2P_LEVEL=PHB NCCL rejects every pair and stages the allreduce through
# host shared memory ("via SHM/direct") even though the peer path is healthy.
# Gate on all three, before the lifecycle:
#   1. host: ASPM policy is [performance] (else the peer path is lossy)
#   2. container: can_device_access_peer for all ordered pairs (else P2P is off)
#   3. container: NCCL transport check with the server's NCCL env
#      (repro/nccl_transport_check.py) — every channel must be "via P2P/",
#      none "via SHM/" or "via NET/" (else the exchange bounces through host
#      memory and the benchmark is not measuring the peer path)
# Skippable with P2P_CHECK=0 (debugging only; not recommended).
if [[ "${P2P_CHECK:-1}" == 1 ]]; then
  aspm_policy="$(cat /sys/module/pcie_aspm/parameters/policy 2>/dev/null || true)"
  if [[ "$aspm_policy" != *"[performance]"* ]]; then
    { echo "Refusing to start: PCIe ASPM policy is '${aspm_policy:-unreadable}', not [performance]."
      echo "On this platform (sWRX8/WRX80) ASPM L1 silently discards PCIe P2P posted"
      echo "writes (no AER, no Xid), so the TP4 peer path would corrupt data."
      echo ""
      echo "Fix: boot with pcie_aspm=force on the kernel command line (GRUB), then verify:"
      echo "  grep pcie_aspm=force /proc/cmdline"
      echo "  cat /sys/module/pcie_aspm/parameters/policy   # should read [performance]"
      echo "Or set P2P_CHECK=0 to skip (not recommended)." ; } >&2
    exit 2
  fi
  echo "  p2p: ASPM policy [performance] (L1 disabled)" >&2
  if ! p2p_out="$("$ENGINE" run --rm "${GPU_ARGS[@]}" \
        -v "$RECIPE_DIR/repro:/work:z" --entrypoint python3 \
        "$IMAGE_TAG" /work/p2p_peer_check.py 2>&1)"; then
    { echo "Refusing to start: P2P peer-access check failed."
      echo "$p2p_out"
      echo "The TP4 cross-rank exchange would fall back to a host bounce."
      echo "Set P2P_CHECK=0 to skip (not recommended)." ; } >&2
    exit 2
  fi
  echo "  ${p2p_out//$'\n'/$'\n  '}" >&2
  # Check 3: NCCL's own transport selection, with the server's NCCL env.
  # The probe runs a 4-rank allreduce and logs "Channel NN : a -> b via
  # <transport>" per channel; the peer path is "via P2P/", a host bounce is
  # "via SHM/" (or "via NET/" if the topology is misread).
  if ! nccl_out="$("$ENGINE" run --rm "${GPU_ARGS[@]}" "${NCCL_ENV_ARGS[@]}" \
        -v "$RECIPE_DIR/repro:/work:z" --entrypoint python3 \
        "$IMAGE_TAG" /work/nccl_transport_check.py 2>&1)"; then
    { echo "Refusing to start: NCCL transport check failed."
      echo "$nccl_out"
      echo "Set P2P_CHECK=0 to skip (not recommended)." ; } >&2
    exit 2
  fi
  p2p_channels="$(grep -cE 'via P2P/' <<<"$nccl_out" || true)"
  bounce_channels="$(grep -cE 'via (SHM|NET)/' <<<"$nccl_out" || true)"
  if (( p2p_channels == 0 || bounce_channels > 0 )); then
    { echo "Refusing to start: NCCL is not using the direct peer path."
      echo "  channels via P2P: $p2p_channels; via SHM/NET: $bounce_channels"
      echo "  (expected: every channel 'via P2P/', none 'via SHM/' or 'via NET/')"
      echo "  The TP4 cross-rank exchange would stage through host shared memory."
      echo "  Relevant lines from the transport check:"
      grep -E 'via (P2P|SHM|NET)/|P2P_LEVEL' <<<"$nccl_out" | head -20
      echo "Set P2P_CHECK=0 to skip (not recommended)." ; } >&2
    exit 2
  fi
  echo "  p2p: NCCL transport check: $p2p_channels channels via P2P, 0 via SHM/NET" >&2
fi

# ------------------------------------------------------------------ co-tenancy
# Four cards at GPU_MEMORY_UTILIZATION of ~96 GiB each leaves little slack, so
# a neighbour that looks harmless fails the boot minutes later with an error
# that blames the device. Name it here, while nothing has been stopped yet.
if [[ "${ALLOW_CO_TENANT:-0}" != 1 ]] && command -v nvidia-smi >/dev/null 2>&1; then
  # "Ours" detection: a GPU pid is ours if it shares the pid namespace of our
  # running container's init. (The cgroup path is not reliable here: under a
  # runuser-launched session the container's processes land in the session
  # scope, not a per-container cgroup, so grepping the cgroup for the container
  # ID never matches.)
  own_pid="$("$ENGINE" inspect -f '{{.State.Pid}}' "$CONTAINER_NAME" 2>/dev/null || true)"
  own_ns=""
  if [[ -n "$own_pid" && -r "/proc/$own_pid/ns/pid" ]]; then
    own_ns="$(readlink "/proc/$own_pid/ns/pid" 2>/dev/null || true)"
  fi
  usable=0
  while IFS=',' read -r idx used free total; do
    idx="${idx// /}"; used="${used// /}"; free="${free// /}"; total="${total// /}"
    [[ -n "$free" ]] || { echo "  GPU $idx: no nvidia-smi reading; not counted" >&2; continue; }
    own=0; foreign=0
    while IFS=',' read -r pid pname pmem; do
      pid="${pid// /}"; pname="${pname// /}"; pmem="${pmem// /}"
      [[ "$pmem" =~ ^[0-9]+$ ]] || continue
      pid_ns=""
      if [[ -r "/proc/$pid/ns/pid" ]]; then
        pid_ns="$(readlink "/proc/$pid/ns/pid" 2>/dev/null || true)"
      fi
      if [[ -n "$own_ns" && "$pid_ns" == "$own_ns" ]]; then
        own=$((own + pmem))
      else
        foreign=$((foreign + pmem)); printf '    GPU %s held by pid %s (%s), %s MiB\n' "$idx" "$pid" "$pname" "$pmem" >&2
      fi
    done < <(nvidia-smi --id="$idx" --query-compute-apps=pid,process_name,used_memory --format=csv,noheader,nounits 2>/dev/null)
    budget="$(awk -v f="$GPU_MEMORY_UTILIZATION" -v t="$total" 'BEGIN{printf "%d", f*t}')"
    margin=$((free + own - budget))
    printf '  GPU %s: %s MiB used (%s ours, %s foreign), %s MiB free, budget %s MiB, margin %s MiB\n' \
      "$idx" "$used" "$own" "$foreign" "$free" "$budget" "$margin" >&2
    (( margin >= 0 && foreign <= 256 )) && usable=$((usable + 1))
  done < <(nvidia-smi --query-gpu=index,memory.used,memory.free,memory.total --format=csv,noheader,nounits)
  if (( usable < 4 )); then
    { echo "Refusing to start: needs 4 cards with room at ${GPU_MEMORY_UTILIZATION}, found $usable."
      echo "  Nothing was stopped. Clear a holder, lower GPU_MEMORY_UTILIZATION, or set ALLOW_CO_TENANT=1." >&2; }
    exit 2
  fi
fi

# Host networking: the port must be free unless it is our own running
# container (in which case the lifecycle below decides).
if command -v ss >/dev/null 2>&1; then
  if ss -ltn 2>/dev/null | awk '{print $4}' | grep -Eq "[:.]${PORT}$"; then
    state="$("$ENGINE" inspect -f '{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo absent)"
    if [[ "$state" != running ]]; then
      echo "Port $PORT is in use and $CONTAINER_NAME is not running. Stop the other listener or set PORT." >&2
      exit 2
    fi
  fi
fi

# -------------------------------------------------------------------- lifecycle
state="$("$ENGINE" inspect -f '{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo absent)"
case "$state" in
  created|exited|dead|absent)
    [[ "$state" == absent ]] || { echo "Removing $state container $CONTAINER_NAME" >&2; "$ENGINE" rm "$CONTAINER_NAME" >/dev/null; } ;;
  *)
    if [[ "${REPLACE:-0}" == 1 ]]; then
      echo "Stopping $state container $CONTAINER_NAME to replace it (REPLACE=1)" >&2
      "$ENGINE" stop --time "${STOP_TIMEOUT:-90}" "$CONTAINER_NAME" >/dev/null
      "$ENGINE" rm "$CONTAINER_NAME" >/dev/null
    else
      echo "$CONTAINER_NAME is already $state. Set REPLACE=1 to replace it, or run ./stop.sh first." >&2
      exit 1
    fi ;;
esac

mkdir -p "$STATE_DIRECTORY"
echo "  checkpoint: $CHECKPOINT_LAYOUT ($MODEL_DIRECTORY)" >&2
echo "  engram: $ENGRAM_TABLE_MEMORY (host memlock hard limit: $memlock_hard)" >&2
echo "  driver: $(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -n1 || echo unknown)" >&2
echo "  two-shot: TWOSHOT_MB=$TWOSHOT_MB (profile default is off; off restores it)" >&2
echo "  max_model_len=$MAX_MODEL_LEN max_num_seqs=$MAX_NUM_SEQS max_num_batched_tokens=$MAX_NUM_BATCHED_TOKENS" >&2
echo "  gpu_mem_util=$GPU_MEMORY_UTILIZATION jit_monitor=$JIT_MONITOR_MODE memory_limit=${MEMORY_LIMIT:-none}" >&2
echo "  model=$MODEL_DIRECTORY state=$STATE_DIRECTORY listen=$BIND_ADDRESS:$PORT" >&2

mem_args=()
[[ -n "$MEMORY_LIMIT" ]] && mem_args=(--memory "$MEMORY_LIMIT" --memory-swap "$MEMORY_LIMIT")

# --ipc=host gives the container the host's /dev/shm (498 G here), which
# covers the recipe's --shm-size 32g; podman has no --shm-size of its own.
# -v ...:z is the SELinux half; rootless podman maps container uid 0 to this
# host user, so the mounted checkpoint and state land user-owned.
"$ENGINE" run -d --name "$CONTAINER_NAME" \
  --init --restart unless-stopped \
  "${GPU_ARGS[@]}" \
  --network=host \
  --ipc=host \
  --cap-add IPC_LOCK \
  --ulimit memlock=-1:-1 \
  --ulimit stack=67108864:67108864 \
  --security-opt seccomp=unconfined \
  "${mem_args[@]}" \
  -v "$MODEL_DIRECTORY:/model:ro,z" \
  -v "$STATE_DIRECTORY:/cache:z" \
  -e PROFILE=ds41-flash -e HARDWARE_PROFILE=rtx-pro-6000-pcie \
  -e MODEL=/model -e ENGRAM_TABLE_MEMORY="$ENGRAM_TABLE_MEMORY" \
  -e TP=4 -e DCP=1 -e PORT="$PORT" \
  -e MAX_MODEL_LEN="$MAX_MODEL_LEN" \
  -e MAX_NUM_SEQS="$MAX_NUM_SEQS" -e MAX_NUM_BATCHED_TOKENS="$MAX_NUM_BATCHED_TOKENS" \
  -e GPU_MEMORY_UTILIZATION="$GPU_MEMORY_UTILIZATION" -e JIT_MONITOR_MODE="$JIT_MONITOR_MODE" \
  -e HF_HUB_OFFLINE=1 "${NCCL_ENV_ARGS[@]}" "${TWOSHOT_ARGS[@]}" "${SHARE_ARGS[@]}" -e GLOO_SOCKET_IFNAME=lo \
  "$IMAGE_TAG" \
  --override-generation-config "$OVERRIDE_GEN" \
  --speculative-config "$OVERRIDE_SPEC" \
  ${EXTRA_ARGS:+"$EXTRA_ARGS"}

# vLLM's /health returns 503 while the engine loads and 200 when ready;
# curl -f treats both correctly. The first boot loads 476 G of weights plus
# the Engram tables, so the default timeout is generous.
deadline=$((SECONDS + READY_TIMEOUT))
while (( SECONDS < deadline )); do
  if "$ENGINE" inspect -f '{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null | grep -q exited; then
    echo "Container exited during startup; last lines:" >&2
    "$ENGINE" logs --tail 40 "$CONTAINER_NAME" 2>&1 || true
    exit 1
  fi
  if curl -fsS "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1; then
    # If we asked for the two-shot, confirm the engine actually activated it
    # instead of silently falling back to the PyNCCL ring (which still serves
    # correctly, just without the measured mid-band gain).
    if (( ${#TWOSHOT_ARGS[@]} > 0 )); then
      if "$ENGINE" logs "$CONTAINER_NAME" 2>&1 \
         | grep -qiE 'two-shot bf16 (initialization failed|max=off)'; then
        echo "WARN: TWOSHOT_MB=$TWOSHOT_MB requested but the two-shot did not activate (fell back to PyNCCL)." >&2
        echo "      Engine is healthy; throughput just matches the profile-default band. Inspect: $ENGINE logs $CONTAINER_NAME | grep -i two-shot" >&2
      fi
    fi
    echo "Ready: http://$BIND_ADDRESS:$PORT (model DeepSeek-V4.1-Flash)"
    exit 0
  fi
  sleep 5
done
echo "Not healthy after ${READY_TIMEOUT}s; inspect: $ENGINE logs $CONTAINER_NAME" >&2
"$ENGINE" logs --tail 40 "$CONTAINER_NAME" 2>&1 || true
exit 1