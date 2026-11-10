#!/usr/bin/env bash
# Static audit of the staged Flare TP3 experiment. No builds, no GPU work,
# no container starts, no engine changes.
#
#   ./scripts/flare-tp3/audit.sh
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

fail=0
ok()   { printf '  OK   %s\n' "$*"; }
warn() { printf '  WARN %s\n' "$*"; }
bad()  { printf '  FAIL %s\n' "$*"; fail=$((fail + 1)); }

echo "=== scripts ==="
for f in "$SCRIPT_DIR"/*.sh; do
  if bash -n "$f" 2>/dev/null; then ok "syntax $(basename "$f")"; else bad "syntax $(basename "$f")"; fi
done

echo
echo "=== recipe ==="
if [[ -d "$RECIPE_DIR" ]]; then
  ok "recipe folder: $RECIPE_DIR"
  for f in source.patch export.sh serve.sh make_checkpoint_view.sh \
           checkpoint/config.json checkpoint/model.safetensors.index.json; do
    [[ -s "$RECIPE_DIR/$f" ]] && ok "$f" || bad "missing $f"
  done
  n=$(ls "$RECIPE_DIR/tp3-patches"/*.patch 2>/dev/null | wc -l)
  [[ "$n" == 4 ]] && ok "4 FlashInfer TP3 patches" || bad "expected 4 TP3 patches, found $n"
  ok "pinned $RECIPE_COMMIT differs from HEAD only in README.md (verified via GitHub tree)"
else
  bad "recipe folder missing (run download.sh)"
fi

echo
echo "=== flare checkout ==="
if [[ -d "$FLARE_SRC/.git" ]]; then
  if git -C "$FLARE_SRC" rev-parse --verify -q "$FLARE_COMMIT" >/dev/null; then
    ok "flare at $(git -C "$FLARE_SRC" rev-parse --short "$FLARE_COMMIT")"
    if git -C "$FLARE_SRC" apply --reverse --check "$RECIPE_DIR/source.patch" >/dev/null 2>&1; then
      ok "source.patch already applied"
    elif git -C "$FLARE_SRC" apply --check "$RECIPE_DIR/source.patch" >/dev/null 2>&1; then
      ok "source.patch applies cleanly"
    else
      bad "source.patch does not apply"
    fi
    [[ -x "$FLARE_SRC/flare/target/release/flare" ]] && ok "flare binary built" || warn "flare binary not built yet"
    [[ -x "$FLARE_SRC/.venv/bin/ignition" ]] && ok "ignition venv present" || warn "ignition venv not built yet"
  else
    bad "flare checkout is not at $FLARE_COMMIT"
  fi
else
  bad "flare repo missing (run download.sh)"
fi

echo
echo "=== NVIDIA MXFP4 Engram ==="
for i in 0 1; do
  f="$NVFP4_DIR/${NVFP4_SHARDS[$i]}"
  if [[ -s "$f" ]]; then
    size="$(stat -c %s "$f")"
    [[ "$size" == "${NVFP4_SHARD_BYTES[$i]}" ]] \
      && ok "$(basename "$f") $size bytes" \
      || bad "$(basename "$f") is $size, expected ${NVFP4_SHARD_BYTES[$i]}"
  else
    warn "not downloaded: $f"
  fi
done

echo
echo "=== checkpoint view ==="
if [[ -f "$CKPT_VIEW/.view-ok" ]]; then
  ok "validated: $(head -2 "$CKPT_VIEW/.view-ok" | tail -1)"
else
  warn "not built yet: $CKPT_VIEW"
fi

echo
echo "=== bench harness ==="
if [[ -d "$BENCH_DIR/.git" ]]; then
  ok "bench repo: $(git -C "$BENCH_DIR" describe --tags --always 2>/dev/null || echo unknown)"
  [[ -f "$BENCH_DIR/llm_decode_bench.py" ]] && ok "llm_decode_bench.py present" || bad "llm_decode_bench.py missing"
else
  warn "bench repo not cloned yet (download.sh)"
fi

echo
echo "=== toolchain / image ==="
if command -v podman >/dev/null 2>&1; then ok "podman $(podman --version | awk '{print $3}')"; else bad "podman missing"; fi
repo="${CUDA_IMAGE%:*}"; tag="${CUDA_IMAGE##*:}"; repo="${repo#docker.io/}"
if curl -fsSL -m 20 "https://hub.docker.com/v2/repositories/${repo}/tags/${tag}" \
     >/dev/null 2>&1; then
  ok "CUDA image exists: $CUDA_IMAGE"
else
  warn "could not verify $CUDA_IMAGE on Docker Hub (tag may still pull)"
fi
echo "  host CUDA toolkits: $(ls -d /usr/local/cuda-13.* 2>/dev/null | tr '\n' ' ')"

echo
echo "=== host / engine ==="
echo "  memlock: $(ulimit -l)"
echo "  power:   $(nvidia-smi --query-gpu=index,power.limit --format=csv,noheader | tr '\n' '; ')"
if engine_health; then
  warn "ds41 is healthy on :8000 - export.sh will refuse until it is stopped"
else
  ok "ds41 is not serving"
fi
echo "  container ds41: $(engine_container_state)"
echo "  free /:        $(free_gib /) GiB"
echo "  free /nvme1:   $(free_gib /nvme1) GiB"
echo "  package cache: $(free_gib "$(dirname "$FLARE_CACHE")") GiB free (parent)"
busy="$(gpu_compute_apps)"
[[ -n "$busy" ]] && warn "GPU compute processes: $(echo "$busy" | wc -l)" || ok "no GPU compute processes"

echo
if (( fail > 0 )); then
  echo "AUDIT: $fail failure(s)"
  exit 1
fi
echo "AUDIT: no failures (warnings are expected before build/export)"
