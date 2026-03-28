# Release Docs

This directory collects milestone and release-facing documents for the project.


## Current Status Snapshot

Current documented release baseline status:

- `make sim`: PASS
- `make regress`: `11/11 PASS`
- `make regress-matrix`: `10/10 PASS`
- `make verilate`: PASS
- `make synth`: PASS
- regression compile warnings: `0`
- Verilator log warnings: `0`

## Which File Should I Read?

Use this quick guide:

- If you want to know **what has already been implemented and validated**, read:
  - `docs/release/milestone_2026_03_bridge_bringup.md`
- If you want to know **what to check and communicate before tagging a release**, read:
  - `docs/release/release_prep_v0_1.md`

## Available Documents

### English
- `docs/release/milestone_2026_03_bridge_bringup.md`
  - milestone snapshot for the March 2026 bridge bring-up baseline
- `docs/release/release_prep_v0_1.md`
  - release preparation note for the proposed `v0.1` tag

### 中文
- `docs/release/milestone_2026_03_bridge_bringup_zh.md`
  - 2026 年 3 月 bridge bring-up 阶段里程碑记录
- `docs/release/release_prep_v0_1_zh.md`
  - `v0.1` 发布准备说明


## Naming And Update Rules

Use the following conventions for new files in this directory:

- milestone snapshots:
  - `milestone_YYYY_MM_<topic>.md`
  - `milestone_YYYY_MM_<topic>_zh.md`
- release preparation notes:
  - `release_prep_vX_Y.md`
  - `release_prep_vX_Y_zh.md`

Recommended maintenance rules:

- update milestone notes when a major implementation/verification stage is completed
- update release prep notes when validation status, release scope, or release messaging changes
- keep English and Chinese files aligned when the content is intended for both audiences

## Suggested Reading Order

1. `docs/release/milestone_2026_03_bridge_bringup.md`
2. `docs/release/release_prep_v0_1.md`

For Chinese readers:

1. `docs/release/milestone_2026_03_bridge_bringup_zh.md`
2. `docs/release/release_prep_v0_1_zh.md`
