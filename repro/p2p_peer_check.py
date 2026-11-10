#!/usr/bin/env python3
"""Verify CUDA peer access (P2P) is available for every ordered GPU pair.

This is the "is P2P enabled" check for the TP4 serving path. The cross-rank
exchange runs on the direct PCIe peer path only when CUDA peer access is
available for every ordered pair; otherwise NCCL falls back to a host bounce.

Exit 0 if all ordered pairs report peer access (torch.cuda.can_device_access_peer
== 1); exit 1 otherwise. Prints a per-pair table of the peer-access flag and a
measured one-way copy speed (GB/s) as evidence that the copy does not bounce
through host memory.

NOTE: peer access being *available* is not the same as the peer path being
*correct*. On the Dell Precision 7865 (AMD sWRX8/WRX80) the fabric silently
discards P2P posted writes when ASPM L1 is enabled (no AER, no Xid). That
defect is avoided by booting with pcie_aspm=force (policy [performance]);
start.sh gates on that host-side posture separately. To check for the write
loss itself, use p2p_write_loss_repro.py.

Run inside a CUDA container with torch, with all GPUs injected:
  podman run --rm --device nvidia.com/gpu=all -v $PWD/repro:/work:z \
    --entrypoint python3 <image> /work/p2p_peer_check.py
"""
import argparse
import sys
import time

import torch


def main() -> int:
    ap = argparse.ArgumentParser(description="Check CUDA peer access for all ordered GPU pairs.")
    ap.add_argument("--copy-mib", type=int, default=256,
                    help="one-way copy size in MiB (default 256)")
    ap.add_argument("--iters", type=int, default=3,
                    help="timed copy iterations per pair (default 3)")
    args = ap.parse_args()

    n = torch.cuda.device_count()
    if n < 2:
        print(f"only {n} GPU(s) visible; nothing to check", file=sys.stderr)
        return 0

    bad = 0
    print(f"GPUs visible: {n}")
    for i in range(n):
        for j in range(n):
            if i == j:
                continue
            ok = bool(torch.cuda.can_device_access_peer(i, j))
            src = torch.empty(args.copy_mib * 1024 * 1024 // 4,
                              dtype=torch.float32, device=f"cuda:{i}")
            dst = torch.empty_like(src, device=f"cuda:{j}")
            dst.copy_(src, non_blocking=True)  # warmup
            torch.cuda.synchronize(j)
            t0 = time.perf_counter()
            for _ in range(args.iters):
                dst.copy_(src, non_blocking=True)
            torch.cuda.synchronize(j)
            dt = time.perf_counter() - t0
            gbps = (args.copy_mib * 1024 * 1024 * args.iters) / dt / 1e9
            if not ok:
                bad += 1
            print(f"  {i} -> {j}: peer_access={int(ok)}  {gbps:6.2f} GB/s  "
                  f"{'OK' if ok else 'NO-P2P'}")
    if bad:
        print(f"FAIL: {bad} ordered pair(s) lack peer access", file=sys.stderr)
        return 1
    print(f"all {n * (n - 1)} ordered pairs report peer access")
    return 0


if __name__ == "__main__":
    sys.exit(main())