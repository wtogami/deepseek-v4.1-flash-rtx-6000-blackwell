# Operations

Everything needed to run, gate and troubleshoot the launcher. The README keeps
the short version; this file is the reference.

## Environment reference

| Variable | Default | Meaning |
|---|---|---|
| `ENGRAM_TABLE_MEMORY` | `ram` | `ram` or `disk`; never switched silently |
| `MAX_MODEL_LEN` | `-1` | model default; `131072` was used for the Karmic Kraken comparison cells |
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
| `TWOSHOT_MB` | `6` | MiB ceiling (1–8) for the B12X two-shot BF16 all-reduce; overrides the profile default `off`. 6 covers the whole 96 KiB–6 MiB band (A/B: C8 verifier +4.8%, see [PERFORMANCE.md](PERFORMANCE.md#tuning-ab)). `TWOSHOT_MB=off` restores the profile default; `start.sh` warns if the engine falls back at boot. Note: mid-band outputs are not byte-identical to ring-config runs (accumulation order) — re-baseline strict hashes when toggling |
| `SHARE` | — | sets `PREFILL_COMPUTE_SHARE` (`auto` or 0<v<1); profile default 0.4 |
| `FAIRNESS` | — | `none` drops the compute-share arg entirely (engine default). Note: measured no effect on uncontended prefill — the scheduler already exempts it; relevant only to mixed prefill+decode serving |
| `DRY_RUN` | `0` | `1` prints the resolved plan and exits |
| `CSF` | `0` | **archived** — `1` served the lossless FP4-CSF container. Not recommended; see [EXPERIMENTS.md](EXPERIMENTS.md) |
| `CSF_DIRECTORY` | `/nvme1/models/DeepSeek-V4.1-Flash-1017-lossless-CSF` | **archived** — CSF container path (used when `CSF=1`) |
| `POWER_LIMIT` | `325` | W per GPU that `csf-ab.sh` requires for both arms (archived with CSF) |
| `ALLOW_POWER_MISMATCH` | `0` | `1` lets `csf-ab.sh` run with off-target power limits (archived with CSF) |

## Podman flags

CDI `--device nvidia.com/gpu=all`, `--network=host`, `--ipc=host` (host
`/dev/shm` is 498 G, covering the recipe's `--shm-size 32g`), `--cap-add
IPC_LOCK` + `--ulimit memlock=-1:-1` (Fedora's host ceiling is 8 MiB by
default), `--ulimit stack=67108864:67108864`, `--security-opt
seccomp=unconfined` (io_uring loader), `--init`, `--restart=unless-stopped`.

## Memlock

The io_uring weight loader and the RAM Engram pin both charge against
`RLIMIT_MEMLOCK`. Rootless podman cannot raise it above the host user's hard
limit (8 MiB on a stock Fedora): `--ulimit memlock=-1:-1` is capped at that hard
limit, not effective. If the ceiling is too low, the engine aborts at weight
load with `io_uring_register_buffers: ENOMEM`.

`start.sh` gates on this: it reads the host `RLIMIT_MEMLOCK` hard limit and
refuses a doomed RAM-mode launch (printing the fix) instead of booting into the
crash. Disk mode needs far less locked memory and is not gated the same way.
The gate compares the limit against `resource.RLIM_INFINITY` rather than the
literal `-1`, and converts to MiB before bash sees it: Python 3.15 (Fedora 45)
reports infinity as `2**64-1` on Linux, and a raw byte count wraps negative in
bash's signed 64-bit arithmetic, which would read as a 0 MiB ceiling even
though `ulimit -l` says `unlimited`.

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
transport. On this platform (Supermicro AS-5014A-TT; earlier the Dell Precision
7865, same conclusion) peer access is on by default, but the fabric silently
discards P2P posted writes (no AER, no Xid) when ASPM L1 is enabled, which is
the BIOS default.

Peer access alone is not enough. Every GPU pair on this board is **PHB** (or
NODE across root segments) in NCCL's topology, while stock NCCL's default P2P
level is **PXB**, so it rejects every pair and stages the TP4 allreduce through
host shared memory — the server log shows `via SHM/direct` on every channel —
even though the peer path is healthy. The launcher therefore sets
`NCCL_P2P_LEVEL=PHB` (in `NCCL_ENV_ARGS`, shared by the gate and the server
run), which admits the direct peer path: every channel becomes `via P2P/CUMEM`
and `isAllDirectP2p 1`.

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

## CDI spec regeneration

The rootless CDI spec is regenerated on every start so it always matches the
current hardware, enumeration and device nodes; stale `/dev` paths after a
module reload or reboot cannot break container injection. Restrict devices with
`GPU=`, which selects CDI entities at run time.

## Platform

4× RTX PRO 6000 Blackwell (2× Workstation Edition + 2× Max-Q), all on Gen4
x16; Supermicro AS-5014A-TT (M12SWA-TF), Threadripper PRO 5995WX 64c/64t,
503 GiB DDR4, Fedora 45 (Python 3.15; the memlock gate handles the changed
`RLIM_INFINITY`), podman 5.8, driver 615.78.08, 325 W per GPU. The Karmic
Kraken reference host is DDR5 with PCIe 5.0 and a +6000 MHz memory offset (see
[PROVENANCE.md](PROVENANCE.md)).

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `io_uring_register_buffers: ENOMEM` at weight load | `RLIMIT_MEMLOCK` too low for the io_uring loader / RAM Engram | Raise it on the launching shell — see [Memlock](#memlock) — or use `ENGRAM_TABLE_MEMORY=disk` |
| Server log shows `via SHM/direct` on every channel | NCCL rejected the PHB/NODE paths at its PXB default, or ASPM L1 is enabled | Check the gate output; `NCCL_P2P_LEVEL=PHB` is set by the launcher, and ASPM must be `[performance]` — see [P2P gate](#p2p-gate) |
| Silent P2P posted-write loss, no AER/Xid | ASPM L1 enabled | `pcie_aspm=force` on the kernel command line; verify the policy file |
| `CSF=1` refuses or warns | CSF is archived and not recommended | Use the default checkpoint; see [EXPERIMENTS.md](EXPERIMENTS.md) |
