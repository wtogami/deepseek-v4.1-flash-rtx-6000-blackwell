# rebar-p2p-131072 — results vs Karmic Kraken

Protocol: llm_decode_bench.py v0.6.2 (sha256-pinned, see bench/PROVENANCE.md), 5 warmed 30 s windows per cell, 15 s warmup, 32K unique prefill (client TTFT), context-zero decode C1/C8, server-side /metrics accounting.

## Headline

| Cell | Ours (median of 5) | KK (Max-Q/325W) | Delta |
|---|---:|---:|---:|
| 32K prefill tok/s | 10,744 | 17,982 | -40.25% |
| C1 output tok/s | 226.1 | 249.1 | -9.21% |
| C1 verifier steps/s | 92.04 | 98.58 | -6.64% |
| C1 accepted length | 2.438 | 2.571 | -5.19% |
| C8 output tok/s | 728.2 | 805.5 | -9.60% |
| C8 verifier steps/s | 345.16 | 361.87 | -4.62% |
| C8 accepted length | 2.116 | 2.295 | -7.82% |
| KV capacity tokens | 4,740,829 | 4,727,748 | +0.28% |

## Per-window samples

| file | prefill tok/s | samples |
|---|---:|---:|
| prefill-2.json | 10,747 | 10 |
| prefill-3.json | 10,745 | 9 |
| prefill-4.json | 10,742 | 9 |
| prefill-5.json | 10,735 | 9 |
| prefill.json | 10,744 | 10 |

| file | C1 output tok/s | verifier steps/s | accepted length | source |
|---|---:|---:|---:|---|
| decode-1.json | 211.5 | 93.37 | 2.265 | openai_continuous_usage |
| decode-2.json | 226.1 | 92.75 | 2.438 | openai_continuous_usage |
| decode-3.json | 229.5 | 91.64 | 2.505 | openai_continuous_usage |
| decode-4.json | 230.8 | 91.97 | 2.510 | openai_continuous_usage |
| decode-5.json | 213.7 | 92.04 | 2.322 | openai_continuous_usage |

| file | C8 output tok/s | verifier steps/s | accepted length | source |
|---|---:|---:|---:|---|
| decode-1.json | 730.3 | 345.16 | 2.116 | openai_continuous_usage |
| decode-2.json | 722.6 | 343.54 | 2.103 | openai_continuous_usage |
| decode-3.json | 727.3 | 343.53 | 2.117 | openai_continuous_usage |
| decode-4.json | 728.2 | 349.30 | 2.085 | openai_continuous_usage |
| decode-5.json | 743.3 | 348.91 | 2.130 | openai_continuous_usage |

## PCIe and system (monitor.tsv)

Gen4 ceilings per direction (detected live: GPU 0 x16, GPU 1 x16, GPU 2 x16, GPU 3 x16).

| scope | GPU | width | tx max | tx p95 | tx mean | rx max | rx p95 | rx mean | util max | pwr max | clk max | mem max |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| overall | 0 | x16 | 14,674 MB/s (47%) | 12,666 MB/s | 4,018 MB/s | 13,886 MB/s (44%) | 12,357 MB/s | 4,109 MB/s | 100 % | 311 W | 2,340 MHz | 93,753 MiB |
| overall | 1 | x16 | 14,928 MB/s (47%) | 12,156 MB/s | 3,945 MB/s | 14,850 MB/s (47%) | 12,360 MB/s | 4,051 MB/s | 100 % | 326 W | 2,340 MHz | 93,733 MiB |
| overall | 2 | x16 | 14,730 MB/s (47%) | 12,724 MB/s | 4,046 MB/s | 15,647 MB/s (50%) | 12,472 MB/s | 4,017 MB/s | 100 % | 409 W | 2,887 MHz | 93,753 MiB |
| overall | 3 | x16 | 13,912 MB/s (44%) | 12,519 MB/s | 4,065 MB/s | 14,690 MB/s (47%) | 12,268 MB/s | 4,074 MB/s | 100 % | 401 W | 2,880 MHz | 93,753 MiB |
| decode_active | 0 | x16 | 14,674 MB/s (47%) | 12,909 MB/s | 4,464 MB/s | 13,886 MB/s (44%) | 12,564 MB/s | 4,541 MB/s | 100 % | 311 W | 2,340 MHz | 93,753 MiB |
| decode_active | 1 | x16 | 14,928 MB/s (47%) | 12,248 MB/s | 4,396 MB/s | 14,850 MB/s (47%) | 12,610 MB/s | 4,513 MB/s | 100 % | 326 W | 2,340 MHz | 93,733 MiB |
| decode_active | 2 | x16 | 14,730 MB/s (47%) | 12,847 MB/s | 4,517 MB/s | 15,647 MB/s (50%) | 12,699 MB/s | 4,483 MB/s | 100 % | 409 W | 2,857 MHz | 93,753 MiB |
| decode_active | 3 | x16 | 13,912 MB/s (44%) | 12,521 MB/s | 4,542 MB/s | 14,690 MB/s (47%) | 12,445 MB/s | 4,551 MB/s | 100 % | 401 W | 2,880 MHz | 93,753 MiB |
| decode-1 | 0 | x16 | 5,672 MB/s (18%) | 5,515 MB/s | 2,852 MB/s | 5,749 MB/s (18%) | 5,551 MB/s | 2,827 MB/s | 100 % | 301 W | 2,340 MHz | 93,753 MiB |
| decode-1 | 1 | x16 | 5,825 MB/s (18%) | 5,559 MB/s | 2,881 MB/s | 5,653 MB/s (18%) | 5,507 MB/s | 2,843 MB/s | 100 % | 303 W | 2,340 MHz | 93,733 MiB |
| decode-1 | 2 | x16 | 5,691 MB/s (18%) | 5,553 MB/s | 2,902 MB/s | 5,801 MB/s (18%) | 5,586 MB/s | 2,879 MB/s | 100 % | 402 W | 2,880 MHz | 93,753 MiB |
| decode-1 | 3 | x16 | 5,806 MB/s (18%) | 5,607 MB/s | 2,934 MB/s | 5,757 MB/s (18%) | 5,554 MB/s | 2,893 MB/s | 100 % | 395 W | 2,880 MHz | 93,753 MiB |
| decode-2 | 0 | x16 | 5,823 MB/s (18%) | 5,529 MB/s | 2,972 MB/s | 5,926 MB/s (19%) | 5,522 MB/s | 2,988 MB/s | 100 % | 300 W | 2,340 MHz | 93,753 MiB |
| decode-2 | 1 | x16 | 5,866 MB/s (19%) | 5,602 MB/s | 3,014 MB/s | 5,926 MB/s (19%) | 5,625 MB/s | 3,049 MB/s | 100 % | 301 W | 2,340 MHz | 93,733 MiB |
| decode-2 | 2 | x16 | 5,909 MB/s (19%) | 5,654 MB/s | 3,041 MB/s | 5,898 MB/s (19%) | 5,636 MB/s | 3,097 MB/s | 100 % | 407 W | 2,865 MHz | 93,753 MiB |
| decode-2 | 3 | x16 | 5,696 MB/s (18%) | 5,604 MB/s | 2,955 MB/s | 5,768 MB/s (18%) | 5,586 MB/s | 3,047 MB/s | 100 % | 398 W | 2,865 MHz | 93,753 MiB |
| decode-3 | 0 | x16 | 5,691 MB/s (18%) | 5,586 MB/s | 3,046 MB/s | 5,994 MB/s (19%) | 5,495 MB/s | 2,910 MB/s | 100 % | 301 W | 2,340 MHz | 93,753 MiB |
| decode-3 | 1 | x16 | 6,030 MB/s (19%) | 5,468 MB/s | 2,975 MB/s | 6,046 MB/s (19%) | 5,574 MB/s | 3,074 MB/s | 100 % | 305 W | 2,340 MHz | 93,733 MiB |
| decode-3 | 2 | x16 | 5,602 MB/s (18%) | 5,538 MB/s | 2,987 MB/s | 6,223 MB/s (20%) | 5,529 MB/s | 3,022 MB/s | 100 % | 409 W | 2,865 MHz | 93,753 MiB |
| decode-3 | 3 | x16 | 5,615 MB/s (18%) | 5,525 MB/s | 2,929 MB/s | 5,620 MB/s (18%) | 5,534 MB/s | 2,879 MB/s | 100 % | 401 W | 2,865 MHz | 93,753 MiB |
| decode-4 | 0 | x16 | 5,769 MB/s (18%) | 5,559 MB/s | 3,028 MB/s | 5,838 MB/s (19%) | 5,630 MB/s | 3,065 MB/s | 100 % | 309 W | 2,340 MHz | 93,753 MiB |
| decode-4 | 1 | x16 | 5,736 MB/s (18%) | 5,647 MB/s | 2,930 MB/s | 5,777 MB/s (18%) | 5,661 MB/s | 3,042 MB/s | 100 % | 326 W | 2,340 MHz | 93,733 MiB |
| decode-4 | 2 | x16 | 6,218 MB/s (20%) | 5,664 MB/s | 3,026 MB/s | 5,706 MB/s (18%) | 5,648 MB/s | 2,987 MB/s | 100 % | 355 W | 2,865 MHz | 93,753 MiB |
| decode-4 | 3 | x16 | 5,822 MB/s (18%) | 5,614 MB/s | 2,930 MB/s | 5,753 MB/s (18%) | 5,624 MB/s | 2,920 MB/s | 100 % | 344 W | 2,865 MHz | 93,753 MiB |
| decode-5 | 0 | x16 | 5,762 MB/s (18%) | 5,646 MB/s | 3,053 MB/s | 5,750 MB/s (18%) | 5,605 MB/s | 2,970 MB/s | 100 % | 311 W | 2,340 MHz | 93,753 MiB |
| decode-5 | 1 | x16 | 5,866 MB/s (19%) | 5,630 MB/s | 2,997 MB/s | 5,794 MB/s (18%) | 5,529 MB/s | 2,966 MB/s | 100 % | 326 W | 2,340 MHz | 93,733 MiB |
| decode-5 | 2 | x16 | 6,159 MB/s (20%) | 5,566 MB/s | 2,964 MB/s | 6,190 MB/s (20%) | 5,629 MB/s | 3,057 MB/s | 100 % | 334 W | 2,865 MHz | 93,753 MiB |
| decode-5 | 3 | x16 | 5,910 MB/s (19%) | 5,602 MB/s | 2,924 MB/s | 5,970 MB/s (19%) | 5,622 MB/s | 3,007 MB/s | 100 % | 329 W | 2,865 MHz | 93,753 MiB |
| prefill | 0 | x16 | 13,655 MB/s (43%) | 13,347 MB/s | 6,645 MB/s | 13,778 MB/s (44%) | 13,253 MB/s | 6,548 MB/s | 100 % | 233 W | 2,332 MHz | 93,753 MiB |
| prefill | 1 | x16 | 14,640 MB/s (46%) | 13,988 MB/s | 6,574 MB/s | 14,850 MB/s (47%) | 14,044 MB/s | 7,181 MB/s | 100 % | 240 W | 2,340 MHz | 93,733 MiB |
| prefill | 2 | x16 | 14,730 MB/s (47%) | 13,655 MB/s | 7,072 MB/s | 15,120 MB/s (48%) | 13,898 MB/s | 6,677 MB/s | 100 % | 320 W | 2,887 MHz | 93,753 MiB |
| prefill | 3 | x16 | 13,655 MB/s (43%) | 13,447 MB/s | 6,804 MB/s | 14,379 MB/s (46%) | 13,289 MB/s | 7,420 MB/s | 100 % | 307 W | 2,880 MHz | 93,753 MiB |
| prefill-2 | 0 | x16 | 14,674 MB/s (47%) | 14,037 MB/s | 6,993 MB/s | 13,682 MB/s (43%) | 12,949 MB/s | 7,834 MB/s | 100 % | 231 W | 2,340 MHz | 93,753 MiB |
| prefill-2 | 1 | x16 | 14,925 MB/s (47%) | 13,659 MB/s | 7,688 MB/s | 14,458 MB/s (46%) | 13,796 MB/s | 7,541 MB/s | 100 % | 242 W | 2,340 MHz | 93,733 MiB |
| prefill-2 | 2 | x16 | 14,360 MB/s (46%) | 13,534 MB/s | 6,702 MB/s | 14,041 MB/s (45%) | 13,546 MB/s | 7,128 MB/s | 100 % | 324 W | 2,880 MHz | 93,753 MiB |
| prefill-2 | 3 | x16 | 13,569 MB/s (43%) | 13,259 MB/s | 6,926 MB/s | 13,236 MB/s (42%) | 13,144 MB/s | 6,379 MB/s | 100 % | 313 W | 2,872 MHz | 93,753 MiB |
| prefill-3 | 0 | x16 | 13,654 MB/s (43%) | 13,654 MB/s | 7,336 MB/s | 13,886 MB/s (44%) | 13,518 MB/s | 7,623 MB/s | 100 % | 234 W | 2,340 MHz | 93,753 MiB |
| prefill-3 | 1 | x16 | 14,928 MB/s (47%) | 13,216 MB/s | 5,610 MB/s | 13,780 MB/s (44%) | 13,078 MB/s | 6,059 MB/s | 100 % | 243 W | 2,340 MHz | 93,733 MiB |
| prefill-3 | 2 | x16 | 14,168 MB/s (45%) | 13,960 MB/s | 7,079 MB/s | 13,812 MB/s (44%) | 12,842 MB/s | 5,752 MB/s | 100 % | 324 W | 2,880 MHz | 93,753 MiB |
| prefill-3 | 3 | x16 | 13,041 MB/s (41%) | 12,836 MB/s | 6,958 MB/s | 14,642 MB/s (46%) | 13,903 MB/s | 6,573 MB/s | 100 % | 308 W | 2,872 MHz | 93,753 MiB |
| prefill-4 | 0 | x16 | 14,139 MB/s (45%) | 13,654 MB/s | 6,571 MB/s | 13,370 MB/s (42%) | 12,897 MB/s | 6,985 MB/s | 100 % | 236 W | 2,340 MHz | 93,753 MiB |
| prefill-4 | 1 | x16 | 13,659 MB/s (43%) | 12,974 MB/s | 6,061 MB/s | 14,502 MB/s (46%) | 13,602 MB/s | 6,967 MB/s | 100 % | 245 W | 2,340 MHz | 93,733 MiB |
| prefill-4 | 2 | x16 | 13,660 MB/s (43%) | 13,427 MB/s | 6,028 MB/s | 14,161 MB/s (45%) | 13,465 MB/s | 5,873 MB/s | 100 % | 318 W | 2,880 MHz | 93,753 MiB |
| prefill-4 | 3 | x16 | 13,912 MB/s (44%) | 13,301 MB/s | 7,002 MB/s | 13,303 MB/s (42%) | 12,696 MB/s | 6,667 MB/s | 100 % | 314 W | 2,880 MHz | 93,753 MiB |
| prefill-5 | 0 | x16 | 13,654 MB/s (43%) | 13,125 MB/s | 6,181 MB/s | 13,765 MB/s (44%) | 13,486 MB/s | 6,915 MB/s | 100 % | 233 W | 2,340 MHz | 93,753 MiB |
| prefill-5 | 1 | x16 | 14,649 MB/s (47%) | 14,040 MB/s | 6,806 MB/s | 13,817 MB/s (44%) | 13,641 MB/s | 6,419 MB/s | 100 % | 243 W | 2,340 MHz | 93,733 MiB |
| prefill-5 | 2 | x16 | 13,267 MB/s (42%) | 13,173 MB/s | 7,441 MB/s | 15,647 MB/s (50%) | 14,844 MB/s | 8,028 MB/s | 100 % | 335 W | 2,880 MHz | 93,753 MiB |
| prefill-5 | 3 | x16 | 13,693 MB/s (43%) | 13,300 MB/s | 7,655 MB/s | 14,690 MB/s (47%) | 13,182 MB/s | 8,260 MB/s | 100 % | 317 W | 2,872 MHz | 93,753 MiB |

load1 max: 5.0   MemAvailable min: 300,227,800 kB
