# Flare TP3 experiment (staged)

Replication of the community Flare TP3 recipe for DeepSeek-V4.1-Flash-1017
on three RTX PRO 6000 cards. Downloads, the working image and the patched
Flare build are done; export, serve and benchmark are not run yet. The engine
(`ds41`, original checkpoint @ 1M) keeps serving on :8000 and is only stopped
by `export.sh --stop-engine`.

Background and expected deviations: [`results/flare-tp3-parked.md`](../../results/flare-tp3-parked.md).

## Prerequisites

- `podman` with the NVIDIA CDI spec (already present), driver 615.78.08.
- `ulimit -l` = `unlimited` (run from the `prlimit` wrapper if not).
- All four GPUs at 325 W (already set); GPUs 1,2,3 are used (2 × WS + 1 × Max-Q).
- ~560 GB free: ~105 GB NVFP4 Engram download + ~380 GiB package + kernel cache.

## Order of operations

```bash
# 1. downloads: recipe, fork, bench harness, MXFP4 Engram shards (~105 GB)
./scripts/flare-tp3/download.sh

# 2. working image with the toolchain baked in (~3 min)
./scripts/flare-tp3/image.sh --run

# 3. patched Flare fork: source.patch, uv sync, ignition.patches,
#    four FlashInfer TP3 patches, cargo build --release (first run 30-90 min)
./scripts/flare-tp3/build.sh --run

# 4. checkpoint view + validation (symlinks only, host-side)
./scripts/flare-tp3/checkpoint-view.sh

# 5. export the package (~1.5-2.5 h). This STOPS ds41.
./scripts/flare-tp3/export.sh --run --stop-engine

# 6. serve on :15015
./scripts/flare-tp3/serve.sh --run

# 7. benchmark: corruption check, prefill 8K/32K/128K, decode 32K C1/C4/C8
./scripts/flare-tp3/bench.sh --run
./scripts/flare-tp3/bench.sh --run --full   # + respect-eos, coding peak,
                                            # tool calls, long retrieval

# 8. stop Flare and restore the vLLM engine
./scripts/flare-tp3/serve.sh --stop
./start.sh
```

`build.sh`, `export.sh`, `serve.sh`, and `bench.sh` print their plan and exit
unless `--run` is passed. `audit.sh` is read-only.

## Images

`image.sh` bakes the build dependencies (compilers, CMake, Ninja, pkg-config,
protoc, OpenSSL/python3/liburing headers, clang), Rust 1.97 and uv 0.11 into
`localhost/flare-tp3:13.2.1`, so every stage starts immediately and the venv's
interpreter (`/usr/bin/python3.12`) exists in all of them. Without that image
the stages fall back to `docker.io/nvidia/cuda:13.2.1-devel-ubuntu24.04` and
install what is missing inside the container.

The CUDA base is 13.2.1 rather than the recipe's stated 13.1 because the fork's
own lock file resolves `torch==2.14.1+cu132` and `cuda-python==13.3.1`.

Caches are bind-mounted (`~/flare-tp3/cache/cargo/registry`,
`~/flare-tp3/cache/uv`), so a retried build resumes. Only the registry
subdirectory is mounted, which keeps the baked Rust toolchain visible.

## Trust for a locally exported package

Flare asks once, in an interactive terminal, to trust the publisher of a
package built by `ignition export`. `serve.sh` avoids that prompt by writing
the acceptance into `$FLARE_CONFIG/trust.toml` from the
`development-publisher.json` that the export creates: fingerprint is the
SHA-256 of the raw 32-byte verification key, namespace
`local-development`, `identity = "profile"`, which is the entry flare's own
trust store accepts. The config directory is mounted at
`/root/.config/flare`, so the acceptance persists across container runs.

## Bench cells

Matches the recipe's published protocol: prefill from `--prefill-only`
(standalone cold, `--prefill-metric client`) at 8K/32K/128K, decode with
`--concurrency 1,4,8 --contexts 32k --duration 60` on the bench's `ignore_eos`
default, then `tools/bench_steps.py` for steps/s and tokens/step.
`tools/verify_fix.py 10` runs first: a non-zero corruption count means a
FlashInfer TP3 patch is missing. `--full` adds the `--respect-eos` repeat
(the recipe notes repetition loops in `ignore_eos` cells are a bench
artifact), coding peak, `tool_calls.py 60 4`, and long retrieval at 128K/900K.

## Paths and knobs

| Variable | Default | Meaning |
|---|---|---|
| `FLARE_TP3_ROOT` | `~/flare-tp3` | recipe + flare + checkpoint view + caches |
| `DS_DIR` | `~/models/DeepSeek-V4.1-Flash` | official shards 1-46 |
| `NVFP4_DIR` | `/nvme1/models/DeepSeek-V4.1-Flash-1017-NVFP4` | MXFP4 Engram 47-48 |
| `CKPT_VIEW` | `~/flare-tp3/ckpt` | symlink view |
| `FLARE_CACHE` | `~/.cache/flare` | exported package (~380 GiB) |
| `FLARE_CONFIG` | `~/flare-tp3/config` | dev signing key, publisher profile, trust store |
| `CUDA_IMAGE` | `docker.io/nvidia/cuda:13.2.1-devel-ubuntu24.04` | base image |
| `FLARE_IMAGE` | `localhost/flare-tp3:13.2.1` | working image used when present |
| `GPUS` | `1,2,3` | host cards passed through CDI |
| `CONTAINER_GPUS` | `0,1,2` | indices inside the container (renumbered) |
| `POWER_LIMIT` | `325` | checked before export |
| `HOT` / `PREFILL` | `300` / `4096` | recipe release export |
| `PORT` | `15015` | Flare API |

## Deviations from the published recipe

- 3 × WS at 350 W → 1 × Max-Q + 2 × WS at **325 W** (Max-Q ceiling).
- Gen5 x16 → **Gen4 x16**; PHB/NODE topology instead of a PCIe switch.
- DDR5-6000 → **DDR4** host memory.
- **Stock memory clock** (13,365 MHz); the recipe's +6000 offset gives
  16,365 MHz and is explicitly part of its numbers.
- ECC reported off on both sides (the recipe's bench JSON also records
  `ecc_mode: [0,0]`).
- CUDA 13.2.1 instead of the stated 13.1, following the fork's lock file.

The recipe itself says a similar build at stock memory clock and Gen4 measured
roughly half its per-step speed, mostly from memory clock and GPU-to-GPU links.
Expect the replica to land well below 254/805 tok/s; the point is to measure
how much survives.

## Audit

```bash
./scripts/flare-tp3/audit.sh
```

Checks script syntax, recipe files, patch application, shard sizes, checkpoint
view stamp, bench checkout, both images, memlock, power, disk, and the engine
state. It does not start containers or touch the GPUs.
