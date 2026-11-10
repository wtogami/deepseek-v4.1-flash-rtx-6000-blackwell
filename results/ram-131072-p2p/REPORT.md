# ram-131072-p2p — results vs Karmic Kraken

Protocol: llm_decode_bench.py v0.6.2 (sha256-pinned, see bench/PROVENANCE.md), 5 warmed 30 s windows per cell, 15 s warmup, 32K unique prefill (client TTFT), context-zero decode C1/C8, server-side /metrics accounting.

## Headline

| Cell | Ours (median of 5) | KK (Max-Q/325W) | Delta |
|---|---:|---:|---:|
| 32K prefill tok/s | 10,323 | 17,982 | -42.59% |
| C1 output tok/s | 122.1 | 249.1 | -50.97% |
| C1 verifier steps/s | 67.47 | 98.58 | -31.56% |
| C1 accepted length | 1.811 | 2.571 | -29.55% |
| C8 output tok/s | 434.2 | 805.5 | -46.09% |
| C8 verifier steps/s | 188.23 | 361.87 | -47.98% |
| C8 accepted length | 2.307 | 2.295 | +0.52% |
| KV capacity tokens | 4,654,930 | 4,727,748 | -1.54% |

## Per-window samples

| file | prefill tok/s | samples |
|---|---:|---:|
| prefill-2.json | 10,352 | 9 |
| prefill-3.json | 10,323 | 9 |
| prefill-4.json | 10,322 | 9 |
| prefill-5.json | 10,311 | 9 |
| prefill.json | 10,388 | 9 |

| file | C1 output tok/s | verifier steps/s | accepted length | source |
|---|---:|---:|---:|---|
| decode-1.json | 125.6 | 67.11 | 1.871 | openai_continuous_usage |
| decode-2.json | 120.4 | 68.87 | 1.749 | openai_continuous_usage |
| decode-3.json | 122.1 | 67.41 | 1.811 | openai_continuous_usage |
| decode-4.json | 122.5 | 67.47 | 1.815 | openai_continuous_usage |
| decode-5.json | 120.8 | 69.33 | 1.742 | openai_continuous_usage |

| file | C8 output tok/s | verifier steps/s | accepted length | source |
|---|---:|---:|---:|---|
| decode-1.json | 434.2 | 187.85 | 2.312 | openai_continuous_usage |
| decode-2.json | 433.4 | 189.88 | 2.282 | openai_continuous_usage |
| decode-3.json | 438.7 | 185.83 | 2.361 | openai_continuous_usage |
| decode-4.json | 436.0 | 188.99 | 2.307 | openai_continuous_usage |
| decode-5.json | 427.2 | 188.23 | 2.270 | openai_continuous_usage |

## PCIe and system (monitor.tsv)

Ceilings per direction: Gen4 x8 ~15,750 MB/s (GPUs 0,3), Gen4 x16 ~31,500 MB/s (GPUs 1,2).

| scope | GPU | width | tx max | tx p95 | tx mean | rx max | rx p95 | rx mean | util max | pwr max | clk max | mem max |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| overall | 0 | x8 | 11,335 MB/s (72%) | 9,175 MB/s | 3,388 MB/s | 12,285 MB/s (78%) | 10,327 MB/s | 3,538 MB/s | 100 % | 309 W | 2,887 MHz | 93,643 MiB |
| overall | 1 | x16 | 10,908 MB/s (35%) | 9,526 MB/s | 3,375 MB/s | 11,114 MB/s (35%) | 9,251 MB/s | 3,309 MB/s | 100 % | 256 W | 2,340 MHz | 93,643 MiB |
| overall | 2 | x16 | 11,883 MB/s (38%) | 9,369 MB/s | 3,402 MB/s | 11,433 MB/s (36%) | 9,751 MB/s | 3,373 MB/s | 100 % | 281 W | 2,340 MHz | 93,643 MiB |
| overall | 3 | x8 | 11,794 MB/s (75%) | 9,512 MB/s | 3,417 MB/s | 11,914 MB/s (76%) | 9,625 MB/s | 3,388 MB/s | 100 % | 305 W | 2,880 MHz | 93,643 MiB |
| decode_active | 0 | x8 | 11,335 MB/s (72%) | 9,241 MB/s | 3,772 MB/s | 12,285 MB/s (78%) | 10,407 MB/s | 3,934 MB/s | 100 % | 309 W | 2,880 MHz | 93,643 MiB |
| decode_active | 1 | x16 | 10,908 MB/s (35%) | 9,665 MB/s | 3,770 MB/s | 11,114 MB/s (35%) | 9,296 MB/s | 3,686 MB/s | 100 % | 256 W | 2,340 MHz | 93,643 MiB |
| decode_active | 2 | x16 | 11,883 MB/s (38%) | 9,507 MB/s | 3,809 MB/s | 11,433 MB/s (36%) | 9,839 MB/s | 3,773 MB/s | 100 % | 281 W | 2,340 MHz | 93,643 MiB |
| decode_active | 3 | x8 | 11,794 MB/s (75%) | 9,567 MB/s | 3,827 MB/s | 11,914 MB/s (76%) | 9,747 MB/s | 3,794 MB/s | 100 % | 305 W | 2,880 MHz | 93,643 MiB |
| decode-1 | 0 | x8 | 5,671 MB/s (36%) | 5,528 MB/s | 2,108 MB/s | 5,839 MB/s (37%) | 5,588 MB/s | 2,088 MB/s | 100 % | 303 W | 2,880 MHz | 93,643 MiB |
| decode-1 | 1 | x16 | 5,469 MB/s (17%) | 5,392 MB/s | 2,081 MB/s | 5,958 MB/s (19%) | 5,605 MB/s | 2,106 MB/s | 100 % | 256 W | 2,340 MHz | 93,643 MiB |
| decode-1 | 2 | x16 | 5,917 MB/s (19%) | 5,572 MB/s | 2,162 MB/s | 5,505 MB/s (17%) | 5,434 MB/s | 1,986 MB/s | 100 % | 281 W | 2,340 MHz | 93,643 MiB |
| decode-1 | 3 | x8 | 5,776 MB/s (37%) | 5,574 MB/s | 2,155 MB/s | 5,648 MB/s (36%) | 5,607 MB/s | 2,055 MB/s | 100 % | 305 W | 2,872 MHz | 93,643 MiB |
| decode-2 | 0 | x8 | 5,864 MB/s (37%) | 5,660 MB/s | 2,258 MB/s | 5,685 MB/s (36%) | 5,598 MB/s | 2,016 MB/s | 100 % | 309 W | 2,880 MHz | 93,643 MiB |
| decode-2 | 1 | x16 | 5,544 MB/s (18%) | 5,453 MB/s | 2,252 MB/s | 5,715 MB/s (18%) | 5,546 MB/s | 2,034 MB/s | 100 % | 253 W | 2,340 MHz | 93,643 MiB |
| decode-2 | 2 | x16 | 5,716 MB/s (18%) | 5,642 MB/s | 2,331 MB/s | 5,541 MB/s (18%) | 5,371 MB/s | 1,994 MB/s | 100 % | 276 W | 2,340 MHz | 93,643 MiB |
| decode-2 | 3 | x8 | 5,678 MB/s (36%) | 5,621 MB/s | 2,322 MB/s | 5,673 MB/s (36%) | 5,556 MB/s | 2,062 MB/s | 100 % | 304 W | 2,872 MHz | 93,643 MiB |
| decode-3 | 0 | x8 | 5,683 MB/s (36%) | 5,527 MB/s | 2,172 MB/s | 5,713 MB/s (36%) | 5,510 MB/s | 2,045 MB/s | 100 % | 302 W | 2,880 MHz | 93,643 MiB |
| decode-3 | 1 | x16 | 5,647 MB/s (18%) | 5,385 MB/s | 2,110 MB/s | 5,767 MB/s (18%) | 5,537 MB/s | 2,056 MB/s | 100 % | 255 W | 2,340 MHz | 93,643 MiB |
| decode-3 | 2 | x16 | 5,851 MB/s (19%) | 5,542 MB/s | 2,189 MB/s | 5,516 MB/s (18%) | 5,340 MB/s | 1,952 MB/s | 100 % | 280 W | 2,340 MHz | 93,643 MiB |
| decode-3 | 3 | x8 | 5,875 MB/s (37%) | 5,513 MB/s | 2,175 MB/s | 5,697 MB/s (36%) | 5,602 MB/s | 2,044 MB/s | 100 % | 304 W | 2,880 MHz | 93,643 MiB |
| decode-4 | 0 | x8 | 5,753 MB/s (37%) | 5,592 MB/s | 2,072 MB/s | 5,660 MB/s (36%) | 5,580 MB/s | 2,066 MB/s | 100 % | 309 W | 2,880 MHz | 93,643 MiB |
| decode-4 | 1 | x16 | 5,537 MB/s (18%) | 5,429 MB/s | 1,996 MB/s | 5,966 MB/s (19%) | 5,629 MB/s | 2,089 MB/s | 100 % | 253 W | 2,340 MHz | 93,643 MiB |
| decode-4 | 2 | x16 | 5,672 MB/s (18%) | 5,551 MB/s | 2,111 MB/s | 5,929 MB/s (19%) | 5,435 MB/s | 2,063 MB/s | 100 % | 279 W | 2,340 MHz | 93,643 MiB |
| decode-4 | 3 | x8 | 5,613 MB/s (36%) | 5,538 MB/s | 2,067 MB/s | 5,741 MB/s (36%) | 5,617 MB/s | 2,131 MB/s | 100 % | 304 W | 2,880 MHz | 93,643 MiB |
| decode-5 | 0 | x8 | 5,594 MB/s (36%) | 5,538 MB/s | 2,076 MB/s | 5,655 MB/s (36%) | 5,579 MB/s | 2,187 MB/s | 100 % | 302 W | 2,880 MHz | 93,643 MiB |
| decode-5 | 1 | x16 | 5,485 MB/s (17%) | 5,368 MB/s | 2,006 MB/s | 5,978 MB/s (19%) | 5,623 MB/s | 2,249 MB/s | 100 % | 253 W | 2,340 MHz | 93,643 MiB |
| decode-5 | 2 | x16 | 5,611 MB/s (18%) | 5,558 MB/s | 2,087 MB/s | 5,795 MB/s (18%) | 5,496 MB/s | 2,160 MB/s | 100 % | 279 W | 2,340 MHz | 93,643 MiB |
| decode-5 | 3 | x8 | 5,639 MB/s (36%) | 5,529 MB/s | 2,097 MB/s | 5,835 MB/s (37%) | 5,622 MB/s | 2,226 MB/s | 100 % | 305 W | 2,872 MHz | 93,643 MiB |
| prefill | 0 | x8 | 9,965 MB/s (63%) | 9,880 MB/s | 6,666 MB/s | 10,557 MB/s (67%) | 10,366 MB/s | 6,570 MB/s | 100 % | 303 W | 2,887 MHz | 93,641 MiB |
| prefill | 1 | x16 | 10,346 MB/s (33%) | 10,327 MB/s | 6,721 MB/s | 10,535 MB/s (33%) | 10,097 MB/s | 6,906 MB/s | 100 % | 213 W | 2,332 MHz | 93,641 MiB |
| prefill | 2 | x16 | 10,713 MB/s (34%) | 9,803 MB/s | 6,409 MB/s | 11,433 MB/s (36%) | 10,319 MB/s | 6,298 MB/s | 100 % | 225 W | 2,340 MHz | 93,641 MiB |
| prefill | 3 | x8 | 10,969 MB/s (70%) | 10,426 MB/s | 7,071 MB/s | 10,321 MB/s (66%) | 10,119 MB/s | 6,846 MB/s | 100 % | 292 W | 2,880 MHz | 93,639 MiB |
| prefill-2 | 0 | x8 | 10,326 MB/s (66%) | 10,132 MB/s | 7,184 MB/s | 10,683 MB/s (68%) | 10,586 MB/s | 7,524 MB/s | 100 % | 303 W | 2,887 MHz | 93,641 MiB |
| prefill-2 | 1 | x16 | 10,908 MB/s (35%) | 10,240 MB/s | 6,895 MB/s | 9,869 MB/s (31%) | 9,699 MB/s | 6,642 MB/s | 100 % | 217 W | 2,332 MHz | 93,641 MiB |
| prefill-2 | 2 | x16 | 10,261 MB/s (33%) | 10,160 MB/s | 6,464 MB/s | 10,462 MB/s (33%) | 10,322 MB/s | 6,843 MB/s | 100 % | 232 W | 2,340 MHz | 93,641 MiB |
| prefill-2 | 3 | x8 | 11,794 MB/s (75%) | 9,654 MB/s | 6,418 MB/s | 11,914 MB/s (76%) | 11,167 MB/s | 6,916 MB/s | 100 % | 296 W | 2,880 MHz | 93,639 MiB |
| prefill-3 | 0 | x8 | 11,335 MB/s (72%) | 9,492 MB/s | 6,382 MB/s | 10,725 MB/s (68%) | 10,593 MB/s | 7,441 MB/s | 100 % | 303 W | 2,880 MHz | 93,641 MiB |
| prefill-3 | 1 | x16 | 10,342 MB/s (33%) | 9,937 MB/s | 6,256 MB/s | 11,114 MB/s (35%) | 10,042 MB/s | 6,105 MB/s | 100 % | 219 W | 2,332 MHz | 93,641 MiB |
| prefill-3 | 2 | x16 | 10,478 MB/s (33%) | 10,174 MB/s | 6,567 MB/s | 10,928 MB/s (35%) | 10,730 MB/s | 6,512 MB/s | 100 % | 235 W | 2,340 MHz | 93,641 MiB |
| prefill-3 | 3 | x8 | 9,804 MB/s (62%) | 9,752 MB/s | 6,495 MB/s | 11,839 MB/s (75%) | 11,109 MB/s | 6,906 MB/s | 100 % | 298 W | 2,872 MHz | 93,639 MiB |
| prefill-4 | 0 | x8 | 10,138 MB/s (64%) | 9,940 MB/s | 6,637 MB/s | 11,242 MB/s (71%) | 10,707 MB/s | 7,914 MB/s | 100 % | 304 W | 2,880 MHz | 93,641 MiB |
| prefill-4 | 1 | x16 | 10,383 MB/s (33%) | 10,302 MB/s | 7,162 MB/s | 9,656 MB/s (31%) | 9,470 MB/s | 6,312 MB/s | 100 % | 220 W | 2,332 MHz | 93,641 MiB |
| prefill-4 | 2 | x16 | 11,883 MB/s (38%) | 10,882 MB/s | 7,190 MB/s | 10,721 MB/s (34%) | 10,594 MB/s | 7,624 MB/s | 100 % | 236 W | 2,340 MHz | 93,641 MiB |
| prefill-4 | 3 | x8 | 9,786 MB/s (62%) | 9,581 MB/s | 6,655 MB/s | 10,206 MB/s (65%) | 9,790 MB/s | 6,418 MB/s | 100 % | 299 W | 2,872 MHz | 93,639 MiB |
| prefill-5 | 0 | x8 | 9,775 MB/s (62%) | 9,640 MB/s | 6,082 MB/s | 12,285 MB/s (78%) | 10,623 MB/s | 6,887 MB/s | 100 % | 304 W | 2,880 MHz | 93,641 MiB |
| prefill-5 | 1 | x16 | 10,635 MB/s (34%) | 10,241 MB/s | 6,312 MB/s | 10,009 MB/s (32%) | 9,871 MB/s | 5,953 MB/s | 100 % | 220 W | 2,340 MHz | 93,641 MiB |
| prefill-5 | 2 | x16 | 10,055 MB/s (32%) | 9,746 MB/s | 6,098 MB/s | 11,374 MB/s (36%) | 10,681 MB/s | 6,771 MB/s | 100 % | 237 W | 2,340 MHz | 93,641 MiB |
| prefill-5 | 3 | x8 | 10,220 MB/s (65%) | 9,779 MB/s | 6,488 MB/s | 10,368 MB/s (66%) | 9,874 MB/s | 6,284 MB/s | 100 % | 299 W | 2,872 MHz | 93,639 MiB |

load1 max: 4.9   MemAvailable min: 805,528,664 kB

## Bottleneck analysis

PCIe is **not** the bottleneck. No link saturates in any window: the Gen4 x8
links (GPUs 0,3) peak at ~72–78% of their ~15,750 MB/s ceiling and the Gen4 x16
links (GPUs 1,2) peak at ~33–38% of their ~31,500 MB/s ceiling; per-direction
means are ~3.3–3.9 GB/s. So the large gaps vs KK (−42% to −51%) point to
compute, not I/O:

- **GPU SKU/link**: this box's GPUs 0,3 are Workstation Ed. on Gen4 **x8** at
  300 W; the KK reference was Max-Q on Gen4 **x16** at 325 W. The x8 links and
  the Workstation Ed. compute are the likely cause of the verifier-step and
  output-rate gaps.
- **KV cache**: 1.54% below KK (4,654,930 vs 4,727,748) because the current
  image enables CUDA-graph memory profiling by default (log suggests
  `--gpu-memory-utilization 0.9685` to restore the old effective size). Minor.
- **Weakest cell**: C1 accepted length is 29.6% below KK (1.811 vs 2.571) while
  C8 is at parity (+0.5%), so single-stream speculative acceptance — i.e.
  verifier cost per step — is the weakest link.

## P2P

**Corrected.** The platform-level peer path was healthy and stable: the
pre-launch gate (ASPM policy `[performance]` + `can_device_access_peer` for
all 12 ordered pairs) passed, a post-launch check confirmed the peer path is
live (x8 legs ~13–14 GB/s, x16 legs ~26 GB/s), and the write-loss probe
(`repro/p2p_write_loss_repro.py`) was clean: 0/20 launches dirty.

However, the earlier claim that "the TP4 cross-rank exchange runs on the
direct peer path" was **wrong**. `can_device_access_peer=1` only proves the
peer path is *available*, not that NCCL *selects* it. An NCCL transport check
(`repro/nccl_transport_check.py`, 4-rank allreduce with `NCCL_DEBUG=INFO`)
showed every channel `via SHM/direct` with `isAllDirectP2p 0`: stock NCCL's
default P2P level is PXB, and every GPU pair on this board is PHB (all four
cards hang off the CPU root complex), so NCCL rejected every pair and staged
the TP4 allreduce through host shared memory. **The numbers in this report
therefore reflect a host-bounced allreduce, not the direct peer path.**

The fix is `NCCL_P2P_LEVEL=PHB` (now set by the launcher and verified by the
gate's transport check), which makes every channel `via P2P/CUMEM` with
`isAllDirectP2p 1`. The corrected run is in `results/ram-131072-nccl-p2p/`.
