# twoshot-B-on — results vs Karmic Kraken

Protocol: llm_decode_bench.py v0.6.2 (sha256-pinned, see bench/PROVENANCE.md), 5 warmed 30 s windows per cell, 15 s warmup, 32K unique prefill (client TTFT), context-zero decode C1/C8, server-side /metrics accounting.

## Headline

| Cell | Ours (median of 5) | KK (Max-Q/325W) | Delta |
|---|---:|---:|---:|
| 32K prefill tok/s | 10,666 | 17,982 | -40.69% |
| C1 output tok/s | 224.9 | 249.1 | -9.68% |
| C1 verifier steps/s | 91.64 | 98.58 | -7.04% |
| C1 accepted length | 2.461 | 2.571 | -4.29% |
| C8 output tok/s | 716.3 | 805.5 | -11.07% |
| C8 verifier steps/s | 325.06 | 361.87 | -10.17% |
| C8 accepted length | 2.192 | 2.295 | -4.52% |
| KV capacity tokens | 4,742,050 | 4,727,748 | +0.30% |

## Per-window samples

| file | prefill tok/s | samples |
|---|---:|---:|
| prefill-2.json | 10,668 | 9 |
| prefill-3.json | 10,648 | 9 |
| prefill-4.json | 10,684 | 9 |
| prefill-5.json | 10,659 | 9 |
| prefill.json | 10,666 | 9 |

| file | C1 output tok/s | verifier steps/s | accepted length | source |
|---|---:|---:|---:|---|
| decode-1.json | 230.7 | 91.64 | 2.517 | openai_continuous_usage |
| decode-2.json | 224.9 | 91.41 | 2.461 | openai_continuous_usage |
| decode-3.json | 203.7 | 91.77 | 2.220 | openai_continuous_usage |
| decode-4.json | 204.2 | 94.37 | 2.164 | openai_continuous_usage |
| decode-5.json | 225.3 | 90.54 | 2.489 | openai_continuous_usage |

| file | C8 output tok/s | verifier steps/s | accepted length | source |
|---|---:|---:|---:|---|
| decode-1.json | 702.9 | 320.72 | 2.192 | openai_continuous_usage |
| decode-2.json | 716.3 | 327.59 | 2.187 | openai_continuous_usage |
| decode-3.json | 726.0 | 324.60 | 2.237 | openai_continuous_usage |
| decode-4.json | 703.9 | 327.00 | 2.153 | openai_continuous_usage |
| decode-5.json | 720.1 | 325.06 | 2.215 | openai_continuous_usage |

## PCIe and system (monitor.tsv)

Gen4 ceilings per direction (detected live: GPU 0 x16, GPU 1 x16, GPU 2 x16, GPU 3 x16).

| scope | GPU | width | tx max | tx p95 | tx mean | rx max | rx p95 | rx mean | util max | pwr max | clk max | mem max |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| overall | 0 | x16 | 15,986 MB/s (51%) | 12,843 MB/s | 3,891 MB/s | 14,610 MB/s (46%) | 12,436 MB/s | 3,849 MB/s | 100 % | 307 W | 2,340 MHz | 93,773 MiB |
| overall | 1 | x16 | 15,672 MB/s (50%) | 13,152 MB/s | 4,067 MB/s | 16,103 MB/s (51%) | 13,112 MB/s | 3,948 MB/s | 100 % | 325 W | 2,347 MHz | 93,773 MiB |
| overall | 2 | x16 | 15,892 MB/s (50%) | 12,247 MB/s | 4,002 MB/s | 16,860 MB/s (54%) | 12,726 MB/s | 4,113 MB/s | 100 % | 340 W | 2,887 MHz | 93,773 MiB |
| overall | 3 | x16 | 15,860 MB/s (50%) | 12,883 MB/s | 3,999 MB/s | 15,993 MB/s (51%) | 12,646 MB/s | 3,971 MB/s | 100 % | 332 W | 2,880 MHz | 93,773 MiB |
| decode_active | 0 | x16 | 15,986 MB/s (51%) | 13,104 MB/s | 4,411 MB/s | 14,610 MB/s (46%) | 12,513 MB/s | 4,342 MB/s | 100 % | 307 W | 2,340 MHz | 93,773 MiB |
| decode_active | 1 | x16 | 15,672 MB/s (50%) | 13,356 MB/s | 4,609 MB/s | 16,103 MB/s (51%) | 13,341 MB/s | 4,478 MB/s | 100 % | 325 W | 2,347 MHz | 93,773 MiB |
| decode_active | 2 | x16 | 15,892 MB/s (50%) | 12,459 MB/s | 4,543 MB/s | 16,860 MB/s (54%) | 13,001 MB/s | 4,669 MB/s | 100 % | 340 W | 2,887 MHz | 93,773 MiB |
| decode_active | 3 | x16 | 15,860 MB/s (50%) | 13,032 MB/s | 4,545 MB/s | 15,993 MB/s (51%) | 12,798 MB/s | 4,513 MB/s | 100 % | 332 W | 2,872 MHz | 93,773 MiB |
| decode-1 | 0 | x16 | 5,357 MB/s (17%) | 5,164 MB/s | 2,828 MB/s | 5,258 MB/s (17%) | 5,194 MB/s | 2,847 MB/s | 100 % | 307 W | 2,340 MHz | 93,773 MiB |
| decode-1 | 1 | x16 | 5,508 MB/s (17%) | 5,285 MB/s | 2,860 MB/s | 5,550 MB/s (18%) | 5,280 MB/s | 2,856 MB/s | 100 % | 325 W | 2,347 MHz | 93,773 MiB |
| decode-1 | 2 | x16 | 5,363 MB/s (17%) | 5,152 MB/s | 2,845 MB/s | 5,515 MB/s (18%) | 5,297 MB/s | 2,821 MB/s | 100 % | 330 W | 2,880 MHz | 93,773 MiB |
| decode-1 | 3 | x16 | 5,456 MB/s (17%) | 5,124 MB/s | 2,699 MB/s | 5,396 MB/s (17%) | 5,147 MB/s | 2,821 MB/s | 100 % | 332 W | 2,880 MHz | 93,773 MiB |
| decode-2 | 0 | x16 | 5,335 MB/s (17%) | 5,211 MB/s | 2,888 MB/s | 5,855 MB/s (19%) | 5,564 MB/s | 2,950 MB/s | 100 % | 304 W | 2,340 MHz | 93,773 MiB |
| decode-2 | 1 | x16 | 6,007 MB/s (19%) | 5,227 MB/s | 2,919 MB/s | 5,283 MB/s (17%) | 5,142 MB/s | 2,846 MB/s | 100 % | 324 W | 2,340 MHz | 93,773 MiB |
| decode-2 | 2 | x16 | 5,709 MB/s (18%) | 5,155 MB/s | 2,940 MB/s | 5,781 MB/s (18%) | 5,317 MB/s | 2,888 MB/s | 100 % | 340 W | 2,865 MHz | 93,773 MiB |
| decode-2 | 3 | x16 | 5,387 MB/s (17%) | 5,168 MB/s | 2,928 MB/s | 5,373 MB/s (17%) | 5,183 MB/s | 2,846 MB/s | 100 % | 332 W | 2,865 MHz | 93,773 MiB |
| decode-3 | 0 | x16 | 5,473 MB/s (17%) | 5,265 MB/s | 2,967 MB/s | 5,526 MB/s (18%) | 5,209 MB/s | 2,898 MB/s | 100 % | 305 W | 2,340 MHz | 93,773 MiB |
| decode-3 | 1 | x16 | 6,104 MB/s (19%) | 5,202 MB/s | 2,881 MB/s | 5,337 MB/s (17%) | 5,225 MB/s | 2,882 MB/s | 100 % | 324 W | 2,340 MHz | 93,773 MiB |
| decode-3 | 2 | x16 | 5,471 MB/s (17%) | 5,190 MB/s | 2,920 MB/s | 6,381 MB/s (20%) | 5,366 MB/s | 2,822 MB/s | 100 % | 335 W | 2,865 MHz | 93,773 MiB |
| decode-3 | 3 | x16 | 5,568 MB/s (18%) | 5,283 MB/s | 2,885 MB/s | 5,805 MB/s (18%) | 5,326 MB/s | 2,938 MB/s | 100 % | 329 W | 2,857 MHz | 93,773 MiB |
| decode-4 | 0 | x16 | 5,421 MB/s (17%) | 5,213 MB/s | 2,802 MB/s | 5,310 MB/s (17%) | 5,209 MB/s | 2,749 MB/s | 100 % | 303 W | 2,340 MHz | 93,773 MiB |
| decode-4 | 1 | x16 | 6,754 MB/s (21%) | 5,262 MB/s | 2,879 MB/s | 5,595 MB/s (18%) | 5,242 MB/s | 2,840 MB/s | 100 % | 324 W | 2,340 MHz | 93,773 MiB |
| decode-4 | 2 | x16 | 5,400 MB/s (17%) | 5,174 MB/s | 2,783 MB/s | 6,432 MB/s (20%) | 5,243 MB/s | 2,868 MB/s | 100 % | 335 W | 2,865 MHz | 93,773 MiB |
| decode-4 | 3 | x16 | 5,490 MB/s (17%) | 5,225 MB/s | 2,870 MB/s | 5,482 MB/s (17%) | 5,176 MB/s | 2,859 MB/s | 100 % | 330 W | 2,865 MHz | 93,773 MiB |
| decode-5 | 0 | x16 | 5,637 MB/s (18%) | 5,211 MB/s | 2,845 MB/s | 5,676 MB/s (18%) | 5,113 MB/s | 2,924 MB/s | 100 % | 307 W | 2,340 MHz | 93,773 MiB |
| decode-5 | 1 | x16 | 5,268 MB/s (17%) | 5,169 MB/s | 2,890 MB/s | 5,642 MB/s (18%) | 5,224 MB/s | 2,982 MB/s | 100 % | 325 W | 2,340 MHz | 93,773 MiB |
| decode-5 | 2 | x16 | 6,311 MB/s (20%) | 5,172 MB/s | 2,867 MB/s | 5,904 MB/s (19%) | 5,214 MB/s | 2,905 MB/s | 100 % | 335 W | 2,865 MHz | 93,773 MiB |
| decode-5 | 3 | x16 | 5,405 MB/s (17%) | 5,187 MB/s | 2,970 MB/s | 5,556 MB/s (18%) | 5,187 MB/s | 2,882 MB/s | 100 % | 331 W | 2,865 MHz | 93,773 MiB |
| prefill | 0 | x16 | 14,052 MB/s (45%) | 14,041 MB/s | 5,951 MB/s | 13,662 MB/s (43%) | 12,968 MB/s | 5,865 MB/s | 100 % | 233 W | 2,332 MHz | 93,773 MiB |
| prefill | 1 | x16 | 14,139 MB/s (45%) | 13,870 MB/s | 6,825 MB/s | 14,877 MB/s (47%) | 13,822 MB/s | 6,324 MB/s | 100 % | 234 W | 2,347 MHz | 93,773 MiB |
| prefill | 2 | x16 | 13,765 MB/s (44%) | 13,663 MB/s | 6,213 MB/s | 16,860 MB/s (54%) | 15,093 MB/s | 7,404 MB/s | 100 % | 306 W | 2,880 MHz | 93,773 MiB |
| prefill | 3 | x16 | 14,573 MB/s (46%) | 13,731 MB/s | 6,749 MB/s | 15,432 MB/s (49%) | 14,030 MB/s | 7,051 MB/s | 100 % | 296 W | 2,880 MHz | 93,773 MiB |
| prefill-2 | 0 | x16 | 14,347 MB/s (46%) | 13,498 MB/s | 6,408 MB/s | 14,610 MB/s (46%) | 13,924 MB/s | 6,334 MB/s | 100 % | 238 W | 2,340 MHz | 93,773 MiB |
| prefill-2 | 1 | x16 | 15,672 MB/s (50%) | 14,901 MB/s | 7,764 MB/s | 15,622 MB/s (50%) | 13,758 MB/s | 6,786 MB/s | 100 % | 244 W | 2,340 MHz | 93,773 MiB |
| prefill-2 | 2 | x16 | 13,797 MB/s (44%) | 12,801 MB/s | 7,162 MB/s | 14,266 MB/s (45%) | 14,121 MB/s | 7,931 MB/s | 100 % | 316 W | 2,887 MHz | 93,773 MiB |
| prefill-2 | 3 | x16 | 13,717 MB/s (44%) | 13,220 MB/s | 6,510 MB/s | 14,131 MB/s (45%) | 13,479 MB/s | 6,735 MB/s | 100 % | 310 W | 2,872 MHz | 93,773 MiB |
| prefill-3 | 0 | x16 | 13,619 MB/s (43%) | 13,299 MB/s | 6,338 MB/s | 13,621 MB/s (43%) | 13,317 MB/s | 6,818 MB/s | 100 % | 239 W | 2,340 MHz | 93,773 MiB |
| prefill-3 | 1 | x16 | 15,449 MB/s (49%) | 14,275 MB/s | 7,321 MB/s | 14,263 MB/s (45%) | 13,747 MB/s | 6,939 MB/s | 100 % | 248 W | 2,347 MHz | 93,773 MiB |
| prefill-3 | 2 | x16 | 15,363 MB/s (49%) | 13,386 MB/s | 6,630 MB/s | 14,339 MB/s (46%) | 13,231 MB/s | 6,475 MB/s | 100 % | 316 W | 2,880 MHz | 93,773 MiB |
| prefill-3 | 3 | x16 | 15,343 MB/s (49%) | 14,631 MB/s | 6,918 MB/s | 15,993 MB/s (51%) | 13,577 MB/s | 6,558 MB/s | 100 % | 304 W | 2,872 MHz | 93,773 MiB |
| prefill-4 | 0 | x16 | 14,034 MB/s (45%) | 14,007 MB/s | 6,272 MB/s | 13,657 MB/s (43%) | 13,197 MB/s | 5,615 MB/s | 100 % | 246 W | 2,340 MHz | 93,773 MiB |
| prefill-4 | 1 | x16 | 14,275 MB/s (45%) | 14,127 MB/s | 6,427 MB/s | 14,278 MB/s (45%) | 12,297 MB/s | 5,606 MB/s | 100 % | 250 W | 2,347 MHz | 93,773 MiB |
| prefill-4 | 2 | x16 | 15,016 MB/s (48%) | 13,371 MB/s | 7,218 MB/s | 14,196 MB/s (45%) | 13,688 MB/s | 7,363 MB/s | 100 % | 315 W | 2,880 MHz | 93,773 MiB |
| prefill-4 | 3 | x16 | 15,860 MB/s (50%) | 13,779 MB/s | 7,423 MB/s | 13,575 MB/s (43%) | 13,551 MB/s | 6,991 MB/s | 100 % | 311 W | 2,872 MHz | 93,773 MiB |
| prefill-5 | 0 | x16 | 15,986 MB/s (51%) | 14,187 MB/s | 7,788 MB/s | 13,672 MB/s (43%) | 13,389 MB/s | 7,292 MB/s | 100 % | 248 W | 2,340 MHz | 93,773 MiB |
| prefill-5 | 1 | x16 | 14,082 MB/s (45%) | 13,937 MB/s | 7,319 MB/s | 16,103 MB/s (51%) | 14,240 MB/s | 7,939 MB/s | 100 % | 254 W | 2,347 MHz | 93,773 MiB |
| prefill-5 | 2 | x16 | 15,892 MB/s (50%) | 14,076 MB/s | 7,449 MB/s | 16,832 MB/s (53%) | 14,604 MB/s | 7,596 MB/s | 100 % | 321 W | 2,880 MHz | 93,773 MiB |
| prefill-5 | 3 | x16 | 15,638 MB/s (50%) | 13,409 MB/s | 7,024 MB/s | 13,976 MB/s (44%) | 13,528 MB/s | 6,810 MB/s | 100 % | 314 W | 2,880 MHz | 93,773 MiB |

load1 max: 4.8   MemAvailable min: 292,061,860 kB
