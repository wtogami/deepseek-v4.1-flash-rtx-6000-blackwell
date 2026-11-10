#!/usr/bin/env bash
# Download everything the Flare TP3 experiment needs, without touching GPUs.
#
#   ./scripts/flare-tp3/download.sh [--dry-run]
#
# Fetches:
#   - the recipe repo (20261105 folder; identical to the pinned commit except README)
#   - the NVIDIA Flare fork source at 78b18b1c
#   - NVIDIA's MXFP4 Engram shards 47-48 (~105 GB) to /nvme1
#   - llm-inference-bench v0.9.1 (the recipe's benchmark harness)
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    *) die "unknown argument: $1 (usage: $0 [--dry-run])" ;;
  esac
done

require_cmd git
require_cmd hf
require_cmd python3

mkdir -p "$FLARE_TP3_ROOT"

# ---------------------------------------------------------------- recipe repo
if [[ -d "$RECIPE_REPO/.git" ]]; then
  log "recipe repo present: $RECIPE_REPO ($(git -C "$RECIPE_REPO" rev-parse --short HEAD 2>/dev/null || echo unknown))"
else
  log "cloning recipe repo"
  if [[ "$DRY_RUN" == 1 ]]; then
    log "dry-run: git clone $RECIPE_REPO_URL $RECIPE_REPO"
  else
    git clone -q "$RECIPE_REPO_URL" "$RECIPE_REPO"
  fi
fi
if [[ "$DRY_RUN" != 1 ]]; then
  [[ -d "$RECIPE_DIR" ]] || die "recipe folder missing: $RECIPE_DIR"
  [[ -s "$RECIPE_DIR/source.patch" ]] || die "recipe source.patch missing"
  log "recipe folder: $RECIPE_DIR"
  log "  note: pinned $RECIPE_COMMIT differs from HEAD only in README.md (verified 2026-11-10)"
fi

# ----------------------------------------------------------------- flare repo
if [[ -d "$FLARE_SRC/.git" ]]; then
  if git -C "$FLARE_SRC" rev-parse --verify -q "$FLARE_COMMIT" >/dev/null; then
    log "flare repo present at $FLARE_COMMIT"
  else
    log "flare repo present but $FLARE_COMMIT is not fetched; fetching"
    if [[ "$DRY_RUN" == 1 ]]; then
      log "dry-run: git -C $FLARE_SRC fetch origin $FLARE_COMMIT && git -C $FLARE_SRC checkout $FLARE_COMMIT"
    else
      git -C "$FLARE_SRC" fetch -q origin "$FLARE_COMMIT"
      git -C "$FLARE_SRC" checkout -q "$FLARE_COMMIT"
    fi
  fi
else
  log "cloning flare repo"
  if [[ "$DRY_RUN" == 1 ]]; then
    log "dry-run: git clone $FLARE_REPO_URL $FLARE_SRC && git -C $FLARE_SRC checkout $FLARE_COMMIT"
  else
    git clone -q "$FLARE_REPO_URL" "$FLARE_SRC"
    git -C "$FLARE_SRC" checkout -q "$FLARE_COMMIT"
  fi
fi

# ------------------------------------------------------- NVIDIA MXFP4 Engram
mkdir -p "$NVFP4_DIR"
log "NVIDIA MXFP4 Engram shards -> $NVFP4_DIR"
if [[ "$DRY_RUN" == 1 ]]; then
  log "dry-run: hf download $NVFP4_REPO --revision $NVFP4_REVISION --include ${NVFP4_SHARDS[0]} --include ${NVFP4_SHARDS[1]} --include LICENSE --include README.md --local-dir $NVFP4_DIR"
else
  hf download "$NVFP4_REPO" --revision "$NVFP4_REVISION" \
    --include "${NVFP4_SHARDS[0]}" --include "${NVFP4_SHARDS[1]}" \
    --include LICENSE --include README.md \
    --local-dir "$NVFP4_DIR"
  python3 - "$NVFP4_DIR" "${NVFP4_SHARDS[@]}" <<'PY'
import sys
from pathlib import Path
root = Path(sys.argv[1])
expected = {"model-00047-of-00048.safetensors": 52382361720,
            "model-00048-of-00048.safetensors": 52383791632}
bad = []
for name, size in expected.items():
    p = root / name
    if not p.is_file():
        bad.append(f"missing {name}")
    elif p.stat().st_size != size:
        bad.append(f"{name}: {p.stat().st_size} != {size}")
if bad:
    print("SIZE CHECK FAILED: " + "; ".join(bad), file=sys.stderr)
    sys.exit(1)
print("MXFP4 Engram shard sizes OK (2 x ~52.4 GB)")
PY
fi

# ------------------------------------------------------------------ bench repo
if [[ -d "$BENCH_DIR/.git" ]]; then
  log "bench repo present: $BENCH_DIR"
else
  log "cloning llm-inference-bench $BENCH_TAG"
  if [[ "$DRY_RUN" == 1 ]]; then
    log "dry-run: git clone --branch $BENCH_TAG --depth 1 $BENCH_REPO_URL $BENCH_DIR"
  else
    git clone -q --branch "$BENCH_TAG" --depth 1 "$BENCH_REPO_URL" "$BENCH_DIR"
  fi
fi

log "download stage complete"
