#!/usr/bin/env bash
# 1 Hz TSV sample of per-GPU PCIe throughput, utilization, SM clocks, power,
# framebuffer use, plus host load and available RAM. Feeds the PCIe
# saturation analysis: Gen4 x8 ceiling is ~16 GB/s per direction (GPUs 0,3
# on this box), Gen4 x16 ~32 GB/s (GPUs 1,2). dmon reports MB/s.
#
# Usage: monitor.sh DURATION_SECONDS OUTFILE
# The file is append-only; a SIGTERM mid-run leaves a valid prefix.
set -euo pipefail
DURATION="${1:?usage: monitor.sh DURATION_SECONDS OUTFILE}"
OUT="${2:?usage: monitor.sh DURATION_SECONDS OUTFILE}"

command -v nvidia-smi >/dev/null 2>&1 || { echo "nvidia-smi is required" >&2; exit 2; }
[[ "$DURATION" =~ ^[0-9]+$ ]] || { echo "DURATION must be whole seconds" >&2; exit 2; }

# Units: p*_rx/p*_tx MB/s (dmon), g*_util %, g*_smclk MHz, g*_pwr W,
# g*_mem MiB, memavail_kb kB.
{
  printf 't\tp0_rx\tp0_tx\tp1_rx\tp1_tx\tp2_rx\tp2_tx\tp3_rx\tp3_tx\t'
  for g in 0 1 2 3; do printf 'g%s_util\tg%s_smclk\tg%s_pwr\tg%s_mem\t' "$g" "$g" "$g" "$g"; done
  printf 'load1\tmemavail_kb\n'
} > "$OUT"

declare -A rx tx
deadline=$((SECONDS + DURATION))
while (( SECONDS < deadline )); do
  t="$SECONDS"
  # One dmon sample: 2 header lines + one line per GPU (idx rx tx).
  while read -r idx r x _; do
    [[ "$idx" =~ ^[0-9]+$ ]] || continue
    rx[$idx]="$r"; tx[$idx]="$x"
  done < <(nvidia-smi dmon -s t -c 1 2>/dev/null || true)
  # One snapshot of util/clocks/power/memory per GPU.
  declare -A util smclk pwr mem
  i=0
  while IFS=', ' read -r u c p m; do
    [[ "$u" =~ ^[0-9]+$ ]] || continue
    util[$i]="$u"; smclk[$i]="$c"; pwr[$i]="$p"; mem[$i]="$m"; i=$((i + 1))
  done < <(nvidia-smi --query-gpu=utilization.gpu,clocks.sm,power.draw,memory.used --format=csv,noheader,nounits 2>/dev/null || true)
  load1="$(cut -d' ' -f1 /proc/loadavg)"
  memavail="$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)"
  {
    printf '%s\t' "$t"
    for g in 0 1 2 3; do printf '%s\t%s\t' "${rx[$g]:-NA}" "${tx[$g]:-NA}"; done
    for g in 0 1 2 3; do printf '%s\t%s\t%s\t%s\t' "${util[$g]:-NA}" "${smclk[$g]:-NA}" "${pwr[$g]:-NA}" "${mem[$g]:-NA}"; done
    printf '%s\t%s\n' "$load1" "$memavail"
  } >> "$OUT"
  sleep 1
done
echo "Monitor finished: $OUT" >&2