# DeepSeek-V4.1-Flash on 4× RTX PRO 6000 Blackwell

Serves `deepseek-ai/DeepSeek-V4.1-Flash` (TP4/DCP1, B12X kernels, adaptive
DSpark K7) from a local checkpoint under rootless podman, with the Engram table
in RAM by default and a disk-backed option. `start.sh` pins the measured
sampling values and verifies the PCIe peer path before launch.

## Requirements

| Item | Requirement |
|---|---|
| GPUs | 4× RTX PRO 6000 Blackwell (96 GB each). No NVLink; the launcher requires the PCIe peer path. |
| Disk | ~500 GB for the flat checkpoint (476 GB of weights). |
| RAM, default | ~213 GiB free and an unlimited `RLIMIT_MEMLOCK` for RAM Engram. |
| RAM, disk mode | Much lower; set `ENGRAM_TABLE_MEMORY=disk`. |
| Host | Linux, NVIDIA 615.x, podman 5.x (Docker also works), CDI. |

Measured on a Supermicro AS-5014A-TT: Threadripper PRO 5995WX, 503 GiB DDR4,
four cards on PCIe 4.0 x16 at 325 W. A separate measured 3-card path exists
(Flare TP3); see below.

## Performance

Medians of five warmed 30 s windows with the pinned Karmic Kraken harness:
32K unique prefill (client TTFT) and context-zero decode at C1/C8, temperature
1. These are throughput numbers, not quality scores.

| Setup | Cards | Host | Prefill 32K tok/s | Decode C1 tok/s | Decode C8 tok/s |
|---|---:|---|---:|---:|---:|
| Reference | 4 | DDR5, PCIe 5.0, VRAM +6000, 325 W Max-Q | 17,982 | 249.1 | 805.5 |
| This recipe | 4 | DDR4, PCIe 4.0 x16, stock VRAM, 325 W | 10,649 | 225.6 | 740.0 |
| 3-card alternative (TP3) | 3 | DDR4, PCIe 4.0 x16, stock VRAM, 325 W | 9,376 | 177.0 | 565.9 |

Decode is within ~10 % of the reference on this host; prefill is the
hardware-sensitive cell at ~40 % lower, which is the DDR4/PCIe 4.0/stock-clock
cost rather than a serving difference. The 3-card arm gives up 12 % prefill and
22–24 % decode in absolute terms, but is ahead per card (+17 % prefill, +5 % C1,
+2 % C8, +18 % KV capacity) and passes its quality checks. It is a separate
measured engine (`scripts/flare-tp3/`), not a mode of this launcher.

Protocol, per-cell detail, tuning A/Bs and the full run index:
[docs/PERFORMANCE.md](docs/PERFORMANCE.md).

## Quick start

```bash
# 1. checkpoint (~476 GB, flat layout)
hf download deepseek-ai/DeepSeek-V4.1-Flash --local-dir ~/models/DeepSeek-V4.1-Flash

# 2. image
podman pull ghcr.io/local-inference-lab/vllm:karmic-kraken-beta

# 3. serve
./start.sh
./stop.sh
```

The API model is `DeepSeek-V4.1-Flash` on `0.0.0.0:8000`. Readiness is polled on
`/health` (503 while loading, 200 when ready).

Disk-backed Engram: `ENGRAM_TABLE_MEMORY=disk ./start.sh`.

## Configuration

| Variable | Default | Meaning |
|---|---|---|
| `ENGRAM_TABLE_MEMORY` | `ram` | `ram` or `disk`; never switched silently |
| `MODEL_DIRECTORY` | `~/models/DeepSeek-V4.1-Flash` | flat checkpoint dir |
| `MAX_MODEL_LEN` | `-1` | model default; cap the context with e.g. `131072` |
| `MAX_NUM_SEQS` | `32` | request slots |
| `MAX_NUM_BATCHED_TOKENS` | `4096` | |
| `GPU_MEMORY_UTILIZATION` | `0.95` | |
| `STATE_DIRECTORY` | `./state` | mounted at `/cache` (JIT + runtime state) |
| `PORT` / `BIND_ADDRESS` | `8000` / `0.0.0.0` | host networking |
| `GPU` | `all` | CDI device selection; needs 4 cards |
| `REPLACE` | `0` | `1` stops and replaces a running container |
| `READY_TIMEOUT` | `3600` | first boot loads 476 G of weights |
| `P2P_CHECK` | `1` | `0` skips the P2P gate (debugging only) |
| `DRY_RUN` | `0` | `1` prints the resolved plan and exits |

Measurement and tuning knobs (`TWOSHOT_MB`, `SHARE`, `FAIRNESS`,
`POWER_LIMIT`, `ALLOW_POWER_MISMATCH`, `EXTRA_ARGS`) and the archived CSF
variables are documented in [docs/OPERATIONS.md](docs/OPERATIONS.md).

## Troubleshooting

**RAM Engram refuses to start with a memlock error.** The container inherits the
host `RLIMIT_MEMLOCK` hard limit. Raise it on the launching shell (as root; no
reboot), then run `./start.sh` from that shell:

```bash
prlimit --memlock=unlimited:unlimited -- runuser -u $(id -un) -- bash
ulimit -l                                  # should print: unlimited
```

Or use `ENGRAM_TABLE_MEMORY=disk`. Full explanation, including the Fedora 45 /
Python 3.15 note: [docs/OPERATIONS.md](docs/OPERATIONS.md#memlock).

**The P2P gate refuses to launch.** `start.sh` checks the host ASPM policy,
CUDA peer access on all 12 ordered pairs, and NCCL selecting `via P2P/`. It
prints the fix for whichever check failed; the long version is in
[docs/OPERATIONS.md](docs/OPERATIONS.md#p2p-gate).

## Documentation

| Document | Contents |
|---|---|
| [docs/PERFORMANCE.md](docs/PERFORMANCE.md) | Measurement protocol, hardware tiers, TP4 vs TP3, tuning A/Bs, run index, reproduce commands |
| [docs/OPERATIONS.md](docs/OPERATIONS.md) | Full environment reference, podman flags, memlock, P2P gate, CDI, platform |
| [docs/PROVENANCE.md](docs/PROVENANCE.md) | Upstream recipe, image lineage, sampling pins, checkpoint identity, deviations |
| [docs/EXPERIMENTS.md](docs/EXPERIMENTS.md) | Tested and not recommended (CSF checkpoint) |

## Provenance

This project started from the DeepSeek V4.1 serving recipe in
[local-inference-lab/rtx6kpro](https://github.com/local-inference-lab/rtx6kpro)
(`models/deepseek-v4.1-flash.md`), which remains the reference for the model
profile, image lineage and the Karmic Kraken measurement methodology. Image:
`ghcr.io/local-inference-lab/vllm:karmic-kraken-beta`. Every deviation is
recorded in [docs/PROVENANCE.md](docs/PROVENANCE.md).
