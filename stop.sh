#!/usr/bin/env bash
# Stop and remove the serving container, leaving checkpoint, state and kernel
# caches in place so the next boot reuses them.
set -euo pipefail

CONTAINER_NAME="${CONTAINER_NAME:-ds41}"
# The engine default grace is 10s and this workload does not fit inside it. A
# four-rank vLLM process group with captured CUDA graphs needs longer to drain
# in-flight requests; the SIGTERM handler kills the whole group, so the wait
# is for the ranks, not for a supervisor. SHORTER is fine on a box where
# nothing is in flight. Override with STOP_TIMEOUT.
STOP_TIMEOUT="${STOP_TIMEOUT:-90}"

if command -v podman >/dev/null 2>&1; then ENGINE=podman; else ENGINE=docker; fi
if ! command -v "$ENGINE" >/dev/null 2>&1; then
  echo "Neither podman nor docker is on PATH." >&2; exit 2
fi

if ! "$ENGINE" inspect -f '{{.State.Status}}' "$CONTAINER_NAME" >/dev/null 2>&1; then
  echo "No container named $CONTAINER_NAME is present. Containers on this host:" >&2
  "$ENGINE" ps -a --format '  {{.Names}}  {{.Status}}' >&2 || true
  exit 1
fi

"$ENGINE" stop --time "$STOP_TIMEOUT" "$CONTAINER_NAME" >/dev/null
"$ENGINE" rm "$CONTAINER_NAME" >/dev/null
echo "Stopped and removed $CONTAINER_NAME; checkpoint, state and kernel caches kept."