# UCIe CXS-FDI Digital Design

**English** | [简体中文](README_zh.md)

[![Language](https://img.shields.io/badge/Language-SystemVerilog-blue.svg)](https://ieeexplore.ieee.org/document/8299595)
[![Simulator](https://img.shields.io/badge/Simulator-Icarus%20Verilog-green.svg)](http://iverilog.icarus.com/)
[![Synthesis](https://img.shields.io/badge/Synthesis-Yosys-orange.svg)](http://www.clifford.at/yosys/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Status](https://img.shields.io/badge/Regression-11%2F11%20PASS-brightgreen.svg)](#current-status)
[![Status](https://img.shields.io/badge/Sim-PASS-brightgreen.svg)](#current-status)
[![Status](https://img.shields.io/badge/Synth-PASS-brightgreen.svg)](#current-status)
[![Status](https://img.shields.io/badge/Verilate-PASS-brightgreen.svg)](#current-status)

Open-source RTL and verification project for a UCIe CXS-FDI bridge built with SystemVerilog,
Icarus Verilog, and Yosys.

## Overview

This repository has evolved from an early proof-of-concept into a small but complete bridge-style
project with:

- 12 RTL modules under `design/rtl`
- 11 SystemVerilog testbenches under `sim/tb`
- architecture and submodule specifications under `docs/specification`
- implementation and verification checklists under `docs/checklist`
- project-level simulation, regression, and synthesis flows in `Makefile`

The current focus is a normalized UCIe CXS-FDI bridge shell covering:

- CXS TX/RX interfaces
- FDI TX/RX interfaces
- top-level `fdi_pl_rx_active_req` integration for FDI RX-active follow behavior
- TX/RX data paths
- credit management
- link control
- register block
- LME sideband handling
- integrated top-level bring-up and error-path verification

## Current Status

The project is currently in a healthy bring-up state.

- `make sim`: PASS
- `make regress`: PASS
- `make synth`: PASS
- `make verilate`: PASS
- module-level regressions: `11/11 PASS`
- parameter-matrix regressions: `10/10 PASS`
- regression compile warnings: `0`
- Verilator log warnings: `0`

Implemented RTL modules:

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
- `design/rtl/counter.sv`

Available testbenches:

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

Top-level `ucie_cxs_fdi_top_tb` currently covers:

- APB sanity and register access
- hardware- and software-triggered link activation, deactivation, retrain, and error transitions
- TX and RX single-flit paths
- TX and RX burst flows
- credit boundary consume/return behavior
- RX `flit_cancel` discard path
- LME normal negotiation
- LME `PARAM_REJECT`, unknown opcode, timeout, remote `ERROR_MSG`
- illegal `ACTIVE_ACK`
- `ERROR_STOP_EN=0` timeout behavior
- `FDI_RX_ACTIVE_FOLLOW_EN` activation behavior via real top-level `fdi_pl_rx_active_req`
- sideband backpressure and long-running protocol checks

## Quick Start

### Prerequisites

Install [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build) and add it to `PATH`:

```bash
export PATH="$HOME/oss-cad-suite/bin:$PATH"
```

Required tools:

- `iverilog` for simulation
- `vvp` for simulation runtime
- `verilator` for compiled smoke simulation
- `yosys` for synthesis
- `gtkwave` for waveform viewing

### Common Commands

```bash
# Run top-level directed simulation
make sim

# Run all module and top-level regressions
make regress

# Run top-level parameter matrix regression
make regress-matrix

# Build and run Verilator top-level smoke
make verilate

# Run synthesis for ucie_cxs_fdi_top
make synth

# Clean generated simulation artifacts
make clean
```

### CI

A minimal GitHub Actions workflow is included at:

- `.github/workflows/ci.yml`

It currently runs:

- `make sim`
- `make regress`
- `make regress-matrix`
- `make verilate`
- `make synth`

and uploads:

- regression summaries and per-testbench logs
- synthesis log and synthesized top netlist

### Regression Outputs

After `make regress`, the main outputs are:

- `sim/logs/regress.summary`
- `sim/logs/regress_status.csv`
- `sim/logs/regress_status.json`
- `sim/logs/regress_junit.xml`
- per-testbench compile and run logs in `sim/logs`

After `make regress-matrix`, the main outputs are:

- `sim/logs/regress_matrix.summary`
- `sim/logs/regress_matrix.csv`
- parameter-matrix compile and run logs in `sim/logs`

After `make verilate`, the main outputs are:

- `sim/logs/verilator.log`
- `sim/obj_dir/Vucie_cxs_fdi_top`
- `sim/waves/verilator_top.vcd`

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


## Release Notes

Release-oriented documents are collected under:

- `docs/release/README.md`

Recommended entry points:

- milestone snapshot: `docs/release/milestone_2026_03_bridge_bringup.md`
- release preparation: `docs/release/release_prep_v0_1.md`

## Project Layout

```text
.
├── design/rtl/              # RTL source files
├── sim/tb/                  # Module and top-level testbenches
├── sim/build/               # Compiled simulation outputs
├── sim/logs/                # Regression and simulation logs
├── frontend/synthesis/      # Yosys netlists and logs
├── docs/specification/      # Architecture and submodule specs
├── docs/checklist/          # RTL/TB checklists and execution plans
├── docs/coding_standards/   # Coding guide
├── docs/flow/               # Automation flow documentation
├── scripts/                 # Utility scripts
└── Makefile                 # sim / regress / synth entry points
```

## Documentation Guide

Start here depending on your goal:

- architecture and module specs:
  - `docs/specification/ucie_cxs_fdi_arch_spec.md`
  - `docs/specification/*.md`
- coding rules:
  - `docs/coding_standards/coding_guide.md`
- build and automation flow:
  - `docs/flow/automation_flow.md`
- release docs:
  - `docs/release/README.md`
- milestone note:
  - `docs/release/milestone_2026_03_bridge_bringup.md`
- release prep:
  - `docs/release/release_prep_v0_1.md`
- verification planning:
  - `docs/checklist/README.md`
  - `docs/checklist/rtl_tb_verification_checklist.md`
  - `docs/checklist/tb_execution_plan.md`

## Development Notes

Key project conventions:

- SystemVerilog only, with `logic`, `always_ff`, and `always_comb`
- active-low reset naming with `_n`
- lowercase_with_underscore for signals and modules
- uppercase_with_underscore for parameters
- keep `always_comb` blocks small and focused
- prefer `assign` for pure bit extraction and simple slicing

For full rules, see `docs/coding_standards/coding_guide.md`.

## Recommended Workflow

1. Read `docs/specification/ucie_cxs_fdi_arch_spec.md`
2. Read the relevant submodule spec in `docs/specification/`
3. Check implementation expectations in `docs/checklist/rtl_implementation_checklist.md`
4. Run `make regress` before and after changes
5. Review `sim/logs/regress.summary` and detailed logs if needed
6. Run `make synth` for top-level structural sanity when touching integration logic

## License

This project is licensed under the MIT License. See `LICENSE`.

## Acknowledgments

- [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build)
- [Icarus Verilog](http://iverilog.icarus.com/)
- [Yosys](http://www.clifford.at/yosys/)
- [UCIe Consortium](https://www.ucie.org/)
