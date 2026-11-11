#!/usr/bin/env bash
# Build the patched Flare fork inside the CUDA container.
#
#   ./scripts/flare-tp3/build.sh            # print the plan (no container)
#   ./scripts/flare-tp3/build.sh --run      # build (first run 30-90 min)
#
# The host has no passwordless sudo, so everything runs in a container. Prefer
# the image from image.sh (CUDA + compilers + uv + Rust already inside); with
# the plain CUDA devel image the script installs them first. CUDA 13.2.1 is
# used rather than the recipe's stated 13.1 because the fork's lock file
# resolves torch==2.14.1+cu132 and cuda-python==13.3.1. The repo and the cargo
# and uv caches are bind-mounted, so a retry resumes instead of restarting.
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --run) RUN=1; shift ;;
    --dry-run) RUN=0; shift ;;
    *) die "unknown argument: $1 (usage: $0 [--run])" ;;
  esac
done

require_cmd podman
[[ -d "$FLARE_SRC/.git" ]] || die "flare repo missing: $FLARE_SRC (run download.sh)"
[[ -d "$RECIPE_DIR" ]] || die "recipe missing: $RECIPE_DIR (run download.sh)"
git -C "$FLARE_SRC" rev-parse --verify -q "$FLARE_COMMIT" >/dev/null \
  || die "flare repo is not at $FLARE_COMMIT (run download.sh)"

if git -C "$FLARE_SRC" apply --reverse --check "$RECIPE_DIR/source.patch" >/dev/null 2>&1; then
  PATCH_STATE="already applied"
elif git -C "$FLARE_SRC" apply --check "$RECIPE_DIR/source.patch" >/dev/null 2>&1; then
  PATCH_STATE="applies cleanly"
else
  die "source.patch neither applies nor is already applied; check the flare checkout"
fi

mkdir -p "$FLARE_TP3_ROOT/cache/cargo/registry" "$FLARE_TP3_ROOT/cache/uv"

IMAGE="$(work_image)"
log "flare:  $FLARE_SRC ($(git -C "$FLARE_SRC" rev-parse --short HEAD))"
log "recipe: $RECIPE_DIR"
log "image:  $IMAGE"
log "patch:  $PATCH_STATE"
log "cache:  $FLARE_TP3_ROOT/cache"

if [[ "$RUN" != 1 ]]; then
  cat <<EOF
Plan (re-run with --run to execute):
  podman run --rm -i --security-opt label=disable \\
    -v $FLARE_SRC:/work -v $RECIPE_DIR:/recipe:ro \\
    -v $FLARE_TP3_ROOT/cache/cargo/registry:/root/.cargo/registry \\
    -v $FLARE_TP3_ROOT/cache/uv:/root/.cache/uv \\
    -w /work $IMAGE bash -s
  inside: (plain CUDA image only) apt build deps, rustup 1.97.0, uv 0.11.0
          -> git apply source.patch
          -> uv sync --locked --extra prepare --extra test
          -> python -m ignition.patches
          -> apply tp3-patches to the installed FlashInfer
          -> cargo build --release -> flare --version
EOF
  exit 0
fi

LOG="$STATE_DIR/flare-build-$(date +%Y%m%d-%H%M%S).log"
log "building; log: $LOG"

podman run --rm -i --security-opt label=disable \
  -v "$FLARE_SRC:/work" \
  -v "$RECIPE_DIR:/recipe:ro" \
  -v "$FLARE_TP3_ROOT/cache/cargo/registry:/root/.cargo/registry" \
  -v "$FLARE_TP3_ROOT/cache/uv:/root/.cache/uv" \
  -w /work \
  "$IMAGE" bash -s <<'INNER' 2>&1 | tee "$LOG"
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# The derived image already carries these; the plain CUDA image does not.
if ! command -v cmake >/dev/null 2>&1 || ! command -v python3 >/dev/null 2>&1; then
  apt-get update
  apt-get install -y --no-install-recommends \
    git curl ca-certificates build-essential cmake ninja-build pkg-config \
    protobuf-compiler libssl-dev python3-dev liburing-dev clang libclang-dev
fi
if ! command -v rustc >/dev/null 2>&1; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --no-modify-path --profile minimal --default-toolchain 1.97.0
  export PATH=/root/.cargo/bin:$PATH
fi
if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/0.11.0/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh
fi
rustc --version
uv --version

cd /work
git config --global --add safe.directory /work
if git apply --reverse --check /recipe/source.patch >/dev/null 2>&1; then
  echo "source.patch already applied"
else
  git apply /recipe/source.patch
  echo "source.patch applied"
fi

uv sync --locked --extra prepare --extra test

# Bundled PyTorch Inductor / Triton fixes; setup_preparation.py runs the same
# module after syncing, and preparation imports it before touching a checkpoint.
uv run --no-sync python -m ignition.patches

SP=$(.venv/bin/python -c 'import flashinfer, pathlib; print(pathlib.Path(flashinfer.__file__).parents[1])')
echo "FlashInfer site-packages: $SP"
for p in /recipe/tp3-patches/*.patch; do
  if patch -p1 -d "$SP" --dry-run <"$p" >/dev/null 2>&1; then
    patch -p1 -d "$SP" <"$p"
    echo "applied $(basename "$p")"
  elif patch -p1 -R -d "$SP" --dry-run <"$p" >/dev/null 2>&1; then
    echo "already applied $(basename "$p")"
  else
    echo "ERROR: cannot apply $(basename "$p")" >&2
    exit 1
  fi
done

cargo build --release --manifest-path flare/Cargo.toml
flare/target/release/flare --version
.venv/bin/ignition export --help | head -5
echo "BUILD OK"
INNER

log "build complete: $LOG"
