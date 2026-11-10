# csf-ab-20261110-133934-B-131k — results vs Karmic Kraken

Protocol: llm_decode_bench.py v0.6.2 (sha256-pinned, see bench/PROVENANCE.md), 5 warmed 30 s windows per cell, 15 s warmup, 32K unique prefill (client TTFT), context-zero decode C1/C8, server-side /metrics accounting.

## Headline

| Cell | Ours (median of 5) | KK (Max-Q/325W) | Delta |
|---|---:|---:|---:|
| 32K prefill tok/s | 10,605 | 17,982 | -41.02% |
| C1 output tok/s | 215.6 | 249.1 | -13.42% |
| C1 verifier steps/s | 90.74 | 98.58 | -7.95% |
| C1 accepted length | 2.379 | 2.571 | -7.47% |
| C8 output tok/s | 749.3 | 805.5 | -6.98% |
| C8 verifier steps/s | 351.76 | 361.87 | -2.79% |
| C8 accepted length | 2.127 | 2.295 | -7.33% |
| KV capacity tokens | 6,061,055 | 4,727,748 | +28.20% |

## Per-window samples

| file | prefill tok/s | samples |
|---|---:|---:|
| prefill-2.json | 10,603 | 9 |
| prefill-3.json | 10,606 | 9 |
| prefill-4.json | 10,617 | 9 |
| prefill-5.json | 10,604 | 9 |
| prefill.json | 10,605 | 9 |

| file | C1 output tok/s | verifier steps/s | accepted length | source |
|---|---:|---:|---:|---|
| decode-1.json | 224.4 | 90.74 | 2.473 | openai_continuous_usage |
| decode-2.json | 216.0 | 90.68 | 2.382 | openai_continuous_usage |
| decode-3.json | 212.5 | 89.34 | 2.379 | openai_continuous_usage |
| decode-4.json | 214.0 | 91.01 | 2.351 | openai_continuous_usage |
| decode-5.json | 215.6 | 91.15 | 2.366 | openai_continuous_usage |

| file | C8 output tok/s | verifier steps/s | accepted length | source |
|---|---:|---:|---:|---|
| decode-1.json | 763.3 | 351.76 | 2.170 | openai_continuous_usage |
| decode-2.json | 749.3 | 352.73 | 2.124 | openai_continuous_usage |
| decode-3.json | 742.3 | 349.78 | 2.122 | openai_continuous_usage |
| decode-4.json | 753.2 | 354.10 | 2.127 | openai_continuous_usage |
| decode-5.json | 740.0 | 346.84 | 2.134 | openai_continuous_usage |

## PCIe and system (monitor.tsv)

Gen4 ceilings per direction (detected live: GPU 0 x16, GPU 1 x16, GPU 2 x16, GPU 3 x16).

| scope | GPU | width | tx max | tx p95 | tx mean | rx max | rx p95 | rx mean | util max | pwr max | clk max | mem max |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| overall | 0 | x16 | 14,294 MB/s (45%) | 11,852 MB/s | 3,906 MB/s | 14,827 MB/s (47%) | 12,682 MB/s | 4,007 MB/s | 100 % | 314 W | 2,340 MHz | 93,789 MiB |
| overall | 1 | x16 | 14,736 MB/s (47%) | 12,622 MB/s | 3,932 MB/s | 14,925 MB/s (47%) | 12,936 MB/s | 3,992 MB/s | 100 % | 328 W | 2,347 MHz | 93,869 MiB |
| overall | 2 | x16 | 14,736 MB/s (47%) | 12,406 MB/s | 3,936 MB/s | 14,825 MB/s (47%) | 12,783 MB/s | 3,997 MB/s | 100 % | 340 W | 2,887 MHz | 93,869 MiB |
| overall | 3 | x16 | 14,736 MB/s (47%) | 12,320 MB/s | 4,019 MB/s | 14,517 MB/s (46%) | 12,868 MB/s | 3,989 MB/s | 100 % | 335 W | 2,880 MHz | 93,873 MiB |
| decode_active | 0 | x16 | 14,294 MB/s (45%) | 11,927 MB/s | 4,430 MB/s | 14,827 MB/s (47%) | 12,904 MB/s | 4,542 MB/s | 100 % | 314 W | 2,340 MHz | 93,789 MiB |
| decode_active | 1 | x16 | 14,736 MB/s (47%) | 12,844 MB/s | 4,466 MB/s | 14,925 MB/s (47%) | 13,204 MB/s | 4,530 MB/s | 100 % | 328 W | 2,347 MHz | 93,869 MiB |
| decode_active | 2 | x16 | 14,736 MB/s (47%) | 12,752 MB/s | 4,470 MB/s | 14,825 MB/s (47%) | 12,921 MB/s | 4,540 MB/s | 100 % | 340 W | 2,880 MHz | 93,869 MiB |
| decode_active | 3 | x16 | 14,736 MB/s (47%) | 12,504 MB/s | 4,565 MB/s | 14,517 MB/s (46%) | 13,020 MB/s | 4,533 MB/s | 100 % | 335 W | 2,872 MHz | 93,873 MiB |
| decode-1 | 0 | x16 | 5,908 MB/s (19%) | 5,703 MB/s | 2,949 MB/s | 5,964 MB/s (19%) | 5,687 MB/s | 3,010 MB/s | 100 % | 314 W | 2,340 MHz | 93,789 MiB |
| decode-1 | 1 | x16 | 5,778 MB/s (18%) | 5,733 MB/s | 2,965 MB/s | 5,794 MB/s (18%) | 5,727 MB/s | 2,942 MB/s | 100 % | 327 W | 2,340 MHz | 93,869 MiB |
| decode-1 | 2 | x16 | 5,853 MB/s (19%) | 5,684 MB/s | 2,912 MB/s | 5,948 MB/s (19%) | 5,749 MB/s | 2,990 MB/s | 100 % | 330 W | 2,872 MHz | 93,869 MiB |
| decode-1 | 3 | x16 | 6,042 MB/s (19%) | 5,703 MB/s | 2,943 MB/s | 6,219 MB/s (20%) | 5,663 MB/s | 2,929 MB/s | 100 % | 331 W | 2,865 MHz | 93,871 MiB |
| decode-2 | 0 | x16 | 5,889 MB/s (19%) | 5,706 MB/s | 3,042 MB/s | 5,970 MB/s (19%) | 5,710 MB/s | 2,976 MB/s | 100 % | 309 W | 2,340 MHz | 93,789 MiB |
| decode-2 | 1 | x16 | 5,998 MB/s (19%) | 5,683 MB/s | 3,047 MB/s | 5,866 MB/s (19%) | 5,770 MB/s | 3,044 MB/s | 100 % | 327 W | 2,340 MHz | 93,869 MiB |
| decode-2 | 2 | x16 | 5,868 MB/s (19%) | 5,749 MB/s | 3,010 MB/s | 5,926 MB/s (19%) | 5,708 MB/s | 3,046 MB/s | 100 % | 328 W | 2,865 MHz | 93,869 MiB |
| decode-2 | 3 | x16 | 5,875 MB/s (19%) | 5,710 MB/s | 2,983 MB/s | 5,882 MB/s (19%) | 5,676 MB/s | 3,015 MB/s | 100 % | 329 W | 2,865 MHz | 93,871 MiB |
| decode-3 | 0 | x16 | 5,899 MB/s (19%) | 5,671 MB/s | 3,005 MB/s | 6,091 MB/s (19%) | 5,674 MB/s | 2,981 MB/s | 100 % | 314 W | 2,340 MHz | 93,789 MiB |
| decode-3 | 1 | x16 | 5,894 MB/s (19%) | 5,618 MB/s | 2,887 MB/s | 5,794 MB/s (18%) | 5,674 MB/s | 2,959 MB/s | 100 % | 326 W | 2,340 MHz | 93,869 MiB |
| decode-3 | 2 | x16 | 6,042 MB/s (19%) | 5,707 MB/s | 2,951 MB/s | 5,886 MB/s (19%) | 5,697 MB/s | 3,022 MB/s | 100 % | 330 W | 2,865 MHz | 93,869 MiB |
| decode-3 | 3 | x16 | 5,954 MB/s (19%) | 5,664 MB/s | 3,033 MB/s | 5,970 MB/s (19%) | 5,666 MB/s | 2,951 MB/s | 100 % | 329 W | 2,857 MHz | 93,871 MiB |
| decode-4 | 0 | x16 | 5,866 MB/s (19%) | 5,778 MB/s | 3,019 MB/s | 5,970 MB/s (19%) | 5,780 MB/s | 3,022 MB/s | 100 % | 310 W | 2,340 MHz | 93,789 MiB |
| decode-4 | 1 | x16 | 5,835 MB/s (19%) | 5,670 MB/s | 3,009 MB/s | 5,926 MB/s (19%) | 5,747 MB/s | 3,068 MB/s | 100 % | 326 W | 2,340 MHz | 93,869 MiB |
| decode-4 | 2 | x16 | 5,910 MB/s (19%) | 5,709 MB/s | 3,059 MB/s | 5,926 MB/s (19%) | 5,760 MB/s | 3,011 MB/s | 100 % | 332 W | 2,865 MHz | 93,869 MiB |
| decode-4 | 3 | x16 | 6,242 MB/s (20%) | 5,637 MB/s | 3,014 MB/s | 5,874 MB/s (19%) | 5,766 MB/s | 2,953 MB/s | 100 % | 328 W | 2,857 MHz | 93,873 MiB |
| decode-5 | 0 | x16 | 5,835 MB/s (19%) | 5,663 MB/s | 3,008 MB/s | 6,802 MB/s (22%) | 5,705 MB/s | 2,999 MB/s | 100 % | 314 W | 2,340 MHz | 93,789 MiB |
| decode-5 | 1 | x16 | 6,308 MB/s (20%) | 5,690 MB/s | 3,023 MB/s | 5,830 MB/s (19%) | 5,621 MB/s | 3,018 MB/s | 100 % | 328 W | 2,340 MHz | 93,869 MiB |
| decode-5 | 2 | x16 | 5,701 MB/s (18%) | 5,581 MB/s | 2,996 MB/s | 5,883 MB/s (19%) | 5,639 MB/s | 3,005 MB/s | 100 % | 340 W | 2,865 MHz | 93,869 MiB |
| decode-5 | 3 | x16 | 6,064 MB/s (19%) | 5,647 MB/s | 3,079 MB/s | 5,704 MB/s (18%) | 5,607 MB/s | 2,995 MB/s | 100 % | 335 W | 2,865 MHz | 93,873 MiB |
| prefill | 0 | x16 | 13,654 MB/s (43%) | 13,318 MB/s | 6,178 MB/s | 13,775 MB/s (44%) | 13,625 MB/s | 6,225 MB/s | 100 % | 240 W | 2,340 MHz | 93,789 MiB |
| prefill | 1 | x16 | 14,736 MB/s (47%) | 13,641 MB/s | 6,336 MB/s | 14,081 MB/s (45%) | 13,804 MB/s | 6,833 MB/s | 100 % | 251 W | 2,347 MHz | 93,869 MiB |
| prefill | 2 | x16 | 14,166 MB/s (45%) | 13,635 MB/s | 6,550 MB/s | 14,526 MB/s (46%) | 13,812 MB/s | 6,573 MB/s | 100 % | 313 W | 2,887 MHz | 93,849 MiB |
| prefill | 3 | x16 | 13,657 MB/s (43%) | 13,646 MB/s | 6,893 MB/s | 14,495 MB/s (46%) | 14,037 MB/s | 7,590 MB/s | 100 % | 304 W | 2,880 MHz | 93,871 MiB |
| prefill-2 | 0 | x16 | 13,115 MB/s (42%) | 13,020 MB/s | 6,188 MB/s | 13,779 MB/s (44%) | 13,568 MB/s | 6,904 MB/s | 100 % | 233 W | 2,340 MHz | 93,789 MiB |
| prefill-2 | 1 | x16 | 13,659 MB/s (43%) | 13,658 MB/s | 5,833 MB/s | 14,225 MB/s (45%) | 13,470 MB/s | 5,924 MB/s | 100 % | 249 W | 2,340 MHz | 93,869 MiB |
| prefill-2 | 2 | x16 | 13,090 MB/s (42%) | 13,090 MB/s | 5,972 MB/s | 14,435 MB/s (46%) | 13,594 MB/s | 6,417 MB/s | 100 % | 315 W | 2,880 MHz | 93,869 MiB |
| prefill-2 | 3 | x16 | 14,736 MB/s (47%) | 13,381 MB/s | 6,328 MB/s | 14,517 MB/s (46%) | 14,055 MB/s | 6,848 MB/s | 100 % | 304 W | 2,872 MHz | 93,871 MiB |
| prefill-3 | 0 | x16 | 14,294 MB/s (45%) | 13,888 MB/s | 6,971 MB/s | 13,774 MB/s (44%) | 13,308 MB/s | 6,333 MB/s | 100 % | 241 W | 2,340 MHz | 93,789 MiB |
| prefill-3 | 1 | x16 | 13,588 MB/s (43%) | 13,488 MB/s | 7,014 MB/s | 14,821 MB/s (47%) | 13,936 MB/s | 7,008 MB/s | 100 % | 255 W | 2,340 MHz | 93,869 MiB |
| prefill-3 | 2 | x16 | 14,169 MB/s (45%) | 13,430 MB/s | 7,227 MB/s | 14,066 MB/s (45%) | 13,588 MB/s | 7,338 MB/s | 100 % | 323 W | 2,880 MHz | 93,869 MiB |
| prefill-3 | 3 | x16 | 14,162 MB/s (45%) | 12,959 MB/s | 6,560 MB/s | 13,589 MB/s (43%) | 12,514 MB/s | 6,221 MB/s | 100 % | 307 W | 2,872 MHz | 93,871 MiB |
| prefill-4 | 0 | x16 | 13,656 MB/s (43%) | 13,315 MB/s | 5,245 MB/s | 13,787 MB/s (44%) | 13,773 MB/s | 5,937 MB/s | 100 % | 249 W | 2,340 MHz | 93,789 MiB |
| prefill-4 | 1 | x16 | 14,735 MB/s (47%) | 14,153 MB/s | 6,052 MB/s | 13,812 MB/s (44%) | 13,668 MB/s | 5,428 MB/s | 100 % | 258 W | 2,340 MHz | 93,869 MiB |
| prefill-4 | 2 | x16 | 14,736 MB/s (47%) | 14,159 MB/s | 6,781 MB/s | 14,825 MB/s (47%) | 13,984 MB/s | 6,228 MB/s | 100 % | 321 W | 2,880 MHz | 93,869 MiB |
| prefill-4 | 3 | x16 | 13,155 MB/s (42%) | 12,848 MB/s | 7,497 MB/s | 13,802 MB/s (44%) | 13,572 MB/s | 7,371 MB/s | 100 % | 311 W | 2,872 MHz | 93,871 MiB |
| prefill-5 | 0 | x16 | 13,435 MB/s (43%) | 13,056 MB/s | 6,613 MB/s | 14,827 MB/s (47%) | 13,756 MB/s | 7,693 MB/s | 100 % | 245 W | 2,340 MHz | 93,789 MiB |
| prefill-5 | 1 | x16 | 13,658 MB/s (43%) | 13,308 MB/s | 6,674 MB/s | 14,925 MB/s (47%) | 14,274 MB/s | 7,520 MB/s | 100 % | 259 W | 2,340 MHz | 93,869 MiB |
| prefill-5 | 2 | x16 | 14,567 MB/s (46%) | 13,348 MB/s | 5,449 MB/s | 13,816 MB/s (44%) | 13,762 MB/s | 6,135 MB/s | 100 % | 323 W | 2,880 MHz | 93,869 MiB |
| prefill-5 | 3 | x16 | 14,168 MB/s (45%) | 13,319 MB/s | 5,867 MB/s | 13,798 MB/s (44%) | 13,569 MB/s | 5,120 MB/s | 100 % | 311 W | 2,872 MHz | 93,871 MiB |

load1 max: 4.9   MemAvailable min: 298,133,448 kB
