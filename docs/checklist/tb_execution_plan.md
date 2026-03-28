# UCIe CXS-FDI Testbench Execution Plan

**文档编号**: [CHK-TB-PLAN-001]  
**版本**: v0.2  
**日期**: 2026-03-25  
**状态**: Draft

---

## 变更记录 / Change Log

| 版本 | 日期 | 变更描述 |
|------|------|----------|
| v0.1 | 2026-03-21 | 初始版本，整理 Testbench 执行计划 |
| v0.2 | 2026-03-25 | 同步当前执行进展，补充顶层 LME 错误路径、sideband backpressure 与长期检查 |
| v0.3 | 2026-03-27 | 同步顶层集成 TB 的 `ERROR_STOP_EN=0` timeout 行为与 `FDI_RX_ACTIVE_FOLLOW_EN` 激活行为 |

---

## 1. 目的 / Purpose

本文档定义 UCIe CXS-FDI Bridge 的 testbench 执行顺序、测试层级和覆盖目标，
用于指导模块级验证到集成验证的逐步展开。

---

## 2. 验证阶段划分

### Phase 1: 基础控制模块

优先模块：
- `credit_mgr`
- `cxs_fdi_link_ctrl`
- `regs`

目标：
- 先建立 credit、状态机、寄存器这三类基础行为的验证闭环
- 为后续 path 和接口模块提供稳定控制基础

### Phase 2: 数据路径模块

优先模块：
- `tx_path`
- `rx_path`

目标：
- 建立 flit 级 scoreboard
- 验证 FIFO、背压、旁带字段一致性

### Phase 3: 接口模块

优先模块：
- `cxs_tx_if`
- `cxs_rx_if`
- `fdi_tx_if`
- `fdi_rx_if`

目标：
- 验证协议侧接口握手
- 验证 active/retrain/error 等边界条件

### Phase 4: 链路管理与集成

优先模块：
- `lme_handler`
- 顶层集成 TB

目标：
- 验证 sideband 协商
- 验证链路初始化、激活、停用、异常流程
- 验证顶层 LME 错误路径与 sideband backpressure
- 验证 `ERROR_STOP_EN=0` timeout 行为
- 验证 `FDI_RX_ACTIVE_FOLLOW_EN` 激活行为

---

## 3. 每阶段测试内容

### 3.1 Phase 1

`credit_mgr`
- 初始化
- 消耗/退还
- 饱和/归零
- 同拍 `consume+return`
- `credit_ready` 语义检查

`cxs_fdi_link_ctrl`
- 正常激活
- 正常停用
- Retrain
- timeout
- auto retry
- `ERROR_STOP_EN`

`regs`
- CSR 读写
- W1C/W1S
- 硬件置位/软件清零同拍
- 中断与错误位联动

### 3.2 Phase 2

`tx_path`
- 入队/出队
- 背压
- FIFO 满/空
- 旁带字段一致性

`rx_path`
- 入队/出队
- 背压
- FIFO 满/空
- 旁带字段一致性

### 3.3 Phase 3

`cxs_tx_if/cxs_rx_if`
- 基本握手
- active 门控
- 背压稳定性
- 可选字段参数组合

`fdi_tx_if/fdi_rx_if`
- Active 状态门控
- Retrain
- cancel/error
- 与 credit/link ready 的协同行为

### 3.4 Phase 4

`lme_handler`
- `PARAM_REQ/RSP/ACCEPT`
- `PARAM_REJECT`
- `ACTIVE_REQ/ACK`
- 未知 opcode
- 非法序列
- 超时
- CDC FIFO 保序

顶层集成
- 上电初始化
- 协商完成后进入运行
- 传输过程中停用/重训练/错误恢复
- `PARAM_REJECT`
- unknown opcode
- timeout
- remote `ERROR_MSG`
- 非法 `ACTIVE_ACK`
- sideband backpressure
- `ERROR_STOP_EN=0` timeout 行为
- `FDI_RX_ACTIVE_FOLLOW_EN` 激活行为

---

## 4. 推荐 Testbench 结构

- driver
- monitor
- scoreboard
- protocol checker
- assertion binder
- coverage collector

建议：
- `tx_path/rx_path` 使用事务级 scoreboard
- `lme_handler` 使用 message 级 scoreboard
- `link_ctrl/credit_mgr/regs` 以 directed TB + assertion 为主

---

## 5. 覆盖目标

### 5.1 功能覆盖

- 所有状态机状态全覆盖
- 所有关键状态转移全覆盖
- 正常流与错误流均覆盖
- 顶层 LME 正常流与错误流均覆盖
- `ERROR_STOP_EN=0` timeout 行为与 `FDI_RX_ACTIVE_FOLLOW_EN` 激活行为均至少覆盖一次

### 5.2 参数覆盖

- `CXS_USER_WIDTH = 0 / 非0`
- `CXS_SRCID_WIDTH = 0 / 非0`
- `CXS_TGTID_WIDTH = 0 / 非0`
- `CXS_MAX_PKT_PER_FLIT = 1 / >1`
- `FDI_RX_ACTIVE_FOLLOW_EN = 0 / 1`
- `ERROR_STOP_EN = 0 / 1`

### 5.3 交叉覆盖

- `link_state x credit_ready`
- `link_state x fdi_pl_state_sts`
- `opcode x lme_state`
- `fifo_level x backpressure`
- `sideband_direction x backpressure`
- `lme_error_type x sideband_response`

---

## 6. 推荐退出准则

模块级退出准则：
- directed test 全通过
- 关键 assertion 全通过
- 核心覆盖项完成

子系统级退出准则：
- path + interface 联调通过
- 错误路径至少验证一次
- CDC 场景验证通过

集成级退出准则：
- 初始化、运行、停用、重训练、错误恢复完整跑通
- 关键寄存器和状态可观测
- 顶层 LME 正常流与错误流完整跑通
- `ERROR_STOP_EN=0` timeout 行为与 `FDI_RX_ACTIVE_FOLLOW_EN` 激活行为完整跑通
- 顶层长期检查无失败项

---

## 7. 建议执行顺序

1. `credit_mgr`
2. `cxs_fdi_link_ctrl`
3. `regs`
4. `tx_path`
5. `rx_path`
6. `cxs_tx_if`
7. `cxs_rx_if`
8. `fdi_tx_if`
9. `fdi_rx_if`
10. `lme_handler`
11. 顶层集成

---

## 8. 当前执行状态 / Current Status

截至目前，以下 testbench 已完成并纳入 `make regress`：

- `credit_mgr_tb`
- `cxs_fdi_link_ctrl_tb`
- `regs_tb`
- `tx_path_tb`
- `rx_path_tb`
- `cxs_tx_if_tb`
- `cxs_rx_if_tb`
- `fdi_tx_if_tb`
- `fdi_rx_if_tb`
- `lme_handler_tb`
- `ucie_cxs_fdi_top_tb`

当前执行结果：

- `make regress`：11/11 PASS
- `make sim`：PASS
- `make synth`：PASS

顶层 `ucie_cxs_fdi_top_tb` 当前已覆盖：

- APB sanity
- link activation
- TX/RX 单 flit 流程
- deactivate / retrain / top-level error
- LME 正常 negotiation
- `PARAM_REJECT`
- unknown opcode
- timeout
- remote `ERROR_MSG`
- 非法 `ACTIVE_ACK`
- sideband backpressure

顶层长期检查当前已启用：

- sideband `valid && !ready` 期间 `valid` 不得掉
- sideband `valid && !ready` 期间 `data` 必须保持稳定
- `lme_timeout -> lme_intr`
- `lme_error -> lme_intr`
- `lme_active -> lme_init_done`
- `link_error -> cxs_tx_active/cxs_rx_active == 0`

---

## 9. 相关文档 / Related Documents

- 总体架构规格：`docs/specification/ucie_cxs_fdi_arch_spec.md`
- RTL/TB总检查表：`docs/checklist/rtl_tb_verification_checklist.md`
- RTL实现清单：`docs/checklist/rtl_implementation_checklist.md`
- CXS TX接口规格：`docs/specification/cxs_tx_if_spec.md`
- CXS RX接口规格：`docs/specification/cxs_rx_if_spec.md`
- FDI TX接口规格：`docs/specification/fdi_tx_if_spec.md`
- FDI RX接口规格：`docs/specification/fdi_rx_if_spec.md`
- TX Path规格：`docs/specification/tx_path_spec.md`
- RX Path规格：`docs/specification/rx_path_spec.md`
- Credit Manager规格：`docs/specification/credit_mgr_spec.md`
- Link Control规格：`docs/specification/cxs_fdi_link_ctrl_spec.md`
- LME Handler规格：`docs/specification/lme_handler_spec.md`
- 寄存器规格：`docs/specification/regs_spec.md`

---

**文档结束**
