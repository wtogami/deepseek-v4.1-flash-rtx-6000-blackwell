# B12X two-shot A/B (2026-11-08, Supermicro AS-5014A-TT)

Protocol: KK serving protocol (5 warmed 30 s windows/cell), same engine, same
day, back-to-back arms; only difference is the container env
`VLLM_PCIE_TWOSHOT_ALLREDUCE_MAX_SIZE` (profile default `off` vs `6MB`),
passed via `TWOSHOT_MB=6 ./start.sh`. Activation verified in the engine log:
`two-shot bf16 max=6291456, DMA min=6291456` (no init fallback).

| Cell | A = off | B = 6MB two-shot | B vs A | KK | B vs KK |
|---|---:|---:|---:|---:|---:|
| 32K prefill tok/s | 10,760 | 10,666 | -0.9% (control) | 17,982 | -40.7% |
| C1 output tok/s | 212.6 | 224.9 | +5.8% | 249.1 | -9.7% |
| C1 verifier steps/s | 92.78 | 91.64 | -1.2% (control) | 98.58 | -7.0% |
| C1 accepted length | 2.292 | 2.461 | sampling | 2.571 | -4.3% |
| C8 output tok/s | 700.5 | 716.3 | +2.3% | 805.5 | -11.1% |
| **C8 verifier steps/s** | **310.26** | **325.06** | **+4.8%** | 361.87 | **-10.2%** |
| C8 accepted length | 2.263 | 2.192 | sampling | 2.295 | -4.5% |
| KV capacity tokens | 4,741,178 | 4,742,050 | +0.02% | 4,727,748 | +0.3% |

Noise floor: three prior same-config runs today (sm-131072 vs this A) differ
by 0.5-1.5% on verifier-rate cells, so the +4.8% C8 verifier gain is outside
noise; prefill (-0.9%) and C1 verifier (-1.2%) held as the designed controls
(DMA and one-shot bands are untouched by the knob).

Reading: C8 decode all-reduces (64 tokens x 5120 x bf16 = 640 KiB) previously
fell in the 96 KiB..6 MiB dispatch gap and ran NCCL ring allreduce with
measured 3-4 ms kernel residency vs ~0.1 ms of pure transfer (nsys, same day).
Two-shot's two-phase peer push absorbs that entry-skew spin; the step critical
path shortens exactly on the band-consuming cell.

Accepted-length differences (+7.4% C1, -3.1% C8) are temperature-1 sampling
movement across the new but deterministic summation order (single-rounding
fixed-rank fp32); they are within the historical acceptance run-to-run range
and not evidence of a numerics change. A strict numeric-identity claim would
need a greedy-output diff, which is not part of this protocol.

Decision: run the engine with `TWOSHOT_MB=6` on this platform (engine is
currently live with it). It is an opt-in override of the LIL profile default;
the profile presumably ships `off` for generality — on this board it
initialized clean, stayed enabled across the full protocol, and costs ~0.02%
KV capacity.

Artifacts: results/twoshot-A-off/, results/twoshot-B-on/ (raw per-window
samples + monitor.tsv + REPORT.md each).

## Follow-up: request-boundary "bubble" and the fairness-gate theory (negative result)

The bench cycle is 3.33 s/request vs TTFT 3.07 s => only ~0.26 s (8%) is
client turnaround between serialized requests (the nsys 460 ms all-silent
gaps). A serialized probe (server-side TTFT 3.093 s mean vs client 3.00-3.39,
request_queue_time ~0) showed the engine spends the whole TTFT inside the
prefill computation itself.

Theory tested: `scheduler_prefill_compute_share` (profile 0.4) reads 0.4
during uncontended serial prefill => maybe the gate paces standalone prefill
to ~40% duty. Restart with FAIRNESS_ENGINE=none (drops the arg; gauge reads
0.0 during the same burst = the drop took effect): TTFT unchanged
(2.97-3.02 s). Verdict: the gauge shows the CONFIGURED share; the scheduler
exempts uncontended prefill on this build. No hidden throttle; the -41%
prefill vs KK is engine step time (Max-Q-paced compute + inter-rank
collective waits), matching the nsys decomposition. The SHARE/FAIRNESS
knobs in start.sh remain for mixed-serving tuning (the gate's purpose is
decode-latency protection under concurrent traffic, which this protocol
never exercises).
