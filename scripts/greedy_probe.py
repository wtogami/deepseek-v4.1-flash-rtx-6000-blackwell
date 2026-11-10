#!/usr/bin/env python3
"""Greedy determinism probe for the CSF A/B.

Sends one fixed completion request with temperature 0 and a fixed seed,
stores the response text, and is used to compare the original and CSF
checkpoints byte-for-byte (CSF is lossless, so the outputs must match).
"""
import argparse
import json
import sys
import time
import urllib.request

# Plain-text prompt on purpose: a trailing "put it in a fenced block" style
# instruction makes this checkpoint emit an immediate EOS (empty completion)
# at temperature 0, which is a deterministic but useless comparison signal.
PROMPT = (
    "Write a Python function named sum_first_n that returns the sum of the "
    "first n positive integers."
)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="http://127.0.0.1:8000")
    ap.add_argument("--model", default="DeepSeek-V4.1-Flash")
    ap.add_argument("--max-tokens", type=int, default=96)
    ap.add_argument("--output", required=True)
    args = ap.parse_args()

    body = json.dumps({
        "model": args.model,
        "prompt": PROMPT,
        "max_tokens": args.max_tokens,
        "temperature": 0.0,
        "top_p": 1.0,
        "seed": 1234,
        "stream": False,
    }).encode()
    req = urllib.request.Request(
        args.host + "/v1/completions",
        data=body,
        headers={"Content-Type": "application/json"},
    )
    started = time.perf_counter()
    with urllib.request.urlopen(req, timeout=300) as resp:
        payload = json.load(resp)
    elapsed = time.perf_counter() - started
    choice = payload["choices"][0]
    text = choice["text"]

    # An empty completion is a comparison that proves nothing; retry once,
    # then fail loudly so the A/B stops instead of comparing blanks.
    if not text.strip():
        time.sleep(2)
        with urllib.request.urlopen(req, timeout=300) as resp:
            payload = json.load(resp)
        choice = payload["choices"][0]
        text = choice["text"]
        elapsed += time.perf_counter() - started
    if not text.strip():
        print("greedy probe returned an empty completion twice", file=sys.stderr)
        return 1

    record = {
        "prompt": PROMPT,
        "text": text,
        "finish_reason": choice.get("finish_reason"),
        "usage": payload.get("usage"),
        "seconds": elapsed,
    }
    with open(args.output, "w", encoding="utf-8") as fh:
        json.dump(record, fh, indent=1, ensure_ascii=False)
        fh.write("\n")
    print(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
