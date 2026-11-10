#!/usr/bin/env bash
# Benchmark the running Flare TP3 server with llm-inference-bench v0.9.1,
# the same harness and cells as the recipe's published numbers.
#
#   ./scripts/flare-tp3/bench.sh --run            # prefill + 32K decode
#   ./scripts/flare-tp3/bench.sh --run --full     # + coding peak + long retrieval
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

PREFILL=("${BASE[@]}" --prefill-only --prefill-contexts 8k,32k,128k \
  --prefill-metric client --output "$OUT/prefill.json")
DECODE=("${BASE[@]}" --skip-prefill --concurrency 1,4,8 --contexts 32k \
  --duration 30 --max-tokens 8192 --output "$OUT/decode-32k.json")
if [[ "$FULL" == 1 ]]; then
  DECODE+=(--coding-peak --coding-peak-runs 5)
fi

if [[ "$RUN" != 1 ]]; then
  log "dry-run prefill: $PY $BENCH_DIR/llm_decode_bench.py ${PREFILL[*]}"
  log "dry-run decode:  $PY $BENCH_DIR/llm_decode_bench.py ${DECODE[*]}"
  log "dry-run steps:   python3 $RECIPE_DIR/tools/bench_steps.py $OUT/decode-32k.json"
  if [[ "$FULL" == 1 ]]; then
    log "dry-run full:    decode includes --coding-peak; plus qualification/long_retrieval.py --targets 128000 900000"
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
log "=== prefill 8K/32K/128K ==="
"$PY" "$BENCH_DIR/llm_decode_bench.py" "${PREFILL[@]}" 2>&1 | tee "$OUT/prefill.log"

log "=== decode 32K C1/C4/C8 ==="
"$PY" "$BENCH_DIR/llm_decode_bench.py" "${DECODE[@]}" 2>&1 | tee "$OUT/decode-32k.log"

log "=== steps/s ==="
python3 "$RECIPE_DIR/tools/bench_steps.py" "$OUT/decode-32k.json" 2>&1 | tee "$OUT/steps.txt"

if [[ "$FULL" == 1 ]]; then
  log "=== long retrieval 128K / 900K ==="
  LABEL="flare-tp3-$(date +%H%M%S)"
  ( cd "$RECIPE_DIR/qualification" && python3 long_retrieval.py \
      --label "$LABEL" --targets 128000 900000 ) 2>&1 | tee "$OUT/long-retrieval.log" || true
fi

log "done: $OUT"
