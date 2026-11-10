#!/usr/bin/env python3
"""Check which transport NCCL selects for intra-node collectives.

Runs an N-rank torch.distributed NCCL allreduce (one rank per GPU) with
NCCL_DEBUG=INFO and reports the per-channel transport selection. This answers
"does NCCL use the direct PCIe peer path (P2P) or a host bounce (SHM)?" for
this platform, with the same NCCL version / GPUs / env as the serving engine.

P2P transport lines look like:  NCCL INFO Channel 00 : 0[0] -> 1[1] via P2P/IPC/read
SHM (host bounce) lines look like: NCCL INFO Channel 00 : 0[0] -> 1[1] via SHM

Run inside a CUDA container with all GPUs injected:
  podman run --rm --device nvidia.com/gpu=all -v $PWD/repro:/work:z \
    --entrypoint python3 <image> /work/nccl_transport_check.py
"""
import os
import re
import sys

import torch
import torch.distributed as dist
import torch.multiprocessing as mp


def worker(rank, world):
    os.environ["MASTER_ADDR"] = "127.0.0.1"
    os.environ["MASTER_PORT"] = "29517"
    torch.cuda.set_device(rank)
    dist.init_process_group("nccl", rank=rank, world_size=world)
    t = torch.ones(1024, 1024, device=f"cuda:{rank}")
    for _ in range(3):
        dist.all_reduce(t)
    dist.barrier()
    dist.destroy_process_group()


def main():
    n = torch.cuda.device_count()
    if n < 2:
        print(f"need >= 2 GPUs, got {n}", file=sys.stderr)
        return 1
    os.environ["NCCL_DEBUG"] = "INFO"
    os.environ["NCCL_SOCKET_IFNAME"] = "lo"
    print(f"running {n}-rank NCCL allreduce with NCCL_DEBUG=INFO", file=sys.stderr)
    mp.spawn(worker, args=(n,), nprocs=n, join=True)
    print("allreduce done", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())