# Parked: Flare TP3 replication on 3 of 4 GPUs

Status: **parked 2026-11-10**, not started. Nothing was built, downloaded, or
changed for this experiment. This note captures the plan so it can be resumed
without re-doing the research.

## Goal

Replicate, as closely as our hardware allows, the community Flare TP3 recipe
for DeepSeek-V4.1-Flash-1017 on 3x RTX PRO 6000 Blackwell, and measure whether
three GPUs can match our four-GPU vLLM TP4 baseline (220-230 tok/s C1,
734-746 tok/s C8, ~10.7k tok/s 32K prefill at 325 W).

## Source

- Recipe: <https://localairecipes.com/r/deepseek-v4-1-flash-1017-flare-tp3-3x-rtx-pro-6000-blackwell>
- Code: `BoxTops4Coochie/RTX-PRO-6000-TP3-Inference-Recipes`, folder
  `DeepSeek-V4.1-Flash Flare-tp3-20261105` @ `a5269231`
- Runtime: NVIDIA/flare-local-inference @ `78b18b1c` + recipe `source.patch`
  (32 files) + FlashInfer `ddbe93fc` + four `tp3-patches/`
- Bench notes: `mark-yong/dsv41f-sm120-tp3-notes` (same-box Gen4 vLLM TP3 data)

## Published numbers (3 x RTX PRO 6000 WS, 350 W, +6000 mem, Gen5 x16, 1M ctx)

| Cell | Value |
|---|---:|
| KV pool (HOT=300, PREFILL=4096) | 2,991,488 tokens |
| Decode 32K C1 / C4 / C8 | 253.8 / 595.0 / 804.5 tok/s |
| Steps/s at 32K C1 / C4 / C8 | 93.8 / 62.0 / 48.1 |
| Prefill 8K / 32K / 128K | 10,977 / 12,548 / 12,160 tok/s |
| TTFT 8K / 32K / 128K | 0.75 / 2.57 / 10.57 s |
| Max concurrency | 8 |
| Startup | ~60 s (Engram in RAM) |

Variants: HOT=267, PREFILL=4096 -> 6.05M KV, 237/510/688 tok/s;
HOT=313, PREFILL=2048 -> 3.47M KV, ~15% slower prefill.

## Checkpoint

Not our CSF container. The recipe builds a checkpoint *view* from:

- `deepseek-ai/DeepSeek-V4.1-Flash-1017` @ `1bae0e10`, shards 1-46 (~307 GB) —
  we already have these in `~/models/DeepSeek-V4.1-Flash`.
- `nvidia/DeepSeek-V4.1-Flash-1017-NVFP4`, shards 47-48 (Engram tables in
  MXFP4, 97 GiB) — **not downloaded**.
- Recipe's corrected `config.json` / `model.safetensors.index.json`.

`make_checkpoint_view.sh` uses symlinks only; its success check is
`96085 tensors in 48 shards, missing 0; layer-1 Engram table U8 [384006168, 128]`.

## Build and export

Build (CUDA 13.1, Rust 1.97, uv 0.11; host has Rust 1.99/uv 0.13, so pin in a
CUDA 13.1 devel container because there is no passwordless sudo):

```bash
git clone https://github.com/NVIDIA/flare-local-inference.git flare
cd flare && git checkout 78b18b1c
git apply /path/to/recipe/source.patch
uv sync --locked --extra prepare --extra test
# apply recipe tp3-patches/*.patch into the installed FlashInfer
cargo build --release --manifest-path flare/Cargo.toml
```

Export (GPUs idle, memlock unlimited, export tunes at the clocks you will serve):

```bash
CKPT=~/ds41-flare-ckpt HOT=300 PREFILL=4096 GPUS=1,2,3 \
  /path/to/recipe/export.sh
```

Recipe env: `FLARE_DS41_HOST_EXPERT_LAYERS=20-33`, `HOT_EXPERTS=300`,
`MERGED_BANK=1`, `TP3_VOCAB_PARALLEL=1`, `TP3_GRAPH_GIB=1`,
`--max-concurrency 8 --mtp-draft-tokens 5 --draft-head-quantization nvfp4
--markov-head-quantization fp8 --vocabulary-parallel-sampling`.

Serve:

```bash
GPUS=1,2,3 PORT=15015 /path/to/recipe/serve.sh
```

Bench with `llm-inference-bench` v0.9.1 (the recipe's harness, not our KK
v0.6.2): prefill 8K/32K/128K, decode 32K C1/C4/C8, steps/s, 1M needle.

## Storage

Incremental need ~557 GB: 105 GB NVFP4 Engram download + 407 GB package +
45 GB kernel cache. Free at parking time: 1.4 TB on `/` (btrfs) and 1.4 TB on
`/nvme1` (XFS). No deletion required; the 462 GiB CSF container can stay.

## Deviations from the recipe (unavoidable)

| Recipe | This box |
|---|---|
| 3 x Workstation Edition at 350 W | 1 x Max-Q + 2 x Workstation at 325 W (Max-Q ceiling); use GPUs 1,2,3 |
| PCIe Gen5 x16 | Gen4 x16 |
| DDR5-6000 8ch | DDR4 8ch (Threadripper PRO 5995WX) |
| +6000 MHz memory VF offset | **not applied** (decision 2026-11-10). All four cards report the range (-2000, +6000) via NVML, so it is possible, but setting it needs root and we chose not to change memory clocks |
| PCIe switch (PIX) | PHB/NODE topology |
| 256 GB host RAM | 503 GiB (fine; export peaks ~160 GB) |

The +6000 offset is part of the recipe's export conditions; without it the
package is tuned at stock clocks and will be slower. The Gen4 link and DDR4
host memory are the larger expected penalties (the Gen4 vLLM TP3 datapoint is
~35-40% below its Gen5 twin on decode).

## Expected outcome

The recipe's own README is explicit: a similar build at **stock memory clock
(13,365 MHz) and PCIe Gen4 measured roughly half its per-step speed** on the
vLLM build, mostly from memory clock and slower GPU-to-GPU links. The +6000
offset raises the memory clock to 16,365 MHz; we are not applying it.

So the realistic expectation is well below the published 254/805 tok/s —
plausibly ~110-150 tok/s C1, ~300-450 tok/s C8 at 32K, and ~6-8k tok/s
prefill. That would be below our four-GPU vLLM baseline (220/745/10.7k), so
this is a measurement of how much of the 3-GPU Flare result survives
Gen4/DDR4/stock clocks, not an expected upgrade. Go/no-go after export: if
Flare is within ~10-15% of the 4-GPU vLLM numbers, consider it for the freed
GPU; otherwise document and revert.

## Staged implementation (2026-11-10)

Everything that does not need the engine stopped is done:

- `scripts/flare-tp3/` — `download`, `image`, `build`, `checkpoint-view`,
  `export`, `serve`, `bench`, plus a read-only `audit`. Everything except
  `--run` paths is side-effect free.
- Recipe repo at `~/flare-tp3/recipe` (20261105 folder; identical to the
  pinned commit except README).
- NVIDIA Flare at `~/flare-tp3/flare` @ `78b18b1c`, `source.patch` applied,
  `flare 0.1.0` built in release mode, `.venv` synced (torch 2.14.1+cu132,
  cuda-python 13.3.1, FlashInfer `ddbe93fc`), `ignition.patches` applied to
  the Inductor/Triton files, and the four FlashInfer TP3 patches applied.
- Working image `localhost/flare-tp3:13.2.1` (CUDA 13.2.1 devel + compilers +
  cmake/ninja/protoc + Rust 1.97 + uv 0.11). Verified: GPU visible through the
  CDI spec, host GPU 1 appears as container index 0.
- `llm-inference-bench` v0.9.1 cloned with its venv; flags checked against
  the tag's parser.
- NVIDIA MXFP4 Engram shards 47-48 in `/nvme1/models/`, sizes verified
  (52,382,361,720 and 52,383,791,632 bytes).
- Checkpoint view built and validated: 96,085 tensors in 48 shards, missing 0;
  layer-1 Engram table U8 [384006168, 128]. Mount resolution checked inside
  the container.
- `audit.sh`: no failures, no warnings once the binary and view exist.

Remaining, in order: `export.sh --run --stop-engine` (stops `ds41`, ~1.5-2.5 h),
`serve.sh --run`, `bench.sh --run`. The engine still runs the original
checkpoint at `MAX_MODEL_LEN=-1`.

## Resume checklist

1. Confirm disk: >= 600 GB free where `~/.cache/flare` lives (1415 GiB now).
2. From a shell with `ulimit -l unlimited`, run
   `./scripts/flare-tp3/export.sh --run --stop-engine` (~1.5-2.5 h; it stops
   `ds41`, sets nothing itself, checks power/memlock/idleness first).
3. `./scripts/flare-tp3/serve.sh --run` (~60 s to healthy on :15015); read the
   printed KV token count (expect ~2.99M at HOT=300).
4. `./scripts/flare-tp3/bench.sh --run --full`; write
   `results/flare-tp3-<date>/REPORT.md` comparing against the four-GPU vLLM
   baseline (decode 220 / 745 tok/s, prefill ~10.7k) at the same cells.
5. Restore `ds41` (`./scripts/flare-tp3/serve.sh --stop && ./start.sh`, original
   checkpoint, `MAX_MODEL_LEN=-1`) or keep Flare if it wins.

## Execution log (2026-11-10/11)

- `ds41` stopped by `export.sh --stop-engine` at 23:52; GPUs idle, 469 GiB host
  RAM available.
- Export attempt 1 (`HOT=300 PREFILL=4096`, GPUs 1,2,3 at 325 W): weights
  routed and loaded in 125.7 s (104.94 GB selected per rank 0, 175.11 GB
  physical reads), embedding tables prepared (97.3 GiB), graph catalog built,
  then kernel tuning ran 1399 s and reached 2078/2452 kernels before CUDA OOM on
  all three ranks while allocating 256 MiB with 249 MiB free (~64 GiB resident
  tensors per rank plus tuning scratch). `[  FAILED  ] Prepare and tune kernels`.
  This is the recipe's documented cold-cache condition; the remedy it gives is a
  lower-`HOT` pass first, since `~/.cache/flare/kernels` is shared. 952 MB of
  tuning cache was kept; no package was written; GPUs and RAM were clean
  afterwards.
- Export attempt 2 (`HOT=290`) started at 00:21 to fill the tuning cache; then
  `HOT=300` re-tunes only what is new and produces the release-configuration
  package to benchmark.
- Export attempt 2 outcome: tuning itself succeeded — 2452/2452 kernels ready,
  1012 measurements taken from the shared cache, 63 restored, 0 rejected, in
  13:58 of session time. Then `b12x failed comm.pcie` and the rank group hung:
  rank 0 sat on `waiting for ranks comm.pcie` and finally died in
  `dist.all_gather_object` with
  `gloo/transport/tcp/unbound_buffer.cc:78 Timed out waiting 7200000ms for recv`,
  after `Prepare and tune kernels. 8181.9s`. No rank 1/2 output at all in that
  log, so a peer stalled rather than crashed with a message. No package was
  written; GPUs were empty afterwards; the 1.1 GB tuning cache was kept.
- Export attempt 3: same `HOT=290`, now with a fully warm cache and a
  `EXPORT_TIMEOUT=3600` wall-clock cap (torch's Gloo timeout is 2 h, which is
  far too long to burn on a deadlock). `export.sh` also removes a leftover
  container and warns about surviving GPU compute processes after a kill.
- Root cause found for both stalls: rootless podman gives each container
  `pids.max=2048`. Three ranks with a 64-thread BLAS pool each, plus inductor
  compile workers and CUDA driver threads, exceed it, so `clone()` returns
  EAGAIN (`OpenBLAS blas_thread_init: pthread_create failed for thread 28 of 64:
  Resource temporarily unavailable`) and CUDA initialization inside a compile
  worker fails with `Error 304: OS call failed or operation not supported on
  this OS`. All three export logs show the OpenBLAS thread failures; only the
  third got far enough (221.7 s tuning, all cached) to reach the compile stage
  where the CUDA error appeared. The 2 h hang in attempt 2 was a peer rank
  unable to make threads, not a PCIe-topology deadlock.
- Fix: `--pids-limit 16384` on the export and serving containers (`PIDS_LIMIT`
  in lib.sh; verified `pids.max` becomes 16384 inside the container). The host
  session scope allows 1,360,814 tasks and `vm.max_map_count` is already
  1,048,576, so nothing else needed raising and no root action is required.
  Attempt 4 is `HOT=290` again with the raised limit.

  Still open: `HOT=300` ran out of VRAM during cold tuning (attempt 1), so if
  the release configuration still cannot export after the thread fix, the
  ordered fallbacks are `FLARE_DS41_JOINT_HEADROOM_MIB` (lowers the
  joint-tuning compile headroom for that phase only), then the documented
  `PREFILL=2048` variant, which halves the per-rank all-reduce staging buffer.
  A 2048 variant is still a measurement of this recipe on this hardware,
  labelled as such; benchmarking the 290 package is the last resort and would
  be reported as a different hot-expert count (KV drops roughly 93K tokens per
  hot expert per parked layer).
