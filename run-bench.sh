#!/usr/bin/env bash
# Run the Karmic Kraken protocol against the running ds41 server, using the
# exact llm_decode_bench.py v0.6.2 pinned in bench/ (see bench/PROVENANCE.md)
# and a 1 Hz PCIe/system monitor alongside.
#
# Usage: KV_CAPACITY=<tokens> NAME=<label> ./run-bench.sh
#   KV_CAPACITY  logical KV capacity from the server startup log
#                ("GPU KV cache size: N tokens"); it only gates over-capacity
#                cells, which the 32K prefill and context-zero decode cells
#                never are
#   NAME         results label, e.g. ram-131072
#
# Env: HOST (default http://127.0.0.1:8000), MODEL_NAME, DROP_CACHES (1 to
# drop the page cache before each cell; only meaningful for disk Engram),
# MONITOR_SECONDS (default 1800).
#
# Total wall time is about 12 minutes: 5 x ~42 s prefill runs plus
# 5 x ~104 s decode runs (C1 and C8 in each).
set -euo pipefail
RECIPE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
HOST="${HOST:-http://127.0.0.1:8000}"
MODEL_NAME="${MODEL_NAME:-DeepSeek-V4.1-Flash}"
KV_CAPACITY="${KV_CAPACITY:?Set KV_CAPACITY from the server log ('GPU KV cache size')}"
NAME="${NAME:?Set NAME to a results label, e.g. ram-131072}"
DROP_CACHES="${DROP_CACHES:-0}"
MONITOR_SECONDS="${MONITOR_SECONDS:-1800}"
OUT_DIR="$RECIPE_DIR/results/$NAME"
mkdir -p "$OUT_DIR"
# Phase markers (epoch seconds) let the monitor timeline be sliced per cell.
echo "$(date +%s.%N) start" > "$OUT_DIR/phases.tsv"

command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 2; }

# ------------------------------------------------------------- readiness gate
echo "Waiting for $HOST/health" >&2
ready=0
for _ in $(seq 1 60); do
  if curl -fsS "$HOST/health" >/dev/null 2>&1; then ready=1; break; fi
  sleep 5
done
if [[ "$ready" != 1 ]]; then
  echo "Server not ready at $HOST after 300 s" >&2; exit 1
fi

# -------------------------------------------------------- metrics presence gate
# The decode cells are accounted from these counters; fail before burning
# twelve minutes if the engine does not expose them.
python3 - "$HOST" <<'PY'
import sys, urllib.request
base = sys.argv[1]
text = urllib.request.urlopen(base + "/metrics", timeout=30).read().decode()
missing = [n for n in (
    "vllm:generation_tokens_total",
    "vllm:spec_decode_num_accepted_tokens_total",
) if n not in text]
if missing:
    sys.exit("FAIL: /metrics is missing: " + ", ".join(missing))
if "vllm:spec_decode_num_drafts_total" not in text:
    print("warn: vllm:spec_decode_num_drafts_total absent; verifier detail will be empty", file=sys.stderr)
print("metrics OK")
PY

# --------------------------------------------------------------------- monitor
echo "$(date +%s.%N) monitor-start" >> "$OUT_DIR/phases.tsv"
./monitor.sh "$MONITOR_SECONDS" "$OUT_DIR/monitor.tsv" &
MON_PID=$!
trap 'kill "$MON_PID" 2>/dev/null || true' EXIT

# ------------------------------------------------------------------------ bench
BENCH="$RECIPE_DIR/bench/llm_decode_bench.py"
COMMON=(--host "$HOST" --model "$MODEL_NAME" --display-mode plain --no-hw-monitor
        --no-resume --respect-eos --temperature 1 --token-targeting exact
        --max-tokens 8192 --decode-warmup-seconds 15 --kv-budget "$KV_CAPACITY")

drop_caches() {
  [[ "$DROP_CACHES" == 1 ]] || return 0
  sudo -n /usr/local/bin/ple-drop-caches
}

for i in 1 2 3 4 5; do
  if [[ $i -eq 1 ]]; then label=prefill; else label="prefill-$i"; fi
  echo "=== prefill window $i/5 ($label) ===" >&2
  echo "$(date +%s.%N) $label" >> "$OUT_DIR/phases.tsv"
  drop_caches
  # </dev/null: the script's startup update check prompts on a live stdin;
  # with /dev/null the prompt raises EOFError and is swallowed.
  python3 "$BENCH" "${COMMON[@]}" --prefill-only --prefill-contexts 32k \
    --prefill-duration 30 --prefill-metric client \
    --output "$OUT_DIR/$label.json" </dev/null
done
for i in 1 2 3 4 5; do
  echo "=== decode window $i/5 (C1 + C8) ===" >&2
  echo "$(date +%s.%N) decode-$i" >> "$OUT_DIR/phases.tsv"
  drop_caches
  python3 "$BENCH" "${COMMON[@]}" --skip-prefill --concurrency 1,8 \
    --contexts 0 --duration 30 \
    --output "$OUT_DIR/decode-$i.json" </dev/null
done

kill "$MON_PID" 2>/dev/null || true
wait "$MON_PID" 2>/dev/null || true
echo "Results in $OUT_DIR"