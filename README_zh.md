# UCIe CXS-FDI 数字设计

[English](README.md) | **简体中文**

[![Language](https://img.shields.io/badge/Language-SystemVerilog-blue.svg)](https://ieeexplore.ieee.org/document/8299595)
[![Simulator](https://img.shields.io/badge/Simulator-Icarus%20Verilog-green.svg)](http://iverilog.icarus.com/)
[![Synthesis](https://img.shields.io/badge/Synthesis-Yosys-orange.svg)](http://www.clifford.at/yosys/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Status](https://img.shields.io/badge/Regression-11%2F11%20PASS-brightgreen.svg)](#当前进度)
[![Status](https://img.shields.io/badge/Sim-PASS-brightgreen.svg)](#当前进度)
[![Status](https://img.shields.io/badge/Synth-PASS-brightgreen.svg)](#当前进度)
[![Status](https://img.shields.io/badge/Verilate-PASS-brightgreen.svg)](#当前进度)

这是一个基于 SystemVerilog、Icarus Verilog 和 Yosys 的开源 UCIe CXS-FDI Bridge RTL 与验证项目。

## 项目概览

这个仓库已经从早期的 PoC 演进成一个小而完整的 bridge 型工程，当前包含：

- `design/rtl` 下 12 个 RTL 模块
- `sim/tb` 下 11 个 SystemVerilog testbench
- `docs/specification` 下的总体与子模块规格文档
- `docs/checklist` 下的实现与验证检查清单
- `Makefile` 中的项目级仿真、回归与综合入口

当前工程主要覆盖这些功能块：

- CXS TX/RX 接口
- FDI TX/RX 接口
- 顶层 `fdi_pl_rx_active_req` 真实接口接入，用于 FDI RX-active follow 行为
- TX/RX 数据通路
- credit 管理
- link control
- 寄存器模块
- LME sideband 处理
- 顶层集成与错误路径验证

## 当前进度

目前项目已经进入比较稳定的 bring-up 阶段。

- `make sim`：PASS
- `make regress`：PASS
- `make synth`：PASS
- `make verilate`：PASS
- 模块级回归：`11/11 PASS`
- 参数矩阵回归：`10/10 PASS`
- regression 编译 warning：`0`
- Verilator 日志 warning：`0`

当前已实现的 RTL 模块：

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

当前已有的 testbench：

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

顶层 `ucie_cxs_fdi_top_tb` 当前已覆盖：

- APB 基础访问与寄存器检查
- 硬件触发与软件触发的 link activation、deactivation、retrain、error 流程
- TX/RX 单 flit 通路
- TX/RX burst 通路
- credit 边界的耗尽与恢复
- RX `flit_cancel` 丢弃路径
- LME 正常 negotiation
- LME `PARAM_REJECT`、unknown opcode、timeout、remote `ERROR_MSG`
- 非法 `ACTIVE_ACK`
- `ERROR_STOP_EN=0` 的 timeout 行为
- 通过真实顶层 `fdi_pl_rx_active_req` 验证 `FDI_RX_ACTIVE_FOLLOW_EN` 的激活行为
- sideband backpressure 与长期协议检查

## 快速开始

### 环境要求

建议安装 [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build)，并加入 `PATH`：

```bash
export PATH="$HOME/oss-cad-suite/bin:$PATH"
```

需要的工具包括：

- `iverilog`
- `vvp`
- `verilator`
- `yosys`
- `gtkwave`

### 常用命令

```bash
# 运行顶层 directed 仿真
make sim

# 运行全部模块和顶层回归
make regress

# 运行顶层参数矩阵回归
make regress-matrix

# 构建并运行 Verilator 顶层 smoke
make verilate

# 对 ucie_cxs_fdi_top 做综合
make synth

# 清理生成的仿真产物
make clean
```

### CI

仓库中已经加入了一个最小可用的 GitHub Actions 工作流：

- `.github/workflows/ci.yml`

当前会执行：

- `make sim`
- `make regress`
- `make regress-matrix`
- `make verilate`
- `make synth`

并上传：

- regression 摘要和各 testbench 日志
- 综合日志与顶层综合网表

### 回归产物

执行 `make regress` 后，主要产物包括：

- `sim/logs/regress.summary`
- `sim/logs/regress_status.csv`
- `sim/logs/regress_status.json`
- `sim/logs/regress_junit.xml`
- `sim/logs` 下各个 testbench 的编译和运行日志

执行 `make regress-matrix` 后，主要产物包括：

- `sim/logs/regress_matrix.summary`
- `sim/logs/regress_matrix.csv`
- `sim/logs` 下参数矩阵各 case 的编译和运行日志

执行 `make verilate` 后，主要产物包括：

- `sim/logs/verilator.log`
- `sim/obj_dir/Vucie_cxs_fdi_top`
- `sim/waves/verilator_top.vcd`

当前 Verilator smoke 运行已经收敛到日志内 `0` 个 warning/error marker。

当前内置的参数矩阵 case 包括：

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


## Release 文档

与 release 相关的文档集中放在：

- `docs/release/README.md`

推荐入口：

- 里程碑快照：`docs/release/milestone_2026_03_bridge_bringup.md`
- 发布准备：`docs/release/release_prep_v0_1.md`

## 项目结构

```text
.
├── design/rtl/              # RTL 源文件
├── sim/tb/                  # 模块级与顶层 testbench
├── sim/build/               # 编译后的仿真产物
├── sim/logs/                # 回归和仿真日志
├── frontend/synthesis/      # Yosys 网表和日志
├── docs/specification/      # 总体与子模块规格
├── docs/checklist/          # RTL/TB 检查清单与执行计划
├── docs/coding_standards/   # 编码规范
├── docs/flow/               # 自动化流程文档
├── scripts/                 # 工具脚本
└── Makefile                 # sim / regress / synth 入口
```

## 文档导航

不同用途建议从这里开始：

- 总体与模块规格：
  - `docs/specification/ucie_cxs_fdi_arch_spec.md`
  - `docs/specification/*.md`
- 编码规范：
  - `docs/coding_standards/coding_guide.md`
- 构建与自动化流程：
  - `docs/flow/automation_flow.md`
- Release 文档入口：
  - `docs/release/README.md`
- 里程碑记录：
  - `docs/release/milestone_2026_03_bridge_bringup.md`
- 发布准备：
  - `docs/release/release_prep_v0_1.md`
- 验证规划：
  - `docs/checklist/README.md`
  - `docs/checklist/rtl_tb_verification_checklist.md`
  - `docs/checklist/tb_execution_plan.md`

## 开发说明

项目当前的重要约定：

- 统一使用 SystemVerilog，优先 `logic`、`always_ff`、`always_comb`
- 低有效复位统一使用 `_n` 后缀
- 信号和模块采用 `lowercase_with_underscore`
- 参数采用 `UPPERCASE_WITH_UNDERSCORE`
- `always_comb` 保持小而清晰，按功能拆分
- 纯位提取和简单切片优先用 `assign`

完整规则请参考 `docs/coding_standards/coding_guide.md`。

## 建议工作流

1. 先读 `docs/specification/ucie_cxs_fdi_arch_spec.md`
2. 再读对应子模块 spec
3. 参考 `docs/checklist/rtl_implementation_checklist.md` 开始实现
4. 修改前后都运行 `make regress`
5. 必要时查看 `sim/logs/regress.summary` 和详细日志
6. 涉及顶层集成时再运行 `make synth`

## 许可证

本项目采用 MIT License，详见 `LICENSE`。

## 致谢

- [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build)
- [Icarus Verilog](http://iverilog.icarus.com/)
- [Yosys](http://www.clifford.at/yosys/)
- [UCIe Consortium](https://www.ucie.org/)
