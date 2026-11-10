# csf-ab-20261110-133934-B-1m — results vs Karmic Kraken

Protocol: llm_decode_bench.py v0.6.2 (sha256-pinned, see bench/PROVENANCE.md), 5 warmed 30 s windows per cell, 15 s warmup, 32K unique prefill (client TTFT), context-zero decode C1/C8, server-side /metrics accounting.

## Headline

| Cell | Ours (median of 5) | KK (Max-Q/325W) | Delta |
|---|---:|---:|---:|
| 32K prefill tok/s | 10,571 | 17,982 | -41.21% |
| C1 output tok/s | 221.0 | 249.1 | -11.28% |
| C1 verifier steps/s | 90.58 | 98.58 | -8.11% |
| C1 accepted length | 2.428 | 2.571 | -5.59% |
| C8 output tok/s | 746.1 | 805.5 | -7.38% |
| C8 verifier steps/s | 352.69 | 361.87 | -2.54% |
| C8 accepted length | 2.114 | 2.295 | -7.89% |
| KV capacity tokens | 12,949,820 | 4,727,748 | +173.91% |

## Per-window samples

| file | prefill tok/s | samples |
|---|---:|---:|
| prefill-2.json | 10,555 | 9 |
| prefill-3.json | 10,572 | 9 |
| prefill-4.json | 10,571 | 9 |
| prefill-5.json | 10,551 | 9 |
| prefill.json | 10,595 | 9 |

| file | C1 output tok/s | verifier steps/s | accepted length | source |
|---|---:|---:|---:|---|
| decode-1.json | 206.9 | 91.85 | 2.253 | openai_continuous_usage |
| decode-2.json | 223.7 | 90.12 | 2.483 | openai_continuous_usage |
| decode-3.json | 219.0 | 90.48 | 2.420 | openai_continuous_usage |
| decode-4.json | 227.8 | 90.58 | 2.515 | openai_continuous_usage |
| decode-5.json | 221.0 | 91.03 | 2.428 | openai_continuous_usage |

| file | C8 output tok/s | verifier steps/s | accepted length | source |
|---|---:|---:|---:|---|
| decode-1.json | 764.0 | 348.99 | 2.189 | openai_continuous_usage |
| decode-2.json | 746.7 | 356.17 | 2.096 | openai_continuous_usage |
| decode-3.json | 746.1 | 348.14 | 2.143 | openai_continuous_usage |
| decode-4.json | 745.7 | 352.69 | 2.114 | openai_continuous_usage |
| decode-5.json | 742.8 | 355.63 | 2.089 | openai_continuous_usage |

## PCIe and system (monitor.tsv)

Gen4 ceilings per direction (detected live: GPU 0 x16, GPU 1 x16, GPU 2 x16, GPU 3 x16).

| scope | GPU | width | tx max | tx p95 | tx mean | rx max | rx p95 | rx mean | util max | pwr max | clk max | mem max |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| overall | 0 | x16 | 14,736 MB/s (47%) | 12,696 MB/s | 3,980 MB/s | 14,827 MB/s (47%) | 12,594 MB/s | 3,974 MB/s | 100 % | 315 W | 2,340 MHz | 93,745 MiB |
| overall | 1 | x16 | 14,734 MB/s (47%) | 12,313 MB/s | 3,901 MB/s | 14,818 MB/s (47%) | 12,230 MB/s | 3,936 MB/s | 100 % | 326 W | 2,347 MHz | 93,725 MiB |
| overall | 2 | x16 | 14,166 MB/s (45%) | 12,444 MB/s | 4,041 MB/s | 14,839 MB/s (47%) | 12,378 MB/s | 3,998 MB/s | 100 % | 338 W | 2,887 MHz | 93,825 MiB |
| overall | 3 | x16 | 14,735 MB/s (47%) | 12,085 MB/s | 3,857 MB/s | 14,634 MB/s (46%) | 12,608 MB/s | 3,972 MB/s | 100 % | 339 W | 2,880 MHz | 93,823 MiB |
| decode_active | 0 | x16 | 14,736 MB/s (47%) | 12,933 MB/s | 4,475 MB/s | 14,827 MB/s (47%) | 12,628 MB/s | 4,454 MB/s | 100 % | 315 W | 2,340 MHz | 93,745 MiB |
| decode_active | 1 | x16 | 14,734 MB/s (47%) | 12,547 MB/s | 4,389 MB/s | 14,818 MB/s (47%) | 12,563 MB/s | 4,433 MB/s | 100 % | 326 W | 2,347 MHz | 93,725 MiB |
| decode_active | 2 | x16 | 14,166 MB/s (45%) | 12,538 MB/s | 4,561 MB/s | 14,839 MB/s (47%) | 12,651 MB/s | 4,502 MB/s | 100 % | 338 W | 2,887 MHz | 93,825 MiB |
| decode_active | 3 | x16 | 14,735 MB/s (47%) | 12,479 MB/s | 4,356 MB/s | 14,634 MB/s (46%) | 12,736 MB/s | 4,485 MB/s | 100 % | 339 W | 2,872 MHz | 93,823 MiB |
| decode-1 | 0 | x16 | 5,823 MB/s (18%) | 5,607 MB/s | 2,933 MB/s | 6,131 MB/s (19%) | 5,697 MB/s | 3,015 MB/s | 100 % | 315 W | 2,340 MHz | 93,743 MiB |
| decode-1 | 1 | x16 | 5,835 MB/s (19%) | 5,756 MB/s | 2,971 MB/s | 5,925 MB/s (19%) | 5,683 MB/s | 2,949 MB/s | 100 % | 326 W | 2,340 MHz | 93,725 MiB |
| decode-1 | 2 | x16 | 6,071 MB/s (19%) | 5,772 MB/s | 2,996 MB/s | 5,802 MB/s (18%) | 5,661 MB/s | 3,023 MB/s | 100 % | 332 W | 2,880 MHz | 93,825 MiB |
| decode-1 | 3 | x16 | 5,733 MB/s (18%) | 5,647 MB/s | 2,924 MB/s | 5,858 MB/s (19%) | 5,749 MB/s | 3,009 MB/s | 100 % | 327 W | 2,865 MHz | 93,823 MiB |
| decode-2 | 0 | x16 | 5,752 MB/s (18%) | 5,656 MB/s | 3,121 MB/s | 5,938 MB/s (19%) | 5,671 MB/s | 3,164 MB/s | 100 % | 311 W | 2,340 MHz | 93,743 MiB |
| decode-2 | 1 | x16 | 5,910 MB/s (19%) | 5,702 MB/s | 3,118 MB/s | 5,882 MB/s (19%) | 5,641 MB/s | 3,083 MB/s | 100 % | 326 W | 2,340 MHz | 93,725 MiB |
| decode-2 | 2 | x16 | 5,867 MB/s (19%) | 5,662 MB/s | 3,118 MB/s | 5,838 MB/s (19%) | 5,665 MB/s | 3,137 MB/s | 100 % | 331 W | 2,865 MHz | 93,825 MiB |
| decode-2 | 3 | x16 | 5,867 MB/s (19%) | 5,648 MB/s | 3,182 MB/s | 5,926 MB/s (19%) | 5,770 MB/s | 3,184 MB/s | 100 % | 330 W | 2,865 MHz | 93,823 MiB |
| decode-3 | 0 | x16 | 5,738 MB/s (18%) | 5,579 MB/s | 2,910 MB/s | 5,793 MB/s (18%) | 5,592 MB/s | 2,880 MB/s | 100 % | 314 W | 2,340 MHz | 93,743 MiB |
| decode-3 | 1 | x16 | 5,911 MB/s (19%) | 5,575 MB/s | 2,930 MB/s | 5,710 MB/s (18%) | 5,636 MB/s | 2,879 MB/s | 100 % | 326 W | 2,340 MHz | 93,725 MiB |
| decode-3 | 2 | x16 | 5,829 MB/s (19%) | 5,692 MB/s | 2,840 MB/s | 5,926 MB/s (19%) | 5,657 MB/s | 2,955 MB/s | 100 % | 338 W | 2,865 MHz | 93,825 MiB |
| decode-3 | 3 | x16 | 5,993 MB/s (19%) | 5,660 MB/s | 2,881 MB/s | 5,881 MB/s (19%) | 5,624 MB/s | 2,912 MB/s | 100 % | 338 W | 2,857 MHz | 93,823 MiB |
| decode-4 | 0 | x16 | 5,735 MB/s (18%) | 5,616 MB/s | 3,038 MB/s | 5,705 MB/s (18%) | 5,596 MB/s | 3,039 MB/s | 100 % | 310 W | 2,340 MHz | 93,745 MiB |
| decode-4 | 1 | x16 | 5,747 MB/s (18%) | 5,646 MB/s | 3,044 MB/s | 5,838 MB/s (19%) | 5,639 MB/s | 2,999 MB/s | 100 % | 326 W | 2,340 MHz | 93,725 MiB |
| decode-4 | 2 | x16 | 5,825 MB/s (18%) | 5,657 MB/s | 3,061 MB/s | 5,793 MB/s (18%) | 5,659 MB/s | 3,054 MB/s | 100 % | 336 W | 2,865 MHz | 93,825 MiB |
| decode-4 | 3 | x16 | 5,959 MB/s (19%) | 5,650 MB/s | 3,040 MB/s | 5,749 MB/s (18%) | 5,661 MB/s | 3,104 MB/s | 100 % | 339 W | 2,857 MHz | 93,823 MiB |
| decode-5 | 0 | x16 | 6,132 MB/s (19%) | 5,691 MB/s | 3,018 MB/s | 6,190 MB/s (20%) | 5,710 MB/s | 3,065 MB/s | 100 % | 314 W | 2,340 MHz | 93,745 MiB |
| decode-5 | 1 | x16 | 6,042 MB/s (19%) | 5,705 MB/s | 3,018 MB/s | 6,014 MB/s (19%) | 5,723 MB/s | 3,078 MB/s | 100 % | 326 W | 2,340 MHz | 93,725 MiB |
| decode-5 | 2 | x16 | 6,032 MB/s (19%) | 5,644 MB/s | 2,952 MB/s | 6,433 MB/s (20%) | 5,735 MB/s | 3,035 MB/s | 100 % | 331 W | 2,865 MHz | 93,825 MiB |
| decode-5 | 3 | x16 | 5,837 MB/s (19%) | 5,694 MB/s | 2,962 MB/s | 5,882 MB/s (19%) | 5,640 MB/s | 3,044 MB/s | 100 % | 328 W | 2,865 MHz | 93,823 MiB |
| prefill | 0 | x16 | 14,736 MB/s (47%) | 12,826 MB/s | 5,508 MB/s | 14,827 MB/s (47%) | 14,358 MB/s | 5,440 MB/s | 100 % | 238 W | 2,340 MHz | 93,743 MiB |
| prefill | 1 | x16 | 13,658 MB/s (43%) | 13,584 MB/s | 6,772 MB/s | 14,818 MB/s (47%) | 14,675 MB/s | 6,725 MB/s | 100 % | 246 W | 2,347 MHz | 93,725 MiB |
| prefill | 2 | x16 | 13,674 MB/s (43%) | 13,597 MB/s | 7,495 MB/s | 14,839 MB/s (47%) | 13,544 MB/s | 7,249 MB/s | 100 % | 317 W | 2,887 MHz | 93,823 MiB |
| prefill | 3 | x16 | 14,735 MB/s (47%) | 13,658 MB/s | 6,614 MB/s | 14,104 MB/s (45%) | 13,360 MB/s | 7,070 MB/s | 100 % | 305 W | 2,880 MHz | 93,803 MiB |
| prefill-2 | 0 | x16 | 13,655 MB/s (43%) | 13,504 MB/s | 7,065 MB/s | 13,774 MB/s (44%) | 13,573 MB/s | 7,129 MB/s | 100 % | 239 W | 2,340 MHz | 93,743 MiB |
| prefill-2 | 1 | x16 | 14,731 MB/s (47%) | 14,113 MB/s | 6,285 MB/s | 13,654 MB/s (43%) | 12,947 MB/s | 6,246 MB/s | 100 % | 252 W | 2,347 MHz | 93,725 MiB |
| prefill-2 | 2 | x16 | 14,166 MB/s (45%) | 13,069 MB/s | 6,306 MB/s | 13,820 MB/s (44%) | 13,800 MB/s | 5,989 MB/s | 100 % | 317 W | 2,880 MHz | 93,823 MiB |
| prefill-2 | 3 | x16 | 13,657 MB/s (43%) | 13,246 MB/s | 5,088 MB/s | 13,687 MB/s (43%) | 13,361 MB/s | 5,511 MB/s | 100 % | 307 W | 2,872 MHz | 93,823 MiB |
| prefill-3 | 0 | x16 | 13,794 MB/s (44%) | 13,656 MB/s | 6,632 MB/s | 14,672 MB/s (47%) | 13,430 MB/s | 6,867 MB/s | 100 % | 247 W | 2,340 MHz | 93,743 MiB |
| prefill-3 | 1 | x16 | 13,660 MB/s (43%) | 13,658 MB/s | 6,544 MB/s | 13,785 MB/s (44%) | 13,646 MB/s | 6,321 MB/s | 100 % | 253 W | 2,340 MHz | 93,725 MiB |
| prefill-3 | 2 | x16 | 13,659 MB/s (43%) | 13,221 MB/s | 6,556 MB/s | 14,819 MB/s (47%) | 13,616 MB/s | 6,975 MB/s | 100 % | 318 W | 2,880 MHz | 93,823 MiB |
| prefill-3 | 3 | x16 | 13,414 MB/s (43%) | 13,039 MB/s | 7,020 MB/s | 13,804 MB/s (44%) | 13,200 MB/s | 6,394 MB/s | 100 % | 311 W | 2,872 MHz | 93,823 MiB |
| prefill-4 | 0 | x16 | 13,657 MB/s (43%) | 13,581 MB/s | 7,243 MB/s | 14,818 MB/s (47%) | 13,709 MB/s | 6,843 MB/s | 100 % | 245 W | 2,340 MHz | 93,743 MiB |
| prefill-4 | 1 | x16 | 14,734 MB/s (47%) | 12,854 MB/s | 5,966 MB/s | 13,808 MB/s (44%) | 13,414 MB/s | 6,571 MB/s | 100 % | 261 W | 2,347 MHz | 93,725 MiB |
| prefill-4 | 2 | x16 | 13,658 MB/s (43%) | 13,477 MB/s | 6,922 MB/s | 13,797 MB/s (44%) | 13,527 MB/s | 6,217 MB/s | 100 % | 327 W | 2,880 MHz | 93,823 MiB |
| prefill-4 | 3 | x16 | 13,658 MB/s (43%) | 13,106 MB/s | 6,335 MB/s | 13,436 MB/s (43%) | 13,116 MB/s | 6,282 MB/s | 100 % | 316 W | 2,872 MHz | 93,823 MiB |
| prefill-5 | 0 | x16 | 13,653 MB/s (43%) | 13,653 MB/s | 5,996 MB/s | 13,370 MB/s (42%) | 13,165 MB/s | 5,724 MB/s | 100 % | 241 W | 2,340 MHz | 93,743 MiB |
| prefill-5 | 1 | x16 | 13,925 MB/s (44%) | 12,535 MB/s | 5,366 MB/s | 13,911 MB/s (44%) | 13,669 MB/s | 5,904 MB/s | 100 % | 253 W | 2,347 MHz | 93,725 MiB |
| prefill-5 | 2 | x16 | 14,164 MB/s (45%) | 12,992 MB/s | 6,400 MB/s | 14,716 MB/s (47%) | 13,642 MB/s | 5,918 MB/s | 100 % | 321 W | 2,880 MHz | 93,823 MiB |
| prefill-5 | 3 | x16 | 13,656 MB/s (43%) | 12,235 MB/s | 5,337 MB/s | 14,634 MB/s (46%) | 13,724 MB/s | 6,478 MB/s | 100 % | 309 W | 2,872 MHz | 93,823 MiB |

load1 max: 5.0   MemAvailable min: 297,600,844 kB
