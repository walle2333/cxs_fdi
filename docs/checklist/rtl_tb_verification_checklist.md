# UCIe CXS-FDI RTL/TB Verification Checklist

**文档编号**: [CHK-RTL-TB-001]  
**版本**: v0.1  
**日期**: 2026-03-21  
**状态**: Draft

---

## 变更记录 / Change Log

| 版本 | 日期 | 变更描述 |
|------|------|----------|
| v0.1 | 2026-03-21 | 初始版本，整理 RTL/TB 总览检查表 |

---

## 1. 目的 / Purpose

本文档整理 UCIe CXS-FDI Bridge 各子模块的 RTL 实现检查项、testbench 检查项和推荐断言，
用于在设计实现与验证规划阶段提供统一 checklist。

本文档面向以下目标：
- 约束 RTL 实现边界，避免接口理解偏差
- 为模块级 testbench 提供最小完备测试矩阵
- 为 assertion 和 scoreboard 提供统一参考

---

## 2. 使用范围 / Scope

本 checklist 覆盖以下模块：
- `cxs_tx_if`
- `cxs_rx_if`
- `fdi_tx_if`
- `fdi_rx_if`
- `tx_path`
- `rx_path`
- `credit_mgr`
- `cxs_fdi_link_ctrl`
- `lme_handler`
- `regs`

相关规格文档位于：
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

---

## 3. 模块级 Testbench Checklist

### 3.1 cxs_tx_if

- 验证 `valid/ready` 正常握手
- 验证 `ready=0` 时 `data/user/cntl/last/srcid/tgtid` 保持稳定
- 验证 `CXS_MAX_PKT_PER_FLIT=1` 时 `cntl/last` 被关闭
- 验证 `CXS_USER_WIDTH/SRCID/TGTID=0` 时可选信号处理正确
- 验证 `cxs_tx_active=0` 时禁止发送

### 3.2 cxs_rx_if

- 验证输入握手到输出握手的 1:1 传递
- 验证背压下字段稳定
- 验证 `cxs_rx_active=0` 时禁止接收提交
- 验证协议错误触发 `ERR_CXS_PROTO`

### 3.3 fdi_tx_if

- 验证仅在 `fdi_pl_state_sts==Active` 时允许发送
- 验证 `credit_ready=0` 时 `fdi_lp_valid=0`
- 验证 `fdi_lp_irdy=0` 时 payload 保持稳定
- 验证 Retrain 进入/退出时暂停和恢复发送
- 验证 `fdi_pl_error` 或 cancel 场景处理正确

### 3.4 fdi_rx_if

- 验证 `fdi_pl_valid && fdi_pl_trdy` 时成功接收
- 验证 `rx_ready=0` 时背压正确
- 验证 `fdi_pl_flit_cancel` 时丢弃当前 flit
- 验证 `fdi_pl_state_sts` 非 Active 时不向下游提交

### 3.5 tx_path

- 验证 `CXS -> FIFO -> FDI` 的 1:1 flit 映射
- 验证 `data/user/cntl/last/srcid/tgtid` 同拍入队、同拍出队
- 验证 FIFO 满时背压
- 验证 `link_tx_ready=0` 时停止出队

### 3.6 rx_path

- 验证 `FDI -> FIFO -> CXS` 的 1:1 flit 映射
- 验证所有旁带字段一致性
- 验证 FIFO 空/满边界行为
- 验证 `link_rx_ready=0` 时停止提交

### 3.7 credit_mgr

- 验证 reset 初始化
- 验证 consume 到 0
- 验证 return 到 max
- 验证 consume 和 return 同拍时净变化为 0
- 验证 `credit_ready == (tx_cnt>0 && rx_cnt>0)`
- 验证超额 return 被忽略，不发生上溢
- 验证零 credit 时不发生下溢

### 3.8 cxs_fdi_link_ctrl

- 验证 `STOP -> ACTIV_REQ -> ACTIV_ACK -> RUN`
- 验证 `RUN -> DEACT -> STOP`
- 验证 `RUN -> RETRAIN -> RUN`
- 验证 timeout 与 auto retry
- 验证 timeout 与 `ERROR_STOP_EN=0`
- 验证 `FDI_RX_ACTIVE_FOLLOW_EN` 开/关行为
- 验证 `LINK_CTRL.SW_*` 为边沿触发且仅触发一次

### 3.9 lme_handler

- 验证正常 `PARAM_REQ/PARAM_RSP/PARAM_ACCEPT`
- 验证参数不兼容时 `PARAM_REJECT`
- 验证 `ACTIVE_REQ/ACTIVE_ACK`
- 验证未知 opcode
- 验证重复 `ACTIVE_ACK`
- 验证 CDC FIFO 保序
- 验证 timeout 触发 `lme_timeout/lme_intr`

### 3.10 regs

- 验证 APB/CSR 基本读写
- 验证 W1C/W1S
- 验证硬件置位与软件清零同拍优先级
- 验证 `STATUS/ERR_STATUS/INT_STATUS` 映射正确
- 验证 `LINK_CTRL` 字段能驱动 `cxs_fdi_link_ctrl`

---

## 4. 推荐 Assertion Checklist

### 4.1 握手稳定性

- `valid && !ready |=> $stable(payload)`
- 背压期间所有旁带字段保持稳定

### 4.2 Credit 安全性

- Credit 计数不下溢
- Credit 计数不上溢
- `credit_ready` 与 TX/RX credit 计数严格一致

### 4.3 状态机唯一性

- 任一时刻只能处于一个合法状态
- 非法状态编码不可达

### 4.4 Link Control 输出一致性

- `link_active -> state==RUN`
- `link_error -> state==ERROR`
- `STOP` 状态下 active/ready 全部为低

### 4.5 LME 协议合法性

- `NEGOTIATE` 前禁止 `ACTIVE_REQ/ACTIVE_ACK`
- 未知 opcode 必须进入错误流
- CDC FIFO 出口顺序必须等于入口顺序

### 4.6 Path 数据一致性

- 入队字段与出队字段最终一致
- FIFO 满/空时无非法读写

---

## 5. Scoreboard Checklist

- 建立 flit 级 reference queue，按进入顺序比对输出
- 每个 flit 必须同时比对：
  - `data`
  - `user`
  - `cntl`
  - `last`
  - `srcid`
  - `tgtid`
- 对 `tx_path/rx_path` 分别维护独立 scoreboard
- 对 `lme_handler` 维护 sideband message scoreboard，检查 opcode、tag、arg0/1/2

---

## 6. 覆盖率 Checklist

### 6.1 功能覆盖

- 所有状态机状态至少覆盖一次
- 所有状态转移至少覆盖一次
- 正常流与错误流都被覆盖
- 可选参数组合至少覆盖：
  - `CXS_USER_WIDTH = 0 / 非0`
  - `CXS_SRCID_WIDTH = 0 / 非0`
  - `CXS_TGTID_WIDTH = 0 / 非0`
  - `CXS_MAX_PKT_PER_FLIT = 1 / >1`
  - `FDI_RX_ACTIVE_FOLLOW_EN = 0 / 1`
  - `ERROR_STOP_EN = 0 / 1`

### 6.2 交叉覆盖

- `link_state x credit_ready`
- `link_state x fdi_pl_state_sts`
- `lme_state x opcode`
- `fifo_level x backpressure`

---

## 7. 推荐验证顺序 / Suggested Bring-Up Order

1. 先完成 `credit_mgr`、`cxs_fdi_link_ctrl`、`regs` 的 directed TB
2. 再完成 `tx_path`、`rx_path` 的 scoreboard 与 assertion
3. 再完成 `cxs_tx_if`、`cxs_rx_if`、`fdi_tx_if`、`fdi_rx_if`
4. 最后完成 `lme_handler` 与端到端集成验证

---

## 8. 退出准则 / Exit Criteria

一个模块可认为达到“可集成”状态，至少满足：
- 模块级 directed TB 全通过
- 关键断言全通过
- 核心状态和关键转移具备功能覆盖
- 关键错误路径至少被验证一次
- 文档中的非目标项未被误实现

---

## 9. 相关文档 / Related Documents

- 总体架构规格：`docs/specification/ucie_cxs_fdi_arch_spec.md`
- RTL实现清单：`docs/checklist/rtl_implementation_checklist.md`
- Testbench执行计划：`docs/checklist/tb_execution_plan.md`
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
