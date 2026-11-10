# ram-131072-reseat-325w — results vs Karmic Kraken

Protocol: llm_decode_bench.py v0.6.2 (sha256-pinned, see bench/PROVENANCE.md), 5 warmed 30 s windows per cell, 15 s warmup, 32K unique prefill (client TTFT), context-zero decode C1/C8, server-side /metrics accounting.

## Headline

| Cell | Ours (median of 5) | KK (Max-Q/325W) | Delta |
|---|---:|---:|---:|
| 32K prefill tok/s | 10,533 | 17,982 | -41.42% |
| C1 output tok/s | 123.4 | 249.1 | -50.44% |
| C1 verifier steps/s | 67.60 | 98.58 | -31.42% |
| C1 accepted length | 1.826 | 2.571 | -28.99% |
| C8 output tok/s | 431.8 | 805.5 | -46.39% |
| C8 verifier steps/s | 189.73 | 361.87 | -47.57% |
| C8 accepted length | 2.285 | 2.295 | -0.47% |
| KV capacity tokens | 4,651,704 | 4,727,748 | -1.61% |

## Per-window samples

| file | prefill tok/s | samples |
|---|---:|---:|
| prefill-2.json | 10,533 | 9 |
| prefill-3.json | 10,533 | 9 |
| prefill-4.json | 10,520 | 9 |
| prefill-5.json | 10,523 | 9 |
| prefill.json | 10,551 | 9 |

| file | C1 output tok/s | verifier steps/s | accepted length | source |
|---|---:|---:|---:|---|
| decode-1.json | 123.4 | 67.60 | 1.826 | openai_continuous_usage |
| decode-2.json | 123.6 | 65.95 | 1.874 | openai_continuous_usage |
| decode-3.json | 126.6 | 66.45 | 1.906 | openai_continuous_usage |
| decode-4.json | 118.6 | 69.24 | 1.714 | openai_continuous_usage |
| decode-5.json | 117.4 | 68.97 | 1.703 | openai_continuous_usage |

| file | C8 output tok/s | verifier steps/s | accepted length | source |
|---|---:|---:|---:|---|
| decode-1.json | 431.8 | 189.01 | 2.285 | openai_continuous_usage |
| decode-2.json | 440.0 | 190.06 | 2.315 | openai_continuous_usage |
| decode-3.json | 437.4 | 189.73 | 2.306 | openai_continuous_usage |
| decode-4.json | 423.3 | 189.78 | 2.230 | openai_continuous_usage |
| decode-5.json | 426.6 | 189.19 | 2.255 | openai_continuous_usage |

## PCIe and system (monitor.tsv)

Ceilings per direction: Gen4 x8 ~15,750 MB/s (GPUs 0,3), Gen4 x16 ~31,500 MB/s (GPUs 1,2).

| scope | GPU | width | tx max | tx p95 | tx mean | rx max | rx p95 | rx mean | util max | pwr max | clk max | mem max |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| overall | 0 | x8 | 11,750 MB/s (75%) | 9,416 MB/s | 3,322 MB/s | 11,092 MB/s (70%) | 10,267 MB/s | 3,587 MB/s | 100 % | 329 W | 2,887 MHz | 93,601 MiB |
| overall | 1 | x16 | 11,213 MB/s (36%) | 9,750 MB/s | 3,282 MB/s | 11,895 MB/s (38%) | 9,563 MB/s | 3,402 MB/s | 100 % | 238 W | 2,332 MHz | 93,623 MiB |
| overall | 2 | x16 | 11,372 MB/s (36%) | 9,284 MB/s | 3,306 MB/s | 10,692 MB/s (34%) | 9,829 MB/s | 3,348 MB/s | 100 % | 250 W | 2,340 MHz | 93,603 MiB |
| overall | 3 | x8 | 11,631 MB/s (74%) | 9,423 MB/s | 3,380 MB/s | 11,928 MB/s (76%) | 9,757 MB/s | 3,417 MB/s | 100 % | 328 W | 2,880 MHz | 93,603 MiB |
| decode_active | 0 | x8 | 11,750 MB/s (75%) | 9,503 MB/s | 3,708 MB/s | 11,092 MB/s (70%) | 10,405 MB/s | 3,994 MB/s | 100 % | 329 W | 2,880 MHz | 93,601 MiB |
| decode_active | 1 | x16 | 11,213 MB/s (36%) | 9,805 MB/s | 3,681 MB/s | 11,895 MB/s (38%) | 9,656 MB/s | 3,806 MB/s | 100 % | 238 W | 2,332 MHz | 93,623 MiB |
| decode_active | 2 | x16 | 11,372 MB/s (36%) | 9,588 MB/s | 3,715 MB/s | 10,692 MB/s (34%) | 9,966 MB/s | 3,761 MB/s | 100 % | 250 W | 2,340 MHz | 93,603 MiB |
| decode_active | 3 | x8 | 11,631 MB/s (74%) | 9,493 MB/s | 3,798 MB/s | 11,928 MB/s (76%) | 10,000 MB/s | 3,841 MB/s | 100 % | 328 W | 2,880 MHz | 93,603 MiB |
| decode-1 | 0 | x8 | 5,671 MB/s (36%) | 5,535 MB/s | 2,168 MB/s | 5,785 MB/s (37%) | 5,589 MB/s | 2,102 MB/s | 100 % | 329 W | 2,880 MHz | 93,601 MiB |
| decode-1 | 1 | x16 | 5,468 MB/s (17%) | 5,409 MB/s | 2,122 MB/s | 5,745 MB/s (18%) | 5,570 MB/s | 2,090 MB/s | 100 % | 235 W | 2,332 MHz | 93,623 MiB |
| decode-1 | 2 | x16 | 5,823 MB/s (18%) | 5,548 MB/s | 2,215 MB/s | 5,521 MB/s (18%) | 5,375 MB/s | 1,989 MB/s | 100 % | 245 W | 2,340 MHz | 93,601 MiB |
| decode-1 | 3 | x8 | 5,708 MB/s (36%) | 5,573 MB/s | 2,178 MB/s | 5,821 MB/s (37%) | 5,602 MB/s | 2,079 MB/s | 100 % | 327 W | 2,872 MHz | 93,603 MiB |
| decode-2 | 0 | x8 | 5,648 MB/s (36%) | 5,492 MB/s | 1,973 MB/s | 5,722 MB/s (36%) | 5,574 MB/s | 2,155 MB/s | 100 % | 328 W | 2,880 MHz | 93,601 MiB |
| decode-2 | 1 | x16 | 5,659 MB/s (18%) | 5,429 MB/s | 1,893 MB/s | 5,740 MB/s (18%) | 5,641 MB/s | 2,169 MB/s | 100 % | 234 W | 2,332 MHz | 93,623 MiB |
| decode-2 | 2 | x16 | 5,861 MB/s (19%) | 5,610 MB/s | 1,954 MB/s | 5,756 MB/s (18%) | 5,442 MB/s | 2,080 MB/s | 100 % | 246 W | 2,340 MHz | 93,601 MiB |
| decode-2 | 3 | x8 | 5,714 MB/s (36%) | 5,522 MB/s | 1,991 MB/s | 5,927 MB/s (38%) | 5,618 MB/s | 2,155 MB/s | 100 % | 328 W | 2,872 MHz | 93,603 MiB |
| decode-3 | 0 | x8 | 5,651 MB/s (36%) | 5,570 MB/s | 2,102 MB/s | 5,736 MB/s (36%) | 5,590 MB/s | 2,145 MB/s | 100 % | 329 W | 2,880 MHz | 93,601 MiB |
| decode-3 | 1 | x16 | 5,533 MB/s (18%) | 5,416 MB/s | 2,014 MB/s | 5,947 MB/s (19%) | 5,655 MB/s | 2,183 MB/s | 100 % | 237 W | 2,332 MHz | 93,623 MiB |
| decode-3 | 2 | x16 | 5,670 MB/s (18%) | 5,587 MB/s | 2,081 MB/s | 5,621 MB/s (18%) | 5,461 MB/s | 2,102 MB/s | 100 % | 248 W | 2,340 MHz | 93,601 MiB |
| decode-3 | 3 | x8 | 5,642 MB/s (36%) | 5,522 MB/s | 2,081 MB/s | 5,747 MB/s (36%) | 5,624 MB/s | 2,177 MB/s | 100 % | 327 W | 2,872 MHz | 93,603 MiB |
| decode-4 | 0 | x8 | 5,934 MB/s (38%) | 5,594 MB/s | 2,161 MB/s | 5,869 MB/s (37%) | 5,589 MB/s | 2,207 MB/s | 100 % | 329 W | 2,880 MHz | 93,601 MiB |
| decode-4 | 1 | x16 | 5,651 MB/s (18%) | 5,435 MB/s | 2,066 MB/s | 5,872 MB/s (19%) | 5,619 MB/s | 2,227 MB/s | 100 % | 234 W | 2,332 MHz | 93,623 MiB |
| decode-4 | 2 | x16 | 5,735 MB/s (18%) | 5,609 MB/s | 2,150 MB/s | 5,452 MB/s (17%) | 5,434 MB/s | 2,150 MB/s | 100 % | 246 W | 2,340 MHz | 93,603 MiB |
| decode-4 | 3 | x8 | 5,866 MB/s (37%) | 5,629 MB/s | 2,177 MB/s | 5,748 MB/s (36%) | 5,607 MB/s | 2,208 MB/s | 100 % | 328 W | 2,872 MHz | 93,603 MiB |
| decode-5 | 0 | x8 | 5,671 MB/s (36%) | 5,582 MB/s | 2,039 MB/s | 5,836 MB/s (37%) | 5,622 MB/s | 2,163 MB/s | 100 % | 328 W | 2,880 MHz | 93,601 MiB |
| decode-5 | 1 | x16 | 5,423 MB/s (17%) | 5,369 MB/s | 1,962 MB/s | 5,769 MB/s (18%) | 5,638 MB/s | 2,181 MB/s | 100 % | 238 W | 2,332 MHz | 93,623 MiB |
| decode-5 | 2 | x16 | 5,672 MB/s (18%) | 5,558 MB/s | 2,073 MB/s | 5,653 MB/s (18%) | 5,492 MB/s | 2,088 MB/s | 100 % | 250 W | 2,340 MHz | 93,603 MiB |
| decode-5 | 3 | x8 | 5,636 MB/s (36%) | 5,548 MB/s | 2,071 MB/s | 5,743 MB/s (36%) | 5,645 MB/s | 2,142 MB/s | 100 % | 327 W | 2,872 MHz | 93,603 MiB |
| prefill | 0 | x8 | 10,685 MB/s (68%) | 9,907 MB/s | 6,613 MB/s | 11,092 MB/s (70%) | 10,915 MB/s | 7,499 MB/s | 100 % | 313 W | 2,887 MHz | 93,599 MiB |
| prefill | 1 | x16 | 10,967 MB/s (35%) | 10,094 MB/s | 6,324 MB/s | 10,908 MB/s (35%) | 9,912 MB/s | 6,870 MB/s | 100 % | 211 W | 2,325 MHz | 93,621 MiB |
| prefill | 2 | x16 | 11,284 MB/s (36%) | 10,570 MB/s | 6,609 MB/s | 10,621 MB/s (34%) | 10,442 MB/s | 6,636 MB/s | 100 % | 214 W | 2,332 MHz | 93,601 MiB |
| prefill | 3 | x8 | 11,631 MB/s (74%) | 10,631 MB/s | 7,060 MB/s | 10,332 MB/s (66%) | 9,940 MB/s | 6,437 MB/s | 100 % | 298 W | 2,880 MHz | 93,601 MiB |
| prefill-2 | 0 | x8 | 11,750 MB/s (75%) | 9,927 MB/s | 6,445 MB/s | 10,850 MB/s (69%) | 10,824 MB/s | 7,188 MB/s | 100 % | 318 W | 2,880 MHz | 93,599 MiB |
| prefill-2 | 1 | x16 | 11,087 MB/s (35%) | 10,340 MB/s | 6,572 MB/s | 10,606 MB/s (34%) | 10,271 MB/s | 6,442 MB/s | 100 % | 212 W | 2,332 MHz | 93,621 MiB |
| prefill-2 | 2 | x16 | 10,185 MB/s (32%) | 10,095 MB/s | 6,662 MB/s | 10,692 MB/s (34%) | 10,363 MB/s | 6,775 MB/s | 100 % | 215 W | 2,340 MHz | 93,601 MiB |
| prefill-2 | 3 | x8 | 9,836 MB/s (62%) | 9,781 MB/s | 6,644 MB/s | 10,977 MB/s (70%) | 10,270 MB/s | 6,908 MB/s | 100 % | 300 W | 2,872 MHz | 93,601 MiB |
| prefill-3 | 0 | x8 | 9,586 MB/s (61%) | 9,470 MB/s | 6,235 MB/s | 10,979 MB/s (70%) | 10,872 MB/s | 7,418 MB/s | 100 % | 320 W | 2,880 MHz | 93,599 MiB |
| prefill-3 | 1 | x16 | 10,322 MB/s (33%) | 10,296 MB/s | 6,467 MB/s | 11,895 MB/s (38%) | 10,794 MB/s | 6,722 MB/s | 100 % | 214 W | 2,332 MHz | 93,621 MiB |
| prefill-3 | 2 | x16 | 10,280 MB/s (33%) | 10,044 MB/s | 6,489 MB/s | 10,405 MB/s (33%) | 10,200 MB/s | 6,392 MB/s | 100 % | 216 W | 2,340 MHz | 93,601 MiB |
| prefill-3 | 3 | x8 | 9,881 MB/s (63%) | 9,751 MB/s | 6,903 MB/s | 10,514 MB/s (67%) | 10,204 MB/s | 6,820 MB/s | 100 % | 304 W | 2,872 MHz | 93,601 MiB |
| prefill-4 | 0 | x8 | 10,138 MB/s (64%) | 9,933 MB/s | 6,826 MB/s | 10,903 MB/s (69%) | 10,821 MB/s | 7,382 MB/s | 100 % | 323 W | 2,880 MHz | 93,599 MiB |
| prefill-4 | 1 | x16 | 10,359 MB/s (33%) | 10,328 MB/s | 6,330 MB/s | 11,164 MB/s (35%) | 9,954 MB/s | 6,433 MB/s | 100 % | 213 W | 2,332 MHz | 93,621 MiB |
| prefill-4 | 2 | x16 | 11,372 MB/s (36%) | 10,612 MB/s | 6,146 MB/s | 10,430 MB/s (33%) | 10,359 MB/s | 6,552 MB/s | 100 % | 218 W | 2,340 MHz | 93,601 MiB |
| prefill-4 | 3 | x8 | 10,518 MB/s (67%) | 9,831 MB/s | 6,552 MB/s | 10,944 MB/s (69%) | 10,589 MB/s | 6,332 MB/s | 100 % | 304 W | 2,872 MHz | 93,601 MiB |
| prefill-5 | 0 | x8 | 10,279 MB/s (65%) | 10,044 MB/s | 6,386 MB/s | 10,945 MB/s (69%) | 10,600 MB/s | 6,906 MB/s | 100 % | 322 W | 2,880 MHz | 93,599 MiB |
| prefill-5 | 1 | x16 | 11,213 MB/s (36%) | 10,352 MB/s | 7,086 MB/s | 10,143 MB/s (32%) | 9,644 MB/s | 6,425 MB/s | 100 % | 214 W | 2,332 MHz | 93,621 MiB |
| prefill-5 | 2 | x16 | 10,069 MB/s (32%) | 9,619 MB/s | 6,239 MB/s | 10,414 MB/s (33%) | 10,291 MB/s | 6,692 MB/s | 100 % | 217 W | 2,340 MHz | 93,601 MiB |
| prefill-5 | 3 | x8 | 9,636 MB/s (61%) | 9,519 MB/s | 6,234 MB/s | 11,928 MB/s (76%) | 11,115 MB/s | 6,891 MB/s | 100 % | 305 W | 2,872 MHz | 93,601 MiB |

load1 max: 4.7   MemAvailable min: 805,394,804 kB
