# Release Preparation: v0.1

## Purpose

This document is the release-facing companion to the milestone note.
It answers a different question:

> What should we communicate and check before tagging `v0.1`?

If you want the historical implementation snapshot, read:

- `docs/release/milestone_2026_03_bridge_bringup.md`

## Proposed Release Identity

| Item | Value |
|------|-------|
| Tag | `v0.1` |
| Scope | First stable bridge bring-up baseline |
| Audience | Internal baseline or early external technical share |

## Release Scope

### RTL Included

- `design/rtl/credit_mgr.sv`
- `design/rtl/cxs_fdi_link_ctrl.sv`
- `design/rtl/cxs_tx_if.sv`
- `design/rtl/cxs_rx_if.sv`
- `design/rtl/fdi_tx_if.sv`
- `design/rtl/fdi_rx_if.sv`
- `design/rtl/tx_path.sv`
- `design/rtl/rx_path.sv`
- `design/rtl/regs.sv`
- `design/rtl/lme_handler.sv`
- `design/rtl/ucie_cxs_fdi_top.sv`

### Verification Included

- module-level regressions
- top-level directed integration testbench
- parameter-matrix sanity regression
- Verilator top-level smoke

### Documentation Included

- architecture and submodule specifications
- RTL/TB checklists and execution plans
- automation flow documentation
- milestone note

## Release Readiness Checklist

Recommended checks before tagging:

- `make sim` passes
- `make regress` passes with `11/11 PASS`
- `make regress-matrix` passes with `10/10 PASS`
- `make verilate` passes
- `make synth` passes
- regression compile warnings remain `0`
- Verilator log warnings remain `0`
- root `README.md` and `README_zh.md` are in sync with current project state

## Validation Snapshot

Current expected validation state for `v0.1`:

| Item | Status |
|------|--------|
| `make sim` | PASS |
| `make regress` | `11/11 PASS` |
| `make regress-matrix` | `10/10 PASS` |
| `make verilate` | PASS |
| `make synth` | PASS |
| Regression compile warnings | `0` |
| Verilator log warnings | `0` |

## Release Summary Text

Recommended short release summary:

> First stable UCIe CXS-FDI bridge bring-up baseline with module RTL, top integration,
> directed verification, parameter-matrix regression, Verilator smoke, and Yosys synthesis flow.

## Suggested Tag Message

```text
v0.1: first stable UCIe CXS-FDI bridge bring-up baseline
```

## Suggested Git Commit Message

Short version:

```text
docs: prepare v0.1 bridge bring-up release note
```

Slightly fuller version:

```text
docs: add v0.1 release prep note and sync release references
```

## Suggested GitHub/GitLab Release Description

```md
## UCIe CXS-FDI Bridge Bring-up Baseline

This release marks the first stable bring-up baseline of the UCIe CXS-FDI bridge project.

### Included in this release
- bridge-oriented RTL modules
- module-level regression testbenches
- top-level directed integration testbench
- parameter-matrix regression
- Verilator top-level smoke
- Yosys synthesis flow

### Validation status
- `make sim`: PASS
- `make regress`: `11/11 PASS`
- `make regress-matrix`: `10/10 PASS`
- `make verilate`: PASS
- `make synth`: PASS
- regression compile warnings: `0`
- Verilator log warnings: `0`
```

## Known Boundaries

- verification is currently directed/regression oriented, not full random/UVM
- top-level coverage is strong for bring-up, but can still be expanded for more stress traffic
- CI is intentionally minimal and focused on OSS tool flows

## Recommended Follow-Up After Tagging

1. Expand parameterized traffic stress coverage.
2. Add more protocol assertions or binders.
3. Consider nightly or longer-running CI regressions.
