#!/usr/bin/env python3
"""Reproducer for silent PCIe P2P posted-write loss on the Dell Precision
7865 Tower (AMD sWRX8 / WRX80, BIOS 1.29.0, driver 615.78.08): the fabric
discards peer posted writes without reporting anything anywhere — no AER,
no IO_PAGE_FAULT under Translated IOMMU + interrupt remapping, no Xid,
zero link replays.

IMPORTANT — the defect is a TRAFFIC-PATTERN state machine, not a per-write
coin flip. ~150 single-leg 16 MiB peer writes on the bad route (including
back-to-back and with 3 s / 15 s idle gaps, plus 11 CE copies) never fired
it. The multi-leg cycle below fired it 11/11 independent processes, always
on the SECOND cycle's 0->3 write, losing 62-91 KB. So: run THIS cycle,
do not simplify it.

Each cycle writes a 16 MiB SM-stored pattern over P2P on seven legs,
exactly in this order (GPU indices = current nvidia-smi enumeration;
see ../evidence/hardware-snapshot for bus IDs):

  (0,3) (1,3) (2,3) (3,0) (2,0) (0,2) (3,1)

GPU0 = WS card on an NBIO00 sibling half (00:01.1 or, after the
       2026-10-31 reseat, 00:01.3 — both halves fire identically)
GPU3 = WS card in SLOT5, behind the WRX80 chipset switch (e8:00.0)
GPU1/GPU2 = Max-Q cards on x16 ports 50:03.1 / 9b:01.1

Bad leg: 0->3 (00:01.1 egress -> chipset-attached target), cycle 2.
Historic defect A (era 1): with a second card on the SIBLING port
00:01.3, the same port pair lost ~37 % of ALL peer posted writes
deterministically; both engines; that slot is currently empty.

  python3 p2p_write_loss_repro.py [--trials CYCLES]  (default 10)

Exit 1 when any cycle shows a loss (the expected outcome on this box).
~2-3 min wall clock (includes torch/triton import). Needs torch + triton
(both ship with PyTorch); run inside any NVIDIA CUDA container with peer
access:

  podman run --rm --device nvidia.com/gpu=all -v $PWD:/work:z \
    --entrypoint python3 <image-with-torch> /work/p2p_write_loss_repro.py
"""
import argparse
import ctypes
import sys

import torch
import triton
import triton.language as tl

SZ = 1 << 24
DIRS = [(0, 3), (1, 3), (2, 3), (3, 0), (2, 0), (0, 2), (3, 1)]

rt = ctypes.CDLL("libcudart.so")


@triton.jit
def peer_store(out, BLOCK: tl.constexpr):
    # Launched on the *current* device (the requester); `out` points into
    # peer BAR memory, so every store is a P2P posted write from SMs.
    i = tl.program_id(0) * BLOCK + tl.arange(0, BLOCK)
    tl.store(out + i, 42.0)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--trials", type=int, default=10, help="cycle count")
    args = ap.parse_args()

    for a in range(4):
        rt.cudaSetDevice(a)
        for b in range(4):
            if a != b:
                rt.cudaDeviceEnablePeerAccess(b, 0)

    dirty = {}
    for cycle in range(args.trials):
        events = []
        for src, dst in DIRS:
            tgt = torch.zeros(SZ, device=f"cuda:{dst}")
            torch.cuda.set_device(src)
            peer_store[(SZ // 1024,)](tgt, BLOCK=1024)
            torch.cuda.synchronize(src)
            torch.cuda.synchronize(dst)
            missing = int((tgt != 42.0).sum().item())
            if missing:
                events.append(f"{src}->{dst} MISSING={missing}/{SZ}")
                dirty[(src, dst)] = dirty.get((src, dst), 0) + 1
        print(f"cycle {cycle}: " + ("  ".join(events) if events else "all exact"),
              flush=True)

    print("--- summary ---", flush=True)
    for leg, n in sorted(dirty.items(), key=lambda kv: -kv[1]):
        print(f"{leg[0]}->{leg[1]}: {n}/{args.trials} cycles dirty", flush=True)
    if not dirty:
        print(f"no loss detected in {args.trials} cycles", flush=True)
    sys.exit(1 if dirty else 0)


if __name__ == "__main__":
    main()
