# Tested and not recommended

Paths that were measured and then parked. They stay in the tree so the
measurements can be reproduced; they are not part of the recommended setup.

## CSF checkpoint (lossless FP4 scale compression)

The original checkpoint stores the routed-expert UE8M0 scale planes
uncompressed. The CSF container compresses them losslessly (16.99 GB -> 2.31 GB;
the weights themselves are byte-identical and the original shards can be
restored bit-exactly). It is not a smaller quantization and no experts are
removed; the freed GPU memory becomes KV cache.

It was offered as `CSF=1 ./start.sh` with a separate download
(`./scripts/csf-download.sh`, 495.6 GB) and a switch/A-B pair
(`./scripts/csf-switch.sh`, `./scripts/csf-ab.sh`). All three are **archived**;
`CSF` and `CSF_DIRECTORY` still work but are documented as archived in
[OPERATIONS.md](OPERATIONS.md#environment-reference). The image's `ds41-flash`
profile ships the matching `checkpoint: csf` variant (`mxfp4_csf` quantization
and load-format); the launcher derived it from the container's `manifest.json`.
License: Local Inference Lab License 1.0 (the base weights are MIT).

`csf-ab.sh` ran four arms (original/CSF at 131072 and at 1M), performed a
greedy determinism probe per arm, ran the KK protocol, wrote
`results/<run>/csf-AB.md`, and left the winner running at 1M. Its knobs were
`KK_CAP` (`131072`), `ONE_M_CAP` (`-1`), `ORIGINAL_DIRECTORY`, `CSF_DIRECTORY`,
`POWER_LIMIT` (`325`) and `ALLOW_POWER_MISMATCH`.

### A/B result

Same engine, same TP4/DSpark configuration and KK protocol; only the checkpoint
layout differs. Each cell is the median of five 30 s windows.

| Cell | Original 131K | CSF 131K | Δ | Original 1M | CSF 1M | Δ |
|---|---:|---:|---:|---:|---:|---:|
| 32K prefill tok/s | 10,775 | 10,605 | -1.58% | 10,684 | 10,571 | -1.06% |
| C1 output tok/s | 217 | 216 | -0.60% | 230 | 221 | -4.12% |
| C1 verifier steps/s | 93 | 91 | -2.08% | 92 | 91 | -1.78% |
| C8 output tok/s | 745 | 749 | +0.63% | 734 | 746 | +1.69% |
| C8 verifier steps/s | 345 | 352 | +1.92% | 349 | 353 | +1.03% |
| KV capacity tokens | 4,742,050 | 6,061,055 | +27.82% | 9,718,137 | 12,949,820 | +33.25% |

Determinism probe (greedy, fixed prompt, seed 1234): outputs **differed** at
both 131K and 1M. The weights are byte-identical, so this is a numerics or
batching-order difference rather than a quantization loss, but it is enough
that the A/B's own decision rule failed ("greedy outputs identical: FAIL").

### Why it is not recommended

- It keeps the four-card requirement and adds a 496 GB download; the measured
  three-card path uses fewer cards and passes its quality checks
  ([PERFORMANCE.md](PERFORMANCE.md#three-card-alternative-flare-tp3)).
- Throughput is neutral (prefill -1 to -2 %, decode within noise), so the only
  gain is KV capacity: +28 % at 131K, +33 % at 1M.
- The greedy determinism probe differed, so "lossless" describes the scale
  compression, not a bit-identical serving output.

Full report: `results/csf-ab-20261110-133934/csf-AB.md`; the four arm
directories are next to it.
