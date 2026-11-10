# twoshot-A-off — results vs Karmic Kraken

Protocol: llm_decode_bench.py v0.6.2 (sha256-pinned, see bench/PROVENANCE.md), 5 warmed 30 s windows per cell, 15 s warmup, 32K unique prefill (client TTFT), context-zero decode C1/C8, server-side /metrics accounting.

## Headline

| Cell | Ours (median of 5) | KK (Max-Q/325W) | Delta |
|---|---:|---:|---:|
| 32K prefill tok/s | 10,760 | 17,982 | -40.16% |
| C1 output tok/s | 212.6 | 249.1 | -14.63% |
| C1 verifier steps/s | 92.78 | 98.58 | -5.88% |
| C1 accepted length | 2.292 | 2.571 | -10.87% |
| C8 output tok/s | 700.5 | 805.5 | -13.04% |
| C8 verifier steps/s | 310.26 | 361.87 | -14.26% |
| C8 accepted length | 2.263 | 2.295 | -1.41% |
| KV capacity tokens | 4,741,178 | 4,727,748 | +0.28% |

## Per-window samples

| file | prefill tok/s | samples |
|---|---:|---:|
| prefill-2.json | 10,756 | 10 |
| prefill-3.json | 10,760 | 10 |
| prefill-4.json | 10,745 | 10 |
| prefill-5.json | 10,762 | 10 |
| prefill.json | 10,778 | 10 |

| file | C1 output tok/s | verifier steps/s | accepted length | source |
|---|---:|---:|---:|---|
| decode-1.json | 209.4 | 93.08 | 2.249 | openai_continuous_usage |
| decode-2.json | 217.1 | 92.36 | 2.351 | openai_continuous_usage |
| decode-3.json | 215.5 | 89.60 | 2.405 | openai_continuous_usage |
| decode-4.json | 212.6 | 92.78 | 2.292 | openai_continuous_usage |
| decode-5.json | 211.7 | 92.98 | 2.277 | openai_continuous_usage |

| file | C8 output tok/s | verifier steps/s | accepted length | source |
|---|---:|---:|---:|---|
| decode-1.json | 683.6 | 306.56 | 2.230 | openai_continuous_usage |
| decode-2.json | 710.3 | 310.26 | 2.289 | openai_continuous_usage |
| decode-3.json | 697.4 | 312.88 | 2.229 | openai_continuous_usage |
| decode-4.json | 700.5 | 307.42 | 2.279 | openai_continuous_usage |
| decode-5.json | 708.1 | 312.92 | 2.263 | openai_continuous_usage |

## PCIe and system (monitor.tsv)

Gen4 ceilings per direction (detected live: GPU 0 x16, GPU 1 x16, GPU 2 x16, GPU 3 x16).

| scope | GPU | width | tx max | tx p95 | tx mean | rx max | rx p95 | rx mean | util max | pwr max | clk max | mem max |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| overall | 0 | x16 | 15,939 MB/s (51%) | 13,214 MB/s | 4,321 MB/s | 16,077 MB/s (51%) | 12,944 MB/s | 4,160 MB/s | 100 % | 311 W | 2,340 MHz | 93,741 MiB |
| overall | 1 | x16 | 16,134 MB/s (51%) | 12,469 MB/s | 4,195 MB/s | 15,854 MB/s (50%) | 12,893 MB/s | 4,151 MB/s | 100 % | 326 W | 2,347 MHz | 93,743 MiB |
| overall | 2 | x16 | 15,065 MB/s (48%) | 12,499 MB/s | 4,241 MB/s | 16,046 MB/s (51%) | 13,555 MB/s | 4,418 MB/s | 100 % | 333 W | 2,895 MHz | 93,743 MiB |
| overall | 3 | x16 | 15,838 MB/s (50%) | 12,676 MB/s | 4,142 MB/s | 16,731 MB/s (53%) | 13,421 MB/s | 4,413 MB/s | 100 % | 332 W | 2,880 MHz | 93,743 MiB |
| decode_active | 0 | x16 | 15,939 MB/s (51%) | 13,431 MB/s | 4,778 MB/s | 16,077 MB/s (51%) | 13,092 MB/s | 4,597 MB/s | 100 % | 311 W | 2,317 MHz | 93,741 MiB |
| decode_active | 1 | x16 | 16,134 MB/s (51%) | 12,646 MB/s | 4,637 MB/s | 15,854 MB/s (50%) | 12,917 MB/s | 4,590 MB/s | 100 % | 326 W | 2,332 MHz | 93,743 MiB |
| decode_active | 2 | x16 | 15,065 MB/s (48%) | 12,690 MB/s | 4,695 MB/s | 16,046 MB/s (51%) | 13,698 MB/s | 4,889 MB/s | 100 % | 333 W | 2,857 MHz | 93,743 MiB |
| decode_active | 3 | x16 | 15,838 MB/s (50%) | 12,714 MB/s | 4,582 MB/s | 16,731 MB/s (53%) | 13,477 MB/s | 4,885 MB/s | 100 % | 332 W | 2,857 MHz | 93,743 MiB |
| decode-1 | 0 | x16 | 6,281 MB/s (20%) | 5,772 MB/s | 2,997 MB/s | 5,905 MB/s (19%) | 5,432 MB/s | 2,975 MB/s | 100 % | 310 W | 2,340 MHz | 93,741 MiB |
| decode-1 | 1 | x16 | 6,169 MB/s (20%) | 5,665 MB/s | 2,937 MB/s | 6,403 MB/s (20%) | 5,778 MB/s | 2,894 MB/s | 100 % | 326 W | 2,347 MHz | 93,743 MiB |
| decode-1 | 2 | x16 | 5,751 MB/s (18%) | 5,420 MB/s | 2,915 MB/s | 6,069 MB/s (19%) | 5,655 MB/s | 3,031 MB/s | 100 % | 330 W | 2,880 MHz | 93,743 MiB |
| decode-1 | 3 | x16 | 5,715 MB/s (18%) | 5,382 MB/s | 2,777 MB/s | 5,725 MB/s (18%) | 5,449 MB/s | 2,922 MB/s | 100 % | 329 W | 2,880 MHz | 93,743 MiB |
| decode-2 | 0 | x16 | 6,251 MB/s (20%) | 5,804 MB/s | 3,135 MB/s | 5,871 MB/s (19%) | 5,436 MB/s | 2,931 MB/s | 100 % | 307 W | 2,340 MHz | 93,741 MiB |
| decode-2 | 1 | x16 | 6,130 MB/s (19%) | 5,657 MB/s | 2,972 MB/s | 6,136 MB/s (19%) | 5,755 MB/s | 3,025 MB/s | 100 % | 326 W | 2,340 MHz | 93,743 MiB |
| decode-2 | 2 | x16 | 5,800 MB/s (18%) | 5,421 MB/s | 2,936 MB/s | 6,202 MB/s (20%) | 5,734 MB/s | 3,065 MB/s | 100 % | 331 W | 2,865 MHz | 93,743 MiB |
| decode-2 | 3 | x16 | 5,888 MB/s (19%) | 5,519 MB/s | 2,914 MB/s | 5,832 MB/s (19%) | 5,493 MB/s | 3,034 MB/s | 100 % | 330 W | 2,865 MHz | 93,743 MiB |
| decode-3 | 0 | x16 | 6,015 MB/s (19%) | 5,851 MB/s | 3,194 MB/s | 5,541 MB/s (18%) | 5,385 MB/s | 2,983 MB/s | 100 % | 310 W | 2,340 MHz | 93,741 MiB |
| decode-3 | 1 | x16 | 5,894 MB/s (19%) | 5,684 MB/s | 2,947 MB/s | 5,957 MB/s (19%) | 5,792 MB/s | 3,108 MB/s | 100 % | 326 W | 2,347 MHz | 93,743 MiB |
| decode-3 | 2 | x16 | 5,640 MB/s (18%) | 5,413 MB/s | 2,968 MB/s | 5,818 MB/s (18%) | 5,740 MB/s | 3,002 MB/s | 100 % | 333 W | 2,865 MHz | 93,743 MiB |
| decode-3 | 3 | x16 | 5,521 MB/s (18%) | 5,458 MB/s | 2,864 MB/s | 6,259 MB/s (20%) | 5,402 MB/s | 3,023 MB/s | 100 % | 332 W | 2,865 MHz | 93,743 MiB |
| decode-4 | 0 | x16 | 5,975 MB/s (19%) | 5,702 MB/s | 3,171 MB/s | 5,534 MB/s (18%) | 5,457 MB/s | 2,949 MB/s | 100 % | 307 W | 2,340 MHz | 93,741 MiB |
| decode-4 | 1 | x16 | 6,013 MB/s (19%) | 5,621 MB/s | 3,018 MB/s | 5,819 MB/s (18%) | 5,717 MB/s | 2,983 MB/s | 100 % | 326 W | 2,340 MHz | 93,743 MiB |
| decode-4 | 2 | x16 | 5,592 MB/s (18%) | 5,425 MB/s | 2,871 MB/s | 5,961 MB/s (19%) | 5,658 MB/s | 2,950 MB/s | 100 % | 333 W | 2,865 MHz | 93,743 MiB |
| decode-4 | 3 | x16 | 5,821 MB/s (18%) | 5,419 MB/s | 2,966 MB/s | 5,739 MB/s (18%) | 5,422 MB/s | 3,024 MB/s | 100 % | 329 W | 2,865 MHz | 93,743 MiB |
| decode-5 | 0 | x16 | 6,079 MB/s (19%) | 5,780 MB/s | 3,078 MB/s | 5,812 MB/s (18%) | 5,521 MB/s | 2,972 MB/s | 100 % | 311 W | 2,340 MHz | 93,741 MiB |
| decode-5 | 1 | x16 | 6,008 MB/s (19%) | 5,715 MB/s | 3,002 MB/s | 6,162 MB/s (20%) | 5,952 MB/s | 3,135 MB/s | 100 % | 326 W | 2,340 MHz | 93,743 MiB |
| decode-5 | 2 | x16 | 5,660 MB/s (18%) | 5,439 MB/s | 2,993 MB/s | 6,032 MB/s (19%) | 5,715 MB/s | 3,169 MB/s | 100 % | 331 W | 2,865 MHz | 93,743 MiB |
| decode-5 | 3 | x16 | 5,475 MB/s (17%) | 5,413 MB/s | 2,948 MB/s | 5,523 MB/s (18%) | 5,404 MB/s | 2,918 MB/s | 100 % | 328 W | 2,865 MHz | 93,743 MiB |
| prefill | 0 | x16 | 14,029 MB/s (45%) | 14,018 MB/s | 5,905 MB/s | 13,798 MB/s (44%) | 13,167 MB/s | 5,739 MB/s | 100 % | 224 W | 2,332 MHz | 93,741 MiB |
| prefill | 1 | x16 | 15,200 MB/s (48%) | 14,189 MB/s | 6,895 MB/s | 14,015 MB/s (44%) | 13,617 MB/s | 5,989 MB/s | 100 % | 217 W | 2,340 MHz | 93,743 MiB |
| prefill | 2 | x16 | 14,071 MB/s (45%) | 13,542 MB/s | 8,402 MB/s | 16,046 MB/s (51%) | 15,143 MB/s | 8,383 MB/s | 100 % | 319 W | 2,895 MHz | 93,741 MiB |
| prefill | 3 | x16 | 13,682 MB/s (43%) | 13,428 MB/s | 8,260 MB/s | 15,175 MB/s (48%) | 14,631 MB/s | 9,992 MB/s | 100 % | 304 W | 2,880 MHz | 93,741 MiB |
| prefill-2 | 0 | x16 | 15,939 MB/s (51%) | 14,043 MB/s | 7,940 MB/s | 14,718 MB/s (47%) | 13,902 MB/s | 7,041 MB/s | 100 % | 235 W | 2,332 MHz | 93,741 MiB |
| prefill-2 | 1 | x16 | 16,134 MB/s (51%) | 13,920 MB/s | 7,594 MB/s | 14,695 MB/s (47%) | 14,082 MB/s | 7,159 MB/s | 100 % | 230 W | 2,340 MHz | 93,743 MiB |
| prefill-2 | 2 | x16 | 15,065 MB/s (48%) | 13,461 MB/s | 7,251 MB/s | 15,096 MB/s (48%) | 14,336 MB/s | 7,490 MB/s | 100 % | 312 W | 2,895 MHz | 93,741 MiB |
| prefill-2 | 3 | x16 | 13,916 MB/s (44%) | 13,887 MB/s | 6,584 MB/s | 16,731 MB/s (53%) | 15,790 MB/s | 6,966 MB/s | 100 % | 309 W | 2,872 MHz | 93,741 MiB |
| prefill-3 | 0 | x16 | 14,036 MB/s (45%) | 14,020 MB/s | 8,314 MB/s | 15,909 MB/s (51%) | 14,634 MB/s | 9,866 MB/s | 100 % | 242 W | 2,332 MHz | 93,741 MiB |
| prefill-3 | 1 | x16 | 13,450 MB/s (43%) | 12,922 MB/s | 6,914 MB/s | 15,854 MB/s (50%) | 15,044 MB/s | 8,331 MB/s | 100 % | 240 W | 2,340 MHz | 93,743 MiB |
| prefill-3 | 2 | x16 | 13,649 MB/s (43%) | 13,603 MB/s | 6,950 MB/s | 14,235 MB/s (45%) | 13,837 MB/s | 7,385 MB/s | 100 % | 319 W | 2,880 MHz | 93,741 MiB |
| prefill-3 | 3 | x16 | 15,838 MB/s (50%) | 14,549 MB/s | 6,889 MB/s | 15,996 MB/s (51%) | 15,383 MB/s | 7,969 MB/s | 100 % | 311 W | 2,872 MHz | 93,741 MiB |
| prefill-4 | 0 | x16 | 15,924 MB/s (51%) | 14,522 MB/s | 6,649 MB/s | 13,640 MB/s (43%) | 13,013 MB/s | 6,675 MB/s | 100 % | 244 W | 2,340 MHz | 93,741 MiB |
| prefill-4 | 1 | x16 | 15,772 MB/s (50%) | 14,503 MB/s | 8,205 MB/s | 13,766 MB/s (44%) | 13,565 MB/s | 6,042 MB/s | 100 % | 248 W | 2,347 MHz | 93,743 MiB |
| prefill-4 | 2 | x16 | 13,358 MB/s (42%) | 13,262 MB/s | 8,366 MB/s | 14,404 MB/s (46%) | 14,221 MB/s | 9,092 MB/s | 100 % | 317 W | 2,880 MHz | 93,741 MiB |
| prefill-4 | 3 | x16 | 13,908 MB/s (44%) | 13,577 MB/s | 7,992 MB/s | 14,779 MB/s (47%) | 13,856 MB/s | 8,480 MB/s | 100 % | 313 W | 2,872 MHz | 93,741 MiB |
| prefill-5 | 0 | x16 | 15,675 MB/s (50%) | 13,955 MB/s | 8,700 MB/s | 16,077 MB/s (51%) | 13,505 MB/s | 7,185 MB/s | 100 % | 247 W | 2,340 MHz | 93,741 MiB |
| prefill-5 | 1 | x16 | 14,077 MB/s (45%) | 13,544 MB/s | 7,393 MB/s | 15,294 MB/s (49%) | 14,523 MB/s | 8,016 MB/s | 100 % | 251 W | 2,340 MHz | 93,743 MiB |
| prefill-5 | 2 | x16 | 13,987 MB/s (44%) | 13,151 MB/s | 7,331 MB/s | 14,138 MB/s (45%) | 13,869 MB/s | 7,748 MB/s | 100 % | 316 W | 2,880 MHz | 93,741 MiB |
| prefill-5 | 3 | x16 | 14,643 MB/s (46%) | 13,828 MB/s | 7,337 MB/s | 15,408 MB/s (49%) | 13,726 MB/s | 7,323 MB/s | 100 % | 314 W | 2,872 MHz | 93,741 MiB |

load1 max: 4.8   MemAvailable min: 293,428,984 kB
