#!/usr/bin/env bash
# Overnight CSF A/B: original vs lossless FP4-CSF, at the KK context and at 1M.
#
#   ./scripts/csf-ab.sh [--dry-run] [--resume RUN_ID]
#
# Sequence (each arm: fresh boot, greedy probe, 5-window KK bench, analysis):
#   A-131k  original @ 131072
#   B-131k  CSF      @ 131072
#   A-1m    original @ -1 (1M)
#   B-1m    CSF      @ -1 (1M)
# Then compares the pairs, writes results/<run>/csf-AB.md, and leaves the
# winner running at 1M. Re-run with --resume RUN_ID to continue an interrupted
# run; completed arms are skipped.
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

RUN_ID=""
DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --resume) RUN_ID="${2:?--resume needs a run id}"; shift 2 ;;
    *) die "unknown argument: $1 (usage: $0 [--dry-run] [--resume RUN_ID])" ;;
  esac
done
RUN_ID="${RUN_ID:-csf-ab-$(date +%Y%m%d-%H%M%S)}"

ORIGINAL_DIRECTORY="${ORIGINAL_DIRECTORY:-$HOME/models/DeepSeek-V4.1-Flash}"
CSF_DIRECTORY="${CSF_DIRECTORY:-/nvme1/models/DeepSeek-V4.1-Flash-1017-lossless-CSF}"
KK_CAP="${KK_CAP:-131072}"
ONE_M_CAP="${ONE_M_CAP:--1}"
POWER_LIMIT="${POWER_LIMIT:-325}"

OUT="$RECIPE_DIR/results/$RUN_ID"
LOGS="$OUT/logs"
PHASES="$OUT/phases.done"
if [[ "$DRY_RUN" == 1 ]]; then
  : # dry run: do not create run artifacts
else
  mkdir -p "$LOGS"
  touch "$PHASES"
fi

phase_done() { grep -qx "$1" "$PHASES" 2>/dev/null; }
mark_done() { echo "$1" >> "$PHASES"; }

KV=""

preflight() {
  require_cmd podman
  require_cmd curl
  require_cmd python3
  require_unlimited_memlock

  local layout
  layout="$(checkpoint_layout "$ORIGINAL_DIRECTORY")"
  if [[ "$layout" != flat ]]; then
    if [[ "$DRY_RUN" == 1 ]]; then
      log "WARN: original checkpoint at $ORIGINAL_DIRECTORY is '$layout' (expected flat)"
    else
      die "original checkpoint at $ORIGINAL_DIRECTORY is '$layout'; expected the flat original checkpoint"
    fi
  fi

  layout="$(checkpoint_layout "$CSF_DIRECTORY")"
  if [[ "$layout" != csf ]]; then
    if [[ "$DRY_RUN" == 1 ]]; then
      log "WARN: CSF container at $CSF_DIRECTORY is '$layout'; run scripts/csf-download.sh first"
    else
      die "CSF container at $CSF_DIRECTORY is '$layout'; run scripts/csf-download.sh first"
    fi
  elif ! csf_complete "$CSF_DIRECTORY"; then
    if [[ "$DRY_RUN" == 1 ]]; then
      log "WARN: CSF container at $CSF_DIRECTORY is incomplete; run scripts/csf-download.sh"
    else
      die "CSF container at $CSF_DIRECTORY is incomplete; run scripts/csf-download.sh"
    fi
  fi

  local free_kb
  free_kb="$(df -Pk "$RECIPE_DIR" | awk 'NR==2 {print $4}')"
  (( free_kb > 1024 * 1024 )) || die "less than 1 GiB free for results under $RECIPE_DIR"

  if command -v nvidia-smi >/dev/null 2>&1; then
    # Comparison integrity: the A/B is only valid at one power envelope. The
    # limits persist across reboots only if something re-applies them, and a
    # reboot resets them (Max-Q 300 W, Workstation 600 W). Accept the current
    # state when it already matches; otherwise try to set it; otherwise stop.
    local limits mismatch=0
    limits="$(nvidia-smi --query-gpu=index,power.limit --format=csv,noheader,nounits 2>/dev/null || true)"
    while IFS=, read -r idx limit; do
      idx="${idx// /}"; limit="${limit// /}"
      [[ -n "$idx" ]] || continue
      if awk -v a="$limit" -v b="$POWER_LIMIT" 'BEGIN { exit !(a+0 == b+0) }'; then
        continue
      fi
      mismatch=1
      sudo -n nvidia-smi -i "$idx" -pl "$POWER_LIMIT" >/dev/null 2>&1 \
        || log "WARN: GPU $idx is at ${limit} W and could not be set to ${POWER_LIMIT} W (no passwordless sudo)"
    done <<< "$limits"

    limits="$(nvidia-smi --query-gpu=index,power.limit,power.default_limit --format=csv,noheader 2>/dev/null || true)"
    log "power limits (index, limit, default):"
    printf '%s\n' "$limits" | while IFS= read -r line; do log "  $line"; done
    if [[ "$DRY_RUN" != 1 ]]; then
      printf '%s\n' "$limits" >> "$LOGS/power.txt"
    fi

    if [[ "$mismatch" == 1 ]]; then
      while IFS=, read -r idx limit; do
        idx="${idx// /}"; limit="${limit// /}"
        [[ -n "$idx" ]] || continue
        awk -v a="$limit" -v b="$POWER_LIMIT" 'BEGIN { exit !(a+0 == b+0) }' && continue
        if [[ "${ALLOW_POWER_MISMATCH:-0}" != 1 ]]; then
          die "GPU $idx is at ${limit} W, not ${POWER_LIMIT} W; the A/B would compare different power envelopes. Fix it (sudo nvidia-smi -i $idx -pl ${POWER_LIMIT}) or set ALLOW_POWER_MISMATCH=1."
        fi
      done <<< "$(nvidia-smi --query-gpu=index,power.limit --format=csv,noheader,nounits 2>/dev/null || true)"
    fi
  fi
}

start_arm() {
  local mode="$1" cap="$2" tag="$3"
  local key="arm-$tag"
  if phase_done "$key"; then
    log "skip $key (already completed)"
    return 0
  fi

  log "=== $key: $mode @ MAX_MODEL_LEN=$cap ==="
  local csfflag=0
  [[ "$mode" == csf ]] && csfflag=1

  ( cd "$RECIPE_DIR" && REPLACE=1 CSF="$csfflag" MAX_MODEL_LEN="$cap" ./start.sh ) \
    2>&1 | tee "$LOGS/start-$tag.log"
  wait_health 60 || die "$key: engine did not become healthy"

  KV="$(kv_capacity)"
  [[ -n "$KV" ]] || die "$key: could not read KV capacity from the engine log"
  log "$key: KV capacity $KV tokens"

  if [[ "$mode" == csf ]]; then
    csf_loader_active \
      || die "$key: engine did not report mxfp4_csf in its startup configuration"
    log "$key: mxfp4_csf loader confirmed"
  fi

  python3 "$SCRIPT_DIR/greedy_probe.py" --output "$OUT/greedy-$tag.json" \
    2>&1 | tee "$LOGS/greedy-$tag.log"

  ( cd "$RECIPE_DIR" && KV_CAPACITY="$KV" NAME="$RUN_ID-$tag" ./run-bench.sh ) \
    2>&1 | tee "$LOGS/bench-$tag.log"

  ( cd "$RECIPE_DIR" && python3 analyze.py "results/$RUN_ID-$tag" --kv-capacity "$KV" ) \
    2>&1 | tee -a "$LOGS/bench-$tag.log"

  [[ -s "$RECIPE_DIR/results/$RUN_ID-$tag/REPORT.md" ]] \
    || die "$key: REPORT.md was not produced"
  mark_done "$key"
}

finish() {
  log "=== comparing arms ==="
  python3 "$SCRIPT_DIR/csf_report.py" --run-id "$RUN_ID" --run-dir "$OUT" \
    2>&1 | tee "$LOGS/report.log"

  local winner
  winner="$(cat "$OUT/winner")"
  log "winner: $winner"
  if [[ "$winner" == csf ]]; then
    log "restarting CSF at 1M"
    ( cd "$RECIPE_DIR" && REPLACE=1 CSF=1 MAX_MODEL_LEN="$ONE_M_CAP" ./start.sh ) \
      2>&1 | tee "$LOGS/final-start.log"
  else
    log "restoring the original checkpoint at 1M"
    ( cd "$RECIPE_DIR" && REPLACE=1 CSF=0 MAX_MODEL_LEN="$ONE_M_CAP" ./start.sh ) \
      2>&1 | tee "$LOGS/final-start.log"
  fi
  wait_health 60 || die "final engine did not become healthy"
  log "final engine healthy; KV $(kv_capacity) tokens"
  log "report: $OUT/csf-AB.md"
}

preflight
log "run id: $RUN_ID"
log "results: $OUT"
log "original: $ORIGINAL_DIRECTORY"
log "csf: $CSF_DIRECTORY"
log "caps: KK=$KK_CAP 1M=$ONE_M_CAP"

if [[ "$DRY_RUN" == 1 ]]; then
  log "dry-run plan:"
  log "  1) original @ $KK_CAP  (greedy + bench)"
  log "  2) csf      @ $KK_CAP  (greedy + bench)"
  log "  3) original @ $ONE_M_CAP (greedy + bench)"
  log "  4) csf      @ $ONE_M_CAP (greedy + bench)"
  log "  5) compare, write $OUT/csf-AB.md, leave winner at $ONE_M_CAP"
  exit 0
fi

acquire_lock csf-ab
trap 'log "FAILED at line $LINENO; logs: $LOGS"' ERR

cat > "$OUT/run.env" <<EOF
run_id=$RUN_ID
original=$ORIGINAL_DIRECTORY
csf=$CSF_DIRECTORY
kk_cap=$KK_CAP
one_m_cap=$ONE_M_CAP
started=$(date -Is)
EOF

start_arm original "$KK_CAP" A-131k
start_arm csf "$KK_CAP" B-131k
start_arm original "$ONE_M_CAP" A-1m
start_arm csf "$ONE_M_CAP" B-1m
finish
