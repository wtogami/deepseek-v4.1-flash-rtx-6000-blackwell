#!/usr/bin/env python3
"""Compare a results/ run against the Karmic Kraken ds41 targets and analyze
the PCIe/system monitor for bottlenecks.

Usage: analyze.py RUN_DIR [--kv-capacity N]

Reads RUN_DIR/prefill*.json, RUN_DIR/decode-*.json, RUN_DIR/monitor.tsv and
RUN_DIR/phases.tsv, writes RUN_DIR/REPORT.md.

KK targets are from rtx6kpro/benchmarks/karmic-kraken-serving-samples.json
(ds41.kk), measured on Max-Q/325 W GPUs 5-8 with the same protocol.
"""
from __future__ import annotations

import argparse
import json
import statistics
import subprocess
import sys
from pathlib import Path

# PCIe Gen4 ceilings per direction (128b/130b): x8 ~15.75 GB/s, x16 ~31.5 GB/s.
# dmon reports MB/s (decimal), so: x8 ~15750, x16 ~31500.
# These maps are the legacy Dell Precision 7865 fallback; the live widths are
# per-slot, not per-host-model, so detect_pci() asks nvidia-smi first.
PCI_CEIL = {0: 15750, 1: 31500, 2: 31500, 3: 15750}
PCI_WIDTH = {0: "x8", 1: "x16", 2: "x16", 3: "x8"}


def detect_pci() -> tuple[dict[int, int], dict[int, str]]:
    """Return (ceiling_mb_s, width_label) per GPU index from live link state.
    PCIe link *width* persists at idle (only the generation downclocks), so a
    plain query is reliable. Falls back to the hardcoded maps if unavailable."""
    try:
        out = subprocess.run(
            ["nvidia-smi", "--query-gpu=index,pcie.link.width.current",
             "--format=csv,noheader,nounits"],
            capture_output=True, text=True, timeout=15,
        ).stdout
        widths = {}
        for line in out.strip().splitlines():
            idx, width = [x.strip() for x in line.split(",")]
            widths[int(idx)] = int(width)
        if widths:
            ceil = {i: (31500 if w >= 16 else 15750 if w == 8 else 31500 * w // 16)
                    for i, w in widths.items()}
            label = {i: f"x{w}" for i, w in widths.items()}
            return ceil, label
    except Exception:
        pass
    return PCI_CEIL, PCI_WIDTH



def load_kk(samples_path: str) -> dict:
    """KK targets are read from the samples JSON (single source of truth)."""
    p = Path(samples_path)
    if not p.exists():
        sys.exit(f"FAIL: KK samples file not found: {samples_path}")
    d = json.loads(p.read_text())
    kk = d["models"]["ds41"]["kk"]
    return {
        "c1_output_tps": kk["decode"]["1"]["output"]["median"],
        "c1_verifier_steps": kk["decode"]["1"]["verifier"]["median"],
        "c1_accepted_length": kk["decode"]["1"]["accepted_length"]["median"],
        "c8_output_tps": kk["decode"]["8"]["output"]["median"],
        "c8_verifier_steps": kk["decode"]["8"]["verifier"]["median"],
        "c8_accepted_length": kk["decode"]["8"]["accepted_length"]["median"],
        "kv_tokens": kk["logical_kv_capacity_tokens"],
        "prefill_32k_tps": statistics.median(w["tok_per_sec"] for w in kk["prefill_windows"]),
    }


def pct(ours: float, ref: float) -> str:
    if ref == 0:
        return "n/a"
    return f"{(ours - ref) / ref * 100:+.2f}%"


def collect(run: Path) -> dict:
    prefill_files = sorted(run.glob("prefill*.json"))
    decode_files = sorted(run.glob("decode-*.json"))
    if not prefill_files or not decode_files:
        sys.exit(f"FAIL: missing prefill/decode JSON in {run}")

    pre = []
    for f in prefill_files:
        d = json.loads(f.read_text())
        entry = (d.get("prefill") or {}).get("32768")
        if not entry:
            sys.exit(f"FAIL: {f.name} has no 32768 prefill entry")
        pre.append({"file": f.name, "tps": entry["tok_per_sec"],
                    "samples": entry["samples"], "prompt_tokens": entry["prompt_tokens"],
                    "ttft": entry["ttft_seconds"]})

    dec = {1: [], 8: []}
    for f in decode_files:
        d = json.loads(f.read_text())
        for r in d.get("results", []):
            if r.get("context_tokens") != 0:
                continue
            c = r.get("concurrency")
            if c not in dec:
                continue
            dec[c].append({
                "file": f.name,
                "tps": r.get("aggregate_tps", 0.0),
                "steps": r.get("server_steps_per_s", 0.0),
                "accept": r.get("server_accept_len_effective", 0.0),
                "source": r.get("aggregate_source", ""),
                "server_tokens": r.get("server_output_tokens", 0),
                "failure": r.get("failure_reason", ""),
                "invalid": r.get("failure_reason", "") != "" or r.get("aggregate_tps", 0) < 0,
            })
    for c in (1, 8):
        if len(dec[c]) != 5:
            print(f"warn: only {len(dec[c])} decode windows for C{c}", file=sys.stderr)
    return {"prefill": pre, "decode": dec}


def monitor_stats(run: Path) -> dict:
    mon = run / "monitor.tsv"
    phases = run / "phases.tsv"
    if not mon.exists():
        return {}
    lines = mon.read_text().splitlines()
    header = lines[0].split("\t")
    rows = []
    for ln in lines[1:]:
        v = ln.split("\t")
        if len(v) != len(header):
            continue
        rows.append(dict(zip(header, v)))

    def fnum(x):
        try:
            return float(x)
        except (TypeError, ValueError):
            return None

    # phase boundaries in monitor-relative seconds
    t0 = None
    if phases.exists():
        for ln in phases.read_text().splitlines():
            parts = ln.split()
            if len(parts) >= 2 and parts[1] == "monitor-start":
                t0 = float(parts[0])
    phase_bounds = {}
    if phases.exists() and t0 is not None:
        marks = []
        for ln in phases.read_text().splitlines():
            parts = ln.split()
            if len(parts) >= 2 and parts[1] not in ("monitor-start", "start"):
                marks.append((float(parts[0]) - t0, parts[1]))
        marks.sort()
        for i, (t, name) in enumerate(marks):
            phase_bounds[name] = (t, marks[i + 1][0] if i + 1 < len(marks) else 1e9)

    def stats_for(sel):
        out = {}
        for g in (0, 1, 2, 3):
            tx = sorted(v for v in (fnum(r[f"p{g}_tx"]) for r in sel) if v is not None)
            rx = sorted(v for v in (fnum(r[f"p{g}_rx"]) for r in sel) if v is not None)
            util = [fnum(r[f"g{g}_util"]) for r in sel]
            pwr = [fnum(r[f"g{g}_pwr"]) for r in sel]
            clk = [fnum(r[f"g{g}_smclk"]) for r in sel]
            mem = [fnum(r[f"g{g}_mem"]) for r in sel]
            def q(a, p):
                if not a:
                    return None
                k = (len(a) - 1) * p
                f = int(k)
                c = min(f + 1, len(a) - 1)
                return a[f] + (a[c] - a[f]) * (k - f)
            out[g] = {
                "tx_max": max(tx) if tx else None, "tx_p95": q(tx, 0.95), "tx_mean": statistics.mean(tx) if tx else None,
                "rx_max": max(rx) if rx else None, "rx_p95": q(rx, 0.95), "rx_mean": statistics.mean(rx) if rx else None,
                "util_max": max(util) if util else None,
                "pwr_max": max(pwr) if pwr else None,
                "clk_max": max(clk) if clk else None,
                "mem_max": max(mem) if mem else None,
            }
        load = [fnum(r["load1"]) for r in sel]
        memav = [fnum(r["memavail_kb"]) for r in sel]
        out["load1_max"] = max(load) if load else None
        out["memavail_min"] = min(memav) if memav else None
        return out

    result = {"overall": stats_for(rows), "phases": {}}
    for name, (lo, hi) in phase_bounds.items():
        sel = [r for r in rows if lo <= (fnum(r["t"]) or -1) < hi]
        if sel:
            result["phases"][name] = stats_for(sel)
    # decode-active: any GPU util > 50
    active = [r for r in rows if any((fnum(r[f"g{g}_util"]) or 0) > 50 for g in (0, 1, 2, 3))]
    if active:
        result["decode_active"] = stats_for(active)
    return result


def fmt(v, unit="", nd=1):
    if v is None:
        return "n/a"
    return f"{v:,.{nd}f}{unit}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("run_dir")
    ap.add_argument("--kv-capacity", type=int, default=None)
    ap.add_argument("--samples", default="/home/opencode/rtx6kpro/benchmarks/karmic-kraken-serving-samples.json")
    args = ap.parse_args()
    run = Path(args.run_dir)
    kk = load_kk(args.samples)
    data = collect(run)
    mon = monitor_stats(run)

    pre_tps = [p["tps"] for p in data["prefill"]]
    pre_med = statistics.median(pre_tps)
    c1 = data["decode"][1]
    c8 = data["decode"][8]

    L = []
    L.append(f"# {run.name} — results vs Karmic Kraken\n")
    L.append(f"Protocol: llm_decode_bench.py v0.6.2 (sha256-pinned, see bench/PROVENANCE.md), "
             f"5 warmed 30 s windows per cell, 15 s warmup, 32K unique prefill (client TTFT), "
             f"context-zero decode C1/C8, server-side /metrics accounting.\n")
    L.append("## Headline\n")
    L.append("| Cell | Ours (median of 5) | KK (Max-Q/325W) | Delta |")
    L.append("|---|---:|---:|---:|")
    L.append(f"| 32K prefill tok/s | {pre_med:,.0f} | {kk['prefill_32k_tps']:,.0f} | {pct(pre_med, kk['prefill_32k_tps'])} |")
    if c1:
        L.append(f"| C1 output tok/s | {statistics.median([c['tps'] for c in c1]):,.1f} | {kk['c1_output_tps']:,.1f} | {pct(statistics.median([c['tps'] for c in c1]), kk['c1_output_tps'])} |")
        L.append(f"| C1 verifier steps/s | {statistics.median([c['steps'] for c in c1]):,.2f} | {kk['c1_verifier_steps']:,.2f} | {pct(statistics.median([c['steps'] for c in c1]), kk['c1_verifier_steps'])} |")
        L.append(f"| C1 accepted length | {statistics.median([c['accept'] for c in c1]):,.3f} | {kk['c1_accepted_length']:,.3f} | {pct(statistics.median([c['accept'] for c in c1]), kk['c1_accepted_length'])} |")
    if c8:
        L.append(f"| C8 output tok/s | {statistics.median([c['tps'] for c in c8]):,.1f} | {kk['c8_output_tps']:,.1f} | {pct(statistics.median([c['tps'] for c in c8]), kk['c8_output_tps'])} |")
        L.append(f"| C8 verifier steps/s | {statistics.median([c['steps'] for c in c8]):,.2f} | {kk['c8_verifier_steps']:,.2f} | {pct(statistics.median([c['steps'] for c in c8]), kk['c8_verifier_steps'])} |")
        L.append(f"| C8 accepted length | {statistics.median([c['accept'] for c in c8]):,.3f} | {kk['c8_accepted_length']:,.3f} | {pct(statistics.median([c['accept'] for c in c8]), kk['c8_accepted_length'])} |")
    if args.kv_capacity:
        L.append(f"| KV capacity tokens | {args.kv_capacity:,} | {kk['kv_tokens']:,} | {pct(args.kv_capacity, kk['kv_tokens'])} |")
    L.append("")

    L.append("## Per-window samples\n")
    L.append("| file | prefill tok/s | samples |")
    L.append("|---|---:|---:|")
    for p in data["prefill"]:
        L.append(f"| {p['file']} | {p['tps']:,.0f} | {p['samples']} |")
    L.append("")
    for c, label in ((1, "C1"), (8, "C8")):
        rows = data["decode"][c]
        if not rows:
            continue
        L.append(f"| file | {label} output tok/s | verifier steps/s | accepted length | source |")
        L.append("|---|---:|---:|---:|---|")
        for r in rows:
            L.append(f"| {r['file']} | {r['tps']:,.1f} | {r['steps']:,.2f} | {r['accept']:,.3f} | {r['source']} |")
        L.append("")

    if mon:
        pci_ceil, pci_width = detect_pci()
        L.append("## PCIe and system (monitor.tsv)\n")
        widths_desc = ", ".join(f"GPU {g} {pci_width.get(g, '?')}" for g in sorted(pci_width))
        L.append(f"Gen4 ceilings per direction (detected live: {widths_desc}).\n")
        L.append("| scope | GPU | width | tx max | tx p95 | tx mean | rx max | rx p95 | rx mean | util max | pwr max | clk max | mem max |")
        L.append("|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
        for scope in ("overall", "decode_active", *sorted(mon.get("phases", {}))):
            s = mon.get(scope) if scope in ("overall", "decode_active") else mon.get("phases", {}).get(scope)
            if not s:
                continue
            for g in (0, 1, 2, 3):
                gs = s[g]
                tx_pct = (gs["tx_max"] / pci_ceil[g] * 100) if gs["tx_max"] else 0
                rx_pct = (gs["rx_max"] / pci_ceil[g] * 100) if gs["rx_max"] else 0
                L.append(f"| {scope} | {g} | {pci_width[g]} | {fmt(gs['tx_max'], ' MB/s', 0)} ({tx_pct:.0f}%) | {fmt(gs['tx_p95'], ' MB/s', 0)} | {fmt(gs['tx_mean'], ' MB/s', 0)} | {fmt(gs['rx_max'], ' MB/s', 0)} ({rx_pct:.0f}%) | {fmt(gs['rx_p95'], ' MB/s', 0)} | {fmt(gs['rx_mean'], ' MB/s', 0)} | {fmt(gs['util_max'], ' %', 0)} | {fmt(gs['pwr_max'], ' W', 0)} | {fmt(gs['clk_max'], ' MHz', 0)} | {fmt(gs['mem_max'], ' MiB', 0)} |")
        L.append("")
        L.append(f"load1 max: {fmt(mon.get('overall', {}).get('load1_max'))}   "
                 f"MemAvailable min: {fmt(mon.get('overall', {}).get('memavail_min'), ' kB', 0)}\n")

    (run / "REPORT.md").write_text("\n".join(L))
    print(f"REPORT.md written to {run / 'REPORT.md'}")


if __name__ == "__main__":
    main()