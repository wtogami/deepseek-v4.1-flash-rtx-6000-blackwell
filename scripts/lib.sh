#!/usr/bin/env bash
# Shared helpers for the CSF download/switch/A-B scripts.
# Sourced by scripts/*.sh; intentionally sets strict mode for the caller.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
RECIPE_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
LOG_DIR="${LOG_DIR:-$RECIPE_DIR/state/logs}"
mkdir -p "$LOG_DIR"

PORT="${PORT:-8000}"
CONTAINER_NAME="${CONTAINER_NAME:-ds41}"

die() { echo "ERROR: $*" >&2; exit 2; }
log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*" >&2; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "$1 is required on PATH"
}

require_unlimited_memlock() {
  local limit
  limit="$(ulimit -l)"
  if [[ "$limit" != unlimited ]]; then
    cat >&2 <<EOF
RAM Engram needs an unlimited RLIMIT_MEMLOCK (current: $limit).
A plain login gets systemd's DefaultLimitMEMLOCK (8 GiB here), which is below
the ~227 GiB the Engram tables need, so re-run from a shell created by root:
  prlimit --memlock=unlimited:unlimited -- runuser -u $(id -un) -- bash
then re-run it (verify: ulimit -l  ->  unlimited).
EOF
    exit 2
  fi
}

engine_health() {
  curl -fsS -m 5 "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1
}

wait_health() {
  local timeout="${1:-1800}" waited=0
  while (( waited < timeout )); do
    if engine_health; then return 0; fi
    sleep 5
    waited=$((waited + 5))
  done
  return 1
}

kv_capacity() {
  podman logs "$CONTAINER_NAME" 2>&1 \
    | grep -oE 'GPU KV cache size: [0-9,]+ tokens' \
    | tail -1 | tr -dc '0-9' || true
}

# True when the engine started with the mxfp4_csf loader. The log text is
# captured first: `podman logs | grep -q` would let grep exit early, kill the
# writer with SIGPIPE, and make the pipeline look failed under pipefail.
csf_loader_active() {
  local txt
  txt="$(podman logs "$CONTAINER_NAME" 2>&1 || true)"
  case "$txt" in
    *mxfp4_csf*) return 0 ;;
    *) return 1 ;;
  esac
}

checkpoint_layout() {
  local d="$1"
  if [[ -s "$d/manifest.json" \
        && -s "$d/metadata/model.safetensors.index.json" \
        && -d "$d/tensors" ]]; then
    echo csf
  elif [[ -s "$d/model.safetensors.index.json" ]]; then
    echo flat
  else
    echo missing
  fi
}

csf_complete() {
  local d="$1"
  python3 - "$d" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
manifest = root / "manifest.json"
if not manifest.is_file():
    sys.exit(1)
try:
    data = json.loads(manifest.read_text())
except (OSError, ValueError):
    sys.exit(1)
shards = data.get("shards") or []
if not shards:
    sys.exit(1)
for shard in shards:
    path = root / "tensors" / shard["file"]
    expected = shard.get("target_file_bytes")
    if not path.is_file():
        sys.exit(1)
    if expected is not None and path.stat().st_size != expected:
        sys.exit(1)
sys.exit(0)
PY
}

# Serialize runs without leaking the lock into the container. A fd-based flock
# survives here because `podman run -d` hands its monitor (conmon) the inherited
# descriptor, so the lock would outlive the script for as long as the engine
# runs. A pidfile does not have that problem: it goes stale with its owner.
acquire_lock() {
  local name="$1"
  local pidfile="$LOG_DIR/$name.pid"
  local old=""
  if [[ -s "$pidfile" ]]; then
    old="$(tr -dc '0-9' <"$pidfile")"
    if [[ -n "$old" ]] && kill -0 "$old" 2>/dev/null \
       && grep -q "$name" "/proc/$old/cmdline" 2>/dev/null; then
      die "another $name process is running (pid $old, $pidfile)"
    fi
  fi
  printf '%s\n' "$$" >"$pidfile"
}
