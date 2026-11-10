# rebar325-cool-131072 — results vs Karmic Kraken

Protocol: llm_decode_bench.py v0.6.2 (sha256-pinned, see bench/PROVENANCE.md), 5 warmed 30 s windows per cell, 15 s warmup, 32K unique prefill (client TTFT), context-zero decode C1/C8, server-side /metrics accounting.

## Headline

| Cell | Ours (median of 5) | KK (Max-Q/325W) | Delta |
|---|---:|---:|---:|
| 32K prefill tok/s | 10,649 | 17,982 | -40.78% |
| C1 output tok/s | 225.6 | 249.1 | -9.41% |
| C1 verifier steps/s | 92.24 | 98.58 | -6.43% |
| C1 accepted length | 2.434 | 2.571 | -5.36% |
| C8 output tok/s | 740.0 | 805.5 | -8.13% |
| C8 verifier steps/s | 349.19 | 361.87 | -3.50% |
| C8 accepted length | 2.103 | 2.295 | -8.39% |
| KV capacity tokens | 4,740,829 | 4,727,748 | +0.28% |

## Per-window samples

| file | prefill tok/s | samples |
|---|---:|---:|
| prefill-2.json | 10,643 | 9 |
| prefill-3.json | 10,652 | 9 |
| prefill-4.json | 10,651 | 9 |
| prefill-5.json | 10,649 | 9 |
| prefill.json | 10,647 | 9 |

| file | C1 output tok/s | verifier steps/s | accepted length | source |
|---|---:|---:|---:|---|
| decode-1.json | 221.4 | 91.74 | 2.413 | openai_continuous_usage |
| decode-2.json | 232.9 | 92.49 | 2.518 | openai_continuous_usage |
| decode-3.json | 224.3 | 92.24 | 2.432 | openai_continuous_usage |
| decode-4.json | 232.6 | 91.65 | 2.538 | openai_continuous_usage |
| decode-5.json | 225.6 | 92.72 | 2.434 | openai_continuous_usage |

| file | C8 output tok/s | verifier steps/s | accepted length | source |
|---|---:|---:|---:|---|
| decode-1.json | 731.6 | 349.19 | 2.095 | openai_continuous_usage |
| decode-2.json | 736.0 | 338.82 | 2.172 | openai_continuous_usage |
| decode-3.json | 745.4 | 355.84 | 2.095 | openai_continuous_usage |
| decode-4.json | 740.0 | 351.93 | 2.103 | openai_continuous_usage |
| decode-5.json | 753.1 | 348.22 | 2.163 | openai_continuous_usage |

## PCIe and system (monitor.tsv)

Gen4 ceilings per direction (detected live: GPU 0 x16, GPU 1 x16, GPU 2 x16, GPU 3 x16).

| scope | GPU | width | tx max | tx p95 | tx mean | rx max | rx p95 | rx mean | util max | pwr max | clk max | mem max |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| overall | 0 | x16 | 14,734 MB/s (47%) | 12,645 MB/s | 3,916 MB/s | 14,596 MB/s (46%) | 12,945 MB/s | 4,040 MB/s | 100 % | 281 W | 2,332 MHz | 93,753 MiB |
| overall | 1 | x16 | 14,737 MB/s (47%) | 12,769 MB/s | 4,019 MB/s | 16,189 MB/s (51%) | 13,009 MB/s | 4,024 MB/s | 100 % | 291 W | 2,347 MHz | 93,733 MiB |
| overall | 2 | x16 | 14,739 MB/s (47%) | 12,536 MB/s | 3,929 MB/s | 15,995 MB/s (51%) | 13,208 MB/s | 4,050 MB/s | 100 % | 333 W | 2,895 MHz | 93,753 MiB |
| overall | 3 | x16 | 15,934 MB/s (51%) | 12,724 MB/s | 3,899 MB/s | 15,725 MB/s (50%) | 12,386 MB/s | 3,863 MB/s | 100 % | 334 W | 2,880 MHz | 93,753 MiB |
| decode_active | 0 | x16 | 14,734 MB/s (47%) | 12,722 MB/s | 4,409 MB/s | 14,596 MB/s (46%) | 13,048 MB/s | 4,535 MB/s | 100 % | 281 W | 2,332 MHz | 93,753 MiB |
| decode_active | 1 | x16 | 14,737 MB/s (47%) | 12,871 MB/s | 4,527 MB/s | 16,189 MB/s (51%) | 13,093 MB/s | 4,536 MB/s | 100 % | 291 W | 2,340 MHz | 93,733 MiB |
| decode_active | 2 | x16 | 14,739 MB/s (47%) | 12,740 MB/s | 4,455 MB/s | 15,995 MB/s (51%) | 13,324 MB/s | 4,591 MB/s | 100 % | 333 W | 2,887 MHz | 93,753 MiB |
| decode_active | 3 | x16 | 15,934 MB/s (51%) | 12,934 MB/s | 4,421 MB/s | 15,725 MB/s (50%) | 12,648 MB/s | 4,380 MB/s | 100 % | 334 W | 2,880 MHz | 93,753 MiB |
| decode-1 | 0 | x16 | 5,693 MB/s (18%) | 5,558 MB/s | 3,021 MB/s | 5,749 MB/s (18%) | 5,594 MB/s | 3,044 MB/s | 100 % | 278 W | 2,332 MHz | 93,753 MiB |
| decode-1 | 1 | x16 | 5,975 MB/s (19%) | 5,662 MB/s | 3,075 MB/s | 6,235 MB/s (20%) | 5,568 MB/s | 3,085 MB/s | 100 % | 288 W | 2,340 MHz | 93,733 MiB |
| decode-1 | 2 | x16 | 5,822 MB/s (18%) | 5,583 MB/s | 2,994 MB/s | 6,499 MB/s (21%) | 5,703 MB/s | 3,137 MB/s | 100 % | 332 W | 2,880 MHz | 93,753 MiB |
| decode-1 | 3 | x16 | 5,844 MB/s (19%) | 5,563 MB/s | 3,031 MB/s | 6,323 MB/s (20%) | 5,585 MB/s | 3,134 MB/s | 100 % | 329 W | 2,880 MHz | 93,753 MiB |
| decode-2 | 0 | x16 | 5,930 MB/s (19%) | 5,630 MB/s | 2,937 MB/s | 5,872 MB/s (19%) | 5,681 MB/s | 3,031 MB/s | 100 % | 279 W | 2,332 MHz | 93,753 MiB |
| decode-2 | 1 | x16 | 5,915 MB/s (19%) | 5,640 MB/s | 2,931 MB/s | 6,117 MB/s (19%) | 5,621 MB/s | 2,899 MB/s | 100 % | 289 W | 2,347 MHz | 93,733 MiB |
| decode-2 | 2 | x16 | 6,762 MB/s (21%) | 5,609 MB/s | 2,891 MB/s | 5,945 MB/s (19%) | 5,665 MB/s | 2,890 MB/s | 100 % | 332 W | 2,865 MHz | 93,753 MiB |
| decode-2 | 3 | x16 | 5,910 MB/s (19%) | 5,652 MB/s | 2,864 MB/s | 6,234 MB/s (20%) | 5,637 MB/s | 2,880 MB/s | 100 % | 330 W | 2,865 MHz | 93,753 MiB |
| decode-3 | 0 | x16 | 5,823 MB/s (18%) | 5,577 MB/s | 2,903 MB/s | 6,139 MB/s (19%) | 5,705 MB/s | 2,934 MB/s | 100 % | 279 W | 2,332 MHz | 93,753 MiB |
| decode-3 | 1 | x16 | 6,214 MB/s (20%) | 5,650 MB/s | 2,979 MB/s | 5,882 MB/s (19%) | 5,661 MB/s | 2,948 MB/s | 100 % | 289 W | 2,340 MHz | 93,733 MiB |
| decode-3 | 2 | x16 | 6,257 MB/s (20%) | 5,692 MB/s | 3,014 MB/s | 5,900 MB/s (19%) | 5,665 MB/s | 3,044 MB/s | 100 % | 333 W | 2,865 MHz | 93,753 MiB |
| decode-3 | 3 | x16 | 5,986 MB/s (19%) | 5,648 MB/s | 2,997 MB/s | 5,883 MB/s (19%) | 5,672 MB/s | 3,001 MB/s | 100 % | 334 W | 2,865 MHz | 93,753 MiB |
| decode-4 | 0 | x16 | 6,815 MB/s (22%) | 5,702 MB/s | 3,108 MB/s | 5,706 MB/s (18%) | 5,547 MB/s | 3,061 MB/s | 100 % | 281 W | 2,332 MHz | 93,753 MiB |
| decode-4 | 1 | x16 | 6,317 MB/s (20%) | 5,672 MB/s | 3,131 MB/s | 5,752 MB/s (18%) | 5,623 MB/s | 3,049 MB/s | 100 % | 291 W | 2,347 MHz | 93,733 MiB |
| decode-4 | 2 | x16 | 5,734 MB/s (18%) | 5,579 MB/s | 2,998 MB/s | 5,666 MB/s (18%) | 5,590 MB/s | 3,128 MB/s | 100 % | 330 W | 2,865 MHz | 93,753 MiB |
| decode-4 | 3 | x16 | 5,775 MB/s (18%) | 5,645 MB/s | 3,036 MB/s | 6,858 MB/s (22%) | 5,637 MB/s | 3,100 MB/s | 100 % | 329 W | 2,865 MHz | 93,753 MiB |
| decode-5 | 0 | x16 | 7,434 MB/s (24%) | 5,646 MB/s | 2,900 MB/s | 6,425 MB/s (20%) | 5,635 MB/s | 2,984 MB/s | 100 % | 280 W | 2,332 MHz | 93,753 MiB |
| decode-5 | 1 | x16 | 5,777 MB/s (18%) | 5,608 MB/s | 3,021 MB/s | 6,059 MB/s (19%) | 5,738 MB/s | 3,041 MB/s | 100 % | 291 W | 2,340 MHz | 93,733 MiB |
| decode-5 | 2 | x16 | 5,916 MB/s (19%) | 5,599 MB/s | 2,965 MB/s | 5,705 MB/s (18%) | 5,584 MB/s | 3,008 MB/s | 100 % | 332 W | 2,865 MHz | 93,753 MiB |
| decode-5 | 3 | x16 | 5,959 MB/s (19%) | 5,674 MB/s | 2,894 MB/s | 5,927 MB/s (19%) | 5,584 MB/s | 2,924 MB/s | 100 % | 331 W | 2,865 MHz | 93,753 MiB |
| prefill | 0 | x16 | 13,656 MB/s (43%) | 13,234 MB/s | 5,797 MB/s | 13,945 MB/s (44%) | 13,775 MB/s | 6,430 MB/s | 100 % | 219 W | 2,325 MHz | 93,753 MiB |
| prefill | 1 | x16 | 14,737 MB/s (47%) | 13,085 MB/s | 6,712 MB/s | 15,952 MB/s (51%) | 14,704 MB/s | 6,570 MB/s | 100 % | 220 W | 2,325 MHz | 93,733 MiB |
| prefill | 2 | x16 | 14,739 MB/s (47%) | 14,004 MB/s | 7,668 MB/s | 14,826 MB/s (47%) | 14,126 MB/s | 7,750 MB/s | 100 % | 306 W | 2,895 MHz | 93,753 MiB |
| prefill | 3 | x16 | 14,735 MB/s (47%) | 14,117 MB/s | 6,518 MB/s | 13,693 MB/s (43%) | 13,152 MB/s | 6,512 MB/s | 100 % | 298 W | 2,880 MHz | 93,753 MiB |
| prefill-2 | 0 | x16 | 14,734 MB/s (47%) | 13,752 MB/s | 6,805 MB/s | 12,970 MB/s (41%) | 12,593 MB/s | 6,657 MB/s | 100 % | 221 W | 2,332 MHz | 93,753 MiB |
| prefill-2 | 1 | x16 | 14,521 MB/s (46%) | 13,658 MB/s | 6,613 MB/s | 13,823 MB/s (44%) | 13,658 MB/s | 6,835 MB/s | 100 % | 221 W | 2,340 MHz | 93,733 MiB |
| prefill-2 | 2 | x16 | 14,721 MB/s (47%) | 14,248 MB/s | 6,120 MB/s | 14,171 MB/s (45%) | 13,973 MB/s | 6,090 MB/s | 100 % | 310 W | 2,887 MHz | 93,753 MiB |
| prefill-2 | 3 | x16 | 15,934 MB/s (51%) | 13,656 MB/s | 6,758 MB/s | 15,725 MB/s (50%) | 13,333 MB/s | 5,706 MB/s | 100 % | 304 W | 2,880 MHz | 93,753 MiB |
| prefill-3 | 0 | x16 | 13,654 MB/s (43%) | 12,524 MB/s | 6,259 MB/s | 14,510 MB/s (46%) | 13,915 MB/s | 6,602 MB/s | 100 % | 223 W | 2,332 MHz | 93,753 MiB |
| prefill-3 | 1 | x16 | 13,659 MB/s (43%) | 13,350 MB/s | 6,623 MB/s | 14,110 MB/s (45%) | 13,939 MB/s | 7,041 MB/s | 100 % | 220 W | 2,340 MHz | 93,733 MiB |
| prefill-3 | 2 | x16 | 13,268 MB/s (42%) | 13,088 MB/s | 5,214 MB/s | 14,844 MB/s (47%) | 14,353 MB/s | 5,729 MB/s | 100 % | 313 W | 2,887 MHz | 93,753 MiB |
| prefill-3 | 3 | x16 | 14,738 MB/s (47%) | 13,516 MB/s | 6,237 MB/s | 14,243 MB/s (45%) | 13,876 MB/s | 6,335 MB/s | 100 % | 300 W | 2,880 MHz | 93,753 MiB |
| prefill-4 | 0 | x16 | 13,660 MB/s (43%) | 13,324 MB/s | 6,371 MB/s | 13,887 MB/s (44%) | 13,779 MB/s | 6,947 MB/s | 100 % | 225 W | 2,332 MHz | 93,753 MiB |
| prefill-4 | 1 | x16 | 14,484 MB/s (46%) | 13,659 MB/s | 6,429 MB/s | 16,189 MB/s (51%) | 14,729 MB/s | 6,594 MB/s | 100 % | 224 W | 2,340 MHz | 93,733 MiB |
| prefill-4 | 2 | x16 | 14,515 MB/s (46%) | 13,986 MB/s | 7,142 MB/s | 15,995 MB/s (51%) | 15,306 MB/s | 7,241 MB/s | 100 % | 316 W | 2,880 MHz | 93,753 MiB |
| prefill-4 | 3 | x16 | 13,658 MB/s (43%) | 13,081 MB/s | 6,259 MB/s | 14,252 MB/s (45%) | 13,534 MB/s | 6,239 MB/s | 100 % | 311 W | 2,872 MHz | 93,753 MiB |
| prefill-5 | 0 | x16 | 14,729 MB/s (47%) | 14,355 MB/s | 6,522 MB/s | 14,596 MB/s (46%) | 13,634 MB/s | 6,862 MB/s | 100 % | 226 W | 2,332 MHz | 93,753 MiB |
| prefill-5 | 1 | x16 | 13,423 MB/s (43%) | 13,253 MB/s | 6,533 MB/s | 14,687 MB/s (47%) | 13,570 MB/s | 6,257 MB/s | 100 % | 232 W | 2,340 MHz | 93,733 MiB |
| prefill-5 | 2 | x16 | 13,957 MB/s (44%) | 13,657 MB/s | 5,928 MB/s | 14,820 MB/s (47%) | 14,395 MB/s | 6,509 MB/s | 100 % | 312 W | 2,880 MHz | 93,753 MiB |
| prefill-5 | 3 | x16 | 13,793 MB/s (44%) | 13,466 MB/s | 5,821 MB/s | 13,605 MB/s (43%) | 13,289 MB/s | 5,599 MB/s | 100 % | 314 W | 2,872 MHz | 93,753 MiB |

load1 max: 5.0   MemAvailable min: 300,107,764 kB
