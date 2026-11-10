# disk-131072 — results vs Karmic Kraken

Protocol: llm_decode_bench.py v0.6.2 (sha256-pinned, see bench/PROVENANCE.md), 5 warmed 30 s windows per cell, 15 s warmup, 32K unique prefill (client TTFT), context-zero decode C1/C8, server-side /metrics accounting.

## Headline

| Cell | Ours (median of 5) | KK (Max-Q/325W) | Delta |
|---|---:|---:|---:|
| 32K prefill tok/s | 9,255 | 17,982 | -48.53% |
| C1 output tok/s | 195.9 | 249.1 | -21.35% |
| C1 verifier steps/s | 84.04 | 98.58 | -14.75% |
| C1 accepted length | 2.323 | 2.571 | -9.65% |
| C8 output tok/s | 578.5 | 805.5 | -28.18% |
| C8 verifier steps/s | 263.14 | 361.87 | -27.28% |
| C8 accepted length | 2.191 | 2.295 | -4.53% |
| KV capacity tokens | 4,782,165 | 4,727,748 | +1.15% |

## Per-window samples

| file | prefill tok/s | samples |
|---|---:|---:|
| prefill-2.json | 9,252 | 9 |
| prefill-3.json | 9,267 | 9 |
| prefill-4.json | 9,256 | 9 |
| prefill-5.json | 9,245 | 9 |
| prefill.json | 9,255 | 9 |

| file | C1 output tok/s | verifier steps/s | accepted length | source |
|---|---:|---:|---:|---|
| decode-1.json | 195.9 | 84.65 | 2.314 | openai_continuous_usage |
| decode-2.json | 206.3 | 82.75 | 2.493 | openai_continuous_usage |
| decode-3.json | 203.8 | 83.60 | 2.438 | openai_continuous_usage |
| decode-4.json | 189.3 | 84.58 | 2.238 | openai_continuous_usage |
| decode-5.json | 195.2 | 84.04 | 2.323 | openai_continuous_usage |

| file | C8 output tok/s | verifier steps/s | accepted length | source |
|---|---:|---:|---:|---|
| decode-1.json | 592.8 | 261.69 | 2.265 | openai_continuous_usage |
| decode-2.json | 578.5 | 264.00 | 2.191 | openai_continuous_usage |
| decode-3.json | 575.7 | 259.89 | 2.215 | openai_continuous_usage |
| decode-4.json | 580.4 | 270.44 | 2.146 | openai_continuous_usage |
| decode-5.json | 573.5 | 263.14 | 2.180 | openai_continuous_usage |

## PCIe and system (monitor.tsv)

Gen4 ceilings per direction (detected live: GPU 0 x16, GPU 1 x16, GPU 2 x16, GPU 3 x16).

| scope | GPU | width | tx max | tx p95 | tx mean | rx max | rx p95 | rx mean | util max | pwr max | clk max | mem max |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| overall | 0 | x16 | 15,938 MB/s (51%) | 13,254 MB/s | 4,132 MB/s | 15,299 MB/s (49%) | 12,805 MB/s | 3,936 MB/s | 100 % | 276 W | 2,340 MHz | 93,865 MiB |
| overall | 1 | x16 | 16,034 MB/s (51%) | 13,535 MB/s | 4,241 MB/s | 16,098 MB/s (51%) | 13,494 MB/s | 4,110 MB/s | 100 % | 293 W | 2,347 MHz | 93,827 MiB |
| overall | 2 | x16 | 15,879 MB/s (50%) | 12,946 MB/s | 4,267 MB/s | 16,076 MB/s (51%) | 13,447 MB/s | 4,385 MB/s | 100 % | 332 W | 2,895 MHz | 93,865 MiB |
| overall | 3 | x16 | 15,346 MB/s (49%) | 12,796 MB/s | 4,112 MB/s | 15,978 MB/s (51%) | 13,473 MB/s | 4,343 MB/s | 100 % | 329 W | 2,895 MHz | 93,885 MiB |
| decode_active | 0 | x16 | 15,938 MB/s (51%) | 13,315 MB/s | 4,478 MB/s | 15,299 MB/s (49%) | 12,816 MB/s | 4,255 MB/s | 100 % | 276 W | 2,325 MHz | 93,865 MiB |
| decode_active | 1 | x16 | 16,034 MB/s (51%) | 13,679 MB/s | 4,667 MB/s | 16,098 MB/s (51%) | 13,598 MB/s | 4,489 MB/s | 100 % | 293 W | 2,332 MHz | 93,827 MiB |
| decode_active | 2 | x16 | 15,879 MB/s (50%) | 13,112 MB/s | 4,706 MB/s | 16,076 MB/s (51%) | 13,473 MB/s | 4,829 MB/s | 100 % | 332 W | 2,895 MHz | 93,865 MiB |
| decode_active | 3 | x16 | 15,346 MB/s (49%) | 12,893 MB/s | 4,526 MB/s | 15,978 MB/s (51%) | 13,496 MB/s | 4,793 MB/s | 100 % | 329 W | 2,872 MHz | 93,885 MiB |
| decode-1 | 0 | x16 | 5,852 MB/s (19%) | 5,430 MB/s | 2,529 MB/s | 5,651 MB/s (18%) | 4,989 MB/s | 2,413 MB/s | 92 % | 272 W | 2,340 MHz | 93,865 MiB |
| decode-1 | 1 | x16 | 5,600 MB/s (18%) | 5,318 MB/s | 2,527 MB/s | 5,838 MB/s (19%) | 5,165 MB/s | 2,514 MB/s | 92 % | 288 W | 2,340 MHz | 93,825 MiB |
| decode-1 | 2 | x16 | 5,375 MB/s (17%) | 5,022 MB/s | 2,430 MB/s | 5,805 MB/s (18%) | 5,216 MB/s | 2,616 MB/s | 92 % | 330 W | 2,880 MHz | 93,865 MiB |
| decode-1 | 3 | x16 | 5,518 MB/s (18%) | 4,865 MB/s | 2,513 MB/s | 5,195 MB/s (16%) | 4,834 MB/s | 2,456 MB/s | 92 % | 328 W | 2,880 MHz | 93,885 MiB |
| decode-2 | 0 | x16 | 5,615 MB/s (18%) | 5,401 MB/s | 2,774 MB/s | 5,323 MB/s (17%) | 4,945 MB/s | 2,630 MB/s | 92 % | 273 W | 2,340 MHz | 93,865 MiB |
| decode-2 | 1 | x16 | 5,938 MB/s (19%) | 4,941 MB/s | 2,611 MB/s | 5,496 MB/s (17%) | 5,178 MB/s | 2,597 MB/s | 100 % | 290 W | 2,340 MHz | 93,827 MiB |
| decode-2 | 2 | x16 | 5,330 MB/s (17%) | 5,154 MB/s | 2,556 MB/s | 5,480 MB/s (17%) | 5,021 MB/s | 2,722 MB/s | 96 % | 328 W | 2,865 MHz | 93,865 MiB |
| decode-2 | 3 | x16 | 5,558 MB/s (18%) | 4,939 MB/s | 2,611 MB/s | 5,305 MB/s (17%) | 4,774 MB/s | 2,578 MB/s | 92 % | 329 W | 2,865 MHz | 93,885 MiB |
| decode-3 | 0 | x16 | 5,434 MB/s (17%) | 5,058 MB/s | 2,569 MB/s | 5,175 MB/s (16%) | 5,036 MB/s | 2,658 MB/s | 92 % | 275 W | 2,340 MHz | 93,865 MiB |
| decode-3 | 1 | x16 | 5,545 MB/s (18%) | 5,265 MB/s | 2,741 MB/s | 5,231 MB/s (17%) | 5,077 MB/s | 2,691 MB/s | 92 % | 291 W | 2,340 MHz | 93,827 MiB |
| decode-3 | 2 | x16 | 6,866 MB/s (22%) | 5,137 MB/s | 2,670 MB/s | 5,739 MB/s (18%) | 5,342 MB/s | 2,656 MB/s | 92 % | 329 W | 2,865 MHz | 93,865 MiB |
| decode-3 | 3 | x16 | 5,320 MB/s (17%) | 4,955 MB/s | 2,534 MB/s | 5,453 MB/s (17%) | 5,179 MB/s | 2,682 MB/s | 92 % | 327 W | 2,865 MHz | 93,885 MiB |
| decode-4 | 0 | x16 | 5,707 MB/s (18%) | 5,316 MB/s | 2,733 MB/s | 5,416 MB/s (17%) | 5,236 MB/s | 2,812 MB/s | 92 % | 275 W | 2,340 MHz | 93,865 MiB |
| decode-4 | 1 | x16 | 5,572 MB/s (18%) | 4,996 MB/s | 2,712 MB/s | 5,451 MB/s (17%) | 5,103 MB/s | 2,774 MB/s | 92 % | 291 W | 2,340 MHz | 93,827 MiB |
| decode-4 | 2 | x16 | 5,457 MB/s (17%) | 5,206 MB/s | 2,707 MB/s | 5,809 MB/s (18%) | 5,317 MB/s | 2,780 MB/s | 92 % | 332 W | 2,865 MHz | 93,865 MiB |
| decode-4 | 3 | x16 | 5,163 MB/s (16%) | 4,874 MB/s | 2,613 MB/s | 5,271 MB/s (17%) | 5,015 MB/s | 2,682 MB/s | 92 % | 328 W | 2,865 MHz | 93,885 MiB |
| decode-5 | 0 | x16 | 5,731 MB/s (18%) | 5,300 MB/s | 2,753 MB/s | 5,523 MB/s (18%) | 4,903 MB/s | 2,470 MB/s | 92 % | 276 W | 2,340 MHz | 93,865 MiB |
| decode-5 | 1 | x16 | 5,186 MB/s (16%) | 4,891 MB/s | 2,583 MB/s | 5,890 MB/s (19%) | 5,417 MB/s | 2,735 MB/s | 92 % | 293 W | 2,340 MHz | 93,827 MiB |
| decode-5 | 2 | x16 | 5,457 MB/s (17%) | 5,093 MB/s | 2,562 MB/s | 5,485 MB/s (17%) | 5,002 MB/s | 2,737 MB/s | 92 % | 327 W | 2,865 MHz | 93,865 MiB |
| decode-5 | 3 | x16 | 5,376 MB/s (17%) | 5,099 MB/s | 2,701 MB/s | 5,463 MB/s (17%) | 4,863 MB/s | 2,476 MB/s | 92 % | 327 W | 2,865 MHz | 93,885 MiB |
| prefill | 0 | x16 | 14,066 MB/s (45%) | 13,867 MB/s | 10,401 MB/s | 13,628 MB/s (43%) | 13,388 MB/s | 9,773 MB/s | 100 % | 205 W | 2,295 MHz | 93,865 MiB |
| prefill | 1 | x16 | 16,000 MB/s (51%) | 15,966 MB/s | 11,511 MB/s | 14,256 MB/s (45%) | 14,240 MB/s | 10,803 MB/s | 100 % | 214 W | 2,310 MHz | 93,825 MiB |
| prefill | 2 | x16 | 15,879 MB/s (50%) | 14,220 MB/s | 11,312 MB/s | 16,076 MB/s (51%) | 14,465 MB/s | 11,036 MB/s | 100 % | 292 W | 2,887 MHz | 93,863 MiB |
| prefill | 3 | x16 | 13,872 MB/s (44%) | 13,383 MB/s | 10,413 MB/s | 15,978 MB/s (51%) | 15,225 MB/s | 11,632 MB/s | 100 % | 284 W | 2,895 MHz | 93,883 MiB |
| prefill-2 | 0 | x16 | 12,727 MB/s (40%) | 11,668 MB/s | 2,254 MB/s | 13,154 MB/s (42%) | 9,830 MB/s | 1,893 MB/s | 100 % | 216 W | 2,332 MHz | 93,865 MiB |
| prefill-2 | 1 | x16 | 14,748 MB/s (47%) | 13,190 MB/s | 3,042 MB/s | 13,935 MB/s (44%) | 9,155 MB/s | 2,273 MB/s | 100 % | 230 W | 2,340 MHz | 93,825 MiB |
| prefill-2 | 2 | x16 | 15,846 MB/s (50%) | 13,000 MB/s | 5,536 MB/s | 13,652 MB/s (43%) | 13,442 MB/s | 4,401 MB/s | 100 % | 286 W | 2,895 MHz | 93,863 MiB |
| prefill-2 | 3 | x16 | 13,929 MB/s (44%) | 13,472 MB/s | 8,289 MB/s | 15,286 MB/s (49%) | 14,976 MB/s | 8,280 MB/s | 100 % | 286 W | 2,887 MHz | 93,883 MiB |
| prefill-3 | 0 | x16 | 15,938 MB/s (51%) | 15,056 MB/s | 11,030 MB/s | 14,940 MB/s (47%) | 13,885 MB/s | 10,507 MB/s | 100 % | 218 W | 2,332 MHz | 93,865 MiB |
| prefill-3 | 1 | x16 | 15,981 MB/s (51%) | 14,081 MB/s | 9,828 MB/s | 14,402 MB/s (46%) | 14,227 MB/s | 9,796 MB/s | 100 % | 228 W | 2,347 MHz | 93,825 MiB |
| prefill-3 | 2 | x16 | 13,242 MB/s (42%) | 12,919 MB/s | 8,192 MB/s | 15,265 MB/s (48%) | 14,306 MB/s | 9,721 MB/s | 100 % | 287 W | 2,887 MHz | 93,863 MiB |
| prefill-3 | 3 | x16 | 13,705 MB/s (44%) | 13,096 MB/s | 3,360 MB/s | 14,145 MB/s (45%) | 13,726 MB/s | 6,025 MB/s | 100 % | 287 W | 2,872 MHz | 93,883 MiB |
| prefill-4 | 0 | x16 | 14,055 MB/s (45%) | 14,022 MB/s | 9,394 MB/s | 15,299 MB/s (49%) | 13,426 MB/s | 9,256 MB/s | 100 % | 227 W | 2,340 MHz | 93,865 MiB |
| prefill-4 | 1 | x16 | 15,918 MB/s (51%) | 14,416 MB/s | 9,548 MB/s | 16,098 MB/s (51%) | 14,040 MB/s | 9,870 MB/s | 100 % | 237 W | 2,347 MHz | 93,825 MiB |
| prefill-4 | 2 | x16 | 15,276 MB/s (48%) | 13,735 MB/s | 9,667 MB/s | 15,861 MB/s (50%) | 14,270 MB/s | 10,171 MB/s | 100 % | 294 W | 2,887 MHz | 93,863 MiB |
| prefill-4 | 3 | x16 | 15,346 MB/s (49%) | 13,789 MB/s | 9,580 MB/s | 15,433 MB/s (49%) | 14,064 MB/s | 10,303 MB/s | 100 % | 289 W | 2,872 MHz | 93,883 MiB |
| prefill-5 | 0 | x16 | 15,451 MB/s (49%) | 14,080 MB/s | 5,834 MB/s | 13,744 MB/s (44%) | 13,408 MB/s | 4,991 MB/s | 100 % | 226 W | 2,332 MHz | 93,865 MiB |
| prefill-5 | 1 | x16 | 16,034 MB/s (51%) | 14,331 MB/s | 7,426 MB/s | 14,184 MB/s (45%) | 13,480 MB/s | 5,934 MB/s | 100 % | 241 W | 2,332 MHz | 93,825 MiB |
| prefill-5 | 2 | x16 | 15,249 MB/s (48%) | 13,801 MB/s | 7,808 MB/s | 13,221 MB/s (42%) | 12,873 MB/s | 7,719 MB/s | 100 % | 296 W | 2,835 MHz | 93,863 MiB |
| prefill-5 | 3 | x16 | 13,554 MB/s (43%) | 13,436 MB/s | 8,166 MB/s | 15,935 MB/s (51%) | 13,867 MB/s | 7,808 MB/s | 100 % | 290 W | 2,880 MHz | 93,883 MiB |

load1 max: 8.9   MemAvailable min: 492,188,276 kB

## Engram direct-I/O verification (the btrfs-compression trap)

Risk checked before trusting this run: O_DIRECT on btrfs silently degrades to
page-cache reads when the file is compressed (compress=zstd:1 is the Fedora
default). Evidence the degradation did NOT occur:

- Both Engram shards (model-00047/48, ~94.5 GiB each) have allocated size ==
  apparent size and empty `lsattr -c` => not compressed on this filesystem.
- The loader code (`flashinfer/experimental/b12x/loader/_direct.c`,
  `_row_plan.h`) opens with O_DIRECT and hard-fails "no buffered fallback" on
  EINVAL; backend is io_uring (liburing.so.2.5 mapped in every worker, 2 live
  io_uring fds + 2 shard fds per worker).
- A 30 s prefill burst showed worker `rchar` growth of exactly 0 (no read()
  syscalls) with nonzero `read_bytes` (block I/O present) => direct path live.
- Residual pgpgin (~24 GiB/30 s) is attributable to lazy weight mmap
  streaming, not Engram misses; per-process read_bytes accounted only the
  fresh block reads.

Bounded conclusion from the mode pair (same board, same session day):
Engram-at-disk costs prefill -13.1% and C8 decode -17.4% versus RAM mode.
Since making the host-table lookup *slower* moves prefill by only 13%, the
Engram lookup path is not the primary prefill limiter on this machine; the
RAM-mode prefill deficit (-41% vs KK) sits elsewhere (rank0 stalls; the VRel
clock ceiling on the two Max-Q ranks gating every TP4 step).
