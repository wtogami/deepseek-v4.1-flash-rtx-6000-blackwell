# DeepSeek-V4.1-Flash on 4x RTX PRO 6000 Blackwell

Serves `deepseek-ai/DeepSeek-V4.1-Flash` (TP4/DCP1, B12X, adaptive DSpark K7)
from a local flat checkpoint under rootless podman, with the Engram table in
RAM by default and a disk-backed option.

The image's `ds41-flash` profile drifts from the measured serving
configuration on two values (`top_p` 1.0 vs 0.95, probabilistic vs greedy
draft sampling), so `start.sh` pins the measured values with two native CLI
overrides after the image. `DRY_RUN=1 ./start.sh` prints the launcher's
resolved plan for auditing.

Every deviation this project makes from its starting point is recorded in
[Provenance and changes from the original recipe](#provenance-and-changes-from-the-original-recipe)
at the end of this document.

## Run

```bash
./start.sh                          # recipe defaults (MAX_MODEL_LEN=-1)
MAX_MODEL_LEN=131072 ./start.sh     # Karmic Kraken comparison context
ENGRAM_TABLE_MEMORY=disk ./start.sh # disk-backed Engram (option; RAM is default)
./stop.sh
```

The API model is `DeepSeek-V4.1-Flash` on `0.0.0.0:8000`. Readiness is polled
on `/health` (503 while loading, 200 when ready).

## Environment

| Variable | Default | Meaning |
|---|---|---|
| `ENGRAM_TABLE_MEMORY` | `ram` | `ram` or `disk`; never switched silently |
| `MAX_MODEL_LEN` | `-1` | recipe default; `131072` for the KK comparison |
| `MAX_NUM_SEQS` | `32` | request slots |
| `MAX_NUM_BATCHED_TOKENS` | `4096` | |
| `GPU_MEMORY_UTILIZATION` | `0.95` | |
| `JIT_MONITOR_MODE` | `warn` | |
| `MODEL_DIRECTORY` | `~/models/DeepSeek-V4.1-Flash` | flat checkpoint dir |
| `STATE_DIRECTORY` | `./state` | mounted at `/cache` (JIT + runtime state) |
| `MEMORY_LIMIT` | `512g` | KK parity; empty disables |
| `PORT` / `BIND_ADDRESS` | `8000` / `0.0.0.0` | host networking |
| `GPU` | `all` | CDI device selection; needs 4 cards |
| `REPLACE` | `0` | `1` stops and replaces a running container |
| `P2P_CHECK` | `1` | `0` skips the P2P gate (debugging only) |
| `READY_TIMEOUT` | `3600` | first boot loads 476 G of weights |
| `EXTRA_ARGS` | — | extra native options after the image |
| `TWOSHOT_MB` | `6` | MiB ceiling (1–8) for the B12X two-shot BF16 all-reduce; overrides the profile default `off`. 6 covers the whole 96 KiB–6 MiB band (A/B: C8 verifier +4.8%, see `results/twoshot-AB.md`). `TWOSHOT_MB=off` restores the profile default; `start.sh` warns if the engine falls back at boot. Note: mid-band outputs are not byte-identical to ring-config runs (accumulation order) — re-baseline strict hashes when toggling |
| `SHARE` | — | sets `PREFILL_COMPUTE_SHARE` (`auto` or 0<v<1); profile default 0.4 |
| `FAIRNESS` | — | `none` drops the compute-share arg entirely (engine default). Note: measured no effect on uncontended prefill — the scheduler already exempts it (`results/twoshot-AB.md`); relevant only to mixed prefill+decode serving |
| `DRY_RUN` | `0` | `1` prints the resolved plan and exits |

Podman flags: CDI `--device nvidia.com/gpu=all`, `--network=host`,
`--ipc=host` (host `/dev/shm` is 498 G, covering the recipe's `--shm-size
32g`), `--cap-add IPC_LOCK` + `--ulimit memlock=-1:-1` (Fedora's host ceiling
is 8 MiB), `--ulimit stack=67108864:67108864`,
`--security-opt seccomp=unconfined` (io_uring loader), `--init`,
`--restart=unless-stopped`.

The io_uring weight loader and the RAM Engram pin both charge against
`RLIMIT_MEMLOCK`. Rootless podman cannot raise it above the host user's hard
limit (8 MiB on Fedora): `--ulimit memlock=-1:-1` is capped at that hard limit,
not effective. If the ceiling is too low, the engine aborts at weight load with
`io_uring_register_buffers: ENOMEM`.

`start.sh` gates on this: it reads the host `RLIMIT_MEMLOCK` hard limit and
refuses a doomed RAM-mode launch (printing the fix) instead of booting into the
crash. Disk mode needs far less locked memory and is not gated the same way.

The reliable fix is to raise the rlimit on the launching shell (as root; no
reboot). `runuser` — unlike `su` — does not go through PAM, so it keeps the
raised limit:

```bash
prlimit --memlock=unlimited:unlimited -- runuser -u $(id -un) -- bash
ulimit -l                                  # should print: unlimited
# then run ./start.sh from that shell
```

Note: the systemd `LimitMEMLOCK=` / `DefaultLimitMEMLOCK=` levers (slice,
`user@.service` drop-in, `user.conf`) do NOT work here — `RLIMIT_MEMLOCK` is a
per-process rlimit, and the user manager reverts forked children to the 8 MiB
default.

## P2P gate

The TP4 cross-rank exchange runs on the direct PCIe peer path only if (a) CUDA
peer access is available for every ordered GPU pair, (b) the fabric does not
silently discard P2P posted writes, and (c) NCCL actually selects the P2P
transport. On this platform (Dell Precision 7865, AMD sWRX8/WRX80) peer access
is on by default, but the fabric silently discards P2P posted writes (no AER,
no Xid) when ASPM L1 is enabled, which is the BIOS default.

Peer access alone is not enough. Every GPU pair on this board is **PHB** in
NCCL's topology (all four cards hang off the CPU root complex; `nvidia-smi
topo -m` shows NODE everywhere, and NCCL's own dump shows 4–5 hops per pair).
Stock NCCL's default P2P level is **PXB**, so it rejects every pair and stages
the TP4 allreduce through host shared memory — the server log shows
`via SHM/direct` on every channel — even though the peer path is healthy. The
launcher therefore sets `NCCL_P2P_LEVEL=PHB` (in `NCCL_ENV_ARGS`, shared by the
gate and the server run), which admits the direct peer path: every channel
becomes `via P2P/CUMEM` and `isAllDirectP2p 1`.

`start.sh` gates on all three before launching (so a failed gate does not stop
a running container):

1. **Host**: the PCIe ASPM policy must be `[performance]` (L1 disabled). This
   requires `pcie_aspm=force` on the kernel command line (GRUB), because the
   BIOS FADT declares ASPM unsupported and the kernel otherwise leaves the
   firmware bits in place. Verify after every boot:
   ```bash
   grep pcie_aspm=force /proc/cmdline
   cat /sys/module/pcie_aspm/parameters/policy   # should read [performance]
   ```
2. **Container**: `torch.cuda.can_device_access_peer(i, j)` must return 1 for
   all 12 ordered pairs (`repro/p2p_peer_check.py`, run in the image with all
   GPUs). The gate prints the per-pair peer-access flag and a measured one-way
   copy speed (x8 legs ~13 GB/s, x16 legs ~25–28 GB/s) as evidence of no host
   bounce.
3. **Container**: NCCL's own transport selection, with the server's NCCL env
   (`repro/nccl_transport_check.py`, a 4-rank allreduce with
   `NCCL_DEBUG=INFO`). Every channel must be `via P2P/`; any `via SHM/` or
   `via NET/` channel refuses the launch. The gate prints the channel counts.

If any check fails, `start.sh` refuses (exit 2) and prints the fix. Set
`P2P_CHECK=0` to skip (debugging only; not recommended).

Note: peer access being *available* is not the same as the peer path being
*correct*. The write-loss defect (silent posted-write discard under ASPM L1)
is checked by `repro/p2p_write_loss_repro.py` — run N separate launches and
count launches with any loss (expected 0/N with L1 disabled). The event is
per-launch, not per-cycle.

## Benchmark

`run-bench.sh` runs the **exact** Karmic Kraken measurement script (pinned in
`bench/`, sha256-identical to the one that produced the KK table — see
`bench/PROVENANCE.md`) with the recorded invocation, plus a 1 Hz monitor:

```bash
KV_CAPACITY=<from server log> NAME=ram-131072 ./run-bench.sh
```

`KV_CAPACITY` is the "GPU KV cache size" line from the startup log. About 12
minutes: 5 x 30 s prefill windows (unique nominal-32K prompts, client TTFT)
and 5 x 30 s decode windows at C1 and C8 (context zero, 15 s warmup).
Decode rates are server-side `/metrics` deltas
(`vllm:generation_tokens_total`, `vllm:spec_decode_num_accepted_tokens_total`).

`monitor.tsv` columns (units): `t` s; `p*_rx`/`p*_tx` MB/s per GPU (dmon);
`g*_util` %; `g*_smclk` MHz; `g*_pwr` W; `g*_mem` MiB; `load1`; `memavail_kb`
kB. PCIe ceiling on the current platform: Gen4 x16 ~32 GB/s per direction on
every GPU.

`DROP_CACHES=1` calls `/usr/local/bin/ple-drop-caches` before each cell
(page-cache drop with a fail-closed idle check); only meaningful for disk
Engram.

## Platform

4x RTX PRO 6000 Blackwell (2x Workstation Edition + 2x Max-Q), all on Gen4
x16; Supermicro AS-5014A-TT (M12SWA-TF), Threadripper PRO 5995WX 64c/64t,
503 GiB DDR4, Fedora 44, podman 5.8, driver 615.78.08, 325 W per GPU. The
Karmic Kraken reference platform is a Gen5 x16 host with 600 W Workstation
Edition cards (see Provenance).

## Provenance and changes from the original recipe

This project started from the DeepSeek V4.1 serving recipe in
[local-inference-lab/rtx6kpro](https://github.com/local-inference-lab/rtx6kpro)
(`models/deepseek-v4.1-flash.md`). The upstream recipe remains the reference
for the model profile, image lineage, and the Karmic Kraken measurement
methodology. Everything this project changed is listed here:

- **Two-shot mid-band default.** `TWOSHOT_MB=6` raises the B12X two-shot
  ceiling to cover the whole 96 KiB..6 MiB band (the image profile ships
  `off`). Measured +4.8% C8 verifier steps/s; prefill and C1 unchanged
  (`results/twoshot-AB.md`).
- **Host P2P prerequisites documented and required.** Resizable BAR with
  BAR1 >= 96 GiB, `ForceP2P=0x11;RMForceP2PType=1;RMPcieP2PType=2;GrdmaPciTopoCheckOverride=1;EnableResizableBar=1`,
  and `nvidia_uvm uvm_disable_hmm=1`. Without them the B12X oneshot/two-shot
  path silently stages through SysMem while `cudaMemcpy`/NCCL still look
  healthy. Measured +7.4% C8 verifier steps/s after enabling.
- **P2P gate in `start.sh`.** Three checks before launch: ASPM
  `[performance]`, CUDA peer access on all 12 ordered pairs, and an NCCL
  transport check requiring every channel `via P2P/` (server runs with
  `NCCL_P2P_LEVEL=PHB`).
- **Memlock gate.** RAM Engram needs ~189 GiB of locked memory; the script
  refuses a doomed launch when the host `RLIMIT_MEMLOCK` hard limit is too
  low.
- **CDI spec regeneration.** The rootless CDI spec is regenerated on every
  start so it always matches the current hardware, enumeration and device
  nodes; stale `/dev` paths after a module reload or reboot cannot break
  container injection. Restrict devices with `GPU=`, which selects CDI
  entities at run time.
- **Measured sampling values pinned.** `top_p=0.95` and greedy draft
  sampling are passed as native CLI overrides because the image profile
  defaults drifted from the measured configuration.
- **Comparison and option modes.** `MAX_MODEL_LEN=131072` for the Karmic
  Kraken comparison; `ENGRAM_TABLE_MEMORY=disk` for the disk-backed table.
- **Pinned measurement harness.** `run-bench.sh` runs the exact Karmic
  Kraken script (sha256-pinned in `bench/`) and `analyze.py` regenerates the
  comparison report.

Additional provenance:

- KK protocol + targets: `rtx6kpro/benchmarks/karmic-kraken-serving.md`,
  `karmic-kraken-serving-samples.json`
- Image: `ghcr.io/local-inference-lab/vllm:karmic-kraken-beta`
- Checkpoint identity: `config.json` sha256 `8be45ce0…`,
  `tokenizer_config.json` `6ac8c8dc…` — match the KK measurement artifacts