# Provenance and changes from the original recipe

This project started from the DeepSeek V4.1 serving recipe in
[local-inference-lab/rtx6kpro](https://github.com/local-inference-lab/rtx6kpro)
(`models/deepseek-v4.1-flash.md`). The upstream recipe remains the reference for
the model profile, image lineage, and the Karmic Kraken measurement methodology.
Everything this project changed is listed here.

## Image lineage and pinned sampling

The image is `ghcr.io/local-inference-lab/vllm:karmic-kraken-beta`. Its
`ds41-flash` profile drifts from the measured serving configuration on two
values (`top_p` 1.0 vs 0.95, probabilistic vs greedy draft sampling), so
`start.sh` pins the measured values with two native CLI overrides after the
image. `DRY_RUN=1 ./start.sh` prints the launcher's resolved plan for auditing.

## Checkpoint identity

`config.json` sha256 `8be45ce0…`, `tokenizer_config.json` `6ac8c8dc…` — these
match the Karmic Kraken measurement artifacts. The flat checkpoint is the
original `deepseek-ai/DeepSeek-V4.1-Flash` layout; the CSF container (archived,
see [EXPERIMENTS.md](EXPERIMENTS.md)) is a separate download.

## Deviations

- **Two-shot mid-band default.** `TWOSHOT_MB=6` raises the B12X two-shot
  ceiling to cover the whole 96 KiB..6 MiB band (the image profile ships
  `off`). Measured +4.8% C8 verifier steps/s; prefill and C1 unchanged
  (`results/twoshot-AB.md`).
- **CSF checkpoint tested, not adopted.** `CSF=1` served the lossless FP4-CSF
  container (compressed expert scales, byte-identical weights) for more KV
  capacity. The A/B measured neutral throughput and +28–33% KV, but greedy
  outputs differed and the option keeps the four-card requirement; the measured
  three-card path uses fewer cards with quality checks passing. Archived in
  [EXPERIMENTS.md](EXPERIMENTS.md); `scripts/csf-download.sh`,
  `scripts/csf-switch.sh` and `scripts/csf-ab.sh` remain to reproduce the A/B.
- **Host P2P prerequisites documented and required.** Resizable BAR with
  BAR1 >= 96 GiB, `ForceP2P=0x11;RMForceP2PType=1;RMPcieP2PType=2;GrdmaPciTopoCheckOverride=1;EnableResizableBar=1`,
  and `nvidia_uvm uvm_disable_hmm=1`. Without them the B12X oneshot/two-shot
  path silently stages through SysMem while `cudaMemcpy`/NCCL still look
  healthy. Measured +7.4% C8 verifier steps/s after enabling.
- **P2P gate in `start.sh`.** Three checks before launch: ASPM
  `[performance]`, CUDA peer access on all 12 ordered pairs, and an NCCL
  transport check requiring every channel `via P2P/` (server runs with
  `NCCL_P2P_LEVEL=PHB`). Details in [OPERATIONS.md](OPERATIONS.md#p2p-gate).
- **Memlock gate.** RAM Engram needs ~189 GiB of locked memory; the script
  refuses a doomed launch when the host `RLIMIT_MEMLOCK` hard limit is too
  low. Details in [OPERATIONS.md](OPERATIONS.md#memlock).
- **CDI spec regeneration.** The rootless CDI spec is regenerated on every
  start so it always matches the current hardware, enumeration and device
  nodes; stale `/dev` paths after a module reload or reboot cannot break
  container injection. Restrict devices with `GPU=`, which selects CDI
  entities at run time.
- **Measured sampling values pinned.** `top_p=0.95` and greedy draft sampling
  are passed as native CLI overrides because the image profile defaults
  drifted from the measured configuration.
- **Comparison and option modes.** `MAX_MODEL_LEN=131072` for the Karmic Kraken
  comparison; `ENGRAM_TABLE_MEMORY=disk` for the disk-backed table.
- **Pinned measurement harness.** `run-bench.sh` runs the exact Karmic Kraken
  script (sha256-pinned in `bench/`) and `analyze.py` regenerates the
  comparison report.

## Additional provenance

- KK protocol + targets: `rtx6kpro/benchmarks/karmic-kraken-serving.md`,
  `karmic-kraken-serving-samples.json`
- Image: `ghcr.io/local-inference-lab/vllm:karmic-kraken-beta`
- Checkpoint identity: `config.json` sha256 `8be45ce0…`,
  `tokenizer_config.json` `6ac8c8dc…` — match the KK measurement artifacts
