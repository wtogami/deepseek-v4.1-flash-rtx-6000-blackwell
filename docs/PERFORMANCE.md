# Performance

Measurement method, hardware tiers, the 3-card alternative, tuning A/Bs and the
run index. The README shows the summary card; this file is the evidence.

## Protocol

The harness is the exact Karmic Kraken script (`bench/llm_decode_bench.py`,
sha256-pinned; see [bench/PROVENANCE.md](../bench/PROVENANCE.md)). Each cell is
the median of five warmed 30 s windows with 15 s warmup:

- **Prefill**: unique, uncached nominal-32K prompts, client time to first
  token (includes speculative prompt-finalization work), five 30 s windows.
- **Decode**: context zero, temperature 1, C1 and C8, server-side `/metrics`
  deltas (`vllm:generation_tokens_total`,
  `vllm:spec_decode_num_accepted_tokens_total`).
- **KV capacity**: the `GPU KV cache size` line from the startup log.

Output rates depend on draft acceptance as well as execution cost, so verifier
steps/s and accepted length are reported separately in the per-run
`REPORT.md` files. These are throughput measurements, not quality scores.

## Hardware tiers

| Setup | Cards | Host | Prefill 32K tok/s | Decode C1 tok/s | Decode C8 tok/s | KV tokens |
|---|---:|---|---:|---:|---:|---:|
| Reference (Karmic Kraken `ds41.kk`) | 4 | DDR5, PCIe 5.0, VRAM +6000, 325 W Max-Q | 17,982 | 249.1 | 805.5 | 4,727,748 |
| This recipe (`rebar325-cool-131072`) | 4 | DDR4, PCIe 4.0 x16, stock VRAM, 325 W | 10,649 | 225.6 | 740.0 | 4,740,829 |
| 3-card alternative (`flare-tp3-baseline-20261111-045100`) | 3 | DDR4, PCIe 4.0 x16, stock VRAM, 325 W | 9,376 | 177.0 | 565.9 | 4,194,304 |

Reference conditions: RTX PRO 6000 Blackwell Max-Q Workstation Edition,
VRAM +6000, automatic graphics clocks, 325 W. The local host is a Supermicro
AS-5014A-TT with a Threadripper PRO 5995WX, 503 GiB DDR4 and all four cards on
Gen4 x16 at 325 W (see [OPERATIONS.md](OPERATIONS.md#platform)).

**Reading the table.** Decode is within ~10 % of the reference on this host;
prefill is the hardware-sensitive cell at ~40 % lower. The 3-card arm gives up
12 % prefill and 22–24 % decode in absolute terms, but is ahead per card
(+17 % prefill, +5 % C1, +2 % C8, +18 % KV capacity).

## Four-card baseline detail

`results/rebar325-cool-131072/REPORT.md` is the canonical four-card run and the
baseline used in the 3-card comparison. Repeats on the same configuration land
within run-to-run noise:

| Run | Prefill 32K tok/s | C1 tok/s | C8 tok/s | KV tokens |
|---|---:|---:|---:|---:|
| `rebar325-cool-131072` | 10,649 | 225.6 | 740.0 | 4,740,829 |
| `sm-131072` | 10,650 | 215.6 | 700.7 | 4,741,178 |
| CSF A/B original arm, 131K (`csf-ab-20261110-133934-A-131k`) | 10,775 | 217 | 745 | 4,742,050 |

At `MAX_MODEL_LEN=-1` (1M) the same engine reports 9,718,137 KV tokens. The
`MAX_MODEL_LEN=131072` cap used for the Karmic Kraken cells does not change the
prefill cell; the 1M decode cells in the CSF A/B arms (archived) are within
run-to-run noise of the 131K ones.

Earlier P2P runs (`ram-131072-p2p`, `ram-131072-nccl-p2p`,
`ram-131072-p2p-325w`) predate `NCCL_P2P_LEVEL=PHB` and measure a host-bounced
allreduce; they are kept for the attempt history, not as serving numbers.

## Three-card alternative (Flare TP3)

`scripts/flare-tp3/` reproduces the community Flare TP3 recipe for this model on
three cards. It is measured and quality-checked, and it is **not** the running
configuration: the engine stays four-GPU vLLM at `MAX_MODEL_LEN=-1`.

```bash
./scripts/flare-tp3/audit.sh          # read-only state check
./scripts/flare-tp3/export.sh --run --stop-engine   # HOT=290 PREFILL=4096
./scripts/flare-tp3/serve.sh --run    # http://127.0.0.1:15015
./scripts/flare-tp3/bench.sh --run --full           # recipe cells
./scripts/flare-tp3/bench-baseline.sh --run         # this project's cells
./scripts/flare-tp3/serve.sh --stop && ./start.sh   # back to TP4 vLLM
```

Like-for-like cells (same harness, same power limit, four GPUs on vLLM versus
three GPUs on Flare):

| Cell | Flare TP3 (3 GPUs) | vLLM TP4 (4 GPUs) | Delta |
|---|---:|---:|---:|
| 32K prefill tok/s | 9,376.0 | 10,649.0 | -11.95% |
| C1 decode tok/s | 177.0 | 225.6 | -21.54% |
| C8 decode tok/s | 565.9 | 740.0 | -23.53% |

Per-card efficiency:

| Metric | Flare TP3 (3 cards) | per card | vLLM TP4 (4 cards) | per card |
|---|---:|---:|---:|---:|
| 32K prefill tok/s | 9,376 | 3,125 | 10,649 | 2,662 |
| C1 decode tok/s | 177.0 | 59.0 | 225.6 | 56.4 |
| C8 decode tok/s | 565.9 | 188.6 | 740.0 | 185.0 |
| KV tokens at this cap | 4,194,304 | 1,398,101 | 4,740,829 | 1,185,207 |

Recipe protocol (`llm-inference-bench` v0.9.1):

| Cell | This run | Recipe published |
|---|---:|---:|
| prefill 8K tok/s | 7,667 | — |
| prefill 32K tok/s | 9,758 | 12,548 |
| prefill 128K tok/s | 9,358 | 12,160 |
| decode 32K C1 tok/s | 173.3 | ~254 |
| decode 32K C4 tok/s | 373.9 | ~595 |
| decode 32K C8 tok/s | 508.8 | ~805 |

| Cell | steps/s | tokens/step | draft acceptance | recipe steps/s |
|---|---:|---:|---:|---:|
| decode 32K C1 | 66.7 | 2.60 | 0.32 | 93.8 (0.71×) |
| decode 32K C4 | 43.3 | 8.63 | 0.52 | 62.0 (0.70×) |
| decode 32K C8 | 33.7 | 15.08 | 0.63 | 48.1 (0.70×) |

Conditions: Flare package exported at `HOT=290 PREFILL=4096` on GPUs 1,2,3
(one Max-Q + two Workstation, 325 W, stock 13,365 MHz memory clock, Gen4 x16
behind PHB/NODE, DDR4 host). The recipe's published `HOT=300` build could not
be exported here: at 290 each rank retains 69,469 MiB with 2,904 MiB free, and
300 would add ~1.9 GiB of hot experts, which OOM'd during cold tuning. The
recipe box is 3 × Workstation at 350 W with a +6000 MHz memory offset on Gen5
x16 and 256 GB DDR5-6000; `EXPORT.md` itself expects roughly half the per-step
speed without those, and this host measures 0.70–0.71× at every concurrency.

Correctness and quality: `tools/verify_fix.py 10` reported 0 corruptions, tool
calls 60/60, and long retrieval passed at 127,986 and 899,988 tokens. Coding
peak (5 runs, median) 245.4 tok/s (range 229.4–267.0) against the recipe's
published 379–398.

Checkpoint note: this arm builds its own checkpoint view from the original
shards plus NVIDIA's NVFP4 Engram shards (MXFP4 table). It is **not** the CSF
container from [EXPERIMENTS.md](EXPERIMENTS.md); that path is archived.

Full tables: `results/flare-tp3-20261111-040643/REPORT.md`; the
attempt-by-attempt log, including the two container/platform fixes this needed
(rootless `pids.max`, mixed-SKU compile cache), is in
`results/flare-tp3-parked.md`.

## Tuning A/B

### B12X two-shot (`TWOSHOT_MB`)

Same engine, same day, back-to-back arms; only the container env
`VLLM_PCIE_TWOSHOT_ALLREDUCE_MAX_SIZE` differs (profile default `off` vs `6MB`,
passed via `TWOSHOT_MB=6 ./start.sh`). Activation was verified in the engine log:
`two-shot bf16 max=6291456, DMA min=6291456`.

| Cell | A = off | B = 6MB | B vs A |
|---|---:|---:|---:|
| 32K prefill tok/s | 10,760 | 10,666 | -0.9% (control) |
| C1 output tok/s | 212.6 | 224.9 | +5.8% |
| C8 output tok/s | 700.5 | 716.3 | +2.3% |
| C8 verifier steps/s | 310.26 | 325.06 | **+4.8%** |
| KV capacity tokens | 4,741,178 | 4,742,050 | +0.02% |

Noise floor: three same-config runs differ by 0.5–1.5 % on verifier-rate cells,
so the +4.8 % C8 verifier gain is outside noise; prefill (-0.9 %) and C1
verifier (-1.2 %) held as the designed controls. Accepted-length movement is
temperature-1 sampling across a new but deterministic summation order. Decision:
run with `TWOSHOT_MB=6` on this platform. Full write-up:
`results/twoshot-AB.md`.

### Prefill compute share (`SHARE`, `FAIRNESS`)

Measured no effect on uncontended prefill — the scheduler already exempts it.
Relevant only to mixed prefill+decode serving. `FAIRNESS=none` drops the
compute-share argument entirely.

### CSF checkpoint

Tested and **not recommended**. The A/B, the KV numbers and the determinism
caveat are in [EXPERIMENTS.md](EXPERIMENTS.md).

## Run index

| Directory | What it is |
|---|---|
| `results/rebar325-cool-131072` | Canonical four-card baseline (10,649 / 225.6 / 740.0) |
| `results/sm-131072` | Same-config repeat (10,650 / 215.6 / 700.7) |
| `results/twoshot-A-off`, `results/twoshot-B-on` | Two-shot A/B arms |
| `results/twoshot-AB.md` | Two-shot write-up and decision |
| `results/flare-tp3-20261111-040643` | TP3 on the recipe protocol |
| `results/flare-tp3-baseline-20261111-045100` | TP3 on this project's cells |
| `results/flare-tp3-parked.md` | TP3 build/attempt log and parked decision |
| `results/csf-ab-20261110-133934*` | CSF A/B arms (archived; see EXPERIMENTS.md) |
| `results/disk-131072` | Disk-backed Engram |
| `results/ram-131072*`, `results/rebar-p2p-131072` | P2P/ReBAR/placement attempt history |
| `results/default-1m-reseat`, `results/ram-131072-reseat-325w` | 1M/reseat variants |

Every directory carries its own `REPORT.md` with per-window samples, PCIe/system
monitor rows and the exact conditions.

## Reproduce

```bash
KV_CAPACITY=<from server log> NAME=ram-131072 ./run-bench.sh
python3 analyze.py results/ram-131072 --kv-capacity <N>
```

`run-bench.sh` runs the pinned Karmic Kraken invocation plus a 1 Hz monitor;
`analyze.py` writes the `REPORT.md` and compares against the reference targets.
About 12 minutes per run: 5 × 30 s prefill windows and 5 × 30 s decode windows
at C1 and C8. `DROP_CACHES=1` calls `/usr/local/bin/ple-drop-caches` before each
cell (page-cache drop with a fail-closed idle check); only meaningful for disk
Engram.

`monitor.tsv` columns (units): `t` s; `p*_rx`/`p*_tx` MB/s per GPU (dmon);
`g*_util` %; `g*_smclk` MHz; `g*_pwr` W; `g*_mem` MiB; `load1`; `memavail_kb`
kB. PCIe ceiling on the current platform: Gen4 x16 ~32 GB/s per direction on
every GPU.
