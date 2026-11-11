# Flare TP3 vs the four-GPU vLLM engine

Baseline arm: `results/rebar325-cool-131072` (5 prefill windows, 5 decode windows, harness 0.6.2).
Flare on our protocol: `results/flare-tp3-baseline-20261111-045100`.
Flare on the recipe protocol: `results/flare-tp3-20261111-040643`.

## Like-for-like (our pinned v0.6.2 cells)

Same harness, same cells, same power limit: four GPUs on vLLM versus three GPUs on Flare. Decode is context-zero at 30 s per concurrency; prefill is a cold 32K prompt measured by client TTFT.

| Cell | Flare TP3 (3 GPUs) | vLLM TP4 (4 GPUs) | Delta |
|---|---:|---:|---:|
| 32K prefill tok/s | 9,376.0 | 10,649.0 | -11.95% |
| C1 decode tok/s | 177.0 | 225.6 | -21.54% |
| C8 decode tok/s | 565.9 | 740.0 | -23.53% |

## Recipe protocol (llm-inference-bench v0.9.1)

| Cell | This run | Recipe published |
|---|---:|---:|
| prefill 8K tok/s | 7,667 | — |
| prefill 32K tok/s | 9,758 | 12,548 |
| prefill 128K tok/s | 9,358 | 12,160 |
| decode 32K C1 tok/s | 173.3 | ~254 |
| decode 32K C4 tok/s | 373.9 | ~595 |
| decode 32K C8 tok/s | 508.8 | ~805 |

| Cell | steps/s | tokens/step | draft acceptance | recipe steps/s |
|---|---:|---:|---:|---:|
| decode 32K C1 | 66.7 | 2.60 | 0.32 | 93.8 (0.71×) |
| decode 32K C4 | 43.3 | 8.63 | 0.52 | 62.0 (0.70×) |
| decode 32K C8 | 33.7 | 15.08 | 0.63 | 48.1 (0.70×) |

## vLLM baseline detail

| Cell | tok/s | verifier steps/s | accepted length |
|---|---:|---:|---:|
| C1 | 225.6 | 92.2 | 2.434 |
| C8 | 740.0 | 349.2 | 2.155 |

## KV capacity

- Flare TP3: 4,194,304 tokens
- vLLM TP4 at `MAX_MODEL_LEN=131072`: — tokens
- vLLM TP4 at `MAX_MODEL_LEN=-1` (1M): 9,718,137 tokens

## Correctness and quality

- `tools/verify_fix.py 10`: TRUE corruptions 0 (the recipe requires 0)
- Coding peak (5 runs, median): 245.4 tok/s (range 229.4-267.0); the recipe publishes 379-398 tok/s
- `tools/tool_calls.py 60 4`: tool calls: 60/60 OK (0 chose a different tool), concurrency 4, 63 s
- Long retrieval at 128,000 tokens: passed (prompt 127,986)
- Long retrieval at 900,000 tokens: passed (prompt 899,988)

## Conditions

- Flare TP3 package exported at `HOT=290 PREFILL=4096` (GPUs 1,2,3 = one Max-Q + two Workstation, all at 325 W, stock 13,365 MHz memory clock, PCIe Gen4 x16 behind PHB/NODE, DDR4 host). The recipe's published `HOT=300` build could not be exported here: at 290 each rank retains 69,469 MiB with 2,904 MiB free, and 300 would add ~1.9 GiB of hot experts on top of that budget — which is what OOM'd during cold tuning.
- Recipe box: 3 × Workstation at 350 W with a +6000 MHz memory offset on Gen5 x16, 256 GB DDR5-6000. EXPORT.md itself expects roughly half the per-step speed without those; measured here is 0.70–0.71× at every concurrency.
- vLLM arm is four GPUs with ReBAR + ForceP2P + `TWOSHOT_MB=6`, `MAX_MODEL_LEN=131072`, KV 4,740,829 tokens (9,718,137 at 1M).
- Like-for-like cells come from the pinned `bench/llm_decode_bench.py` v0.6.2 with `--token-targeting estimate` (Flare exposes no /tokenize) and `--respect-eos`; that build does not read Flare counters, so its engine-side accounting is absent and the decode rows are client-measured stream usage.
- The v0.9.1 tag prints an internal banner of 'llm-decode-bench v0.8.0' (the constant was not bumped); the checkout is tagged v0.9.1.
- Flare's `--prefix-cache-memory 16G` and host expert layers 20-33 keep ~102 GiB of Engram tables in host RAM; serving used ~150 GiB of the 503 GiB box.

## GPU state (before)

```
0, NVIDIA RTX PRO 6000 Blackwell Max-Q Workstation Edition, 325.00 W, 180 MHz, 405 MHz, 1, 39
1, NVIDIA RTX PRO 6000 Blackwell Max-Q Workstation Edition, 325.00 W, 180 MHz, 405 MHz, 1, 68
2, NVIDIA RTX PRO 6000 Blackwell Workstation Edition, 325.00 W, 180 MHz, 405 MHz, 1, 56
3, NVIDIA RTX PRO 6000 Blackwell Workstation Edition, 325.00 W, 180 MHz, 405 MHz, 1, 46
```

## GPU state (after)

```
0, NVIDIA RTX PRO 6000 Blackwell Max-Q Workstation Edition, 325.00 W, 180 MHz, 405 MHz, 1, 39
1, NVIDIA RTX PRO 6000 Blackwell Max-Q Workstation Edition, 325.00 W, 2340 MHz, 13365 MHz, 4, 81
2, NVIDIA RTX PRO 6000 Blackwell Workstation Edition, 325.00 W, 2760 MHz, 13365 MHz, 4, 66
3, NVIDIA RTX PRO 6000 Blackwell Workstation Edition, 325.00 W, 2610 MHz, 13365 MHz, 4, 55
```


## Per-card efficiency

Absolute throughput favours the four-GPU vLLM engine, but the normalised view
is where this replication gets interesting:

| Metric | Flare TP3 (3 cards) | per card | vLLM TP4 (4 cards) | per card |
|---|---:|---:|---:|---:|
| 32K prefill tok/s | 9,376 | 3,125 | 10,649 | 2,662 |
| C1 decode tok/s | 177.0 | 59.0 | 225.6 | 56.4 |
| C8 decode tok/s | 565.9 | 188.6 | 740.0 | 185.0 |
| KV tokens at this cap | 4,194,304 | 1,398,101 | 4,740,829 | 1,185,207 |

Per card, Flare is ahead or level on every cell: +17% prefill, +5% C1, +2% C8,
+18% KV. The recipe's efficiency survives Gen4, DDR4 and stock memory clocks —
what we lose in absolute terms is almost exactly the fourth card, plus the
mixed-SKU group's lower ceiling. Decode cells averaged 889-894 W across three
cards against a 975 W cap (297 W/card), so the group is running at its power
limit rather than being link-starved.

## Verdict

The parked decision rule was: keep Flare only if it lands within ~10-15% of the
four-GPU vLLM numbers. It does not — decode is -21.5% at C1 and -23.5% at C8,
prefill -12.0% — so `ds41` goes back on four GPUs at `MAX_MODEL_LEN=-1` and
this stays a documented measurement rather than a serving configuration.

What it is worth: a working Flare `78b18b1c` + recipe build on this box
(`localhost/flare-tp3:13.2.1`, exported package `gb202-tp3-202611110954`,
380 GB), two fixes that generalise to anything multi-rank in a rootless
container here (the `--pids-limit` ceiling and the mixed-SKU compile-cache
check), and the per-card numbers above. If a fourth card ever leaves this
group, a homogeneous three-Workstation TP3 Flare group plus one spare card is a
different trade-off worth revisiting — at 350 W the recipe's own data puts
prefill ~10% higher again.
