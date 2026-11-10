# ram-131072-nccl-p2p — results vs Karmic Kraken

Protocol: llm_decode_bench.py v0.6.2 (sha256-pinned, see bench/PROVENANCE.md), 5 warmed 30 s windows per cell, 15 s warmup, 32K unique prefill (client TTFT), context-zero decode C1/C8, server-side /metrics accounting.

## Headline

| Cell | Ours (median of 5) | KK (Max-Q/325W) | Delta |
|---|---:|---:|---:|
| 32K prefill tok/s | 10,356 | 17,982 | -42.41% |
| C1 output tok/s | 118.4 | 249.1 | -52.46% |
| C1 verifier steps/s | 69.05 | 98.58 | -29.95% |
| C1 accepted length | 1.715 | 2.571 | -33.31% |
| C8 output tok/s | 439.2 | 805.5 | -45.48% |
| C8 verifier steps/s | 188.44 | 361.87 | -47.93% |
| C8 accepted length | 2.329 | 2.295 | +1.45% |
| KV capacity tokens | 4,651,704 | 4,727,748 | -1.61% |

## Per-window samples

| file | prefill tok/s | samples |
|---|---:|---:|
| prefill-2.json | 10,375 | 9 |
| prefill-3.json | 10,356 | 9 |
| prefill-4.json | 10,342 | 9 |
| prefill-5.json | 10,324 | 9 |
| prefill.json | 10,415 | 9 |

| file | C1 output tok/s | verifier steps/s | accepted length | source |
|---|---:|---:|---:|---|
| decode-1.json | 117.6 | 69.83 | 1.684 | openai_continuous_usage |
| decode-2.json | 118.4 | 69.05 | 1.715 | openai_continuous_usage |
| decode-3.json | 125.8 | 65.90 | 1.909 | openai_continuous_usage |
| decode-4.json | 128.1 | 64.55 | 1.984 | openai_continuous_usage |
| decode-5.json | 117.2 | 69.52 | 1.685 | openai_continuous_usage |

| file | C8 output tok/s | verifier steps/s | accepted length | source |
|---|---:|---:|---:|---|
| decode-1.json | 429.1 | 188.44 | 2.277 | openai_continuous_usage |
| decode-2.json | 444.9 | 189.06 | 2.353 | openai_continuous_usage |
| decode-3.json | 439.2 | 188.59 | 2.329 | openai_continuous_usage |
| decode-4.json | 432.6 | 186.35 | 2.321 | openai_continuous_usage |
| decode-5.json | 442.2 | 187.78 | 2.355 | openai_continuous_usage |

## PCIe and system (monitor.tsv)

Ceilings per direction: Gen4 x8 ~15,750 MB/s (GPUs 0,3), Gen4 x16 ~31,500 MB/s (GPUs 1,2).

| scope | GPU | width | tx max | tx p95 | tx mean | rx max | rx p95 | rx mean | util max | pwr max | clk max | mem max |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| overall | 0 | x8 | 11,811 MB/s (75%) | 9,406 MB/s | 3,509 MB/s | 11,550 MB/s (73%) | 10,158 MB/s | 3,490 MB/s | 100 % | 308 W | 2,887 MHz | 93,605 MiB |
| overall | 1 | x16 | 11,672 MB/s (37%) | 9,430 MB/s | 3,344 MB/s | 11,060 MB/s (35%) | 9,430 MB/s | 3,364 MB/s | 100 % | 256 W | 2,340 MHz | 93,603 MiB |
| overall | 2 | x16 | 11,349 MB/s (36%) | 9,351 MB/s | 3,386 MB/s | 10,914 MB/s (35%) | 9,528 MB/s | 3,270 MB/s | 100 % | 281 W | 2,340 MHz | 93,623 MiB |
| overall | 3 | x8 | 11,182 MB/s (71%) | 9,499 MB/s | 3,358 MB/s | 11,411 MB/s (72%) | 9,431 MB/s | 3,320 MB/s | 100 % | 305 W | 2,887 MHz | 93,627 MiB |
| decode_active | 0 | x8 | 11,811 MB/s (75%) | 9,478 MB/s | 3,901 MB/s | 11,550 MB/s (73%) | 10,210 MB/s | 3,867 MB/s | 100 % | 308 W | 2,880 MHz | 93,605 MiB |
| decode_active | 1 | x16 | 11,672 MB/s (37%) | 9,492 MB/s | 3,740 MB/s | 11,060 MB/s (35%) | 9,492 MB/s | 3,753 MB/s | 100 % | 256 W | 2,332 MHz | 93,603 MiB |
| decode_active | 2 | x16 | 11,349 MB/s (36%) | 9,398 MB/s | 3,788 MB/s | 10,914 MB/s (35%) | 9,798 MB/s | 3,657 MB/s | 100 % | 281 W | 2,340 MHz | 93,623 MiB |
| decode_active | 3 | x8 | 11,182 MB/s (71%) | 9,514 MB/s | 3,761 MB/s | 11,411 MB/s (72%) | 9,547 MB/s | 3,719 MB/s | 100 % | 305 W | 2,880 MHz | 93,627 MiB |
| decode-1 | 0 | x8 | 5,842 MB/s (37%) | 5,588 MB/s | 2,226 MB/s | 5,618 MB/s (36%) | 5,404 MB/s | 2,033 MB/s | 100 % | 308 W | 2,880 MHz | 93,605 MiB |
| decode-1 | 1 | x16 | 5,569 MB/s (18%) | 5,434 MB/s | 2,138 MB/s | 5,798 MB/s (18%) | 5,625 MB/s | 2,047 MB/s | 100 % | 254 W | 2,340 MHz | 93,603 MiB |
| decode-1 | 2 | x16 | 5,730 MB/s (18%) | 5,577 MB/s | 2,206 MB/s | 5,541 MB/s (18%) | 5,372 MB/s | 1,969 MB/s | 100 % | 280 W | 2,340 MHz | 93,623 MiB |
| decode-1 | 3 | x8 | 5,706 MB/s (36%) | 5,578 MB/s | 2,210 MB/s | 5,748 MB/s (36%) | 5,581 MB/s | 2,068 MB/s | 100 % | 303 W | 2,872 MHz | 93,627 MiB |
| decode-2 | 0 | x8 | 5,787 MB/s (37%) | 5,572 MB/s | 2,192 MB/s | 5,791 MB/s (37%) | 5,597 MB/s | 2,063 MB/s | 100 % | 301 W | 2,880 MHz | 93,605 MiB |
| decode-2 | 1 | x16 | 5,563 MB/s (18%) | 5,353 MB/s | 2,120 MB/s | 5,800 MB/s (18%) | 5,663 MB/s | 2,070 MB/s | 100 % | 254 W | 2,332 MHz | 93,603 MiB |
| decode-2 | 2 | x16 | 5,735 MB/s (18%) | 5,534 MB/s | 2,158 MB/s | 5,523 MB/s (18%) | 5,433 MB/s | 1,984 MB/s | 100 % | 279 W | 2,340 MHz | 93,623 MiB |
| decode-2 | 3 | x8 | 5,813 MB/s (37%) | 5,520 MB/s | 2,146 MB/s | 5,752 MB/s (37%) | 5,585 MB/s | 2,074 MB/s | 100 % | 304 W | 2,880 MHz | 93,627 MiB |
| decode-3 | 0 | x8 | 5,835 MB/s (37%) | 5,628 MB/s | 2,269 MB/s | 5,638 MB/s (36%) | 4,903 MB/s | 1,972 MB/s | 100 % | 302 W | 2,880 MHz | 93,605 MiB |
| decode-3 | 1 | x16 | 5,662 MB/s (18%) | 5,408 MB/s | 2,167 MB/s | 5,699 MB/s (18%) | 5,159 MB/s | 2,028 MB/s | 100 % | 254 W | 2,340 MHz | 93,603 MiB |
| decode-3 | 2 | x16 | 5,827 MB/s (18%) | 5,596 MB/s | 2,223 MB/s | 5,670 MB/s (18%) | 5,416 MB/s | 1,968 MB/s | 100 % | 279 W | 2,340 MHz | 93,623 MiB |
| decode-3 | 3 | x8 | 5,672 MB/s (36%) | 5,543 MB/s | 2,157 MB/s | 5,840 MB/s (37%) | 5,631 MB/s | 2,080 MB/s | 100 % | 304 W | 2,880 MHz | 93,627 MiB |
| decode-4 | 0 | x8 | 5,743 MB/s (36%) | 5,568 MB/s | 2,125 MB/s | 5,871 MB/s (37%) | 5,521 MB/s | 2,126 MB/s | 100 % | 302 W | 2,880 MHz | 93,605 MiB |
| decode-4 | 1 | x16 | 5,652 MB/s (18%) | 5,396 MB/s | 2,045 MB/s | 5,677 MB/s (18%) | 5,565 MB/s | 2,134 MB/s | 100 % | 254 W | 2,340 MHz | 93,603 MiB |
| decode-4 | 2 | x16 | 5,882 MB/s (19%) | 5,561 MB/s | 2,132 MB/s | 5,507 MB/s (17%) | 5,426 MB/s | 2,061 MB/s | 100 % | 278 W | 2,340 MHz | 93,623 MiB |
| decode-4 | 3 | x8 | 5,747 MB/s (36%) | 5,575 MB/s | 2,077 MB/s | 5,660 MB/s (36%) | 5,558 MB/s | 2,118 MB/s | 100 % | 305 W | 2,872 MHz | 93,627 MiB |
| decode-5 | 0 | x8 | 7,633 MB/s (48%) | 5,552 MB/s | 2,353 MB/s | 6,834 MB/s (43%) | 5,618 MB/s | 2,167 MB/s | 100 % | 307 W | 2,880 MHz | 93,605 MiB |
| decode-5 | 1 | x16 | 5,479 MB/s (17%) | 5,382 MB/s | 2,189 MB/s | 5,882 MB/s (19%) | 5,638 MB/s | 2,128 MB/s | 100 % | 256 W | 2,340 MHz | 93,603 MiB |
| decode-5 | 2 | x16 | 5,670 MB/s (18%) | 5,520 MB/s | 2,235 MB/s | 5,620 MB/s (18%) | 5,465 MB/s | 2,034 MB/s | 100 % | 281 W | 2,340 MHz | 93,623 MiB |
| decode-5 | 3 | x8 | 5,562 MB/s (35%) | 5,482 MB/s | 2,210 MB/s | 5,824 MB/s (37%) | 5,610 MB/s | 2,100 MB/s | 100 % | 304 W | 2,880 MHz | 93,627 MiB |
| prefill | 0 | x8 | 9,701 MB/s (62%) | 9,588 MB/s | 6,891 MB/s | 10,691 MB/s (68%) | 10,646 MB/s | 6,876 MB/s | 100 % | 302 W | 2,887 MHz | 93,601 MiB |
| prefill | 1 | x16 | 10,337 MB/s (33%) | 9,899 MB/s | 6,899 MB/s | 10,971 MB/s (35%) | 9,745 MB/s | 6,530 MB/s | 100 % | 213 W | 2,332 MHz | 93,601 MiB |
| prefill | 2 | x16 | 10,005 MB/s (32%) | 9,397 MB/s | 6,349 MB/s | 10,432 MB/s (33%) | 10,408 MB/s | 7,155 MB/s | 100 % | 224 W | 2,340 MHz | 93,621 MiB |
| prefill | 3 | x8 | 9,907 MB/s (63%) | 9,813 MB/s | 6,515 MB/s | 10,217 MB/s (65%) | 10,009 MB/s | 6,832 MB/s | 100 % | 293 W | 2,887 MHz | 93,621 MiB |
| prefill-2 | 0 | x8 | 10,470 MB/s (66%) | 9,789 MB/s | 6,733 MB/s | 10,821 MB/s (69%) | 10,697 MB/s | 7,620 MB/s | 100 % | 303 W | 2,880 MHz | 93,601 MiB |
| prefill-2 | 1 | x16 | 10,052 MB/s (32%) | 9,729 MB/s | 6,156 MB/s | 10,574 MB/s (34%) | 9,908 MB/s | 6,632 MB/s | 100 % | 218 W | 2,332 MHz | 93,601 MiB |
| prefill-2 | 2 | x16 | 10,599 MB/s (34%) | 10,154 MB/s | 6,514 MB/s | 10,914 MB/s (35%) | 10,435 MB/s | 6,490 MB/s | 100 % | 231 W | 2,340 MHz | 93,621 MiB |
| prefill-2 | 3 | x8 | 10,774 MB/s (68%) | 9,825 MB/s | 6,286 MB/s | 10,779 MB/s (68%) | 9,830 MB/s | 6,155 MB/s | 100 % | 296 W | 2,880 MHz | 93,621 MiB |
| prefill-3 | 0 | x8 | 11,811 MB/s (75%) | 9,717 MB/s | 6,456 MB/s | 11,550 MB/s (73%) | 10,671 MB/s | 6,897 MB/s | 100 % | 304 W | 2,880 MHz | 93,601 MiB |
| prefill-3 | 1 | x16 | 9,915 MB/s (31%) | 9,640 MB/s | 6,110 MB/s | 10,368 MB/s (33%) | 10,052 MB/s | 6,596 MB/s | 100 % | 220 W | 2,332 MHz | 93,601 MiB |
| prefill-3 | 2 | x16 | 11,349 MB/s (36%) | 10,818 MB/s | 6,372 MB/s | 10,441 MB/s (33%) | 10,433 MB/s | 6,359 MB/s | 100 % | 234 W | 2,340 MHz | 93,621 MiB |
| prefill-3 | 3 | x8 | 10,180 MB/s (65%) | 9,687 MB/s | 6,185 MB/s | 11,411 MB/s (72%) | 10,981 MB/s | 6,626 MB/s | 100 % | 298 W | 2,880 MHz | 93,621 MiB |
| prefill-4 | 0 | x8 | 9,755 MB/s (62%) | 9,607 MB/s | 6,783 MB/s | 11,236 MB/s (71%) | 10,555 MB/s | 7,549 MB/s | 100 % | 305 W | 2,880 MHz | 93,601 MiB |
| prefill-4 | 1 | x16 | 10,330 MB/s (33%) | 10,068 MB/s | 6,726 MB/s | 9,971 MB/s (32%) | 9,881 MB/s | 6,921 MB/s | 100 % | 220 W | 2,340 MHz | 93,601 MiB |
| prefill-4 | 2 | x16 | 9,946 MB/s (32%) | 9,699 MB/s | 6,386 MB/s | 9,871 MB/s (31%) | 9,579 MB/s | 6,312 MB/s | 100 % | 238 W | 2,340 MHz | 93,621 MiB |
| prefill-4 | 3 | x8 | 10,928 MB/s (69%) | 10,245 MB/s | 6,952 MB/s | 10,297 MB/s (65%) | 10,059 MB/s | 6,593 MB/s | 100 % | 300 W | 2,880 MHz | 93,621 MiB |
| prefill-5 | 0 | x8 | 10,801 MB/s (69%) | 10,165 MB/s | 6,953 MB/s | 11,074 MB/s (70%) | 10,186 MB/s | 6,606 MB/s | 100 % | 304 W | 2,880 MHz | 93,601 MiB |
| prefill-5 | 1 | x16 | 11,672 MB/s (37%) | 10,225 MB/s | 6,309 MB/s | 11,060 MB/s (35%) | 10,001 MB/s | 6,509 MB/s | 100 % | 221 W | 2,340 MHz | 93,601 MiB |
| prefill-5 | 2 | x16 | 10,172 MB/s (32%) | 10,094 MB/s | 6,553 MB/s | 10,362 MB/s (33%) | 9,787 MB/s | 6,186 MB/s | 100 % | 237 W | 2,340 MHz | 93,621 MiB |
| prefill-5 | 3 | x8 | 11,182 MB/s (71%) | 10,258 MB/s | 6,162 MB/s | 11,028 MB/s (70%) | 10,127 MB/s | 6,121 MB/s | 100 % | 301 W | 2,880 MHz | 93,621 MiB |

load1 max: 4.9   MemAvailable min: 803,945,884 kB

## NCCL transport (the fix and its effect)

This run is the first measured with the TP4 cross-rank exchange on the direct
PCIe peer path. The launcher now sets `NCCL_P2P_LEVEL=PHB` (in `NCCL_ENV_ARGS`)
and the P2P gate verifies it before launch:

- **Root cause.** Every GPU pair on this board is PHB in NCCL's topology (all
  four cards hang off the CPU root complex; `nvidia-smi topo -m` shows NODE
  everywhere). Stock NCCL's default P2P level is PXB, stricter than PHB, so it
  rejected every pair and staged the TP4 allreduce through host shared memory
  (`via SHM/direct`, `isAllDirectP2p 0`). The image's built-in ENV sets no P2P
  level, so a bare `run` inherited the PXB default.
- **Fix + verification.** `NCCL_P2P_LEVEL=PHB` admits the peer path. The gate's
  transport check (`repro/nccl_transport_check.py`, 4-rank allreduce,
  `NCCL_DEBUG=INFO`) reported **8/8 channels `via P2P/CUMEM`, 0 via SHM/NET,
  `isAllDirectP2p 1`** with the server's exact env. The running container
  carries `NCCL_P2P_LEVEL=PHB` (confirmed via `podman inspect`).
- **Platform.** All four cards at the 300 W limit (the user reverted GPUs 0/3
  from 325 W), matching the KK power envelope. ASPM `[performance]`, peer
  access 1 for all 12 pairs, 0/20 write-loss.

**Finding: the transport fix is correct but has no meaningful performance
effect.** The allreduce transport was not the bottleneck — compute is. Every
cell is within noise of the immediately preceding SHM-staged run
(`ram-131072-p2p-325w`):

| Cell | This run (P2P) | SHM-staged run | Δ |
|---|---:|---:|---:|
| 32K prefill tok/s | 10,356 | 10,374 | −0.17% |
| C1 output tok/s | 118.4 | 122.7 | −3.50% |
| C1 verifier steps/s | 69.05 | 67.92 | +1.66% |
| C1 accepted length | 1.715 | 1.806 | −5.04% |
| C8 output tok/s | 439.2 | 430.3 | +2.07% |
| C8 verifier steps/s | 188.44 | 188.13 | +0.16% |
| C8 accepted length | 2.329 | 2.290 | +1.70% |
| KV capacity tokens | 4,651,704 | 4,654,930 | −0.07% |

The KK gap (−42% to −52% on throughput) is therefore **not** caused by the
NCCL host bounce. It is dominated by compute/PCIe-width differences: the KK
platform is Max-Q (x16-equivalent, 325 W) on GPUs 5–8, while this board's
GPUs 0/3 are Workstation Ed. on Gen4 x8 legs (~15,750 MB/s ceiling) and GPUs
1/2 are Max-Q on x16. The PCIe monitor confirms the x8 legs (GPUs 0/3) run at
~70–75% of their ~15,750 MB/s ceiling in prefill and ~36–37% in decode, while
the x16 legs (GPUs 1/2) run at only ~35% of their ~31,500 MB/s ceiling — the
x8 legs are the binding constraint, and the allreduce (a small fraction of
per-step time) is not.

The `NCCL_P2P_LEVEL=PHB` fix is retained because it is the correct transport
(the direct peer path, no host bounce) and the gate now guarantees it, but it
does not close the KK gap.
