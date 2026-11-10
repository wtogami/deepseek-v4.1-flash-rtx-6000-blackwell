#!/usr/bin/env python3
"""Build the CSF A/B report and decide whether CSF is equal-or-better.

Reads the four KK-protocol REPORT.md files produced by scripts/csf-ab.sh,
extracts the headline cells, compares the greedy determinism probes, writes
<run-dir>/csf-AB.md and <run-dir>/decision.json, and stores the winner in
<run-dir>/winner for the caller to leave running.
"""
import argparse
import json
import re
import sys
from pathlib import Path

CELLS = [
    ("prefill", "32K prefill tok/s"),
    ("c1_out", "C1 output tok/s"),
    ("c1_ver", "C1 verifier steps/s"),
    ("c8_out", "C8 output tok/s"),
    ("c8_ver", "C8 verifier steps/s"),
    ("kv", "KV capacity tokens"),
]
THROUGHPUT = ["prefill", "c1_out", "c1_ver", "c8_out", "c8_ver"]
NOISE = 0.015  # 1.5%: measured same-config run-to-run floor on this box


def parse_report(path: Path) -> dict[str, float]:
    if not path.is_file():
        sys.exit(f"missing report: {path}")
    values: dict[str, float] = {}
    for line in path.read_text().splitlines():
        if not line.startswith("|"):
            continue
        parts = [p.strip() for p in line.strip().strip("|").split("|")]
        if len(parts) < 2:
            continue
        label, ours = parts[0], parts[1]
        for key, wanted in CELLS:
            if label == wanted:
                try:
                    values[key] = float(ours.replace(",", ""))
                except ValueError:
                    sys.exit(f"cannot parse '{ours}' for {wanted} in {path}")
    missing = [wanted for _, wanted in CELLS if _ not in values]
    if missing:
        sys.exit(f"{path} is missing headline rows: {', '.join(missing)}")
    return values


def delta(a: float, b: float) -> str:
    return f"{(b / a - 1.0) * 100:+.2f}%"


def greedy_ok(path_a: Path, path_b: Path) -> tuple[bool, str]:
    if not path_a.is_file() or not path_b.is_file():
        return False, "probe files missing"
    a = json.loads(path_a.read_text())["text"]
    b = json.loads(path_b.read_text())["text"]
    if a == b:
        return True, "identical"
    first = next((i for i, (x, y) in enumerate(zip(a, b)) if x != y), min(len(a), len(b)))
    return False, f"differs at character {first}: {a[first:first + 40]!r} vs {b[first:first + 40]!r}"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--run-id", required=True)
    ap.add_argument("--run-dir", required=True)
    args = ap.parse_args()

    run_dir = Path(args.run_dir)
    base = Path(__file__).resolve().parent.parent / "results"
    reports = {
        "A131": base / f"{args.run_id}-A-131k" / "REPORT.md",
        "B131": base / f"{args.run_id}-B-131k" / "REPORT.md",
        "A1M": base / f"{args.run_id}-A-1m" / "REPORT.md",
        "B1M": base / f"{args.run_id}-B-1m" / "REPORT.md",
    }
    data = {name: parse_report(path) for name, path in reports.items()}

    greedy = {}
    for cap, a_tag, b_tag in (("131k", "A-131k", "B-131k"), ("1m", "A-1m", "B-1m")):
        ok, detail = greedy_ok(run_dir / f"greedy-{a_tag}.json", run_dir / f"greedy-{b_tag}.json")
        greedy[cap] = (ok, detail)

    # Explicit keys (avoid clever name construction mistakes).
    a131, b131 = data["A131"], data["B131"]
    a1m, b1m = data["A1M"], data["B1M"]
    ok_131 = b131["kv"] >= a131["kv"] and all(b131[k] >= a131[k] * (1.0 - NOISE) for k in THROUGHPUT)
    ok_1m = b1m["kv"] >= a1m["kv"] and all(b1m[k] >= a1m[k] * (1.0 - NOISE) for k in THROUGHPUT)
    winner = "csf" if (ok_131 and ok_1m and greedy["131k"][0] and greedy["1m"][0]) else "original"

    lines = [
        f"# CSF A/B — {args.run_id}",
        "",
        "Same engine, same TP4/DSpark configuration and KK protocol; only the "
        "checkpoint layout differs (original flat MXFP4 vs lossless FP4-CSF). "
        "Each cell is the median of five 30 s windows.",
        "",
        "| Cell | Original 131K | CSF 131K | Δ | Original 1M | CSF 1M | Δ |",
        "|---|---:|---:|---:|---:|---:|---:|",
    ]
    for key, label in CELLS:
        lines.append(
            f"| {label} | {a131[key]:,.0f} | {b131[key]:,.0f} | {delta(a131[key], b131[key])} "
            f"| {a1m[key]:,.0f} | {b1m[key]:,.0f} | {delta(a1m[key], b1m[key])} |"
        )
    lines += [
        "",
        "## Determinism (greedy, fixed prompt, seed 1234)",
        "",
        f"- 131K: {'IDENTICAL' if greedy['131k'][0] else 'DIFFERS'} — {greedy['131k'][1]}",
        f"- 1M: {'IDENTICAL' if greedy['1m'][0] else 'DIFFERS'} — {greedy['1m'][1]}",
        "",
        "## Decision",
        "",
        f"- 131K pair equal-or-better (1.5% noise floor, KV >= original): {'PASS' if ok_131 else 'FAIL'}",
        f"- 1M pair equal-or-better: {'PASS' if ok_1m else 'FAIL'}",
        f"- Greedy outputs identical: {'PASS' if greedy['131k'][0] and greedy['1m'][0] else 'FAIL'}",
        "",
        f"**Winner: {winner.upper()}** — the script leaves the engine running on "
        f"the winner at `MAX_MODEL_LEN=-1` (1M thinking configuration).",
        "",
    ]
    (run_dir / "csf-AB.md").write_text("\n".join(lines))
    (run_dir / "decision.json").write_text(json.dumps({
        "run_id": args.run_id,
        "winner": winner,
        "ok_131k": ok_131,
        "ok_1m": ok_1m,
        "greedy_131k": greedy["131k"][0],
        "greedy_1m": greedy["1m"][0],
        "data": data,
    }, indent=1) + "\n")
    (run_dir / "winner").write_text(winner + "\n")
    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main())
