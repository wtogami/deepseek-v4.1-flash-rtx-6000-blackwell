# csf-ab-20261110-133934-A-1m — results vs Karmic Kraken

Protocol: llm_decode_bench.py v0.6.2 (sha256-pinned, see bench/PROVENANCE.md), 5 warmed 30 s windows per cell, 15 s warmup, 32K unique prefill (client TTFT), context-zero decode C1/C8, server-side /metrics accounting.

## Headline

| Cell | Ours (median of 5) | KK (Max-Q/325W) | Delta |
|---|---:|---:|---:|
| 32K prefill tok/s | 10,684 | 17,982 | -40.59% |
| C1 output tok/s | 230.5 | 249.1 | -7.44% |
| C1 verifier steps/s | 92.22 | 98.58 | -6.45% |
| C1 accepted length | 2.497 | 2.571 | -2.89% |
| C8 output tok/s | 733.7 | 805.5 | -8.91% |
| C8 verifier steps/s | 349.11 | 361.87 | -3.53% |
| C8 accepted length | 2.105 | 2.295 | -8.30% |
| KV capacity tokens | 9,718,137 | 4,727,748 | +105.56% |

## Per-window samples

| file | prefill tok/s | samples |
|---|---:|---:|
| prefill-2.json | 10,725 | 9 |
| prefill-3.json | 10,696 | 9 |
| prefill-4.json | 10,666 | 9 |
| prefill-5.json | 10,684 | 9 |
| prefill.json | 10,675 | 9 |

| file | C1 output tok/s | verifier steps/s | accepted length | source |
|---|---:|---:|---:|---|
| decode-1.json | 234.8 | 92.22 | 2.546 | openai_continuous_usage |
| decode-2.json | 230.5 | 92.32 | 2.497 | openai_continuous_usage |
| decode-3.json | 225.6 | 90.94 | 2.481 | openai_continuous_usage |
| decode-4.json | 235.0 | 91.48 | 2.569 | openai_continuous_usage |
| decode-5.json | 213.1 | 92.63 | 2.301 | openai_continuous_usage |

| file | C8 output tok/s | verifier steps/s | accepted length | source |
|---|---:|---:|---:|---|
| decode-1.json | 749.8 | 346.09 | 2.166 | openai_continuous_usage |
| decode-2.json | 733.7 | 353.03 | 2.078 | openai_continuous_usage |
| decode-3.json | 738.0 | 349.11 | 2.114 | openai_continuous_usage |
| decode-4.json | 733.3 | 349.87 | 2.096 | openai_continuous_usage |
| decode-5.json | 724.0 | 343.99 | 2.105 | openai_continuous_usage |

## PCIe and system (monitor.tsv)

Gen4 ceilings per direction (detected live: GPU 0 x16, GPU 1 x16, GPU 2 x16, GPU 3 x16).

| scope | GPU | width | tx max | tx p95 | tx mean | rx max | rx p95 | rx mean | util max | pwr max | clk max | mem max |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| overall | 0 | x16 | 14,061 MB/s (45%) | 12,411 MB/s | 3,916 MB/s | 15,654 MB/s (50%) | 12,593 MB/s | 4,010 MB/s | 100 % | 310 W | 2,340 MHz | 93,689 MiB |
| overall | 1 | x16 | 14,736 MB/s (47%) | 12,987 MB/s | 4,026 MB/s | 15,112 MB/s (48%) | 12,890 MB/s | 4,019 MB/s | 100 % | 326 W | 2,347 MHz | 93,689 MiB |
| overall | 2 | x16 | 14,739 MB/s (47%) | 12,590 MB/s | 4,035 MB/s | 15,715 MB/s (50%) | 12,822 MB/s | 4,084 MB/s | 100 % | 340 W | 2,880 MHz | 93,669 MiB |
| overall | 3 | x16 | 14,737 MB/s (47%) | 12,252 MB/s | 3,960 MB/s | 14,841 MB/s (47%) | 12,570 MB/s | 4,073 MB/s | 100 % | 330 W | 2,880 MHz | 93,567 MiB |
| decode_active | 0 | x16 | 14,061 MB/s (45%) | 12,616 MB/s | 4,404 MB/s | 15,654 MB/s (50%) | 12,651 MB/s | 4,511 MB/s | 100 % | 310 W | 2,310 MHz | 93,689 MiB |
| decode_active | 1 | x16 | 14,736 MB/s (47%) | 13,112 MB/s | 4,530 MB/s | 15,112 MB/s (48%) | 13,085 MB/s | 4,522 MB/s | 100 % | 326 W | 2,317 MHz | 93,689 MiB |
| decode_active | 2 | x16 | 14,739 MB/s (47%) | 12,711 MB/s | 4,540 MB/s | 15,715 MB/s (50%) | 12,998 MB/s | 4,596 MB/s | 100 % | 340 W | 2,872 MHz | 93,669 MiB |
| decode_active | 3 | x16 | 14,737 MB/s (47%) | 12,374 MB/s | 4,456 MB/s | 14,841 MB/s (47%) | 12,671 MB/s | 4,583 MB/s | 100 % | 330 W | 2,880 MHz | 93,567 MiB |
| decode-1 | 0 | x16 | 5,850 MB/s (19%) | 5,545 MB/s | 2,725 MB/s | 5,653 MB/s (18%) | 5,529 MB/s | 2,912 MB/s | 100 % | 310 W | 2,340 MHz | 93,685 MiB |
| decode-1 | 1 | x16 | 6,148 MB/s (20%) | 5,618 MB/s | 2,949 MB/s | 5,815 MB/s (18%) | 5,534 MB/s | 2,829 MB/s | 100 % | 326 W | 2,340 MHz | 93,687 MiB |
| decode-1 | 2 | x16 | 5,604 MB/s (18%) | 5,569 MB/s | 2,877 MB/s | 5,946 MB/s (19%) | 5,584 MB/s | 2,952 MB/s | 100 % | 329 W | 2,865 MHz | 93,665 MiB |
| decode-1 | 3 | x16 | 5,657 MB/s (18%) | 5,524 MB/s | 2,854 MB/s | 5,713 MB/s (18%) | 5,588 MB/s | 2,839 MB/s | 100 % | 328 W | 2,865 MHz | 93,565 MiB |
| decode-2 | 0 | x16 | 5,692 MB/s (18%) | 5,578 MB/s | 3,011 MB/s | 5,628 MB/s (18%) | 5,573 MB/s | 2,997 MB/s | 100 % | 305 W | 2,340 MHz | 93,687 MiB |
| decode-2 | 1 | x16 | 5,646 MB/s (18%) | 5,582 MB/s | 3,003 MB/s | 5,805 MB/s (18%) | 5,661 MB/s | 2,991 MB/s | 100 % | 326 W | 2,340 MHz | 93,687 MiB |
| decode-2 | 2 | x16 | 5,690 MB/s (18%) | 5,513 MB/s | 2,947 MB/s | 5,706 MB/s (18%) | 5,618 MB/s | 3,020 MB/s | 100 % | 340 W | 2,865 MHz | 93,667 MiB |
| decode-2 | 3 | x16 | 5,728 MB/s (18%) | 5,551 MB/s | 2,952 MB/s | 5,838 MB/s (19%) | 5,512 MB/s | 3,062 MB/s | 100 % | 330 W | 2,865 MHz | 93,565 MiB |
| decode-3 | 0 | x16 | 5,833 MB/s (19%) | 5,531 MB/s | 2,984 MB/s | 5,805 MB/s (18%) | 5,587 MB/s | 2,996 MB/s | 100 % | 310 W | 2,340 MHz | 93,689 MiB |
| decode-3 | 1 | x16 | 5,817 MB/s (18%) | 5,614 MB/s | 3,012 MB/s | 5,866 MB/s (19%) | 5,516 MB/s | 2,995 MB/s | 100 % | 326 W | 2,340 MHz | 93,689 MiB |
| decode-3 | 2 | x16 | 5,789 MB/s (18%) | 5,603 MB/s | 3,043 MB/s | 5,794 MB/s (18%) | 5,630 MB/s | 3,046 MB/s | 100 % | 337 W | 2,865 MHz | 93,669 MiB |
| decode-3 | 3 | x16 | 5,775 MB/s (18%) | 5,584 MB/s | 2,972 MB/s | 5,843 MB/s (19%) | 5,602 MB/s | 3,032 MB/s | 100 % | 330 W | 2,865 MHz | 93,567 MiB |
| decode-4 | 0 | x16 | 5,692 MB/s (18%) | 5,564 MB/s | 2,960 MB/s | 5,750 MB/s (18%) | 5,594 MB/s | 3,019 MB/s | 100 % | 305 W | 2,340 MHz | 93,689 MiB |
| decode-4 | 1 | x16 | 5,824 MB/s (18%) | 5,570 MB/s | 2,887 MB/s | 5,794 MB/s (18%) | 5,585 MB/s | 2,967 MB/s | 100 % | 326 W | 2,340 MHz | 93,689 MiB |
| decode-4 | 2 | x16 | 5,734 MB/s (18%) | 5,586 MB/s | 2,966 MB/s | 5,838 MB/s (19%) | 5,544 MB/s | 2,842 MB/s | 100 % | 337 W | 2,865 MHz | 93,669 MiB |
| decode-4 | 3 | x16 | 6,936 MB/s (22%) | 5,707 MB/s | 2,990 MB/s | 5,750 MB/s (18%) | 5,617 MB/s | 2,901 MB/s | 100 % | 329 W | 2,865 MHz | 93,567 MiB |
| decode-5 | 0 | x16 | 5,648 MB/s (18%) | 5,568 MB/s | 2,980 MB/s | 5,793 MB/s (18%) | 5,533 MB/s | 2,947 MB/s | 100 % | 309 W | 2,340 MHz | 93,689 MiB |
| decode-5 | 1 | x16 | 5,739 MB/s (18%) | 5,599 MB/s | 3,015 MB/s | 5,793 MB/s (18%) | 5,617 MB/s | 3,049 MB/s | 100 % | 326 W | 2,340 MHz | 93,689 MiB |
| decode-5 | 2 | x16 | 5,678 MB/s (18%) | 5,523 MB/s | 2,885 MB/s | 5,663 MB/s (18%) | 5,587 MB/s | 2,960 MB/s | 100 % | 331 W | 2,865 MHz | 93,669 MiB |
| decode-5 | 3 | x16 | 5,743 MB/s (18%) | 5,590 MB/s | 2,980 MB/s | 5,917 MB/s (19%) | 5,612 MB/s | 3,008 MB/s | 100 % | 329 W | 2,865 MHz | 93,567 MiB |
| prefill | 0 | x16 | 14,010 MB/s (44%) | 13,688 MB/s | 6,328 MB/s | 14,806 MB/s (47%) | 13,763 MB/s | 6,804 MB/s | 100 % | 240 W | 2,340 MHz | 93,665 MiB |
| prefill | 1 | x16 | 14,667 MB/s (47%) | 13,659 MB/s | 6,088 MB/s | 15,112 MB/s (48%) | 14,437 MB/s | 6,419 MB/s | 100 % | 256 W | 2,340 MHz | 93,665 MiB |
| prefill | 2 | x16 | 13,656 MB/s (43%) | 13,585 MB/s | 7,355 MB/s | 14,851 MB/s (47%) | 14,169 MB/s | 7,151 MB/s | 100 % | 319 W | 2,880 MHz | 93,665 MiB |
| prefill | 3 | x16 | 13,658 MB/s (43%) | 12,616 MB/s | 6,660 MB/s | 13,781 MB/s (44%) | 13,353 MB/s | 7,577 MB/s | 100 % | 304 W | 2,880 MHz | 93,565 MiB |
| prefill-2 | 0 | x16 | 14,000 MB/s (44%) | 13,792 MB/s | 6,764 MB/s | 13,765 MB/s (44%) | 13,291 MB/s | 6,843 MB/s | 100 % | 243 W | 2,340 MHz | 93,665 MiB |
| prefill-2 | 1 | x16 | 14,736 MB/s (47%) | 14,095 MB/s | 7,648 MB/s | 14,169 MB/s (45%) | 13,812 MB/s | 7,736 MB/s | 100 % | 260 W | 2,347 MHz | 93,665 MiB |
| prefill-2 | 2 | x16 | 13,225 MB/s (42%) | 13,125 MB/s | 7,771 MB/s | 14,841 MB/s (47%) | 14,568 MB/s | 7,764 MB/s | 100 % | 319 W | 2,880 MHz | 93,665 MiB |
| prefill-2 | 3 | x16 | 13,014 MB/s (41%) | 12,744 MB/s | 6,754 MB/s | 13,739 MB/s (44%) | 13,210 MB/s | 7,672 MB/s | 100 % | 306 W | 2,872 MHz | 93,565 MiB |
| prefill-3 | 0 | x16 | 13,655 MB/s (43%) | 13,653 MB/s | 6,349 MB/s | 15,654 MB/s (50%) | 13,857 MB/s | 6,503 MB/s | 100 % | 244 W | 2,340 MHz | 93,685 MiB |
| prefill-3 | 1 | x16 | 14,736 MB/s (47%) | 14,303 MB/s | 6,260 MB/s | 13,817 MB/s (44%) | 13,806 MB/s | 6,188 MB/s | 100 % | 260 W | 2,347 MHz | 93,685 MiB |
| prefill-3 | 2 | x16 | 14,735 MB/s (47%) | 14,072 MB/s | 6,760 MB/s | 14,330 MB/s (45%) | 13,587 MB/s | 6,708 MB/s | 100 % | 326 W | 2,880 MHz | 93,665 MiB |
| prefill-3 | 3 | x16 | 14,138 MB/s (45%) | 12,972 MB/s | 6,943 MB/s | 14,841 MB/s (47%) | 13,848 MB/s | 7,037 MB/s | 100 % | 308 W | 2,872 MHz | 93,565 MiB |
| prefill-4 | 0 | x16 | 14,061 MB/s (45%) | 13,266 MB/s | 5,460 MB/s | 14,117 MB/s (45%) | 13,015 MB/s | 5,845 MB/s | 100 % | 244 W | 2,340 MHz | 93,685 MiB |
| prefill-4 | 1 | x16 | 14,554 MB/s (46%) | 13,747 MB/s | 6,944 MB/s | 13,812 MB/s (44%) | 13,486 MB/s | 6,105 MB/s | 100 % | 257 W | 2,347 MHz | 93,685 MiB |
| prefill-4 | 2 | x16 | 13,090 MB/s (42%) | 12,565 MB/s | 6,462 MB/s | 14,200 MB/s (45%) | 13,802 MB/s | 6,264 MB/s | 100 % | 323 W | 2,880 MHz | 93,665 MiB |
| prefill-4 | 3 | x16 | 14,732 MB/s (47%) | 13,176 MB/s | 6,650 MB/s | 14,489 MB/s (46%) | 13,852 MB/s | 6,880 MB/s | 100 % | 305 W | 2,872 MHz | 93,565 MiB |
| prefill-5 | 0 | x16 | 13,654 MB/s (43%) | 13,122 MB/s | 7,305 MB/s | 13,677 MB/s (43%) | 13,357 MB/s | 7,359 MB/s | 100 % | 246 W | 2,340 MHz | 93,685 MiB |
| prefill-5 | 1 | x16 | 14,736 MB/s (47%) | 13,597 MB/s | 6,777 MB/s | 14,773 MB/s (47%) | 13,444 MB/s | 7,198 MB/s | 100 % | 261 W | 2,347 MHz | 93,685 MiB |
| prefill-5 | 2 | x16 | 14,739 MB/s (47%) | 13,390 MB/s | 5,919 MB/s | 15,715 MB/s (50%) | 14,371 MB/s | 6,966 MB/s | 100 % | 323 W | 2,880 MHz | 93,665 MiB |
| prefill-5 | 3 | x16 | 14,737 MB/s (47%) | 13,707 MB/s | 5,841 MB/s | 14,141 MB/s (45%) | 13,659 MB/s | 5,489 MB/s | 100 % | 309 W | 2,872 MHz | 93,565 MiB |

load1 max: 4.9   MemAvailable min: 299,305,252 kB
