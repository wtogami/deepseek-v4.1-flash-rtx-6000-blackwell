#!/usr/bin/env python3
"""Build the Flare TP3 comparison report from the benchmark JSON files.

  python3 scripts/flare-tp3/report.py \
      --recipe  results/flare-tp3-<stamp> \
      --ours    results/flare-tp3-baseline-<stamp> \
      --vllm    results/rebar325-cool-131072 \
      [--kv <tokens>] [--out results/flare-tp3-<stamp>/REPORT.md]

--recipe  is the run from scripts/flare-tp3/bench.sh (llm-inference-bench
          v0.9.1, the recipe's cells).
--ours    is the run from scripts/flare-tp3/bench-baseline.sh (the pinned
          v0.6.2 cells every other result in results/ uses).
--vllm    is the four-GPU vLLM baseline measured with the same --ours protocol.
"""
import argparse
import glob
import json
import re
import statistics
import sys
from pathlib import Path


def load(path):
    try:
        with open(path) as fh:
            return json.load(fh)
    except (OSError, ValueError) as exc:
        print(f"warn: cannot read {path}: {exc}", file=sys.stderr)
        return None


def prefill_tok_s(doc, ctx):
    """tok_per_sec for one prefill context key (8192 / 32768 / 131072)."""
    if not doc:
        return None
    entry = (doc.get("prefill") or {}).get(str(ctx))
    return entry.get("tok_per_sec") if entry else None


def decode_cell(doc, concurrency, context=None):
    """The decode result row for one cell, as a dict of the fields we report."""
    if not doc:
        return None
    for r in doc.get("results", []):
        if r.get("concurrency") != concurrency:
            continue
        if context is not None and r.get("context_tokens") not in (context, None):
            continue
        out = {
            "tok_s": r.get("aggregate_tps"),
            "steps_s": r.get("server_steps_per_s"),
            "accept": r.get("server_spec_accept_length"),
            "flare_steps_s": None,
            "flare_tok_step": None,
        }
        f = r.get("server_flare_metrics") or {}
        c = f.get("counter_delta") or {}
        if f.get("valid") and c.get("verification_graphs"):
            out["flare_steps_s"] = f.get("verification_graphs_per_second")
            out["flare_tok_step"] = c.get("raw_emitted_tokens", 0) / c["verification_graphs"]
            out["flare_accept"] = f.get("raw_draft_acceptance")
        return out
    return None


def median_of(directory, pattern, extractor):
    values = []
    for path in sorted(glob.glob(str(Path(directory) / pattern))):
        doc = load(path)
        if doc is None:
            continue
        value = extractor(doc)
        if value:
            values.append(value)
    if not values:
        return None, 0
    return statistics.median(values), len(values)


def fmt(value, spec="{:,.1f}"):
    return spec.format(value) if isinstance(value, (int, float)) else "—"


def row(label, ours, base, spec="{:,.1f}", better_high=True):
    delta = "—"
    if isinstance(ours, (int, float)) and isinstance(base, (int, float)) and base:
        pct = (ours / base - 1) * 100
        delta = f"{pct:+.2f}%"
    return f"| {label} | {fmt(ours, spec)} | {fmt(base, spec)} | {delta} |"


def read_text(path):
    try:
        return Path(path).read_text(errors="replace")
    except OSError:
        return ""


def kv_from(directory):
    if not directory:
        return None
    text = read_text(Path(directory) / "kv.txt").strip()
    if text:
        try:
            return int(float(text))
        except ValueError:
            pass
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--recipe", type=Path, help="bench.sh results directory")
    ap.add_argument("--ours", type=Path, help="bench-baseline.sh results directory")
    ap.add_argument("--vllm", type=Path, required=True, help="four-GPU vLLM baseline directory")
    ap.add_argument("--kv", type=int, help="Flare KV capacity in tokens")
    ap.add_argument("--recipe-published", action="store_true",
                    help="compare against the recipe's published numbers too")
    ap.add_argument("--out", type=Path, help="write Markdown here instead of stdout")
    args = ap.parse_args()

    lines = []
    add = lines.append

    # ---------------------------------------------------------------- vLLM side
    v_prefill, v_n = median_of(args.vllm, "prefill*.json", lambda d: prefill_tok_s(d, 32768))
    v_c1, v_c1n = median_of(args.vllm, "decode-*.json", lambda d: (decode_cell(d, 1) or {}).get("tok_s"))
    v_c8, v_c8n = median_of(args.vllm, "decode-*.json", lambda d: (decode_cell(d, 8) or {}).get("tok_s"))
    v_c1s, _ = median_of(args.vllm, "decode-*.json", lambda d: (decode_cell(d, 1) or {}).get("steps_s"))
    v_c8s, _ = median_of(args.vllm, "decode-*.json", lambda d: (decode_cell(d, 8) or {}).get("steps_s"))
    v_c1a, _ = median_of(args.vllm, "decode-*.json", lambda d: (decode_cell(d, 1) or {}).get("accept"))
    v_c8a, _ = median_of(args.vllm, "decode-*.json", lambda d: (decode_cell(d, 8) or {}).get("accept"))
    v_kv = kv_from(args.vllm)
    v_meta = (load(Path(args.vllm) / "prefill.json") or {}).get("metadata", {})

    # ---------------------------------------------------------------- Flare ours
    f_prefill, f_n = (None, 0)
    if args.ours:
        f_prefill, f_n = median_of(args.ours, "prefill*.json", lambda d: prefill_tok_s(d, 32768))
    f_c1, f_c1n = (None, 0)
    f_c8, f_c8n = (None, 0)
    if args.ours:
        f_c1, f_c1n = median_of(args.ours, "decode-*.json", lambda d: (decode_cell(d, 1) or {}).get("tok_s"))
        f_c8, f_c8n = median_of(args.ours, "decode-*.json", lambda d: (decode_cell(d, 8) or {}).get("tok_s"))

    # -------------------------------------------------------------- Flare recipe
    r_doc = load(args.recipe / "decode-32k.json") if args.recipe else None
    p_doc = load(args.recipe / "prefill.json") if args.recipe else None
    recipe_prefill = {ctx: prefill_tok_s(p_doc, ctx) for ctx in (8192, 32768, 131072)}
    recipe_decode = {c: decode_cell(r_doc, c, context=32768) for c in (1, 4, 8)}

    add("# Flare TP3 vs the four-GPU vLLM engine")
    add("")
    add(f"Baseline arm: `{args.vllm}` "
        f"({v_n or '?'} prefill windows, {v_c1n or '?'} decode windows, "
        f"harness {v_meta.get('bench_version', v_meta.get('version', 'unknown'))}).")
    if args.ours:
        add(f"Flare on our protocol: `{args.ours}`.")
    if args.recipe:
        add(f"Flare on the recipe protocol: `{args.recipe}`.")
    add("")

    add("## Like-for-like (our pinned v0.6.2 cells)")
    add("")
    add("Same harness, same cells, same power limit: four GPUs on vLLM versus three "
        "GPUs on Flare. Decode is context-zero at 30 s per concurrency; prefill is a "
        "cold 32K prompt measured by client TTFT.")
    add("")
    add("| Cell | Flare TP3 (3 GPUs) | vLLM TP4 (4 GPUs) | Delta |")
    add("|---|---:|---:|---:|")
    add(row("32K prefill tok/s", f_prefill, v_prefill))
    add(row("C1 decode tok/s", f_c1, v_c1))
    add(row("C8 decode tok/s", f_c8, v_c8))
    add("")

    if any(v for v in recipe_prefill.values()) or any(recipe_decode.values()):
        add("## Recipe protocol (llm-inference-bench v0.9.1)")
        add("")
        add("| Cell | This run | Recipe published |")
        add("|---|---:|---:|")
        published = {8192: None, 32768: 12548, 131072: 12160}
        for ctx, value in recipe_prefill.items():
            add(f"| prefill {ctx // 1024}K tok/s | {fmt(value, '{:,.0f}')} | {fmt(published.get(ctx), '{:,.0f}')} |")
        pub_decode = {1: 254, 4: 595, 8: 805}
        for conc, cell in recipe_decode.items():
            tok_s = (cell or {}).get("tok_s")
            add(f"| decode 32K C{conc} tok/s | {fmt(tok_s)} | ~{pub_decode[conc]} |")
        add("")
        add("| Cell | steps/s | tokens/step | draft acceptance |")
        add("|---|---:|---:|---:|")
        pub_steps = {1: "93.8", 4: "62.0", 8: "48.1"}
        for conc, cell in recipe_decode.items():
            if not cell:
                add(f"| decode 32K C{conc} | — | — | — |")
                continue
            steps = cell.get("flare_steps_s") or cell.get("steps_s")
            tps = cell.get("flare_tok_step")
            acc = cell.get("flare_accept") or cell.get("accept")
            add(f"| decode 32K C{conc} | {fmt(steps)} | {fmt(tps, '{:.2f}')} | {fmt(acc, '{:.2f}')} |")
        add("")

    if v_c1s or v_c8s:
        add("## vLLM baseline detail")
        add("")
        add("| Cell | tok/s | verifier steps/s | accepted length |")
        add("|---|---:|---:|---:|")
        add(f"| C1 | {fmt(v_c1)} | {fmt(v_c1s)} | {fmt(v_c1a, '{:.3f}')} |")
        add(f"| C8 | {fmt(v_c8)} | {fmt(v_c8s)} | {fmt(v_c8a, '{:.3f}')} |")
        add("")

    kv = args.kv or kv_from(args.recipe) or kv_from(args.ours)
    if kv or v_kv:
        add("## KV capacity")
        add("")
        add(f"- Flare TP3: {fmt(kv, '{:,.0f}')} tokens")
        add(f"- vLLM TP4 at `MAX_MODEL_LEN=131072`: {fmt(v_kv, '{:,.0f}')} tokens")
        add(f"- vLLM TP4 at `MAX_MODEL_LEN=-1` (1M): 9,718,137 tokens")
        add("")

    if args.recipe:
        vf = read_text(args.recipe / "verify-fix.log")
        m = re.search(r"TRUE corruptions\s+(\d+)", vf)
        if m:
            add("## Correctness")
            add("")
            add(f"- `tools/verify_fix.py 10`: TRUE corruptions {m.group(1)} "
                f"(the recipe requires 0)")
            add("")

    for label, directory in (("before", "gpu-before.txt"), ("after", "gpu-after.txt")):
        if args.ours and (Path(args.ours) / directory).is_file():
            text = read_text(args.ours / directory).strip()
            if text:
                add(f"## GPU state ({label})")
                add("")
                add("```")
                add(text)
                add("```")
                add("")

    out = "\n".join(lines) + "\n"
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(out)
        print(f"wrote {args.out}", file=sys.stderr)
    else:
        sys.stdout.write(out)


if __name__ == "__main__":
    main()
