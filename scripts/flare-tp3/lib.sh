#!/usr/bin/env bash
# Shared paths and helpers for the Flare TP3 experiment.
# Sourced by scripts/flare-tp3/*.sh; sets strict mode for the caller.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd)"

FLARE_TP3_ROOT="${FLARE_TP3_ROOT:-$HOME/flare-tp3}"
RECIPE_REPO="${RECIPE_REPO:-$FLARE_TP3_ROOT/recipe}"
RECIPE_SUBDIR="DeepSeek-V4.1-Flash Flare-tp3-20261105"
RECIPE_DIR="$RECIPE_REPO/$RECIPE_SUBDIR"
FLARE_SRC="${FLARE_SRC:-$FLARE_TP3_ROOT/flare}"
CKPT_VIEW="${CKPT_VIEW:-$FLARE_TP3_ROOT/ckpt}"
DS_DIR="${DS_DIR:-$HOME/models/DeepSeek-V4.1-Flash}"
NVFP4_DIR="${NVFP4_DIR:-/nvme1/models/DeepSeek-V4.1-Flash-1017-NVFP4}"
FLARE_CACHE="${FLARE_CACHE:-$HOME/.cache/flare}"
FLARE_CONFIG="${FLARE_CONFIG:-$FLARE_TP3_ROOT/config}"
BENCH_DIR="${BENCH_DIR:-$FLARE_TP3_ROOT/llm-inference-bench}"
CUDA_IMAGE="${CUDA_IMAGE:-docker.io/nvidia/cuda:13.2.1-devel-ubuntu24.04}"
GPUS="${GPUS:-1,2,3}"
CONTAINER_GPUS="${CONTAINER_GPUS:-0,1,2}"
POWER_LIMIT="${POWER_LIMIT:-325}"
PORT="${PORT:-15015}"
FLARE_CONTAINER_NAME="${FLARE_CONTAINER_NAME:-flare-tp3}"
STATE_DIR="${STATE_DIR:-$PROJECT_DIR/state/logs}"
mkdir -p "$STATE_DIR" "$FLARE_CONFIG"

RECIPE_REPO_URL="https://github.com/BoxTops4Coochie/RTX-PRO-6000-TP3-Inference-Recipes.git"
RECIPE_COMMIT="a5269231a570286898ba041690d524fdf1769c7e"
FLARE_REPO_URL="https://github.com/NVIDIA/flare-local-inference.git"
FLARE_COMMIT="78b18b1c"
BENCH_REPO_URL="https://github.com/local-inference-lab/llm-inference-bench.git"
BENCH_TAG="v0.9.1"
NVFP4_REPO="nvidia/DeepSeek-V4.1-Flash-1017-NVFP4"
NVFP4_REVISION="3ae9c0d3fbbea5370bd06e679d22044db15883f1"
NVFP4_SHARDS=("model-00047-of-00048.safetensors" "model-00048-of-00048.safetensors")
NVFP4_SHARD_BYTES=(52382361720 52383791632)

die() { echo "ERROR: $*" >&2; exit 2; }
log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*" >&2; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "$1 is required on PATH"
}

engine_health() {
  curl -fsS -m 5 "http://127.0.0.1:8000/health" >/dev/null 2>&1
}

engine_container_state() {
  podman inspect -f '{{.State.Status}}' ds41 2>/dev/null || echo absent
}

require_unlimited_memlock() {
  local limit
  limit="$(ulimit -l)"
  if [[ "$limit" != unlimited ]]; then
    cat >&2 <<EOF
Flare pins ~150 GB of host memory; RLIMIT_MEMLOCK must be unlimited (current: $limit).
A plain login gets systemd's DefaultLimitMEMLOCK (8 GiB here). Run from:
  prlimit --memlock=unlimited:unlimited -- runuser -u $(id -un) -- bash
EOF
    exit 2
  fi
}

gpu_indices() {
  tr ',' ' ' <<<"$GPUS"
}

gpu_device_args() {
  local idx
  for idx in $(gpu_indices); do
    printf '%s\n' --device "nvidia.com/gpu=$idx"
  done
}

gpu_power_mismatch() {
  local idx limit
  while read -r idx limit; do
    idx="${idx// /}"; limit="${limit// /}"
    [[ -n "$idx" ]] || continue
    awk -v a="$limit" -v b="$POWER_LIMIT" 'BEGIN { exit !(a+0 == b+0) }' || echo "$idx $limit"
  done < <(nvidia-smi --query-gpu=index,power.limit --format=csv,noheader,nounits)
}

gpu_compute_apps() {
  nvidia-smi --query-compute-apps=gpu_uuid,pid,process_name,used_memory --format=csv,noheader 2>/dev/null || true
}

free_gib() {
  df -Pk "$1" | awk 'NR==2 {printf "%d", $4/1024/1024}'
}

seed_trust() {
  # Flare asks once, interactively, to trust the local development publisher.
  # In a detached container there is no terminal, so record the acceptance from
  # the profile that `ignition export` wrote beside the config. The store schema
  # is the one flare's trust.rs reads: fingerprint = sha256 of the raw key bytes.
  python3 - "$FLARE_CONFIG" <<'PY'
import hashlib, json, sys
from pathlib import Path
cfg = Path(sys.argv[1])
profile = cfg / "development-publisher.json"
store = cfg / "trust.toml"
if not profile.is_file():
    print(f"no publisher profile at {profile}; flare will prompt on first run")
    sys.exit(0)
rows = json.loads(profile.read_text())
rows = rows if isinstance(rows, list) else [rows]
for row in rows:
    key = row.get("public_key")
    if isinstance(key, str):
        raw = bytes.fromhex(key)
    elif isinstance(key, list):
        raw = bytes(key)
    else:
        continue
    if len(raw) != 32:
        continue
    fp = hashlib.sha256(raw).hexdigest()
    ns = row.get("namespace") or "local-development"
    name = row.get("name") or "Local development signer"
    if store.is_file() and fp in store.read_text():
        print(f"trust already recorded for {fp[:12]}")
        sys.exit(0)
    lines = [
        "[[trusted]]",
        f'fingerprint = "{fp}"',
        f'namespace = "{ns}"',
        f'public_key = "{raw.hex()}"',
        f'name = "{name}"',
        'identity = "profile"',
    ]
    nl = chr(10)
    with store.open("a", encoding="utf-8") as fh:
        fh.write(nl.join(lines) + nl)
    print(f"trusted {ns} ({fp[:12]}) in {store}")
PY
}

wait_http() {
  local url="$1" timeout="${2:-600}" waited=0
  while (( waited < timeout )); do
    if curl -fsS -m 5 "$url" >/dev/null 2>&1; then return 0; fi
    sleep 5
    waited=$((waited + 5))
  done
  return 1
}

port_in_use() {
  ss -ltn 2>/dev/null | awk '{print $4}' | grep -Eq "[:.]${1}$"
}
