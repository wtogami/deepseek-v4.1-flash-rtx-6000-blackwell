# CSF A/B — csf-ab-20261110-133934

Same engine, same TP4/DSpark configuration and KK protocol; only the checkpoint layout differs (original flat MXFP4 vs lossless FP4-CSF). Each cell is the median of five 30 s windows.

| Cell | Original 131K | CSF 131K | Δ | Original 1M | CSF 1M | Δ |
|---|---:|---:|---:|---:|---:|---:|
| 32K prefill tok/s | 10,775 | 10,605 | -1.58% | 10,684 | 10,571 | -1.06% |
| C1 output tok/s | 217 | 216 | -0.60% | 230 | 221 | -4.12% |
| C1 verifier steps/s | 93 | 91 | -2.08% | 92 | 91 | -1.78% |
| C8 output tok/s | 745 | 749 | +0.63% | 734 | 746 | +1.69% |
| C8 verifier steps/s | 345 | 352 | +1.92% | 349 | 353 | +1.03% |
| KV capacity tokens | 4,742,050 | 6,061,055 | +27.82% | 9,718,137 | 12,949,820 | +33.25% |

## Determinism (greedy, fixed prompt, seed 1234)

- 131K: DIFFERS — differs at character 1: 'If n is not positive, return 0.' vs 'The function should take an integer n as'
- 1M: DIFFERS — differs at character 1: 'The function should take an integer n as' vs 'If n is not positive, return 0. Then, wr'

## Decision

- 131K pair equal-or-better (1.5% noise floor, KV >= original): FAIL
- 1M pair equal-or-better: FAIL
- Greedy outputs identical: FAIL

**Winner: ORIGINAL** — the script leaves the engine running on the winner at `MAX_MODEL_LEN=-1` (1M thinking configuration).
