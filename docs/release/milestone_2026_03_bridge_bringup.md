# 2026-03 Bridge Bring-up Milestone

## Purpose

This document is a milestone snapshot for the March 2026 bridge bring-up stage.
It answers one question:

> What has already been implemented and validated at this point?

If you want a pre-release checklist or tagging guidance, read:

- `docs/release/release_prep_v0_1.md`

## Milestone Summary

The repository has moved from an early proof-of-concept into a stable bridge-style RTL and
verification baseline for the UCIe CXS-FDI project.

At this milestone, the project includes:

- a bridge-oriented RTL decomposition under `design/rtl`
- module-level and top-level SystemVerilog testbenches under `sim/tb`
- project automation for simulation, regression, parameter-matrix regression, Verilator smoke,
  and Yosys synthesis
- synchronized specs, checklists, flow docs, and root README files

## Implemented Deliverables

### RTL Modules

Implemented RTL at this milestone:

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

### Verification Assets

Implemented testbenches at this milestone:

- `sim/tb/credit_mgr_tb.sv`
- `sim/tb/cxs_fdi_link_ctrl_tb.sv`
- `sim/tb/cxs_tx_if_tb.sv`
- `sim/tb/cxs_rx_if_tb.sv`
- `sim/tb/fdi_tx_if_tb.sv`
- `sim/tb/fdi_rx_if_tb.sv`
- `sim/tb/tx_path_tb.sv`
- `sim/tb/rx_path_tb.sv`
- `sim/tb/regs_tb.sv`
- `sim/tb/lme_handler_tb.sv`
- `sim/tb/ucie_cxs_fdi_top_tb.sv`

### Automation and CI

Available and validated project entry points:

- `make sim`
- `make regress`
- `make regress-matrix`
- `make verilate`
- `make synth`

CI baseline:

- `.github/workflows/ci.yml`

## Validation Snapshot

Current validated status at this milestone:

| Item | Status |
|------|--------|
| `make sim` | PASS |
| `make regress` | `11/11 PASS` |
| `make regress-matrix` | `10/10 PASS` |
| `make verilate` | PASS |
| `make synth` | PASS |
| Regression compile warnings | `0` |
| Verilator log warnings | `0` |

## Top-Level Coverage Snapshot

`sim/tb/ucie_cxs_fdi_top_tb.sv` currently covers:

- APB sanity and register access
- hardware-triggered link activation, deactivation, retrain, and error
- software-triggered `LINK_CTRL.SW_*` activation, deactivation, and retrain
- TX/RX single-flit data paths
- TX/RX burst data paths
- credit boundary exhaust and recovery
- RX `flit_cancel` discard path
- LME normal negotiation
- LME error paths:
  - `PARAM_REJECT`
  - unknown opcode
  - timeout
  - remote `ERROR_MSG`
  - illegal `ACTIVE_ACK`
- sideband backpressure behavior
- `ERROR_STOP_EN=0` timeout behavior
- `FDI_RX_ACTIVE_FOLLOW_EN` behavior via top-level `fdi_pl_rx_active_req`
- long-running protocol monitors/checks

## Parameter Matrix Snapshot

Current built-in matrix cases:

- `default`
- `fifo64_last0`
- `fifo128_last1`
- `fifo256_last1`
- `opt_fields_off`
- `single_pkt_mode`
- `credit8_fifo64`
- `user128`
- `srcids_off`
- `user32`

## Documentation State

The following document sets are aligned with this milestone baseline:

- `docs/specification/`
- `docs/checklist/`
- `docs/flow/automation_flow.md`
- `README.md`
- `README_zh.md`

## Engineering Improvements Completed In This Milestone

Notable cleanup and process improvements delivered along the way:

- coding guidance for cleaner `always_comb` structure and signal extraction in
  `docs/coding_standards/coding_guide.md`
- Icarus warning cleanup to `0` regression compile warnings
- Verilator warning cleanup to `0` warning/error markers in `sim/logs/verilator.log`
- CI-friendly regression outputs:
  - `sim/logs/regress.summary`
  - `sim/logs/regress_status.csv`
  - `sim/logs/regress_status.json`
  - `sim/logs/regress_junit.xml`

## Suggested Next Steps

Recommended follow-up work after this milestone:

1. Strengthen top-level parameterized traffic scenarios further.
2. Add more explicit assertion or binder-style protocol checks.
3. Extend CI/reporting for longer regressions or nightly jobs.
4. Prepare a formal tagged release baseline for external sharing.
