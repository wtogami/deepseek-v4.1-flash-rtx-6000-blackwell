#!/usr/bin/env bash
# Export the Flare TP3 package. Requires the engine stopped: the export tunes
# kernels and captures CUDA graphs on the exact cards it will serve on.
#
#   ./scripts/flare-tp3/export.sh                 # checks + prints the command
#   ./scripts/flare-tp3/export.sh --run            # requires ds41 stopped
#   ./scripts/flare-tp3/export.sh --run --stop-engine
#
# Env: GPUS=1,2,3  HOT=300  PREFILL=4096  POWER_LIMIT=325
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

RUN=0
STOP_ENGINE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --run) RUN=1; shift ;;
    --stop-engine) STOP_ENGINE=1; shift ;;
    --dry-run) RUN=0; shift ;;
    *) die "unknown argument: $1 (usage: $0 [--run] [--stop-engine])" ;;
  esac
done

HOT="${HOT:-300}"
PREFILL="${PREFILL:-4096}"
MIN_FREE_GIB="${MIN_FREE_GIB:-500}"

require_cmd podman
require_cmd nvidia-smi
require_unlimited_memlock

# --------------------------------------------------------------- engine gate
if [[ "$RUN" == 1 ]]; then
  if engine_health; then
    if [[ "$STOP_ENGINE" == 1 ]]; then
      log "stopping ds41 (requested with --stop-engine)"
      "$PROJECT_DIR/stop.sh"
    else
      die "ds41 is healthy on :8000. Stop it first (./stop.sh) or pass --stop-engine."
    fi
  fi
  if [[ "$(engine_container_state)" != absent ]]; then
    die "container ds41 still exists ($(engine_container_state)); export needs the GPUs idle"
  fi
elif engine_health; then
  log "NOTE: ds41 is healthy; --run will require it stopped (or --stop-engine)"
fi

# --------------------------------------------------------------- GPU checks
mismatch="$(gpu_power_mismatch)"
if [[ -n "$mismatch" ]]; then
  if [[ "$RUN" == 1 && "${ALLOW_POWER_MISMATCH:-0}" != 1 ]]; then
    die "power limits differ from ${POWER_LIMIT} W: $(echo "$mismatch" | tr '\n' '; '). Fix with sudo nvidia-smi -i N -pl ${POWER_LIMIT}, or set ALLOW_POWER_MISMATCH=1."
  fi
  log "WARN: power limits differ from ${POWER_LIMIT} W: $(echo "$mismatch" | tr '\n' '; ')"
fi
busy="$(gpu_compute_apps)"
if [[ -n "$busy" ]]; then
  if [[ "$RUN" == 1 && "${ALLOW_GPU_BUSY:-0}" != 1 ]]; then
    die "GPU compute processes are still running:
$busy"
  fi
  log "NOTE: GPU compute processes are running (ds41); --run will refuse until they are gone"
fi

# --------------------------------------------------------------- artifacts
need() { if [[ "$RUN" == 1 ]]; then die "$1"; else log "WARN: $1"; fi; }
[[ -f "$CKPT_VIEW/.view-ok" ]] || need "checkpoint view not validated: $CKPT_VIEW (run checkpoint-view.sh)"
for n in 1 47 48; do
  [[ -e "$CKPT_VIEW/model-000$(printf '%02d' "$n")-of-00048.safetensors" ]] \
    || need "checkpoint view is missing shard $n"
done
[[ -x "$FLARE_SRC/flare/target/release/flare" ]] || need "flare binary missing (run build.sh --run)"
[[ -x "$FLARE_SRC/.venv/bin/ignition" ]] || need "ignition venv missing (run build.sh --run)"

mkdir -p "$FLARE_CACHE"
IMAGE="$(work_image)"
free="$(free_gib "$FLARE_CACHE")"
(( free >= MIN_FREE_GIB )) || need "need >= ${MIN_FREE_GIB} GiB free for the package under $FLARE_CACHE (have ${free} GiB)"

log "checkpoint: $CKPT_VIEW"
log "image: $IMAGE"
log "package cache: $FLARE_CACHE (${free} GiB free)"
log "GPUs: $GPUS (container $CONTAINER_GPUS)  HOT=$HOT PREFILL=$PREFILL"

mapfile -t DEVICE_ARGS < <(gpu_device_args)
CMD=(podman run --rm -i
  "${DEVICE_ARGS[@]}"
  --security-opt label=disable --security-opt seccomp=unconfined
  --ipc=host --network host --cap-add IPC_LOCK
  --ulimit memlock=-1:-1
  -v "$FLARE_SRC:/work"
  -v "$RECIPE_DIR:/recipe:ro"
  -v "$CKPT_VIEW:/ckpt:ro"
  -v "$DS_DIR:$DS_DIR:ro"
  -v "$NVFP4_DIR:$NVFP4_DIR:ro"
  -v "$FLARE_CACHE:/root/.cache/flare"
  -v "$FLARE_CONFIG:/root/.config/flare"
  -w /work
  -e CUDA_HOME=/usr/local/cuda
  -e LD_LIBRARY_PATH=/usr/local/cuda/lib64:/usr/local/nvidia/lib64
  -e PATH=/usr/local/cuda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
  -e CKPT=/ckpt -e GPUS="$CONTAINER_GPUS" -e HOT="$HOT" -e PREFILL="$PREFILL"
  "$IMAGE" bash -lc 'bash /recipe/export.sh')

if [[ "$RUN" != 1 ]]; then
  log "dry-run: ${CMD[*]}"
  exit 0
fi

LOG="$STATE_DIR/flare-export-$(date +%Y%m%d-%H%M%S).log"
log "exporting; log: $LOG"
rc=0
if [[ -n "${EXPORT_TIMEOUT:-}" ]]; then
  # Tuning that deadlocks waits on torch's 2 h Gloo timeout; cap the wall clock
  # instead so a retry can be scheduled. EXPORT_TIMEOUT is in seconds.
  log "wall-clock cap: ${EXPORT_TIMEOUT}s"
  timeout -k 120 "$EXPORT_TIMEOUT" "${CMD[@]}" 2>&1 | tee "$LOG" || rc=$?
else
  "${CMD[@]}" 2>&1 | tee "$LOG" || rc=$?
fi

# A killed or timed-out run can leave the container holding ~95 GiB per card.
leftover="$(podman ps --quiet --filter "ancestor=$IMAGE" 2>/dev/null || true)"
if [[ -n "$leftover" ]]; then
  log "removing leftover export container: $(tr ' ' ',' <<<"$leftover")"
  podman rm -f $leftover >/dev/null 2>&1 || true
fi
busy="$(gpu_compute_apps)"
if [[ -n "$busy" ]]; then
  log "WARN: GPU compute processes still present after the run:"
  echo "$busy" >&2
fi
(( rc == 0 )) || die "export failed with rc=$rc (see $LOG)"

pkg="$(find "$FLARE_CACHE/packages/models" -maxdepth 3 -type d -name 'gb202-tp3-*' 2>/dev/null | sort | tail -1 || true)"
[[ -n "$pkg" ]] || die "export finished but no gb202-tp3-* package was found under $FLARE_CACHE/packages/models"
log "package: $pkg"
log "serve it with: ./scripts/flare-tp3/serve.sh --run"
