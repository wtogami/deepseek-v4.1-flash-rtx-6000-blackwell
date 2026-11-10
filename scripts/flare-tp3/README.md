# Flare TP3 experiment (staged)

Replication of the community Flare TP3 recipe for DeepSeek-V4.1-Flash-1017
on three RTX PRO 6000 cards. **Staged only**: downloads and scripts are in
place; nothing has been built, exported, served, or benchmarked. The engine
(`ds41`, original checkpoint @ 1M) has not been touched.

Background and expected deviations: [`results/flare-tp3-parked.md`](../../results/flare-tp3-parked.md).

## Prerequisites

- `podman` with the NVIDIA CDI spec (already present), driver 615.78.08.
- `ulimit -l` = `unlimited` (run from the `prlimit` wrapper if not).
- All four GPUs at 325 W (already set); GPUs 1,2,3 are used (2 × WS + 1 × Max-Q).
- ~560 GB free: ~105 GB NVFP4 Engram download + ~380 GiB package + kernel cache.

## Order of operations

```bash
# 1. download (~105 GB; resumable)
./scripts/flare-tp3/download.sh

# 2. build the patched Flare fork in the CUDA 13.2.1 container (30-90 min)
./scripts/flare-tp3/build.sh --run

# 3. assemble + validate the checkpoint view (symlinks only)
./scripts/flare-tp3/checkpoint-view.sh

# 4. export the package (~1.5-2.5 h). This STOPS ds41.
./scripts/flare-tp3/export.sh --run --stop-engine

# 5. serve on :15015
./scripts/flare-tp3/serve.sh --run

# 6. benchmark (prefill 8K/32K/128K + decode 32K C1/C4/C8)
./scripts/flare-tp3/bench.sh --run
./scripts/flare-tp3/bench.sh --run --full     # + coding peak + long retrieval

# 7. stop Flare and restore the vLLM engine
./scripts/flare-tp3/serve.sh --stop
./start.sh
```

`build.sh`, `export.sh`, `serve.sh`, and `bench.sh` print their plan and exit
unless `--run` is passed. `audit.sh` is read-only.

## What gets downloaded

- Recipe repo at `a5269231` (the 20261105 folder; the pinned commit differs
  from `main` only in `README.md`, verified against the GitHub tree).
- NVIDIA Flare at `78b18b1c` + the recipe's `source.patch` (32 files) and four
  FlashInfer TP3 patches.
- `nvidia/DeepSeek-V4.1-Flash-1017-NVFP4` revision `3ae9c0d3`, shards 47-48
  (~105 GB, MXFP4 Engram tables) to `/nvme1/models/`.
- `llm-inference-bench` v0.9.1.

## Paths and knobs

| Variable | Default | Meaning |
|---|---|---|
| `FLARE_TP3_ROOT` | `~/flare-tp3` | recipe + flare + checkpoint view |
| `DS_DIR` | `~/models/DeepSeek-V4.1-Flash` | official shards 1-46 |
| `NVFP4_DIR` | `/nvme1/models/DeepSeek-V4.1-Flash-1017-NVFP4` | MXFP4 Engram 47-48 |
| `CKPT_VIEW` | `~/flare-tp3/ckpt` | symlink view |
| `FLARE_CACHE` | `~/.cache/flare` | exported package (~380 GiB) |
| `CUDA_IMAGE` | `docker.io/nvidia/cuda:13.2.1-devel-ubuntu24.04` | build/export/serve image |
| `GPUS` | `1,2,3` | host cards passed through CDI |
| `CONTAINER_GPUS` | `0,1,2` | indices inside the container (renumbered) |
| `POWER_LIMIT` | `325` | checked before export |
| `HOT` / `PREFILL` | `300` / `4096` | recipe release export |
| `PORT` | `15015` | Flare API |

The CUDA image is 13.2.1, not the recipe's stated 13.1, because the fork's
lock file resolves `torch==2.14.1+cu132` and `cuda-python==13.3.1`.

## Deviations from the published recipe

- 3 × WS at 350 W → 1 × Max-Q + 2 × WS at **325 W** (Max-Q ceiling).
- Gen5 x16 → **Gen4 x16**; PHB/NODE topology instead of a PCIe switch.
- DDR5-6000 → **DDR4** host memory.
- **Stock memory clock** (13,365 MHz); the recipe's +6000 offset gives
  16,365 MHz and is explicitly part of its numbers.
- ECC reported off on both sides (the recipe's bench JSON also records
  `ecc_mode: [0,0]`).

The recipe itself says a similar build at stock memory clock and Gen4 measured
roughly half its per-step speed, mostly from memory clock and GPU-to-GPU links.
Expect the replica to land well below 254/805 tok/s; the point is to measure
how much survives.

## Audit

```bash
./scripts/flare-tp3/audit.sh
```

Checks script syntax, recipe files, patch application, shard sizes, checkpoint
view stamp, bench checkout, image availability, memlock, power, disk, and the
engine state. It does not start containers or touch the GPUs.
