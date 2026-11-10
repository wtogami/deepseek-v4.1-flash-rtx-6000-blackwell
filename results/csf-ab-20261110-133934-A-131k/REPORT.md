# csf-ab-20261110-133934-A-131k — results vs Karmic Kraken

Protocol: llm_decode_bench.py v0.6.2 (sha256-pinned, see bench/PROVENANCE.md), 5 warmed 30 s windows per cell, 15 s warmup, 32K unique prefill (client TTFT), context-zero decode C1/C8, server-side /metrics accounting.

## Headline

| Cell | Ours (median of 5) | KK (Max-Q/325W) | Delta |
|---|---:|---:|---:|
| 32K prefill tok/s | 10,775 | 17,982 | -40.08% |
| C1 output tok/s | 216.9 | 249.1 | -12.89% |
| C1 verifier steps/s | 92.67 | 98.58 | -6.00% |
| C1 accepted length | 2.318 | 2.571 | -9.84% |
| C8 output tok/s | 744.6 | 805.5 | -7.57% |
| C8 verifier steps/s | 345.14 | 361.87 | -4.62% |
| C8 accepted length | 2.131 | 2.295 | -7.16% |
| KV capacity tokens | 4,742,050 | 4,727,748 | +0.30% |

## Per-window samples

| file | prefill tok/s | samples |
|---|---:|---:|
| prefill-2.json | 10,779 | 10 |
| prefill-3.json | 10,781 | 10 |
| prefill-4.json | 10,755 | 10 |
| prefill-5.json | 10,775 | 10 |
| prefill.json | 10,769 | 10 |

| file | C1 output tok/s | verifier steps/s | accepted length | source |
|---|---:|---:|---:|---|
| decode-1.json | 211.8 | 92.33 | 2.294 | openai_continuous_usage |
| decode-2.json | 228.1 | 92.67 | 2.461 | openai_continuous_usage |
| decode-3.json | 213.2 | 93.50 | 2.280 | openai_continuous_usage |
| decode-4.json | 226.1 | 91.87 | 2.461 | openai_continuous_usage |
| decode-5.json | 216.9 | 93.59 | 2.318 | openai_continuous_usage |

| file | C8 output tok/s | verifier steps/s | accepted length | source |
|---|---:|---:|---:|---|
| decode-1.json | 732.2 | 343.60 | 2.131 | openai_continuous_usage |
| decode-2.json | 744.6 | 345.14 | 2.157 | openai_continuous_usage |
| decode-3.json | 745.7 | 350.30 | 2.129 | openai_continuous_usage |
| decode-4.json | 726.3 | 345.21 | 2.104 | openai_continuous_usage |
| decode-5.json | 766.0 | 340.85 | 2.247 | openai_continuous_usage |

## PCIe and system (monitor.tsv)

Gen4 ceilings per direction (detected live: GPU 0 x16, GPU 1 x16, GPU 2 x16, GPU 3 x16).

| scope | GPU | width | tx max | tx p95 | tx mean | rx max | rx p95 | rx mean | util max | pwr max | clk max | mem max |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| overall | 0 | x16 | 15,711 MB/s (50%) | 12,512 MB/s | 4,088 MB/s | 15,019 MB/s (48%) | 13,123 MB/s | 4,147 MB/s | 100 % | 310 W | 2,340 MHz | 93,793 MiB |
| overall | 1 | x16 | 14,735 MB/s (47%) | 13,023 MB/s | 4,185 MB/s | 15,655 MB/s (50%) | 12,443 MB/s | 4,150 MB/s | 100 % | 326 W | 2,340 MHz | 93,773 MiB |
| overall | 2 | x16 | 14,925 MB/s (47%) | 12,750 MB/s | 4,152 MB/s | 14,850 MB/s (47%) | 12,884 MB/s | 4,176 MB/s | 100 % | 337 W | 2,887 MHz | 93,773 MiB |
| overall | 3 | x16 | 14,736 MB/s (47%) | 12,518 MB/s | 4,139 MB/s | 15,605 MB/s (50%) | 12,873 MB/s | 4,151 MB/s | 100 % | 337 W | 2,880 MHz | 93,773 MiB |
| decode_active | 0 | x16 | 15,711 MB/s (50%) | 12,907 MB/s | 4,490 MB/s | 15,019 MB/s (48%) | 13,204 MB/s | 4,553 MB/s | 100 % | 310 W | 2,332 MHz | 93,793 MiB |
| decode_active | 1 | x16 | 14,735 MB/s (47%) | 13,218 MB/s | 4,596 MB/s | 15,655 MB/s (50%) | 12,516 MB/s | 4,558 MB/s | 100 % | 326 W | 2,332 MHz | 93,773 MiB |
| decode_active | 2 | x16 | 14,925 MB/s (47%) | 12,929 MB/s | 4,560 MB/s | 14,850 MB/s (47%) | 13,050 MB/s | 4,586 MB/s | 100 % | 337 W | 2,865 MHz | 93,773 MiB |
| decode_active | 3 | x16 | 14,736 MB/s (47%) | 12,520 MB/s | 4,547 MB/s | 15,605 MB/s (50%) | 12,923 MB/s | 4,560 MB/s | 100 % | 337 W | 2,872 MHz | 93,773 MiB |
| decode-1 | 0 | x16 | 5,787 MB/s (18%) | 5,545 MB/s | 2,796 MB/s | 5,785 MB/s (18%) | 5,632 MB/s | 2,881 MB/s | 100 % | 310 W | 2,340 MHz | 93,793 MiB |
| decode-1 | 1 | x16 | 5,606 MB/s (18%) | 5,480 MB/s | 2,946 MB/s | 5,804 MB/s (18%) | 5,412 MB/s | 2,856 MB/s | 100 % | 326 W | 2,340 MHz | 93,773 MiB |
| decode-1 | 2 | x16 | 5,691 MB/s (18%) | 5,526 MB/s | 2,837 MB/s | 5,794 MB/s (18%) | 5,508 MB/s | 2,931 MB/s | 100 % | 337 W | 2,872 MHz | 93,773 MiB |
| decode-1 | 3 | x16 | 5,914 MB/s (19%) | 5,538 MB/s | 2,933 MB/s | 5,735 MB/s (18%) | 5,544 MB/s | 2,894 MB/s | 100 % | 337 W | 2,872 MHz | 93,773 MiB |
| decode-2 | 0 | x16 | 5,912 MB/s (19%) | 5,751 MB/s | 2,984 MB/s | 5,899 MB/s (19%) | 5,590 MB/s | 2,871 MB/s | 100 % | 304 W | 2,340 MHz | 93,793 MiB |
| decode-2 | 1 | x16 | 6,008 MB/s (19%) | 5,561 MB/s | 2,907 MB/s | 5,971 MB/s (19%) | 5,664 MB/s | 2,995 MB/s | 100 % | 326 W | 2,340 MHz | 93,773 MiB |
| decode-2 | 2 | x16 | 6,009 MB/s (19%) | 5,689 MB/s | 2,988 MB/s | 5,786 MB/s (18%) | 5,617 MB/s | 2,966 MB/s | 100 % | 337 W | 2,865 MHz | 93,773 MiB |
| decode-2 | 3 | x16 | 5,690 MB/s (18%) | 5,514 MB/s | 2,818 MB/s | 5,821 MB/s (18%) | 5,588 MB/s | 2,933 MB/s | 100 % | 337 W | 2,857 MHz | 93,773 MiB |
| decode-3 | 0 | x16 | 5,770 MB/s (18%) | 5,646 MB/s | 2,999 MB/s | 5,847 MB/s (19%) | 5,693 MB/s | 3,050 MB/s | 100 % | 308 W | 2,340 MHz | 93,793 MiB |
| decode-3 | 1 | x16 | 5,658 MB/s (18%) | 5,530 MB/s | 3,022 MB/s | 5,759 MB/s (18%) | 5,572 MB/s | 2,992 MB/s | 100 % | 326 W | 2,340 MHz | 93,773 MiB |
| decode-3 | 2 | x16 | 5,646 MB/s (18%) | 5,529 MB/s | 3,013 MB/s | 5,617 MB/s (18%) | 5,551 MB/s | 3,012 MB/s | 100 % | 336 W | 2,865 MHz | 93,773 MiB |
| decode-3 | 3 | x16 | 5,748 MB/s (18%) | 5,573 MB/s | 2,992 MB/s | 5,661 MB/s (18%) | 5,618 MB/s | 3,084 MB/s | 100 % | 331 W | 2,857 MHz | 93,773 MiB |
| decode-4 | 0 | x16 | 5,964 MB/s (19%) | 5,557 MB/s | 2,913 MB/s | 5,817 MB/s (18%) | 5,537 MB/s | 2,936 MB/s | 100 % | 304 W | 2,340 MHz | 93,793 MiB |
| decode-4 | 1 | x16 | 5,999 MB/s (19%) | 5,532 MB/s | 2,949 MB/s | 6,014 MB/s (19%) | 5,583 MB/s | 2,925 MB/s | 100 % | 326 W | 2,340 MHz | 93,773 MiB |
| decode-4 | 2 | x16 | 5,646 MB/s (18%) | 5,534 MB/s | 2,899 MB/s | 5,686 MB/s (18%) | 5,604 MB/s | 2,989 MB/s | 100 % | 334 W | 2,865 MHz | 93,773 MiB |
| decode-4 | 3 | x16 | 5,925 MB/s (19%) | 5,637 MB/s | 3,064 MB/s | 5,705 MB/s (18%) | 5,577 MB/s | 2,993 MB/s | 100 % | 330 W | 2,865 MHz | 93,773 MiB |
| decode-5 | 0 | x16 | 5,690 MB/s (18%) | 5,654 MB/s | 2,864 MB/s | 5,829 MB/s (19%) | 5,629 MB/s | 2,912 MB/s | 100 % | 309 W | 2,340 MHz | 93,793 MiB |
| decode-5 | 1 | x16 | 5,737 MB/s (18%) | 5,576 MB/s | 2,943 MB/s | 5,838 MB/s (19%) | 5,661 MB/s | 2,988 MB/s | 100 % | 326 W | 2,340 MHz | 93,773 MiB |
| decode-5 | 2 | x16 | 6,076 MB/s (19%) | 5,529 MB/s | 2,919 MB/s | 5,794 MB/s (18%) | 5,558 MB/s | 2,892 MB/s | 100 % | 328 W | 2,865 MHz | 93,773 MiB |
| decode-5 | 3 | x16 | 6,069 MB/s (19%) | 5,654 MB/s | 2,917 MB/s | 6,102 MB/s (19%) | 5,577 MB/s | 2,867 MB/s | 100 % | 328 W | 2,857 MHz | 93,773 MiB |
| prefill | 0 | x16 | 14,733 MB/s (47%) | 14,164 MB/s | 7,546 MB/s | 15,019 MB/s (48%) | 13,501 MB/s | 8,030 MB/s | 100 % | 232 W | 2,332 MHz | 93,793 MiB |
| prefill | 1 | x16 | 14,343 MB/s (46%) | 14,016 MB/s | 7,739 MB/s | 13,827 MB/s (44%) | 13,624 MB/s | 7,206 MB/s | 100 % | 244 W | 2,340 MHz | 93,773 MiB |
| prefill | 2 | x16 | 14,168 MB/s (45%) | 13,658 MB/s | 6,837 MB/s | 13,818 MB/s (44%) | 13,721 MB/s | 6,761 MB/s | 100 % | 314 W | 2,887 MHz | 93,773 MiB |
| prefill | 3 | x16 | 14,736 MB/s (47%) | 14,602 MB/s | 6,990 MB/s | 14,238 MB/s (45%) | 13,287 MB/s | 6,642 MB/s | 100 % | 306 W | 2,880 MHz | 93,773 MiB |
| prefill-2 | 0 | x16 | 14,271 MB/s (45%) | 13,603 MB/s | 7,247 MB/s | 13,780 MB/s (44%) | 13,775 MB/s | 7,637 MB/s | 100 % | 238 W | 2,340 MHz | 93,793 MiB |
| prefill-2 | 1 | x16 | 14,735 MB/s (47%) | 13,992 MB/s | 6,827 MB/s | 13,817 MB/s (44%) | 13,299 MB/s | 7,087 MB/s | 100 % | 259 W | 2,340 MHz | 93,773 MiB |
| prefill-2 | 2 | x16 | 14,736 MB/s (47%) | 14,667 MB/s | 7,515 MB/s | 14,136 MB/s (45%) | 13,800 MB/s | 7,480 MB/s | 100 % | 317 W | 2,880 MHz | 93,773 MiB |
| prefill-2 | 3 | x16 | 14,090 MB/s (45%) | 12,905 MB/s | 7,114 MB/s | 13,792 MB/s (44%) | 13,364 MB/s | 6,925 MB/s | 100 % | 311 W | 2,872 MHz | 93,773 MiB |
| prefill-3 | 0 | x16 | 14,731 MB/s (47%) | 13,507 MB/s | 7,627 MB/s | 13,646 MB/s (43%) | 13,461 MB/s | 7,234 MB/s | 100 % | 243 W | 2,340 MHz | 93,793 MiB |
| prefill-3 | 1 | x16 | 13,659 MB/s (43%) | 13,656 MB/s | 7,992 MB/s | 15,655 MB/s (50%) | 14,709 MB/s | 8,402 MB/s | 100 % | 257 W | 2,340 MHz | 93,773 MiB |
| prefill-3 | 2 | x16 | 14,169 MB/s (45%) | 13,627 MB/s | 6,371 MB/s | 14,850 MB/s (47%) | 13,646 MB/s | 6,768 MB/s | 100 % | 312 W | 2,880 MHz | 93,773 MiB |
| prefill-3 | 3 | x16 | 14,736 MB/s (47%) | 13,311 MB/s | 6,805 MB/s | 15,605 MB/s (50%) | 13,704 MB/s | 7,520 MB/s | 100 % | 305 W | 2,872 MHz | 93,773 MiB |
| prefill-4 | 0 | x16 | 14,225 MB/s (45%) | 13,623 MB/s | 6,338 MB/s | 14,260 MB/s (45%) | 13,602 MB/s | 6,446 MB/s | 100 % | 239 W | 2,340 MHz | 93,793 MiB |
| prefill-4 | 1 | x16 | 13,660 MB/s (43%) | 13,387 MB/s | 7,191 MB/s | 13,813 MB/s (44%) | 13,676 MB/s | 7,098 MB/s | 100 % | 261 W | 2,340 MHz | 93,773 MiB |
| prefill-4 | 2 | x16 | 13,853 MB/s (44%) | 13,561 MB/s | 6,944 MB/s | 14,796 MB/s (47%) | 14,016 MB/s | 7,541 MB/s | 100 % | 311 W | 2,880 MHz | 93,773 MiB |
| prefill-4 | 3 | x16 | 14,166 MB/s (45%) | 13,656 MB/s | 7,103 MB/s | 13,912 MB/s (44%) | 13,529 MB/s | 6,939 MB/s | 100 % | 306 W | 2,872 MHz | 93,773 MiB |
| prefill-5 | 0 | x16 | 15,711 MB/s (50%) | 14,355 MB/s | 7,412 MB/s | 14,818 MB/s (47%) | 14,211 MB/s | 7,661 MB/s | 100 % | 249 W | 2,340 MHz | 93,793 MiB |
| prefill-5 | 1 | x16 | 14,463 MB/s (46%) | 13,922 MB/s | 7,611 MB/s | 13,817 MB/s (44%) | 13,440 MB/s | 6,941 MB/s | 100 % | 264 W | 2,340 MHz | 93,773 MiB |
| prefill-5 | 2 | x16 | 14,925 MB/s (47%) | 14,525 MB/s | 9,453 MB/s | 13,969 MB/s (44%) | 13,802 MB/s | 8,612 MB/s | 100 % | 314 W | 2,872 MHz | 93,773 MiB |
| prefill-5 | 3 | x16 | 14,164 MB/s (45%) | 13,362 MB/s | 8,678 MB/s | 13,783 MB/s (44%) | 13,289 MB/s | 8,756 MB/s | 100 % | 314 W | 2,857 MHz | 93,773 MiB |

load1 max: 5.4   MemAvailable min: 298,221,484 kB
