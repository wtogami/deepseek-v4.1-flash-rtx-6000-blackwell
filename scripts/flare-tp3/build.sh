#!/usr/bin/env bash
# Build the patched Flare fork inside a CUDA 13.2.1 container.
#
#   ./scripts/flare-tp3/build.sh            # print the plan (no container)
#   ./scripts/flare-tp3/build.sh --run      # pull + build (30-90 min)
#
# The host has no passwordless sudo, so the build runs in the NVIDIA CUDA
# devel image. The repo and the cargo/uv caches are bind-mounted, so a retry
# resumes instead of starting over. CUDA 13.2.1 is chosen to match the fork's
# torch==2.14.1+cu132 / cuda-python==13.3.1 environment (the recipe text says
# 13.1, but its own lock file resolves cu132).
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

mkdir -p "$FLARE_TP3_ROOT/cache/cargo" "$FLARE_TP3_ROOT/cache/rustup" \
         "$FLARE_TP3_ROOT/cache/uv"

log "flare:  $FLARE_SRC ($(git -C "$FLARE_SRC" rev-parse --short HEAD))"
log "recipe: $RECIPE_DIR"
log "image:  $CUDA_IMAGE"
log "patch:  $PATCH_STATE"
log "cache:  $FLARE_TP3_ROOT/cache"

if [[ "$RUN" != 1 ]]; then
  cat <<EOF
Plan (re-run with --run to execute):
  podman run --rm -i --network host --security-opt label=disable \\
    -v $FLARE_SRC:/work -v $RECIPE_DIR:/recipe:ro \\
    -v $FLARE_TP3_ROOT/cache/cargo:/root/.cargo \\
    -v $FLARE_TP3_ROOT/cache/rustup:/root/.rustup \\
    -v $FLARE_TP3_ROOT/cache/uv:/root/.cache/uv \\
    -w /work $CUDA_IMAGE bash -s
  inside: apt build deps -> rustup 1.97.0 -> uv 0.11.0 -> git apply source.patch
          -> uv sync --locked --extra prepare --extra test
          -> apply tp3-patches to the installed FlashInfer
          -> cargo build --release -> flare --version
EOF
  exit 0
fi

LOG="$STATE_DIR/flare-build-$(date +%Y%m%d-%H%M%S).log"
log "building; log: $LOG"

podman run --rm -i --network host --security-opt label=disable \
  -v "$FLARE_SRC:/work" \
  -v "$RECIPE_DIR:/recipe:ro" \
  -v "$FLARE_TP3_ROOT/cache/cargo:/root/.cargo" \
  -v "$FLARE_TP3_ROOT/cache/rustup:/root/.rustup" \
  -v "$FLARE_TP3_ROOT/cache/uv:/root/.cache/uv" \
  -w /work \
  -e CUDA_HOME=/usr/local/cuda \
  -e PATH=/usr/local/cuda/bin:/root/.cargo/bin:/root/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  "$CUDA_IMAGE" bash -s <<'INNER' 2>&1 | tee "$LOG"
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  git curl ca-certificates build-essential cmake ninja-build pkg-config \
  protobuf-compiler libssl-dev python3-dev liburing-dev clang libclang-dev

# Rust 1.97 (recipe-tested); the crate only requires 1.88.
if ! command -v rustup >/dev/null 2>&1; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --profile minimal --default-toolchain 1.97.0
fi
export PATH=/root/.cargo/bin:$PATH
rustup toolchain install 1.97.0 --profile minimal
rustup default 1.97.0
rustc --version

# uv 0.11 (the fork's lock file was produced with it).
if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/0.11.0/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh
fi
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
