#!/usr/bin/env bash
# Download the pinned lossless FP4-CSF container and verify its integrity.
#
#   ./scripts/csf-download.sh [--dry-run] [--no-hash-verify]
#
# The Hugging Face client verifies every LFS file against the Hub while
# downloading; the extra verification below checks the container's manifest,
# metadata and per-file SHA-256 against lil-manifest.json. The download is
# resumable (hf re-uses completed files).
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

CSF_REPO="${CSF_REPO:-local-inference-lab/DeepSeek-V4.1-Flash-1017-lossless-CSF}"
CSF_REVISION="${CSF_REVISION:-90d665c19e1a9ff2097cc787515e370d86b616f0}"
CSF_DIRECTORY="${CSF_DIRECTORY:-/nvme1/models/DeepSeek-V4.1-Flash-1017-lossless-CSF}"
DRY_RUN="${DRY_RUN:-0}"
VERIFY_HASHES="${VERIFY_HASHES:-1}"
MIN_FREE_GIB="${MIN_FREE_GIB:-520}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --no-hash-verify) VERIFY_HASHES=0; shift ;;
    *) die "unknown argument: $1 (usage: $0 [--dry-run] [--no-hash-verify])" ;;
  esac
done

require_cmd hf
require_cmd python3
require_cmd df

parent="$(dirname "$CSF_DIRECTORY")"
mkdir -p "$parent"
avail_kb="$(df -Pk "$parent" | awk 'NR==2 {print $4}')"
avail_gib=$(( avail_kb / 1024 / 1024 ))
log "target: $CSF_DIRECTORY (${avail_gib} GiB free on $parent)"
(( avail_gib >= MIN_FREE_GIB )) || die "need at least ${MIN_FREE_GIB} GiB free on $parent (have ${avail_gib} GiB)"

if csf_complete "$CSF_DIRECTORY"; then
  log "CSF container already complete; skipping download"
else
  log "download: $CSF_REPO @ $CSF_REVISION"
  if [[ "$DRY_RUN" == 1 ]]; then
    log "dry-run: would run: hf download $CSF_REPO --revision $CSF_REVISION --local-dir $CSF_DIRECTORY"
  else
    acquire_lock csf-download
    hf download "$CSF_REPO" --revision "$CSF_REVISION" --local-dir "$CSF_DIRECTORY"
  fi
fi

if [[ "$DRY_RUN" == 1 ]]; then
  log "dry-run: would verify manifest, metadata and tensor sizes"
  exit 0
fi

python3 - "$CSF_DIRECTORY" "$VERIFY_HASHES" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
verify_hashes = sys.argv[2] == "1"

def fail(msg: str) -> None:
    print(f"VERIFY FAIL: {msg}", file=sys.stderr)
    raise SystemExit(1)

manifest_path = root / "manifest.json"
contract_path = root / "build-contract.json"
if not manifest_path.is_file():
    fail(f"{manifest_path} is missing")
if not contract_path.is_file():
    fail(f"{contract_path} is missing")

manifest = json.loads(manifest_path.read_text())
contract = json.loads(contract_path.read_text())
if manifest.get("schema") != "lil-mxfp4-csf-checkpoint/1":
    fail(f"unexpected manifest schema: {manifest.get('schema')!r}")
if contract.get("schema") != manifest.get("schema"):
    fail("manifest and build-contract schemas differ")
if contract.get("family") != "deepseek_v41":
    fail(f"unexpected checkpoint family: {contract.get('family')!r}")
if manifest.get("family") != contract.get("family"):
    fail("manifest and build-contract families differ")

index_path = root / "metadata" / "model.safetensors.index.json"
if not index_path.is_file():
    fail(f"{index_path} is missing")
json.loads(index_path.read_text())

missing = []
for name, expected in (manifest.get("metadata_sha256") or {}).items():
    path = root / "metadata" / name
    if not path.is_file():
        missing.append(str(path))
        continue
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    if digest != expected:
        fail(f"metadata hash mismatch: {path}")
if missing:
    fail("missing metadata files: " + ", ".join(missing))

shards = manifest.get("shards") or []
if not shards:
    fail("manifest lists no tensor shards")
for shard in shards:
    path = root / "tensors" / shard["file"]
    if not path.is_file():
        fail(f"missing tensor shard: {path}")
    expected = shard.get("target_file_bytes")
    if expected is not None and path.stat().st_size != expected:
        fail(f"size mismatch: {path} ({path.stat().st_size} != {expected})")
print(f"manifest/metadata/sizes OK: {len(shards)} tensor shards", file=sys.stderr)

if verify_hashes:
    lil_path = root / "lil-manifest.json"
    if not lil_path.is_file():
        fail(f"{lil_path} is missing")
    lil = json.loads(lil_path.read_text())
    entries = [e for e in lil.get("files", []) if e.get("path", "").startswith("tensors/")]
    if not entries:
        fail("lil-manifest.json lists no tensor files")
    for n, entry in enumerate(entries, 1):
        path = root / entry["path"]
        if not path.is_file():
            fail(f"missing file: {path}")
        if path.stat().st_size != entry.get("size"):
            fail(f"size mismatch: {path}")
        digest = hashlib.sha256()
        with path.open("rb") as fh:
            for chunk in iter(lambda: fh.read(64 * 1024 * 1024), b""):
                digest.update(chunk)
        if digest.hexdigest() != entry.get("sha256"):
            fail(f"sha256 mismatch: {path}")
        print(f"  [{n}/{len(entries)}] {entry['path']} OK", file=sys.stderr)
    print(f"all tensor SHA-256 values match lil-manifest.json ({len(entries)} files)", file=sys.stderr)
else:
    print("hash verification skipped (--no-hash-verify)", file=sys.stderr)
PY

log "CSF container verified at $CSF_DIRECTORY"
