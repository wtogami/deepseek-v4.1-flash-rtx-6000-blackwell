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

Everything that does not need the engine stopped is in place:

- `scripts/flare-tp3/` — download, build, checkpoint-view, export, serve,
  bench, audit wrappers. `audit.sh` is read-only.
- Recipe repo at `~/flare-tp3/recipe` (20261105 folder; identical to the
  pinned commit except README).
- NVIDIA Flare at `~/flare-tp3/flare` @ `78b18b1c`; `source.patch` applies
  cleanly; four FlashInfer TP3 patches staged.
- `llm-inference-bench` v0.9.1 cloned with its venv.
- NVIDIA MXFP4 Engram shards 47-48 downloading to `/nvme1/models/`.
- CUDA 13.2.1 devel image pull staged.

Not done (waiting for the user): build, checkpoint view, export, serve,
benchmark. The engine is still running the original checkpoint at 1M.

## Resume checklist

1. Confirm disk: >= 600 GB free on the export filesystem.
2. Stop `ds41` (GPUs idle, frees ~200 GB RAM Engram).
3. Set 325 W on GPUs 1,2,3; run from a shell with `ulimit -l unlimited`.
4. Build in CUDA 13.1 devel container; verify `flare --version` and
   `ignition export --help`.
5. Download NVFP4 shards 47-48; build and validate the checkpoint view.
6. Export, serve, bench; write `results/flare-tp3-<date>/REPORT.md`.
7. Restore `ds41` (original checkpoint, `MAX_MODEL_LEN=-1`) or keep Flare.
