#!/usr/bin/env bash
# Benchmark the running Flare TP3 server with llm-inference-bench v0.9.1,
# the harness and cells the recipe's published numbers come from.
#
#   ./scripts/flare-tp3/bench.sh --run          # corruption check, prefill, 32K decode
#   ./scripts/flare-tp3/bench.sh --run --full   # + coding peak, tool calls, retrieval
#
# Results land in results/flare-tp3-<timestamp>/.
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

RUN=0
FULL=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --run) RUN=1; shift ;;
    --full) FULL=1; shift ;;
    --dry-run) RUN=0; shift ;;
    *) die "unknown argument: $1 (usage: $0 [--run] [--full])" ;;
  esac
done

require_cmd python3
if [[ ! -f "$BENCH_DIR/llm_decode_bench.py" ]]; then
  if [[ "$RUN" == 1 ]]; then
    die "bench repo missing: $BENCH_DIR (run download.sh)"
  fi
  log "WARN: bench repo not cloned yet; --run will need download.sh"
fi
[[ -f "$RECIPE_DIR/tools/bench_steps.py" ]] || die "recipe bench_steps.py missing"

OUT="$PROJECT_DIR/results/flare-tp3-$(date +%Y%m%d-%H%M%S)"
PY="$BENCH_DIR/.venv/bin/python"
BASE=(--host http://127.0.0.1 --port "$PORT" --model DeepSeek-V4.1-Flash)

# The recipe's decode cells are "--concurrency 1,4,8 --contexts 32k --duration 60"
# with the bench's own ignore_eos default; --skip-prefill only trims the other
# cells so each phase writes its own JSON.
PREFILL=("${BASE[@]}" --prefill-only --prefill-contexts 8k,32k,128k \
  --prefill-metric client --output "$OUT/prefill.json")
DECODE=("${BASE[@]}" --skip-prefill --concurrency 1,4,8 --contexts 32k \
  --duration 60 --output "$OUT/decode-32k.json")
DECODE_EOS=("${BASE[@]}" --skip-prefill --concurrency 1,4,8 --contexts 32k \
  --duration 60 --respect-eos --output "$OUT/decode-32k-eos.json")
CODING=("${BASE[@]}" --coding-peak --coding-peak-runs 5 --output "$OUT/coding-peak.json")

if [[ "$RUN" != 1 ]]; then
  log "dry-run corrupt: python3 $RECIPE_DIR/tools/verify_fix.py 10"
  log "dry-run prefill: $PY $BENCH_DIR/llm_decode_bench.py ${PREFILL[*]}"
  log "dry-run decode:  $PY $BENCH_DIR/llm_decode_bench.py ${DECODE[*]}"
  log "dry-run steps:   python3 $RECIPE_DIR/tools/bench_steps.py $OUT/decode-32k.json"
  if [[ "$FULL" == 1 ]]; then
    log "dry-run full:    ${DECODE_EOS[*]}"
    log "dry-run full:    ${CODING[*]}"
    log "dry-run full:    python3 $RECIPE_DIR/tools/tool_calls.py 60 4"
    log "dry-run full:    qualification/long_retrieval.py --targets 128000 900000"
  fi
  exit 0
fi

engine_health && die "ds41 is running; Flare should be on :$PORT"
curl -fsS -m 5 "http://127.0.0.1:$PORT/health" >/dev/null \
  || die "no Flare server on :$PORT (run serve.sh --run)"

mkdir -p "$OUT"
if [[ ! -x "$PY" ]]; then
  log "creating bench venv: $BENCH_DIR/.venv"
  python3 -m venv "$BENCH_DIR/.venv"
  "$BENCH_DIR/.venv/bin/pip" install -q --upgrade pip
  "$BENCH_DIR/.venv/bin/pip" install -q httpx rich psutil
fi

log "results: $OUT"

# The recipe's first check: decode junk against a teacher-forced prefill.
# A non-zero count means the FlashInfer tiny_decode/swiglu patch is missing.
log "=== corruption check (expect: TRUE corruptions 0) ==="
python3 "$RECIPE_DIR/tools/verify_fix.py" 10 2>&1 | tee "$OUT/verify-fix.log"

log "=== prefill 8K/32K/128K ==="
"$PY" "$BENCH_DIR/llm_decode_bench.py" "${PREFILL[@]}" 2>&1 | tee "$OUT/prefill.log"

log "=== decode 32K C1/C4/C8 ==="
"$PY" "$BENCH_DIR/llm_decode_bench.py" "${DECODE[@]}" 2>&1 | tee "$OUT/decode-32k.log"

log "=== steps/s ==="
python3 "$RECIPE_DIR/tools/bench_steps.py" "$OUT/decode-32k.json" 2>&1 | tee "$OUT/steps.txt"

if [[ "$FULL" == 1 ]]; then
  log "=== decode 32K with --respect-eos (loop-free repeat) ==="
  "$PY" "$BENCH_DIR/llm_decode_bench.py" "${DECODE_EOS[@]}" 2>&1 \
    | tee "$OUT/decode-32k-eos.log" || true

  log "=== coding peak (5 runs, median) ==="
  "$PY" "$BENCH_DIR/llm_decode_bench.py" "${CODING[@]}" 2>&1 | tee "$OUT/coding-peak.log" || true

  log "=== tool calls (60 prompts, concurrency 4) ==="
  python3 "$RECIPE_DIR/tools/tool_calls.py" 60 4 2>&1 | tee "$OUT/tool-calls.log" || true

  log "=== long retrieval 128K / 900K ==="
  ( cd "$RECIPE_DIR/qualification" && python3 long_retrieval.py \
      --label "flare-tp3-$(date +%H%M%S)" --targets 128000 900000 ) 2>&1 \
      | tee "$OUT/long-retrieval.log" || true
fi

log "done: $OUT"
