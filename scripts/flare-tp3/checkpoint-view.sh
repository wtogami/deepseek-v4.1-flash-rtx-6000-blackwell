#!/usr/bin/env bash
# Assemble and validate the TP3 checkpoint view:
#   DeepSeek official shards 1-46 (symlinked from our flat checkpoint)
#   + NVIDIA MXFP4 Engram shards 47-48
#   + the recipe's corrected config.json / model.safetensors.index.json
#
#   ./scripts/flare-tp3/checkpoint-view.sh [--dry-run] [--force]
#
# Symlinks only; no tensor data is copied.
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

DRY_RUN=0
FORCE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --force) FORCE=1; shift ;;
    *) die "unknown argument: $1 (usage: $0 [--dry-run] [--force])" ;;
  esac
done

[[ -s "$DS_DIR/model.safetensors.index.json" ]] \
  || { [[ "$DRY_RUN" == 1 ]] && log "WARN: official checkpoint index missing under $DS_DIR" || die "official checkpoint index missing under $DS_DIR"; }
for i in 0 1; do
  f="$NVFP4_DIR/${NVFP4_SHARDS[$i]}"
  if [[ -s "$f" ]]; then
    size="$(stat -c %s "$f")"
    if [[ "$size" != "${NVFP4_SHARD_BYTES[$i]}" ]]; then
      if [[ "$DRY_RUN" == 1 ]]; then
        log "WARN: $(basename "$f") is $size bytes, expected ${NVFP4_SHARD_BYTES[$i]} (download in progress?)"
      else
        die "$f is $size bytes, expected ${NVFP4_SHARD_BYTES[$i]}"
      fi
    fi
  elif [[ "$DRY_RUN" == 1 ]]; then
    log "WARN: MXFP4 Engram shard not present yet: $f"
  else
    die "MXFP4 Engram shard missing: $f (run download.sh)"
  fi
done
[[ -x "$RECIPE_DIR/make_checkpoint_view.sh" || -f "$RECIPE_DIR/make_checkpoint_view.sh" ]] \
  || die "make_checkpoint_view.sh missing under $RECIPE_DIR"

if [[ -f "$CKPT_VIEW/.view-ok" && "$FORCE" != 1 ]]; then
  log "checkpoint view already validated: $CKPT_VIEW"
  cat "$CKPT_VIEW/.view-ok"
  exit 0
fi

if [[ "$DRY_RUN" == 1 ]]; then
  log "dry-run: $RECIPE_DIR/make_checkpoint_view.sh $DS_DIR $NVFP4_DIR $CKPT_VIEW"
  exit 0
fi

LOG="$STATE_DIR/flare-checkpoint-view.log"
log "building checkpoint view: $CKPT_VIEW"
bash "$RECIPE_DIR/make_checkpoint_view.sh" "$DS_DIR" "$NVFP4_DIR" "$CKPT_VIEW" 2>&1 | tee "$LOG"

# The script's own check is authoritative; keep its last line as the stamp.
VALIDATION="$(tail -2 "$LOG" | head -1)"
{
  echo "validated $(date -Is)"
  echo "$VALIDATION"
} > "$CKPT_VIEW/.view-ok"

log "checkpoint view ready: $CKPT_VIEW"
echo "$VALIDATION"
