# 2026-03 Bridge Bring-up 里程碑记录

## 文档用途

这份文档用于记录 2026 年 3 月 bridge bring-up 阶段的里程碑状态，回答的问题是：

> 到当前阶段为止，项目已经实现并验证了什么？

如果你想看发版前检查项或 tag 前沟通内容，请阅读：

- `docs/release/release_prep_v0_1_zh.md`

## 里程碑摘要

仓库已经从早期 PoC 演进为一个稳定的、面向 bridge 的 UCIe CXS-FDI RTL 与验证基线。

在这个里程碑阶段，项目已经具备：

- `design/rtl` 下较完整的 bridge 化 RTL 模块拆分
- `sim/tb` 下模块级与顶层级 SystemVerilog testbench
- 包含仿真、回归、参数矩阵回归、Verilator smoke、Yosys 综合的自动化入口
- 与实现状态对齐的规格、checklist、flow 文档以及根目录 README

## 已实现交付物

### RTL 模块

本阶段已实现的 RTL 模块：

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

### 验证资产

本阶段已实现的 testbench：

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

### 自动化与 CI

当前已具备并验证通过的入口：

- `make sim`
- `make regress`
- `make regress-matrix`
- `make verilate`
- `make synth`

CI 基线：

- `.github/workflows/ci.yml`

## 验证状态快照

当前里程碑对应的验证状态：

| 项目 | 状态 |
|------|------|
| `make sim` | PASS |
| `make regress` | `11/11 PASS` |
| `make regress-matrix` | `10/10 PASS` |
| `make verilate` | PASS |
| `make synth` | PASS |
| Regression 编译 warning | `0` |
| Verilator 日志 warning | `0` |

## 顶层覆盖快照

`sim/tb/ucie_cxs_fdi_top_tb.sv` 当前覆盖：

- APB 基础访问与寄存器检查
- 硬件触发的 link activation / deactivation / retrain / error
- 软件触发的 `LINK_CTRL.SW_*` activation / deactivation / retrain
- TX/RX 单 flit 数据通路
- TX/RX burst 数据通路
- credit 边界耗尽与恢复
- RX `flit_cancel` 丢弃路径
- LME 正常 negotiation
- LME 错误路径：
  - `PARAM_REJECT`
  - unknown opcode
  - timeout
  - remote `ERROR_MSG`
  - illegal `ACTIVE_ACK`
- sideband backpressure
- `ERROR_STOP_EN=0` timeout 行为
- 通过顶层真实端口 `fdi_pl_rx_active_req` 验证 `FDI_RX_ACTIVE_FOLLOW_EN`
- 长期协议检查/监视项

## 参数矩阵快照

当前内置参数矩阵 case：

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

## 文档对齐状态

当前已与实现基线对齐的文档集合：

- `docs/specification/`
- `docs/checklist/`
- `docs/flow/automation_flow.md`
- `README.md`
- `README_zh.md`

## 本阶段完成的工程改进

在这个里程碑阶段，还完成了以下工程性改进：

- 在 `docs/coding_standards/coding_guide.md` 中固化了更清晰的 `always_comb` 组织与信号提取规则
- 将 Icarus regression 编译 warning 清到 `0`
- 将 Verilator `sim/logs/verilator.log` 中的 warning/error marker 清到 `0`
- 补齐 CI 友好的 regression 输出：
  - `sim/logs/regress.summary`
  - `sim/logs/regress_status.csv`
  - `sim/logs/regress_status.json`
  - `sim/logs/regress_junit.xml`

## 下一步建议

建议在这个里程碑之后继续推进：

1. 继续加强顶层参数化流量场景。
2. 增加更明确的 assertion / binder 风格协议检查。
3. 扩展更长时长的回归或 nightly CI。
4. 准备正式 tag 的稳定基线。
