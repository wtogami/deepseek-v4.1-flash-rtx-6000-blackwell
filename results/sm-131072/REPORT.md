# sm-131072 — results vs Karmic Kraken

Protocol: llm_decode_bench.py v0.6.2 (sha256-pinned, see bench/PROVENANCE.md), 5 warmed 30 s windows per cell, 15 s warmup, 32K unique prefill (client TTFT), context-zero decode C1/C8, server-side /metrics accounting.

## Headline

| Cell | Ours (median of 5) | KK (Max-Q/325W) | Delta |
|---|---:|---:|---:|
| 32K prefill tok/s | 10,650 | 17,982 | -40.77% |
| C1 output tok/s | 215.6 | 249.1 | -13.42% |
| C1 verifier steps/s | 91.37 | 98.58 | -7.31% |
| C1 accepted length | 2.368 | 2.571 | -7.89% |
| C8 output tok/s | 700.7 | 805.5 | -13.01% |
| C8 verifier steps/s | 311.77 | 361.87 | -13.85% |
| C8 accepted length | 2.256 | 2.295 | -1.69% |
| KV capacity tokens | 4,741,178 | 4,727,748 | +0.28% |

## Per-window samples

| file | prefill tok/s | samples |
|---|---:|---:|
| prefill-2.json | 10,652 | 9 |
| prefill-3.json | 10,645 | 9 |
| prefill-4.json | 10,627 | 9 |
| prefill-5.json | 10,650 | 9 |
| prefill.json | 10,651 | 9 |

| file | C1 output tok/s | verifier steps/s | accepted length | source |
|---|---:|---:|---:|---|
| decode-1.json | 219.4 | 92.39 | 2.375 | openai_continuous_usage |
| decode-2.json | 212.4 | 91.37 | 2.324 | openai_continuous_usage |
| decode-3.json | 227.8 | 91.29 | 2.496 | openai_continuous_usage |
| decode-4.json | 215.6 | 91.05 | 2.368 | openai_continuous_usage |
| decode-5.json | 202.3 | 92.97 | 2.176 | openai_continuous_usage |

| file | C8 output tok/s | verifier steps/s | accepted length | source |
|---|---:|---:|---:|---|
| decode-1.json | 691.2 | 306.34 | 2.256 | openai_continuous_usage |
| decode-2.json | 700.4 | 313.46 | 2.234 | openai_continuous_usage |
| decode-3.json | 712.0 | 310.71 | 2.292 | openai_continuous_usage |
| decode-4.json | 700.7 | 311.77 | 2.248 | openai_continuous_usage |
| decode-5.json | 717.7 | 316.87 | 2.265 | openai_continuous_usage |

## PCIe and system (monitor.tsv)

Gen4 ceilings per direction (detected live: GPU 0 x16, GPU 1 x16, GPU 2 x16, GPU 3 x16).

| scope | GPU | width | tx max | tx p95 | tx mean | rx max | rx p95 | rx mean | util max | pwr max | clk max | mem max |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| overall | 0 | x16 | 17,153 MB/s (54%) | 12,277 MB/s | 4,065 MB/s | 16,002 MB/s (51%) | 12,916 MB/s | 4,054 MB/s | 100 % | 311 W | 2,340 MHz | 93,763 MiB |
| overall | 1 | x16 | 15,989 MB/s (51%) | 12,942 MB/s | 4,031 MB/s | 15,926 MB/s (51%) | 12,939 MB/s | 4,160 MB/s | 100 % | 326 W | 2,340 MHz | 93,763 MiB |
| overall | 2 | x16 | 15,312 MB/s (49%) | 13,186 MB/s | 4,028 MB/s | 16,371 MB/s (52%) | 12,819 MB/s | 4,067 MB/s | 100 % | 336 W | 2,887 MHz | 93,743 MiB |
| overall | 3 | x16 | 14,875 MB/s (47%) | 12,637 MB/s | 4,023 MB/s | 15,319 MB/s (49%) | 13,112 MB/s | 4,023 MB/s | 100 % | 335 W | 2,880 MHz | 93,743 MiB |
| decode_active | 0 | x16 | 17,153 MB/s (54%) | 12,418 MB/s | 4,606 MB/s | 16,002 MB/s (51%) | 12,990 MB/s | 4,574 MB/s | 100 % | 311 W | 2,340 MHz | 93,763 MiB |
| decode_active | 1 | x16 | 15,989 MB/s (51%) | 13,072 MB/s | 4,583 MB/s | 15,926 MB/s (51%) | 13,219 MB/s | 4,722 MB/s | 100 % | 326 W | 2,340 MHz | 93,763 MiB |
| decode_active | 2 | x16 | 15,312 MB/s (49%) | 13,296 MB/s | 4,576 MB/s | 16,371 MB/s (52%) | 12,920 MB/s | 4,624 MB/s | 100 % | 336 W | 2,880 MHz | 93,743 MiB |
| decode_active | 3 | x16 | 14,875 MB/s (47%) | 12,824 MB/s | 4,575 MB/s | 15,319 MB/s (49%) | 13,253 MB/s | 4,574 MB/s | 100 % | 335 W | 2,880 MHz | 93,743 MiB |
| decode-1 | 0 | x16 | 6,533 MB/s (21%) | 5,829 MB/s | 2,995 MB/s | 5,982 MB/s (19%) | 5,495 MB/s | 2,961 MB/s | 100 % | 310 W | 2,340 MHz | 93,763 MiB |
| decode-1 | 1 | x16 | 5,886 MB/s (19%) | 5,663 MB/s | 2,912 MB/s | 6,006 MB/s (19%) | 5,814 MB/s | 2,956 MB/s | 100 % | 325 W | 2,340 MHz | 93,763 MiB |
| decode-1 | 2 | x16 | 5,735 MB/s (18%) | 5,432 MB/s | 2,901 MB/s | 6,037 MB/s (19%) | 5,670 MB/s | 2,958 MB/s | 100 % | 330 W | 2,880 MHz | 93,743 MiB |
| decode-1 | 3 | x16 | 5,542 MB/s (18%) | 5,416 MB/s | 2,690 MB/s | 6,043 MB/s (19%) | 5,437 MB/s | 2,955 MB/s | 100 % | 329 W | 2,880 MHz | 93,743 MiB |
| decode-2 | 0 | x16 | 7,189 MB/s (23%) | 5,748 MB/s | 3,098 MB/s | 6,703 MB/s (21%) | 5,441 MB/s | 2,949 MB/s | 100 % | 307 W | 2,340 MHz | 93,763 MiB |
| decode-2 | 1 | x16 | 6,429 MB/s (20%) | 5,708 MB/s | 3,134 MB/s | 6,091 MB/s (19%) | 5,805 MB/s | 3,149 MB/s | 100 % | 326 W | 2,340 MHz | 93,763 MiB |
| decode-2 | 2 | x16 | 5,808 MB/s (18%) | 5,497 MB/s | 3,024 MB/s | 6,572 MB/s (21%) | 5,723 MB/s | 3,110 MB/s | 100 % | 331 W | 2,865 MHz | 93,743 MiB |
| decode-2 | 3 | x16 | 5,776 MB/s (18%) | 5,461 MB/s | 2,938 MB/s | 5,777 MB/s (18%) | 5,465 MB/s | 2,954 MB/s | 100 % | 329 W | 2,865 MHz | 93,743 MiB |
| decode-3 | 0 | x16 | 6,103 MB/s (19%) | 5,771 MB/s | 3,240 MB/s | 5,729 MB/s (18%) | 5,461 MB/s | 3,048 MB/s | 100 % | 311 W | 2,340 MHz | 93,763 MiB |
| decode-3 | 1 | x16 | 5,933 MB/s (19%) | 5,732 MB/s | 3,003 MB/s | 6,134 MB/s (19%) | 5,847 MB/s | 3,110 MB/s | 100 % | 325 W | 2,340 MHz | 93,763 MiB |
| decode-3 | 2 | x16 | 5,671 MB/s (18%) | 5,444 MB/s | 3,016 MB/s | 5,901 MB/s (19%) | 5,720 MB/s | 3,048 MB/s | 100 % | 332 W | 2,865 MHz | 93,743 MiB |
| decode-3 | 3 | x16 | 5,712 MB/s (18%) | 5,477 MB/s | 2,930 MB/s | 5,809 MB/s (18%) | 5,495 MB/s | 2,925 MB/s | 100 % | 334 W | 2,865 MHz | 93,743 MiB |
| decode-4 | 0 | x16 | 6,083 MB/s (19%) | 5,771 MB/s | 3,182 MB/s | 5,615 MB/s (18%) | 5,379 MB/s | 2,988 MB/s | 100 % | 307 W | 2,340 MHz | 93,763 MiB |
| decode-4 | 1 | x16 | 5,924 MB/s (19%) | 5,764 MB/s | 3,048 MB/s | 7,177 MB/s (23%) | 5,889 MB/s | 3,236 MB/s | 100 % | 326 W | 2,340 MHz | 93,763 MiB |
| decode-4 | 2 | x16 | 5,652 MB/s (18%) | 5,415 MB/s | 2,787 MB/s | 7,089 MB/s (23%) | 5,735 MB/s | 3,000 MB/s | 100 % | 331 W | 2,865 MHz | 93,743 MiB |
| decode-4 | 3 | x16 | 5,615 MB/s (18%) | 5,431 MB/s | 3,060 MB/s | 5,843 MB/s (19%) | 5,447 MB/s | 3,029 MB/s | 100 % | 329 W | 2,865 MHz | 93,743 MiB |
| decode-5 | 0 | x16 | 6,069 MB/s (19%) | 5,964 MB/s | 3,130 MB/s | 5,730 MB/s (18%) | 5,657 MB/s | 2,963 MB/s | 100 % | 309 W | 2,340 MHz | 93,763 MiB |
| decode-5 | 1 | x16 | 5,974 MB/s (19%) | 5,800 MB/s | 3,055 MB/s | 6,879 MB/s (22%) | 6,165 MB/s | 3,172 MB/s | 100 % | 325 W | 2,340 MHz | 93,763 MiB |
| decode-5 | 2 | x16 | 5,770 MB/s (18%) | 5,427 MB/s | 2,957 MB/s | 5,969 MB/s (19%) | 5,835 MB/s | 3,139 MB/s | 100 % | 336 W | 2,865 MHz | 93,743 MiB |
| decode-5 | 3 | x16 | 5,550 MB/s (18%) | 5,472 MB/s | 2,939 MB/s | 5,701 MB/s (18%) | 5,496 MB/s | 2,926 MB/s | 100 % | 335 W | 2,865 MHz | 93,743 MiB |
| prefill | 0 | x16 | 17,153 MB/s (54%) | 13,856 MB/s | 7,012 MB/s | 16,002 MB/s (51%) | 14,248 MB/s | 7,650 MB/s | 100 % | 232 W | 2,340 MHz | 93,763 MiB |
| prefill | 1 | x16 | 14,369 MB/s (46%) | 14,059 MB/s | 8,015 MB/s | 14,280 MB/s (45%) | 13,545 MB/s | 7,122 MB/s | 100 % | 248 W | 2,340 MHz | 93,763 MiB |
| prefill | 2 | x16 | 14,980 MB/s (48%) | 14,082 MB/s | 6,889 MB/s | 16,173 MB/s (51%) | 14,596 MB/s | 7,719 MB/s | 100 % | 321 W | 2,887 MHz | 93,741 MiB |
| prefill | 3 | x16 | 14,875 MB/s (47%) | 14,074 MB/s | 7,177 MB/s | 14,139 MB/s (45%) | 13,911 MB/s | 7,061 MB/s | 100 % | 312 W | 2,880 MHz | 93,741 MiB |
| prefill-2 | 0 | x16 | 14,159 MB/s (45%) | 13,796 MB/s | 7,000 MB/s | 14,142 MB/s (45%) | 13,902 MB/s | 7,749 MB/s | 100 % | 237 W | 2,340 MHz | 93,763 MiB |
| prefill-2 | 1 | x16 | 15,339 MB/s (49%) | 13,917 MB/s | 6,650 MB/s | 15,926 MB/s (51%) | 14,211 MB/s | 7,141 MB/s | 100 % | 253 W | 2,340 MHz | 93,763 MiB |
| prefill-2 | 2 | x16 | 15,013 MB/s (48%) | 13,729 MB/s | 5,672 MB/s | 14,311 MB/s (45%) | 13,913 MB/s | 6,462 MB/s | 100 % | 322 W | 2,887 MHz | 93,741 MiB |
| prefill-2 | 3 | x16 | 14,729 MB/s (47%) | 12,865 MB/s | 6,121 MB/s | 14,164 MB/s (45%) | 13,990 MB/s | 5,826 MB/s | 100 % | 312 W | 2,880 MHz | 93,741 MiB |
| prefill-3 | 0 | x16 | 15,280 MB/s (49%) | 14,060 MB/s | 6,376 MB/s | 14,584 MB/s (46%) | 14,062 MB/s | 6,183 MB/s | 100 % | 242 W | 2,340 MHz | 93,763 MiB |
| prefill-3 | 1 | x16 | 13,793 MB/s (44%) | 13,330 MB/s | 5,806 MB/s | 15,089 MB/s (48%) | 14,253 MB/s | 6,471 MB/s | 100 % | 257 W | 2,340 MHz | 93,763 MiB |
| prefill-3 | 2 | x16 | 14,793 MB/s (47%) | 14,005 MB/s | 7,569 MB/s | 14,202 MB/s (45%) | 13,882 MB/s | 6,444 MB/s | 100 % | 331 W | 2,880 MHz | 93,741 MiB |
| prefill-3 | 3 | x16 | 13,777 MB/s (44%) | 13,514 MB/s | 6,546 MB/s | 15,319 MB/s (49%) | 13,494 MB/s | 6,431 MB/s | 100 % | 311 W | 2,880 MHz | 93,741 MiB |
| prefill-4 | 0 | x16 | 14,155 MB/s (45%) | 14,099 MB/s | 6,015 MB/s | 13,650 MB/s (43%) | 13,232 MB/s | 6,129 MB/s | 100 % | 239 W | 2,340 MHz | 93,763 MiB |
| prefill-4 | 1 | x16 | 15,989 MB/s (51%) | 14,210 MB/s | 6,204 MB/s | 14,197 MB/s (45%) | 13,411 MB/s | 5,995 MB/s | 100 % | 255 W | 2,340 MHz | 93,763 MiB |
| prefill-4 | 2 | x16 | 14,315 MB/s (45%) | 13,585 MB/s | 6,840 MB/s | 14,257 MB/s (45%) | 13,376 MB/s | 6,265 MB/s | 100 % | 327 W | 2,880 MHz | 93,741 MiB |
| prefill-4 | 3 | x16 | 14,793 MB/s (47%) | 14,350 MB/s | 7,483 MB/s | 14,259 MB/s (45%) | 14,179 MB/s | 7,367 MB/s | 100 % | 316 W | 2,880 MHz | 93,741 MiB |
| prefill-5 | 0 | x16 | 13,353 MB/s (42%) | 12,764 MB/s | 5,950 MB/s | 15,244 MB/s (48%) | 13,971 MB/s | 6,295 MB/s | 100 % | 234 W | 2,340 MHz | 93,763 MiB |
| prefill-5 | 1 | x16 | 15,526 MB/s (49%) | 13,799 MB/s | 6,326 MB/s | 14,286 MB/s (45%) | 14,213 MB/s | 7,352 MB/s | 100 % | 256 W | 2,340 MHz | 93,763 MiB |
| prefill-5 | 2 | x16 | 15,312 MB/s (49%) | 14,252 MB/s | 7,147 MB/s | 16,371 MB/s (52%) | 13,468 MB/s | 6,484 MB/s | 100 % | 322 W | 2,880 MHz | 93,741 MiB |
| prefill-5 | 3 | x16 | 13,691 MB/s (43%) | 12,917 MB/s | 7,041 MB/s | 14,997 MB/s (48%) | 14,021 MB/s | 7,081 MB/s | 100 % | 312 W | 2,880 MHz | 93,741 MiB |

load1 max: 5.0   MemAvailable min: 293,882,640 kB

## Prefill after the platform swap (still open)

Decode closed from ~2x off KK to ~1.14x on the new board (all x16 Gen4, 64-core
5995WX). Prefill did not move (10,650 vs 10,330 on the old board) — which
refutes the earlier "x8 legs bottleneck prefill" reading. This run's data:

- PCIe legs are no longer saturated: tx/rx peak 45-54% of the x16 Gen4
  ceiling (the old x8 legs sat at 70-75%). Same throughput, same prefill
  rate => prefill was never link-throughput-bound.
- Host CPU: load1 max 5.0 on 64 cores — not CPU-bound.
- prefill_compute_share=0.4 is identical in the KK run's argv (with
  prefill-schedule-interval=1), so the fairness settings are not the delta.
- New asymmetry: mean SM activity during prefill is GPU0 58% vs 78-79% on
  GPU1-3, though GPU0/GPU1 are the same Max-Q SKU at the same clock. GPU0 is
  rank 0 (and the Engram DP-gather/writer path touches rank ordering).

Remaining hypotheses for the 1.7x prefill gap, in order: (1) Engram host
lookups throttling prefill on DDR4 (this board: 8ch DDR4-3200, ~205 GB/s; the
KK/qmax host was DDR5-class at roughly 2x that) — consistent with rank
stalls showing as 58% activity on GPU0 rather than link saturation; (2) the
KK machine's "Max-Q" cards sustaining higher clocks than this box's VRel
ceiling (~2,332 MHz here) — the raptor/GLM receipts show 2,745-2,865 MHz on
that host's cards at a 400 W cap, i.e. those were Workstation Edition cards,
so KK's DS41 host clock behavior needs its own telemetry to compare.

## WS-straggler chase: nsys + NCCL microbenchmark (resolution)

Question from the first nsys pass: GPU2/GPU3 (Workstation Ed.) sit idle
14.5s/11.7s per 35 s prefill window while GPU0/GPU1 (Max-Q) spend 9.9s/10.6s
inside NCCL AllReduce kernels. Was the 2x2-segment fabric (segment 0x20 vs
0x40, ring hops 1->2 and 3->0 are root-crossing NODE paths) punishing the WS
ranks?

Evidence:
- Standalone NCCL ring microbenchmark (this box, engine's NCCL env, bf16,
  sizes 0.55/1/4/8/40 MiB, p50 per rank): IDENTICAL across ranks to 1 us
  (0.103/0.137/0.370/0.690/3.259 ms). Fabric and ring order are symmetric.
- Engine AllReduce kernel residency (median 3.1-3.6 ms GPU0/1, 0.2 ms GPU2)
  vs pure transfer cost at the same sizes (~0.1-0.4 ms): the extra 30x is
  ENTRY SKEW WAITING, not data movement.
- GPU2 idle structure: five ~460 ms request-boundary stalls (all-rank silent)
  + thousands of sub-2 ms micro-gaps at a 10-20 ms cadence.
- Workers run with Cpus_allowed=0-63, no pinning asymmetry.
- GPU0/1 idle only 4.7-5.4s; GPU2/3 compute-busy ~= GPU0/1 (10.8 vs 11.8s).

Verdict: there is no WS straggler and no fabric penalty. The WS ranks are
HOST-SUBMISSION-BOUND relative to their own faster GPUs: the common engine
host loop enqueues work slightly slower than WS cards drain it (micro-gaps),
while Max-Q cards stay saturated and therefore enter collectives early and
accumulate wait-time inside NCCL kernels. Max-Q compute is the step pacer;
WS idleness is slack, not loss. Spin residency asymmetry is a symptom of the
rank that arrives last, which on a uniform host is simply the faster card.

Actionables this leaves on the table:
1. VRel clock ceiling on the two Max-Q ranks (~2,332 MHz) - card VBIOS;
   unchanged by any of this.
2. The 460 ms x 5 request-boundary bubbles (11.5% engine-wide silence) live
   in per-request start/finalization on the host path - the next real lever
   for prefill TTFT-style throughput, not fabric.
3. NCCL mid-band residency could be compressed further by enabling the B12X
   two-shot (VLLM_PCIE_TWOSHOT_ALLREDUCE_MAX_SIZE) for the 96 KiB-6 MiB band,
   which would replace PYNCCL ring spins in ep:0/mixed groups with PCIe
   peer-push - untested, needs one restart cycle.
