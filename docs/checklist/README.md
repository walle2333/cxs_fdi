# Checklist Index

本目录用于集中管理 UCIe CXS-FDI Bridge 的实现与验证检查清单。

## 变更记录 / Change Log

| 版本 | 日期 | 变更描述 |
|------|------|----------|
| v0.1 | 2026-03-21 | 初始版本，建立 checklist 目录索引 |

## 文档索引

- `docs/checklist/rtl_tb_verification_checklist.md`
  - RTL 与 testbench 的总览型检查表
  - 适合做项目启动和阶段性评审

- `docs/checklist/rtl_implementation_checklist.md`
  - 面向 RTL 编写的实现清单
  - 重点覆盖接口、状态机、CDC、参数约束与集成前自检

- `docs/checklist/tb_execution_plan.md`
  - 面向验证实施的执行计划
  - 重点覆盖分阶段推进、覆盖目标和退出准则

- `docs/checklist/tb_task_breakdown.md`
  - 面向 testbench 落地的任务拆解文档
  - 重点覆盖 `sim/tb` 文件映射、每个 TB 的实现任务与优先级

## 建议使用方式

1. 先阅读 `docs/checklist/rtl_tb_verification_checklist.md` 建立总体视图
2. RTL 编写时使用 `docs/checklist/rtl_implementation_checklist.md`
3. 验证规划和执行时使用 `docs/checklist/tb_execution_plan.md`
4. 编写 testbench 时使用 `docs/checklist/tb_task_breakdown.md`

## 相关规格

- `docs/specification/ucie_cxs_fdi_arch_spec.md`
- `docs/specification/cxs_tx_if_spec.md`
- `docs/specification/cxs_rx_if_spec.md`
- `docs/specification/fdi_tx_if_spec.md`
- `docs/specification/fdi_rx_if_spec.md`
- `docs/specification/tx_path_spec.md`
- `docs/specification/rx_path_spec.md`
- `docs/specification/credit_mgr_spec.md`
- `docs/specification/cxs_fdi_link_ctrl_spec.md`
- `docs/specification/lme_handler_spec.md`
- `docs/specification/regs_spec.md`
