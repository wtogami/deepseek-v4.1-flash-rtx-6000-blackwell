# ram-131072 — results vs Karmic Kraken

Protocol: llm_decode_bench.py v0.6.2 (sha256-pinned, see bench/PROVENANCE.md), 5 warmed 30 s windows per cell, 15 s warmup, 32K unique prefill (client TTFT), context-zero decode C1/C8, server-side /metrics accounting.

## Headline

| Cell | Ours (median of 5) | KK (Max-Q/325W) | Delta |
|---|---:|---:|---:|
| 32K prefill tok/s | 10,330 | 17,982 | -42.55% |
| C1 output tok/s | 122.8 | 249.1 | -50.69% |
| C1 verifier steps/s | 65.86 | 98.58 | -33.19% |
| C1 accepted length | 1.861 | 2.571 | -27.62% |
| C8 output tok/s | 435.7 | 805.5 | -45.91% |
| C8 verifier steps/s | 188.91 | 361.87 | -47.79% |
| C8 accepted length | 2.306 | 2.295 | +0.49% |
| KV capacity tokens | 4,564,235 | 4,727,748 | -3.46% |

## Per-window samples

| file | prefill tok/s | samples |
|---|---:|---:|
| prefill-2.json | 10,365 | 9 |
| prefill-3.json | 10,330 | 9 |
| prefill-4.json | 10,325 | 9 |
| prefill-5.json | 10,323 | 9 |
| prefill.json | 10,400 | 9 |

| file | C1 output tok/s | verifier steps/s | accepted length | source |
|---|---:|---:|---:|---|
| decode-1.json | 127.1 | 65.17 | 1.950 | openai_continuous_usage |
| decode-2.json | 123.8 | 65.71 | 1.884 | openai_continuous_usage |
| decode-3.json | 121.1 | 65.86 | 1.839 | openai_continuous_usage |
| decode-4.json | 122.7 | 66.69 | 1.840 | openai_continuous_usage |
| decode-5.json | 122.8 | 65.98 | 1.861 | openai_continuous_usage |

| file | C8 output tok/s | verifier steps/s | accepted length | source |
|---|---:|---:|---:|---|
| decode-1.json | 441.0 | 189.30 | 2.330 | openai_continuous_usage |
| decode-2.json | 425.6 | 186.54 | 2.281 | openai_continuous_usage |
| decode-3.json | 444.4 | 189.18 | 2.349 | openai_continuous_usage |
| decode-4.json | 435.7 | 188.91 | 2.306 | openai_continuous_usage |
| decode-5.json | 422.3 | 187.08 | 2.257 | openai_continuous_usage |

## PCIe and system (monitor.tsv)

Ceilings per direction: Gen4 x8 ~15,750 MB/s (GPUs 0,3), Gen4 x16 ~31,500 MB/s (GPUs 1,2).

| scope | GPU | width | tx max | tx p95 | tx mean | rx max | rx p95 | rx mean | util max | pwr max | clk max | mem max |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| overall | 0 | x8 | 11,470 MB/s (73%) | 9,382 MB/s | 3,288 MB/s | 11,777 MB/s (75%) | 10,248 MB/s | 3,554 MB/s | 100 % | 311 W | 2,880 MHz | 93,575 MiB |
| overall | 1 | x16 | 11,979 MB/s (38%) | 9,597 MB/s | 3,225 MB/s | 11,496 MB/s (36%) | 9,223 MB/s | 3,390 MB/s | 100 % | 256 W | 2,340 MHz | 93,531 MiB |
| overall | 2 | x16 | 10,971 MB/s (35%) | 9,574 MB/s | 3,376 MB/s | 11,425 MB/s (36%) | 9,876 MB/s | 3,391 MB/s | 100 % | 282 W | 2,340 MHz | 93,569 MiB |
| overall | 3 | x8 | 11,459 MB/s (73%) | 9,234 MB/s | 3,311 MB/s | 11,365 MB/s (72%) | 9,393 MB/s | 3,405 MB/s | 100 % | 305 W | 2,880 MHz | 93,627 MiB |
| decode_active | 0 | x8 | 11,470 MB/s (73%) | 9,456 MB/s | 3,646 MB/s | 11,777 MB/s (75%) | 10,401 MB/s | 3,915 MB/s | 100 % | 311 W | 2,880 MHz | 93,575 MiB |
| decode_active | 1 | x16 | 11,979 MB/s (38%) | 9,631 MB/s | 3,608 MB/s | 11,496 MB/s (36%) | 9,290 MB/s | 3,779 MB/s | 100 % | 256 W | 2,332 MHz | 93,531 MiB |
| decode_active | 2 | x16 | 10,971 MB/s (35%) | 9,614 MB/s | 3,781 MB/s | 11,425 MB/s (36%) | 9,997 MB/s | 3,797 MB/s | 100 % | 282 W | 2,340 MHz | 93,569 MiB |
| decode_active | 3 | x8 | 11,459 MB/s (73%) | 9,321 MB/s | 3,708 MB/s | 11,365 MB/s (72%) | 9,607 MB/s | 3,813 MB/s | 100 % | 305 W | 2,880 MHz | 93,627 MiB |
| decode-1 | 0 | x8 | 5,723 MB/s (36%) | 5,578 MB/s | 2,084 MB/s | 5,655 MB/s (36%) | 5,574 MB/s | 2,035 MB/s | 100 % | 310 W | 2,880 MHz | 93,573 MiB |
| decode-1 | 1 | x16 | 5,532 MB/s (18%) | 5,352 MB/s | 2,022 MB/s | 5,765 MB/s (18%) | 5,604 MB/s | 2,058 MB/s | 100 % | 256 W | 2,340 MHz | 93,527 MiB |
| decode-1 | 2 | x16 | 5,597 MB/s (18%) | 5,507 MB/s | 2,116 MB/s | 5,467 MB/s (17%) | 5,360 MB/s | 1,953 MB/s | 100 % | 281 W | 2,340 MHz | 93,565 MiB |
| decode-1 | 3 | x8 | 5,628 MB/s (36%) | 5,513 MB/s | 2,145 MB/s | 5,648 MB/s (36%) | 5,090 MB/s | 2,081 MB/s | 100 % | 304 W | 2,880 MHz | 93,623 MiB |
| decode-2 | 0 | x8 | 5,653 MB/s (36%) | 5,482 MB/s | 1,972 MB/s | 5,716 MB/s (36%) | 5,574 MB/s | 2,214 MB/s | 100 % | 311 W | 2,880 MHz | 93,575 MiB |
| decode-2 | 1 | x16 | 5,712 MB/s (18%) | 5,366 MB/s | 1,909 MB/s | 5,696 MB/s (18%) | 5,585 MB/s | 2,177 MB/s | 100 % | 256 W | 2,340 MHz | 93,529 MiB |
| decode-2 | 2 | x16 | 5,781 MB/s (18%) | 5,542 MB/s | 1,965 MB/s | 5,536 MB/s (18%) | 5,448 MB/s | 2,091 MB/s | 100 % | 280 W | 2,340 MHz | 93,567 MiB |
| decode-2 | 3 | x8 | 5,686 MB/s (36%) | 5,505 MB/s | 1,985 MB/s | 5,755 MB/s (37%) | 5,590 MB/s | 2,139 MB/s | 100 % | 305 W | 2,880 MHz | 93,625 MiB |
| decode-3 | 0 | x8 | 5,923 MB/s (38%) | 5,593 MB/s | 2,082 MB/s | 5,775 MB/s (37%) | 5,556 MB/s | 2,147 MB/s | 100 % | 302 W | 2,880 MHz | 93,575 MiB |
| decode-3 | 1 | x16 | 5,622 MB/s (18%) | 5,467 MB/s | 1,986 MB/s | 5,789 MB/s (18%) | 5,621 MB/s | 2,199 MB/s | 100 % | 255 W | 2,340 MHz | 93,531 MiB |
| decode-3 | 2 | x16 | 5,695 MB/s (18%) | 5,574 MB/s | 2,069 MB/s | 5,573 MB/s (18%) | 5,464 MB/s | 2,132 MB/s | 100 % | 279 W | 2,340 MHz | 93,569 MiB |
| decode-3 | 3 | x8 | 5,632 MB/s (36%) | 5,550 MB/s | 2,009 MB/s | 5,676 MB/s (36%) | 5,636 MB/s | 2,216 MB/s | 100 % | 304 W | 2,880 MHz | 93,627 MiB |
| decode-4 | 0 | x8 | 5,619 MB/s (36%) | 5,570 MB/s | 2,034 MB/s | 5,792 MB/s (37%) | 5,599 MB/s | 2,266 MB/s | 100 % | 302 W | 2,880 MHz | 93,575 MiB |
| decode-4 | 1 | x16 | 5,466 MB/s (17%) | 5,354 MB/s | 1,967 MB/s | 5,801 MB/s (18%) | 5,633 MB/s | 2,269 MB/s | 100 % | 255 W | 2,340 MHz | 93,531 MiB |
| decode-4 | 2 | x16 | 5,582 MB/s (18%) | 5,519 MB/s | 2,067 MB/s | 5,585 MB/s (18%) | 5,451 MB/s | 2,192 MB/s | 100 % | 280 W | 2,340 MHz | 93,569 MiB |
| decode-4 | 3 | x8 | 5,579 MB/s (35%) | 5,477 MB/s | 2,057 MB/s | 5,718 MB/s (36%) | 5,605 MB/s | 2,253 MB/s | 100 % | 303 W | 2,872 MHz | 93,627 MiB |
| decode-5 | 0 | x8 | 5,671 MB/s (36%) | 5,536 MB/s | 2,067 MB/s | 5,772 MB/s (37%) | 5,561 MB/s | 2,105 MB/s | 100 % | 309 W | 2,880 MHz | 93,575 MiB |
| decode-5 | 1 | x16 | 5,507 MB/s (17%) | 5,419 MB/s | 2,022 MB/s | 5,816 MB/s (18%) | 5,572 MB/s | 2,104 MB/s | 100 % | 256 W | 2,340 MHz | 93,531 MiB |
| decode-5 | 2 | x16 | 7,028 MB/s (22%) | 5,597 MB/s | 2,211 MB/s | 5,549 MB/s (18%) | 5,404 MB/s | 2,064 MB/s | 100 % | 282 W | 2,340 MHz | 93,569 MiB |
| decode-5 | 3 | x8 | 5,704 MB/s (36%) | 5,521 MB/s | 2,146 MB/s | 5,625 MB/s (36%) | 5,560 MB/s | 2,108 MB/s | 100 % | 304 W | 2,880 MHz | 93,627 MiB |
| prefill | 0 | x8 | 10,864 MB/s (69%) | 10,129 MB/s | 6,509 MB/s | 10,762 MB/s (68%) | 10,312 MB/s | 6,647 MB/s | 100 % | 302 W | 2,880 MHz | 93,573 MiB |
| prefill | 1 | x16 | 10,334 MB/s (33%) | 9,952 MB/s | 6,139 MB/s | 11,496 MB/s (36%) | 10,751 MB/s | 6,813 MB/s | 100 % | 214 W | 2,332 MHz | 93,527 MiB |
| prefill | 2 | x16 | 10,582 MB/s (34%) | 10,192 MB/s | 6,704 MB/s | 10,434 MB/s (33%) | 10,410 MB/s | 6,553 MB/s | 100 % | 224 W | 2,340 MHz | 93,565 MiB |
| prefill | 3 | x8 | 11,247 MB/s (71%) | 9,383 MB/s | 6,196 MB/s | 10,680 MB/s (68%) | 9,699 MB/s | 6,337 MB/s | 100 % | 292 W | 2,880 MHz | 93,623 MiB |
| prefill-2 | 0 | x8 | 9,874 MB/s (63%) | 9,558 MB/s | 6,382 MB/s | 10,531 MB/s (67%) | 10,461 MB/s | 7,371 MB/s | 100 % | 303 W | 2,880 MHz | 93,573 MiB |
| prefill-2 | 1 | x16 | 11,979 MB/s (38%) | 10,208 MB/s | 6,411 MB/s | 9,956 MB/s (32%) | 9,774 MB/s | 6,338 MB/s | 100 % | 217 W | 2,332 MHz | 93,527 MiB |
| prefill-2 | 2 | x16 | 10,971 MB/s (35%) | 10,514 MB/s | 6,734 MB/s | 10,391 MB/s (33%) | 10,121 MB/s | 6,415 MB/s | 100 % | 232 W | 2,340 MHz | 93,565 MiB |
| prefill-2 | 3 | x8 | 9,822 MB/s (62%) | 9,798 MB/s | 6,638 MB/s | 10,288 MB/s (65%) | 9,901 MB/s | 6,642 MB/s | 100 % | 295 W | 2,880 MHz | 93,623 MiB |
| prefill-3 | 0 | x8 | 11,470 MB/s (73%) | 9,858 MB/s | 6,538 MB/s | 11,777 MB/s (75%) | 11,166 MB/s | 7,281 MB/s | 100 % | 303 W | 2,880 MHz | 93,573 MiB |
| prefill-3 | 1 | x16 | 10,012 MB/s (32%) | 9,753 MB/s | 6,482 MB/s | 10,232 MB/s (32%) | 9,833 MB/s | 6,359 MB/s | 100 % | 219 W | 2,332 MHz | 93,527 MiB |
| prefill-3 | 2 | x16 | 10,127 MB/s (32%) | 9,839 MB/s | 6,555 MB/s | 11,425 MB/s (36%) | 10,421 MB/s | 7,080 MB/s | 100 % | 237 W | 2,340 MHz | 93,565 MiB |
| prefill-3 | 3 | x8 | 11,459 MB/s (73%) | 10,626 MB/s | 6,679 MB/s | 11,365 MB/s (72%) | 10,224 MB/s | 6,602 MB/s | 100 % | 298 W | 2,880 MHz | 93,623 MiB |
| prefill-4 | 0 | x8 | 9,990 MB/s (63%) | 9,748 MB/s | 6,707 MB/s | 11,141 MB/s (71%) | 10,504 MB/s | 7,472 MB/s | 100 % | 303 W | 2,880 MHz | 93,573 MiB |
| prefill-4 | 1 | x16 | 10,334 MB/s (33%) | 10,103 MB/s | 6,256 MB/s | 10,030 MB/s (32%) | 9,528 MB/s | 6,319 MB/s | 100 % | 221 W | 2,332 MHz | 93,527 MiB |
| prefill-4 | 2 | x16 | 9,940 MB/s (32%) | 9,861 MB/s | 6,532 MB/s | 11,362 MB/s (36%) | 10,392 MB/s | 7,141 MB/s | 100 % | 238 W | 2,340 MHz | 93,565 MiB |
| prefill-4 | 3 | x8 | 9,567 MB/s (61%) | 9,437 MB/s | 6,496 MB/s | 10,290 MB/s (65%) | 10,004 MB/s | 6,505 MB/s | 100 % | 298 W | 2,880 MHz | 93,623 MiB |
| prefill-5 | 0 | x8 | 11,068 MB/s (70%) | 9,700 MB/s | 6,162 MB/s | 10,695 MB/s (68%) | 10,648 MB/s | 6,900 MB/s | 100 % | 305 W | 2,880 MHz | 93,573 MiB |
| prefill-5 | 1 | x16 | 11,799 MB/s (37%) | 10,441 MB/s | 6,737 MB/s | 11,398 MB/s (36%) | 10,582 MB/s | 6,834 MB/s | 100 % | 222 W | 2,340 MHz | 93,527 MiB |
| prefill-5 | 2 | x16 | 10,965 MB/s (35%) | 10,009 MB/s | 6,859 MB/s | 10,748 MB/s (34%) | 10,231 MB/s | 6,431 MB/s | 100 % | 239 W | 2,340 MHz | 93,565 MiB |
| prefill-5 | 3 | x8 | 9,844 MB/s (63%) | 9,657 MB/s | 6,429 MB/s | 10,120 MB/s (64%) | 9,984 MB/s | 6,868 MB/s | 100 % | 301 W | 2,880 MHz | 93,623 MiB |

load1 max: 4.7   MemAvailable min: 781,789,108 kB

## Bottleneck analysis

PCIe is **not** the bottleneck. No link saturates in any window: the Gen4 x8
links (GPUs 0,3) peak at ~73–75% of their ~15,750 MB/s ceiling and the Gen4 x16
links (GPUs 1,2) peak at ~36–38% of their ~31,500 MB/s ceiling; per-direction
means are ~3.3–3.6 GB/s. So the large gaps vs KK (−42% to −51%) point to
compute, not I/O:

- **GPU SKU/link**: this box's GPUs 0,3 are Workstation Ed. on Gen4 **x8** at
  300 W; the KK reference was Max-Q on Gen4 **x16** at 325 W. The x8 links and
  the Workstation Ed. compute are the likely cause of the verifier-step and
  output-rate gaps.
- **KV cache**: 3.46% below KK (4,564,235 vs 4,727,748) because the current
  image enables CUDA-graph memory profiling by default (log suggests
  `--gpu-memory-utilization 0.9687` to restore the old effective size). Minor.
- **Weakest cell**: C1 accepted length is 27.6% below KK (1.861 vs 2.571) while
  C8 is at parity (+0.5%), so single-stream speculative acceptance — i.e.
  verifier cost per step — is the weakest link.
