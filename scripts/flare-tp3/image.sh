#!/usr/bin/env bash
# Build the working image once: CUDA devel + compiler/build deps + uv + Rust.
#
#   ./scripts/flare-tp3/image.sh            # print the plan
#   ./scripts/flare-tp3/image.sh --run      # build it
#
# Every other stage (build, export, serve) runs in this image. Building it
# ahead of time means the ephemeral containers do not repeat a one-minute apt
# pass, and the Python 3.12 that the repo's .venv points at is already there.
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

CONTAINERFILE="$FLARE_TP3_ROOT/Containerfile.flare-tp3"

write_containerfile() {
  cat >"$CONTAINERFILE" <<EOF
FROM $CUDA_IMAGE

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \\
 && apt-get install -y --no-install-recommends \\
      git curl ca-certificates build-essential cmake ninja-build pkg-config \\
      protobuf-compiler libssl-dev python3-dev liburing-dev clang libclang-dev \\
 && rm -rf /var/lib/apt/lists/*

# Rust 1.97 (recipe-tested; the crates require 1.88) and uv 0.11 (the lock file).
ENV RUSTUP_HOME=/root/.rustup CARGO_HOME=/root/.cargo
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \\
    | sh -s -- -y --no-modify-path --profile minimal --default-toolchain 1.97.0 \\
 && curl -LsSf https://astral.sh/uv/0.11.0/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh

ENV CUDA_HOME=/usr/local/cuda \\
    LD_LIBRARY_PATH=/usr/local/cuda/lib64:/usr/local/nvidia/lib64 \\
    PATH=/usr/local/cuda/bin:/root/.cargo/bin:/root/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

CMD ["bash"]
EOF
}

write_containerfile
log "Containerfile: $CONTAINERFILE"

if [[ "$RUN" != 1 ]]; then
  log "dry-run: podman build -t $FLARE_IMAGE -f $CONTAINERFILE $FLARE_TP3_ROOT"
  sed -n '1,6p' "$CONTAINERFILE"
  exit 0
fi

podman build -t "$FLARE_IMAGE" -f "$CONTAINERFILE" "$FLARE_TP3_ROOT"
podman run --rm "$FLARE_IMAGE" bash -lc \
  'nvcc --version | tail -2; python3 --version; rustc --version; uv --version; cmake --version | head -1; protoc --version'
log "image ready: $FLARE_IMAGE"
