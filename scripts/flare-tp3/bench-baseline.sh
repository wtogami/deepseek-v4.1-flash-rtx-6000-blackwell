#!/usr/bin/env bash
# Run OUR protocol (the pinned llm-inference-bench v0.6.2 cells used for every
# result in results/) against the Flare TP3 server, so the comparison against
# the four-GPU vLLM baseline is like-for-like.
#
#   ./scripts/flare-tp3/bench-baseline.sh --run
#
# Cells: 5 x prefill-only 32K (client TTFT, 30 s) and 5 x decode C1 + C8 at
# context 0 (30 s each, --respect-eos, --temperature 1, --max-tokens 8192,
# 15 s warm-up). About 12 minutes plus monitor start/stop.
#
# Differences from run-bench.sh, all forced by the engine:
#   - no vLLM /metrics gate: Flare exposes flare_* counters, and the verifier
#     detail for Flare comes from the recipe-protocol run (bench.sh) instead.
#   - --token-targeting estimate: Flare has no /tokenize endpoint, so exact
#     prompt sizing is not available. The decode cells are context-zero and
#     the prefill cell calibrates on one request, so the effect is small.
#   - no --kv-budget: it only gates over-capacity cells, which these are not.
#   - no drop_caches: Engram tables live in host RAM.
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --run) RUN=1; shift ;;
    --dry-run) RUN=0; shift ;;
    *) die "unknown argument: $1 (usage: $0 [--run])" ;;
  esac
done

BENCH="$PROJECT_DIR/bench/llm_decode_bench.py"
[[ -f "$BENCH" ]] || die "pinned bench script missing: $BENCH"
require_cmd python3
require_cmd nvidia-smi

URL="http://127.0.0.1:$PORT"
WINDOWS="${WINDOWS:-5}"
MONITOR_SECONDS="${MONITOR_SECONDS:-900}"
OUT="${OUT:-$PROJECT_DIR/results/flare-tp3-baseline-$(date +%Y%m%d-%H%M%S)}"

COMMON=(--host "$URL" --model DeepSeek-V4.1-Flash --display-mode plain
        --no-hw-monitor --no-resume --respect-eos --temperature 1
        --token-targeting estimate --max-tokens 8192
        --decode-warmup-seconds 15)

if [[ "$RUN" != 1 ]]; then
  log "out: $OUT"
  log "dry-run prefill: python3 $BENCH ${COMMON[*]} --prefill-only --prefill-contexts 32k --prefill-duration 30 --prefill-metric client --output $OUT/prefill-N.json  (x$WINDOWS)"
  log "dry-run decode:  python3 $BENCH ${COMMON[*]} --skip-prefill --concurrency 1,8 --contexts 0 --duration 30 --output $OUT/decode-N.json  (x$WINDOWS)"
  log "dry-run monitor: $PROJECT_DIR/monitor.sh $MONITOR_SECONDS $OUT/monitor.tsv"
  exit 0
fi

engine_health && die "ds41 is healthy on :8000; Flare should own the GPUs (stop it first)"
curl -fsS -m 5 "$URL/health" >/dev/null || die "no Flare server on $URL (run serve.sh --run)"
curl -fsS -m 10 "$URL/metrics" >/dev/null || die "Flare /metrics is not reachable"

mkdir -p "$OUT"
echo "$(date +%s.%N) start" > "$OUT/phases.tsv"
curl -fsS "$URL/metrics" 2>/dev/null | awk '/^flare_total_kv_tokens/{print $2; exit}' > "$OUT/kv.txt" || true
log "KV: $(cat "$OUT/kv.txt" 2>/dev/null || echo unknown) tokens"
nvidia-smi --query-gpu=index,name,power.limit,clocks.sm,clocks.mem,pcie.link.gen.current,temperature.gpu \
  --format=csv,noheader > "$OUT/gpu-before.txt"

"$PROJECT_DIR/monitor.sh" "$MONITOR_SECONDS" "$OUT/monitor.tsv" &
MON_PID=$!
trap 'kill "$MON_PID" 2>/dev/null || true' EXIT

for i in $(seq 1 "$WINDOWS"); do
  log "prefill window $i/$WINDOWS"
  echo "$(date +%s.%N) prefill-$i" >> "$OUT/phases.tsv"
  python3 "$BENCH" "${COMMON[@]}" --prefill-only --prefill-contexts 32k \
    --prefill-duration 30 --prefill-metric client \
    --output "$OUT/prefill-$i.json" </dev/null
done
for i in $(seq 1 "$WINDOWS"); do
  log "decode window $i/$WINDOWS (C1 + C8)"
  echo "$(date +%s.%N) decode-$i" >> "$OUT/phases.tsv"
  python3 "$BENCH" "${COMMON[@]}" --skip-prefill --concurrency 1,8 \
    --contexts 0 --duration 30 \
    --output "$OUT/decode-$i.json" </dev/null
done

kill "$MON_PID" 2>/dev/null || true
trap - EXIT
nvidia-smi --query-gpu=index,name,power.limit,clocks.sm,clocks.mem,pcie.link.gen.current,temperature.gpu \
  --format=csv,noheader > "$OUT/gpu-after.txt"
echo "$(date +%s.%N) done" >> "$OUT/phases.tsv"
log "results: $OUT"
