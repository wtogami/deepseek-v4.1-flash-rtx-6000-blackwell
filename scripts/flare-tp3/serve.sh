#!/usr/bin/env bash
# Serve the exported Flare TP3 package on GPUs 1,2,3, port 15015.
#
#   ./scripts/flare-tp3/serve.sh --run
#   ./scripts/flare-tp3/serve.sh --stop
#
# The engine (ds41) must be stopped; Flare and vLLM cannot share the cards.
# Env: PACKAGE (name or path under ~/.cache/flare), GPUS=1,2,3, PORT=15015.
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

RUN=0
STOP=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --run) RUN=1; shift ;;
    --stop) STOP=1; shift ;;
    --dry-run) RUN=0; shift ;;
    *) die "unknown argument: $1 (usage: $0 [--run|--stop])" ;;
  esac
done

require_cmd podman

if [[ "$STOP" == 1 ]]; then
  podman rm -f "$FLARE_CONTAINER_NAME" >/dev/null 2>&1 || true
  log "stopped $FLARE_CONTAINER_NAME"
  exit 0
fi

require_unlimited_memlock
if [[ "$RUN" == 1 ]]; then
  engine_health && die "ds41 is healthy on :8000; stop it first (./stop.sh)"
  [[ "$(engine_container_state)" == absent ]] || die "container ds41 still exists ($(engine_container_state))"
  port_in_use "$PORT" && die "port $PORT is already in use"
elif engine_health; then
  log "NOTE: ds41 is healthy; --run will require it stopped"
fi

# Resolve the package: name (Flare looks it up in its cache) or a path under
# the cache, which is mounted at /root/.cache/flare in the container.
if [[ -z "${PACKAGE:-}" ]]; then
  host_pkg="$(find "$FLARE_CACHE/packages/models" -maxdepth 3 -type d -name 'gb202-tp3-*' 2>/dev/null | sort | tail -1 || true)"
  if [[ -n "$host_pkg" ]]; then
    PACKAGE="/root/.cache/flare/${host_pkg#"$FLARE_CACHE"/}"
  elif [[ "$RUN" == 1 ]]; then
    die "no exported package found under $FLARE_CACHE/packages/models (run export.sh --run)"
  else
    PACKAGE="<no package yet>"
    log "WARN: no exported package yet; the printed command is a placeholder"
  fi
elif [[ "$PACKAGE" == "$FLARE_CACHE"/* ]]; then
  PACKAGE="/root/.cache/flare/${PACKAGE#"$FLARE_CACHE"/}"
fi

mapfile -t DEVICE_ARGS < <(gpu_device_args)
if [[ "$RUN" == 1 ]]; then
  # Record the local development publisher so a detached container never waits
  # on the first-run trust prompt. No-op when ignition has not written a profile.
  log "trust: $(seed_trust)"
fi
CMD=(podman run -d --name "$FLARE_CONTAINER_NAME" --replace
  "${DEVICE_ARGS[@]}"
  --security-opt label=disable --security-opt seccomp=unconfined
  --ipc=host --network host --cap-add IPC_LOCK
  --ulimit memlock=-1:-1
  -v "$FLARE_SRC:/work"
  -v "$RECIPE_DIR:/recipe:ro"
  -v "$FLARE_CACHE:/root/.cache/flare"
  -v "$FLARE_CONFIG:/root/.config/flare"
  -w /work
  -e CUDA_HOME=/usr/local/cuda
  -e LD_LIBRARY_PATH=/usr/local/cuda/lib64:/usr/local/nvidia/lib64
  -e PATH=/usr/local/cuda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
  -e PACKAGE="$PACKAGE" -e GPUS="$CONTAINER_GPUS" -e PORT="$PORT" -e HOST=127.0.0.1
  "$CUDA_IMAGE" bash -lc 'bash /recipe/serve.sh')

if [[ "$RUN" != 1 ]]; then
  log "dry-run: ${CMD[*]}"
  exit 0
fi

LOG="$STATE_DIR/flare-serve-$(date +%Y%m%d-%H%M%S).log"
log "starting Flare ($PACKAGE) on GPUs $GPUS; log: $LOG"
"${CMD[@]}" 2>&1 | tee "$LOG"

log "waiting for http://127.0.0.1:$PORT/health"
if ! wait_http "http://127.0.0.1:$PORT/health" 900; then
  podman logs --tail 60 "$FLARE_CONTAINER_NAME" >&2 || true
  die "Flare did not become healthy"
fi
curl -fsS "http://127.0.0.1:$PORT/health" || true
echo
podman logs --tail 20 "$FLARE_CONTAINER_NAME" 2>&1 | tail -20 || true
echo "KV: $(curl -fsS "http://127.0.0.1:$PORT/metrics" 2>/dev/null | awk '/^flare_total_kv_tokens/{print $2; exit}' || echo unknown)"
log "Flare is healthy on :$PORT"
