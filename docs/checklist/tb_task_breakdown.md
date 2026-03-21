# UCIe CXS-FDI Testbench Task Breakdown

**文档编号**: [CHK-TB-TASK-001]  
**版本**: v0.1  
**日期**: 2026-03-21  
**状态**: Draft

---

## 变更记录 / Change Log

| 版本 | 日期 | 变更描述 |
|------|------|----------|
| v0.1 | 2026-03-21 | 初始版本，整理 testbench 任务分解 |

---

## 1. 目的 / Purpose

本文档将 `docs/checklist/tb_execution_plan.md` 的验证计划进一步拆解为可执行任务，
用于指导 `sim/tb` 下 testbench、checker、scoreboard 和覆盖率代码的逐步落地。

---

## 2. 建议目录映射 / Suggested TB Mapping

建议后续在 `sim/tb` 下逐步补齐：

- `sim/tb/credit_mgr_tb.sv` - 已创建 skeleton
- `sim/tb/cxs_fdi_link_ctrl_tb.sv` - 已创建 skeleton
- `sim/tb/regs_tb.sv` - 已创建 skeleton
- `sim/tb/tx_path_tb.sv` - 已创建 skeleton
- `sim/tb/rx_path_tb.sv` - 已创建 skeleton
- `sim/tb/cxs_tx_if_tb.sv` - 已创建 skeleton
- `sim/tb/cxs_rx_if_tb.sv` - 已创建 skeleton
- `sim/tb/fdi_tx_if_tb.sv` - 已创建 skeleton
- `sim/tb/fdi_rx_if_tb.sv` - 已创建 skeleton
- `sim/tb/lme_handler_tb.sv` - 已创建 skeleton，已补 message scoreboard 框架
- `sim/tb/ucie_cxs_fdi_top_tb.sv`

如后续需要公共组件，可增加：

- `sim/tb/common/`
- `sim/tb/common/tb_pkg.sv`
- `sim/tb/common/flit_scoreboard.sv`
- `sim/tb/common/msg_scoreboard.sv`
- `sim/tb/common/protocol_assertions.sv`

---

## 3. Phase 1 任务分解

### 3.1 credit_mgr_tb

实现任务：
- 建立基础 clock/reset
- 驱动 `tx_data_valid`、`rx_data_valid`
- 驱动 `cxs_tx_crdret`、`cxs_rx_crdret`
- 监测 `cxs_tx_crdgnt`、`cxs_rx_crdgnt`、`credit_ready`
- 监测 `status_tx_credit_cnt`、`status_rx_credit_cnt`

测试项：
- reset 初始化
- consume 到 0
- return 到 max
- 同拍 consume+return
- 超额 return
- 零 credit 下继续请求

断言项：
- credit 不下溢
- credit 不上溢
- `credit_ready` 与计数一致

### 3.2 cxs_fdi_link_ctrl_tb

实现任务：
- 驱动 `cxs_*_active_req`、`cxs_*_deact_hint`
- 驱动 `fdi_pl_state_sts`、`fdi_pl_rx_active_req`
- 驱动 `credit_ready`
- 驱动 `link_ctrl_reg`
- 监测 `link_status`、`link_active`、`link_error`

测试项：
- 正常激活
- 正常停用
- Retrain 进入/退出
- timeout
- auto retry
- `ERROR_STOP_EN=0`
- `FDI_RX_ACTIVE_FOLLOW_EN=0/1`

断言项：
- `link_active -> RUN`
- `link_error -> ERROR`
- STOP 状态输出拉低

### 3.3 regs_tb

实现任务：
- 构建 APB 访问任务
- 驱动状态/事件/错误输入
- 监测 CSR 输出和 `irq`

测试项：
- 基本读写
- W1C
- W1S
- 硬件置位与软件清零同拍
- `LINK_CTRL` 字段联动

断言项：
- 只读字段不可被软件错误覆盖
- W1C/W1S 语义正确

---

## 4. Phase 2 任务分解

### 4.1 tx_path_tb

实现任务：
- 构建 CXS 输入 driver
- 构建 FDI 输出 monitor
- 建立 flit scoreboard

测试项：
- 单 flit 传输
- 连续 flit 传输
- FIFO 满背压
- `link_tx_ready=0`
- 旁带字段一致性

断言项：
- 背压下输出稳定
- FIFO 满时不允许继续写入

### 4.2 rx_path_tb

实现任务：
- 构建 FDI 输入 driver
- 构建 CXS 输出 monitor
- 建立 flit scoreboard

测试项：
- 单 flit 接收
- 连续 flit 接收
- FIFO 空/满边界
- `link_rx_ready=0`
- 旁带字段一致性

断言项：
- 背压下输出稳定
- FIFO 空时不允许继续读出

---

## 5. Phase 3 任务分解

### 5.1 cxs_tx_if_tb

测试项：
- normal handshake
- backpressure
- active 门控
- `CXS_MAX_PKT_PER_FLIT=1`
- 可选字段宽度为 0

### 5.2 cxs_rx_if_tb

测试项：
- normal handshake
- backpressure
- active 门控
- 错误路径

### 5.3 fdi_tx_if_tb

测试项：
- Active 状态发送
- 非 Active 状态禁止发送
- `credit_ready=0`
- Retrain
- cancel/error

### 5.4 fdi_rx_if_tb

测试项：
- Active 状态接收
- `rx_ready=0`
- flit cancel
- 非 Active 状态禁止提交

---

## 6. Phase 4 任务分解

### 6.1 lme_handler_tb

实现任务：
- 建立 CXS/FDI sideband message driver
- 建立 message monitor
- 建立 message scoreboard

测试项：
- `PARAM_REQ/RSP/ACCEPT`
- `PARAM_REJECT`
- `ACTIVE_REQ/ACK`
- 未知 opcode
- 非法序列
- timeout
- CDC 背压与保序

断言项：
- `valid && !ready` 时消息保持稳定
- 非法序列进入错误流
- FIFO 输出顺序等于输入顺序

### 6.2 top_tb

实现任务：
- 连接主要模块或顶层封装
- 驱动初始化、协商、运行、停用、重训练场景

测试项：
- 上电初始化
- 正常运行
- 停用
- Retrain
- 错误恢复

---

## 7. 公共组件任务

建议统一建设以下公共验证资产：

- `flit` 事务定义
- `sideband message` 事务定义
- 通用 scoreboard
- 通用 assertion bind 文件
- 通用 coverage collector
- 通用 APB driver/task

---

## 8. 优先级建议

P0：
- `credit_mgr_tb`
- `cxs_fdi_link_ctrl_tb`
- `regs_tb`

P1：
- `tx_path_tb`
- `rx_path_tb`
- `cxs_tx_if_tb`
- `cxs_rx_if_tb`
- `fdi_tx_if_tb`
- `fdi_rx_if_tb`

P2：
- `lme_handler_tb`
- `ucie_cxs_fdi_top_tb` 增强版

---

## 9. 相关文档 / Related Documents

- `docs/checklist/rtl_tb_verification_checklist.md`
- `docs/checklist/rtl_implementation_checklist.md`
- `docs/checklist/tb_execution_plan.md`
- `docs/checklist/README.md`
- `docs/specification/ucie_cxs_fdi_arch_spec.md`

---

**文档结束**
