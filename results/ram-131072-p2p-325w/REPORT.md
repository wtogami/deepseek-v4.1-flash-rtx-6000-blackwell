# ram-131072-p2p-325w — results vs Karmic Kraken

Protocol: llm_decode_bench.py v0.6.2 (sha256-pinned, see bench/PROVENANCE.md), 5 warmed 30 s windows per cell, 15 s warmup, 32K unique prefill (client TTFT), context-zero decode C1/C8, server-side /metrics accounting.

**NCCL transport note (corrected).** Like the `ram-131072-p2p` run, this run
predates the `NCCL_P2P_LEVEL=PHB` fix. The platform peer path was healthy
(ASPM `[performance]`, `can_device_access_peer` 1 for all pairs, 0/20
write-loss), but NCCL's default P2P level (PXB) rejected every PHB pair on
this board, so the TP4 allreduce was staged through host shared memory
(`via SHM/direct`). These numbers therefore reflect a host-bounced allreduce,
not the direct peer path. The corrected run (every channel `via P2P/CUMEM`)
is in `results/ram-131072-nccl-p2p/`.

## Headline

| Cell | Ours (median of 5) | KK (Max-Q/325W) | Delta |
|---|---:|---:|---:|
| 32K prefill tok/s | 10,374 | 17,982 | -42.31% |
| C1 output tok/s | 122.7 | 249.1 | -50.75% |
| C1 verifier steps/s | 67.92 | 98.58 | -31.10% |
| C1 accepted length | 1.806 | 2.571 | -29.77% |
| C8 output tok/s | 430.3 | 805.5 | -46.58% |
| C8 verifier steps/s | 188.13 | 361.87 | -48.01% |
| C8 accepted length | 2.290 | 2.295 | -0.25% |
| KV capacity tokens | 4,654,930 | 4,727,748 | -1.54% |

## Per-window samples

| file | prefill tok/s | samples |
|---|---:|---:|
| prefill-2.json | 10,405 | 9 |
| prefill-3.json | 10,374 | 9 |
| prefill-4.json | 10,343 | 9 |
| prefill-5.json | 10,325 | 9 |
| prefill.json | 10,430 | 9 |

| file | C1 output tok/s | verifier steps/s | accepted length | source |
|---|---:|---:|---:|---|
| decode-1.json | 122.7 | 67.92 | 1.806 | openai_continuous_usage |
| decode-2.json | 125.2 | 66.52 | 1.883 | openai_continuous_usage |
| decode-3.json | 118.9 | 69.24 | 1.718 | openai_continuous_usage |
| decode-4.json | 120.4 | 69.65 | 1.729 | openai_continuous_usage |
| decode-5.json | 122.9 | 67.09 | 1.832 | openai_continuous_usage |

| file | C8 output tok/s | verifier steps/s | accepted length | source |
|---|---:|---:|---:|---|
| decode-1.json | 428.5 | 187.17 | 2.290 | openai_continuous_usage |
| decode-2.json | 439.2 | 188.03 | 2.336 | openai_continuous_usage |
| decode-3.json | 430.3 | 188.13 | 2.287 | openai_continuous_usage |
| decode-4.json | 434.3 | 188.22 | 2.308 | openai_continuous_usage |
| decode-5.json | 420.3 | 188.47 | 2.230 | openai_continuous_usage |

## PCIe and system (monitor.tsv)

Ceilings per direction: Gen4 x8 ~15,750 MB/s (GPUs 0,3), Gen4 x16 ~31,500 MB/s (GPUs 1,2).

| scope | GPU | width | tx max | tx p95 | tx mean | rx max | rx p95 | rx mean | util max | pwr max | clk max | mem max |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| overall | 0 | x8 | 11,008 MB/s (70%) | 9,342 MB/s | 3,321 MB/s | 12,140 MB/s (77%) | 10,384 MB/s | 3,477 MB/s | 100 % | 328 W | 2,895 MHz | 93,643 MiB |
| overall | 1 | x16 | 11,385 MB/s (36%) | 9,656 MB/s | 3,294 MB/s | 11,424 MB/s (36%) | 9,246 MB/s | 3,357 MB/s | 100 % | 256 W | 2,340 MHz | 93,643 MiB |
| overall | 2 | x16 | 11,496 MB/s (36%) | 9,349 MB/s | 3,331 MB/s | 11,904 MB/s (38%) | 9,865 MB/s | 3,355 MB/s | 100 % | 281 W | 2,340 MHz | 93,643 MiB |
| overall | 3 | x8 | 11,696 MB/s (74%) | 9,566 MB/s | 3,341 MB/s | 10,981 MB/s (70%) | 9,578 MB/s | 3,385 MB/s | 100 % | 327 W | 2,880 MHz | 93,643 MiB |
| decode_active | 0 | x8 | 11,008 MB/s (70%) | 9,418 MB/s | 3,693 MB/s | 12,140 MB/s (77%) | 10,439 MB/s | 3,847 MB/s | 100 % | 328 W | 2,895 MHz | 93,643 MiB |
| decode_active | 1 | x16 | 11,385 MB/s (36%) | 9,781 MB/s | 3,673 MB/s | 11,424 MB/s (36%) | 9,344 MB/s | 3,742 MB/s | 100 % | 256 W | 2,332 MHz | 93,643 MiB |
| decode_active | 2 | x16 | 11,496 MB/s (36%) | 9,448 MB/s | 3,714 MB/s | 11,904 MB/s (38%) | 9,993 MB/s | 3,742 MB/s | 100 % | 281 W | 2,340 MHz | 93,643 MiB |
| decode_active | 3 | x8 | 11,696 MB/s (74%) | 9,615 MB/s | 3,726 MB/s | 10,981 MB/s (70%) | 9,601 MB/s | 3,775 MB/s | 100 % | 327 W | 2,880 MHz | 93,643 MiB |
| decode-1 | 0 | x8 | 5,703 MB/s (36%) | 5,559 MB/s | 2,174 MB/s | 5,883 MB/s (37%) | 5,526 MB/s | 2,109 MB/s | 100 % | 328 W | 2,880 MHz | 93,643 MiB |
| decode-1 | 1 | x16 | 5,577 MB/s (18%) | 5,419 MB/s | 2,125 MB/s | 5,669 MB/s (18%) | 5,567 MB/s | 2,112 MB/s | 100 % | 255 W | 2,340 MHz | 93,643 MiB |
| decode-1 | 2 | x16 | 5,986 MB/s (19%) | 5,599 MB/s | 2,200 MB/s | 5,439 MB/s (17%) | 5,377 MB/s | 2,031 MB/s | 100 % | 277 W | 2,340 MHz | 93,643 MiB |
| decode-1 | 3 | x8 | 5,823 MB/s (37%) | 5,591 MB/s | 2,205 MB/s | 5,635 MB/s (36%) | 5,560 MB/s | 2,116 MB/s | 100 % | 327 W | 2,880 MHz | 93,643 MiB |
| decode-2 | 0 | x8 | 5,657 MB/s (36%) | 5,603 MB/s | 2,108 MB/s | 5,881 MB/s (37%) | 5,568 MB/s | 2,138 MB/s | 100 % | 328 W | 2,880 MHz | 93,643 MiB |
| decode-2 | 1 | x16 | 5,523 MB/s (18%) | 5,410 MB/s | 2,039 MB/s | 5,931 MB/s (19%) | 5,609 MB/s | 2,163 MB/s | 100 % | 255 W | 2,340 MHz | 93,643 MiB |
| decode-2 | 2 | x16 | 5,823 MB/s (18%) | 5,590 MB/s | 2,104 MB/s | 5,612 MB/s (18%) | 5,393 MB/s | 2,078 MB/s | 100 % | 279 W | 2,340 MHz | 93,643 MiB |
| decode-2 | 3 | x8 | 5,605 MB/s (36%) | 5,538 MB/s | 2,096 MB/s | 5,739 MB/s (36%) | 5,588 MB/s | 2,157 MB/s | 100 % | 327 W | 2,880 MHz | 93,643 MiB |
| decode-3 | 0 | x8 | 5,805 MB/s (37%) | 5,646 MB/s | 2,130 MB/s | 5,758 MB/s (37%) | 5,622 MB/s | 2,189 MB/s | 100 % | 327 W | 2,880 MHz | 93,643 MiB |
| decode-3 | 1 | x16 | 5,546 MB/s (18%) | 5,460 MB/s | 2,070 MB/s | 5,669 MB/s (18%) | 5,598 MB/s | 2,179 MB/s | 100 % | 256 W | 2,340 MHz | 93,643 MiB |
| decode-3 | 2 | x16 | 5,937 MB/s (19%) | 5,593 MB/s | 2,161 MB/s | 5,506 MB/s (17%) | 5,420 MB/s | 2,086 MB/s | 100 % | 281 W | 2,340 MHz | 93,643 MiB |
| decode-3 | 3 | x8 | 5,917 MB/s (38%) | 5,571 MB/s | 2,162 MB/s | 5,743 MB/s (36%) | 5,601 MB/s | 2,179 MB/s | 100 % | 327 W | 2,880 MHz | 93,643 MiB |
| decode-4 | 0 | x8 | 5,626 MB/s (36%) | 5,538 MB/s | 2,079 MB/s | 5,848 MB/s (37%) | 5,587 MB/s | 2,219 MB/s | 100 % | 328 W | 2,880 MHz | 93,643 MiB |
| decode-4 | 1 | x16 | 5,580 MB/s (18%) | 5,400 MB/s | 2,021 MB/s | 5,954 MB/s (19%) | 5,603 MB/s | 2,242 MB/s | 100 % | 255 W | 2,340 MHz | 93,643 MiB |
| decode-4 | 2 | x16 | 5,806 MB/s (18%) | 5,538 MB/s | 2,079 MB/s | 5,556 MB/s (18%) | 5,423 MB/s | 2,148 MB/s | 100 % | 279 W | 2,340 MHz | 93,643 MiB |
| decode-4 | 3 | x8 | 5,688 MB/s (36%) | 5,548 MB/s | 2,075 MB/s | 5,719 MB/s (36%) | 5,606 MB/s | 2,223 MB/s | 100 % | 327 W | 2,880 MHz | 93,643 MiB |
| decode-5 | 0 | x8 | 5,730 MB/s (36%) | 5,633 MB/s | 2,260 MB/s | 5,609 MB/s (36%) | 5,505 MB/s | 1,977 MB/s | 100 % | 327 W | 2,880 MHz | 93,643 MiB |
| decode-5 | 1 | x16 | 5,490 MB/s (17%) | 5,461 MB/s | 2,192 MB/s | 5,678 MB/s (18%) | 5,565 MB/s | 2,040 MB/s | 100 % | 254 W | 2,340 MHz | 93,643 MiB |
| decode-5 | 2 | x16 | 5,724 MB/s (18%) | 5,665 MB/s | 2,260 MB/s | 5,510 MB/s (17%) | 5,332 MB/s | 1,968 MB/s | 100 % | 278 W | 2,340 MHz | 93,643 MiB |
| decode-5 | 3 | x8 | 5,690 MB/s (36%) | 5,540 MB/s | 2,179 MB/s | 5,942 MB/s (38%) | 5,550 MB/s | 2,074 MB/s | 100 % | 327 W | 2,880 MHz | 93,643 MiB |
| prefill | 0 | x8 | 11,008 MB/s (70%) | 10,460 MB/s | 6,756 MB/s | 11,430 MB/s (73%) | 11,408 MB/s | 7,226 MB/s | 100 % | 307 W | 2,895 MHz | 93,643 MiB |
| prefill | 1 | x16 | 10,360 MB/s (33%) | 10,293 MB/s | 6,673 MB/s | 10,085 MB/s (32%) | 9,963 MB/s | 6,705 MB/s | 100 % | 205 W | 2,332 MHz | 93,643 MiB |
| prefill | 2 | x16 | 9,705 MB/s (31%) | 9,560 MB/s | 6,392 MB/s | 11,041 MB/s (35%) | 10,454 MB/s | 7,264 MB/s | 100 % | 210 W | 2,332 MHz | 93,643 MiB |
| prefill | 3 | x8 | 11,189 MB/s (71%) | 9,920 MB/s | 6,600 MB/s | 10,443 MB/s (66%) | 10,007 MB/s | 6,387 MB/s | 100 % | 289 W | 2,880 MHz | 93,643 MiB |
| prefill-2 | 0 | x8 | 10,466 MB/s (66%) | 9,165 MB/s | 5,800 MB/s | 12,092 MB/s (77%) | 10,851 MB/s | 7,050 MB/s | 100 % | 310 W | 2,887 MHz | 93,643 MiB |
| prefill-2 | 1 | x16 | 11,385 MB/s (36%) | 10,668 MB/s | 6,853 MB/s | 9,789 MB/s (31%) | 9,655 MB/s | 6,229 MB/s | 100 % | 211 W | 2,332 MHz | 93,643 MiB |
| prefill-2 | 2 | x16 | 10,173 MB/s (32%) | 9,838 MB/s | 6,526 MB/s | 10,720 MB/s (34%) | 10,180 MB/s | 6,854 MB/s | 100 % | 218 W | 2,340 MHz | 93,643 MiB |
| prefill-2 | 3 | x8 | 11,696 MB/s (74%) | 9,707 MB/s | 6,483 MB/s | 10,118 MB/s (64%) | 10,080 MB/s | 6,783 MB/s | 100 % | 293 W | 2,880 MHz | 93,643 MiB |
| prefill-3 | 0 | x8 | 10,857 MB/s (69%) | 10,363 MB/s | 6,362 MB/s | 11,429 MB/s (73%) | 11,063 MB/s | 6,990 MB/s | 100 % | 314 W | 2,887 MHz | 93,643 MiB |
| prefill-3 | 1 | x16 | 10,668 MB/s (34%) | 10,276 MB/s | 6,712 MB/s | 9,959 MB/s (32%) | 9,873 MB/s | 6,497 MB/s | 100 % | 214 W | 2,332 MHz | 93,643 MiB |
| prefill-3 | 2 | x16 | 11,496 MB/s (36%) | 9,901 MB/s | 6,251 MB/s | 10,426 MB/s (33%) | 10,082 MB/s | 6,416 MB/s | 100 % | 226 W | 2,340 MHz | 93,643 MiB |
| prefill-3 | 3 | x8 | 9,874 MB/s (63%) | 9,699 MB/s | 6,154 MB/s | 10,230 MB/s (65%) | 10,129 MB/s | 6,525 MB/s | 100 % | 296 W | 2,872 MHz | 93,643 MiB |
| prefill-4 | 0 | x8 | 9,965 MB/s (63%) | 9,574 MB/s | 6,535 MB/s | 12,140 MB/s (77%) | 10,699 MB/s | 6,631 MB/s | 100 % | 316 W | 2,872 MHz | 93,643 MiB |
| prefill-4 | 1 | x16 | 10,353 MB/s (33%) | 10,234 MB/s | 5,737 MB/s | 11,424 MB/s (36%) | 10,642 MB/s | 6,836 MB/s | 100 % | 216 W | 2,332 MHz | 93,643 MiB |
| prefill-4 | 2 | x16 | 10,974 MB/s (35%) | 10,309 MB/s | 5,978 MB/s | 11,904 MB/s (38%) | 10,398 MB/s | 6,549 MB/s | 100 % | 230 W | 2,340 MHz | 93,643 MiB |
| prefill-4 | 3 | x8 | 10,678 MB/s (68%) | 10,351 MB/s | 6,788 MB/s | 10,135 MB/s (64%) | 10,050 MB/s | 6,744 MB/s | 100 % | 299 W | 2,872 MHz | 93,643 MiB |
| prefill-5 | 0 | x8 | 9,986 MB/s (63%) | 9,857 MB/s | 6,100 MB/s | 11,163 MB/s (71%) | 10,442 MB/s | 6,725 MB/s | 100 % | 317 W | 2,880 MHz | 93,643 MiB |
| prefill-5 | 1 | x16 | 10,583 MB/s (34%) | 10,289 MB/s | 5,877 MB/s | 9,647 MB/s (31%) | 9,445 MB/s | 5,978 MB/s | 100 % | 219 W | 2,332 MHz | 93,643 MiB |
| prefill-5 | 2 | x16 | 10,917 MB/s (35%) | 10,450 MB/s | 6,423 MB/s | 10,459 MB/s (33%) | 10,195 MB/s | 6,209 MB/s | 100 % | 232 W | 2,340 MHz | 93,643 MiB |
| prefill-5 | 3 | x8 | 9,771 MB/s (62%) | 9,719 MB/s | 5,979 MB/s | 10,981 MB/s (70%) | 10,642 MB/s | 6,241 MB/s | 100 % | 299 W | 2,880 MHz | 93,643 MiB |

load1 max: 4.7   MemAvailable min: 805,640,188 kB

## 325 W vs 300 W (WS cards)

The WS cards (GPUs 0, 3) were raised from 300 W to 325 W. The power draw
confirms the limit took effect (GPU 0: 328 W, GPU 3: 327 W, vs 309/305 W at
300 W). But the performance improvement is within noise:

| Cell | 300 W | 325 W | Δ |
|---|---:|---:|---:|
| 32K prefill tok/s | 10,323 | 10,374 | +0.5% |
| C1 output tok/s | 122.1 | 122.7 | +0.5% |
| C1 verifier steps/s | 67.47 | 67.92 | +0.7% |
| C1 accepted length | 1.811 | 1.806 | −0.3% |
| C8 output tok/s | 434.2 | 430.3 | −0.9% |
| C8 verifier steps/s | 188.23 | 188.13 | −0.05% |
| C8 accepted length | 2.307 | 2.290 | −0.7% |

The prefill and C1 metrics show a slight improvement (+0.5–0.7%), but the C8
metrics show a slight decrease (−0.9%). Overall, the power limit increase did
not significantly improve the performance. The bottleneck is compute (GPU
SKU/link), not power: the WS cards are on Gen4 x8 links, which is the limiting
factor. Increasing the power limit allows the GPUs to boost slightly higher,
but the x8 link and the Workstation Ed. compute are still the bottleneck.
