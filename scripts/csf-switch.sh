#!/usr/bin/env bash
# Restart the engine with the original checkpoint or the CSF container.
#
#   ./scripts/csf-switch.sh original [--max-model-len N] [--dry-run]
#   ./scripts/csf-switch.sh csf      [--max-model-len N] [--dry-run]
#
# The switch is a REPLACE=1 start.sh boot; it waits for health and prints the
# KV capacity from the startup log. The launcher derives mxfp4_csf from the
# CSF container's manifest.json, so no extra quantization flags are needed.
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

MODE=""
DRY_RUN=0
MAXLEN="${MAX_MODEL_LEN:--1}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    original|csf) MODE="$1"; shift ;;
    --max-model-len) MAXLEN="${2:?--max-model-len needs a value}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    *) die "unknown argument: $1 (usage: $0 {original|csf} [--max-model-len N] [--dry-run])" ;;
  esac
done
[[ -n "$MODE" ]] || die "usage: $0 {original|csf} [--max-model-len N] [--dry-run]"

ORIGINAL_DIRECTORY="${ORIGINAL_DIRECTORY:-$HOME/models/DeepSeek-V4.1-Flash}"
CSF_DIRECTORY="${CSF_DIRECTORY:-/nvme1/models/DeepSeek-V4.1-Flash-1017-lossless-CSF}"

if [[ "$MODE" == csf ]]; then
  DIRECTORY="$CSF_DIRECTORY"; CSF_FLAG=1; WANT_LAYOUT=csf
else
  DIRECTORY="$ORIGINAL_DIRECTORY"; CSF_FLAG=0; WANT_LAYOUT=flat
fi

layout="$(checkpoint_layout "$DIRECTORY")"
[[ "$layout" == "$WANT_LAYOUT" ]] || die "checkpoint at $DIRECTORY is '$layout', expected '$WANT_LAYOUT'"

require_cmd podman
require_cmd curl
require_unlimited_memlock

log "switch to $MODE: $DIRECTORY (MAX_MODEL_LEN=$MAXLEN)"
if [[ "$DRY_RUN" == 1 ]]; then
  log "dry-run: would run: (cd $RECIPE_DIR && REPLACE=1 CSF=$CSF_FLAG MAX_MODEL_LEN=$MAXLEN ./start.sh)"
  exit 0
fi

acquire_lock csf-switch
( cd "$RECIPE_DIR" && REPLACE=1 CSF="$CSF_FLAG" MAX_MODEL_LEN="$MAXLEN" ./start.sh ) \
  2>&1 | tee -a "$LOG_DIR/switch-$(date +%Y%m%d-%H%M%S).log"

wait_health 60 || die "engine did not become healthy after start.sh returned"
kv="$(kv_capacity)"
[[ -n "$kv" ]] || die "could not read 'GPU KV cache size' from the engine log"
log "engine healthy; KV capacity: $kv tokens"

if [[ "$MODE" == csf ]]; then
  if csf_loader_active; then
    log "mxfp4_csf loader confirmed in the startup configuration"
  else
    log "WARNING: mxfp4_csf not found in the startup configuration; run DRY_RUN=1 CSF=1 ./start.sh to inspect"
  fi
fi

echo "$kv"
