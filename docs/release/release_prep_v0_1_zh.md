# 发布准备：v0.1

## 文档用途

这份文档是里程碑记录的“发版配套版”，回答的问题是：

> 在打 `v0.1` tag 之前，我们应该检查什么、对外怎么描述？

如果你想看历史性的阶段实现快照，请阅读：

- `docs/release/milestone_2026_03_bridge_bringup_zh.md`

## 建议的发布身份

| 项目 | 内容 |
|------|------|
| Tag | `v0.1` |
| 范围 | 首个稳定的 bridge bring-up 基线 |
| 面向对象 | 内部稳定基线，或早期对外技术共享 |

## 发布范围

### 包含的 RTL

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

### 包含的验证能力

- 模块级 regression
- 顶层 directed integration testbench
- 参数矩阵 sanity regression
- Verilator 顶层 smoke

### 包含的文档

- 总体与子模块规格文档
- RTL/TB checklist 与执行计划
- 自动化 flow 文档
- milestone 记录

## 发版前检查清单

建议打 tag 前确认：

- `make sim` 通过
- `make regress` 通过，并保持 `11/11 PASS`
- `make regress-matrix` 通过，并保持 `10/10 PASS`
- `make verilate` 通过
- `make synth` 通过
- regression compile warnings 保持为 `0`
- Verilator log warnings 保持为 `0`
- 根目录 `README.md` 与 `README_zh.md` 已和当前工程状态同步

## 验证状态快照

当前 `v0.1` 预期验证状态：

| 项目 | 状态 |
|------|------|
| `make sim` | PASS |
| `make regress` | `11/11 PASS` |
| `make regress-matrix` | `10/10 PASS` |
| `make verilate` | PASS |
| `make synth` | PASS |
| Regression 编译 warning | `0` |
| Verilator 日志 warning | `0` |

## 建议的 Release Summary

推荐用于 release 页面或对外说明的简短摘要：

> 首个稳定的 UCIe CXS-FDI bridge bring-up 基线，包含模块级 RTL、顶层集成、
> directed 验证、参数矩阵回归、Verilator smoke 与 Yosys 综合流程。

## 建议的 Tag Message

```text
v0.1: first stable UCIe CXS-FDI bridge bring-up baseline
```

## 建议的 Git Commit Message

短版本：

```text
docs: prepare v0.1 bridge bring-up release note
```

稍完整版本：

```text
docs: add v0.1 release prep note and sync release references
```

## 建议的 GitHub/GitLab Release Description

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

## 已知边界

- 当前验证方式仍以 directed/regression 为主，不是完整 random/UVM 基线
- 顶层覆盖对 bring-up 已较充分，但仍可继续增强高压流量场景
- 当前 CI 仍是轻量级 OSS flow 导向

## Tag 后建议继续推进

1. 扩展参数化流量压力场景。
2. 增加更多协议 assertion / binder。
3. 评估 nightly 或更长时长回归。
