# UCIe CXS-FDI RTL Implementation Checklist

**文档编号**: [CHK-RTL-001]  
**版本**: v0.1  
**日期**: 2026-03-21  
**状态**: Draft

---

## 变更记录 / Change Log

| 版本 | 日期 | 变更描述 |
|------|------|----------|
| v0.1 | 2026-03-21 | 初始版本，整理 RTL 实现检查表 |

---

## 1. 目的 / Purpose

本文档用于指导 UCIe CXS-FDI Bridge 各模块的 RTL 落地实现，确保实现边界、接口行为、
状态机语义和 CDC/寄存器约束与规格文档一致。

---

## 2. 通用实现要求

- 所有时序逻辑使用 `always_ff`
- 所有组合逻辑使用 `always_comb`
- 禁止不完整组合赋值导致锁存器
- 所有跨时钟域路径必须使用同步器或异步 FIFO
- 禁止从 credit grant 到 data valid 的同拍组合路径
- 所有输出信号方向与规格文档严格一致
- 所有可选位宽为 0 的信号必须采用可综合写法处理

---

## 3. 模块级 RTL Checklist

### 3.1 cxs_tx_if

- 实现 `valid/ready` 握手
- `ready=0` 时保持 `data/user/cntl/last/srcid/tgtid`
- 支持 `CXS_USER_WIDTH=0..128`
- 支持 `CXS_SRCID_WIDTH=0..8`
- 支持 `CXS_TGTID_WIDTH=0..8`
- `CXS_MAX_PKT_PER_FLIT=1` 时强制 `CXS_CNTL_WIDTH=0`、`CXS_HAS_LAST=0`
- `cxs_tx_active=0` 时禁止发起传输

### 3.2 cxs_rx_if

- 实现接收侧 `valid/ready` 握手
- 保持旁带字段与 `data` 同步
- 背压时输出字段保持稳定
- `cxs_rx_active=0` 时禁止向下游提交
- 对协议错误上报 `ERR_CXS_PROTO`

### 3.3 fdi_tx_if

- 仅在 `fdi_pl_state_sts==Active` 时允许发送
- `credit_ready=0` 时禁止拉高 `fdi_lp_valid`
- `fdi_lp_irdy=0` 时保持发送 payload 稳定
- Retrain 期间暂停发送
- 错误/取消事件不得错误提交 flit

### 3.4 fdi_rx_if

- 仅在合法状态下接收并提交 flit
- `fdi_pl_flit_cancel` 时丢弃当前 flit
- `rx_ready=0` 时进行背压
- 输出数据和旁带字段保持一致

### 3.5 tx_path

- 建立 `CXS -> FIFO -> FDI` 一对一 flit 映射
- FIFO 表项包含：
  - `data`
  - `user`
  - `cntl`
  - `last`
  - `srcid`
  - `tgtid`
- 满 FIFO 时正确背压
- `link_tx_ready=0` 时停止出队

### 3.6 rx_path

- 建立 `FDI -> FIFO -> CXS` 一对一 flit 映射
- FIFO 表项包含所有旁带字段
- 空/满边界无非法读写
- `link_rx_ready=0` 时停止提交

### 3.7 credit_mgr

- TX/RX 方向各自维护独立 credit 计数
- `consume + return` 同拍时净变化为 0
- 计数不得下溢/上溢
- `credit_ready` 必须定义为 `(tx_cnt > 0) && (rx_cnt > 0)`
- `cxs_*_crdgnt` 必须寄存器化输出

### 3.8 cxs_fdi_link_ctrl

- 使用单一主状态机管理链路状态
- 状态至少包含：
  - `STOP`
  - `ACTIV_REQ`
  - `ACTIV_ACK`
  - `RUN`
  - `DEACT`
  - `RETRAIN`
  - `ERROR`
- `LINK_CTRL.SW_*` 必须做沿检测
- 支持 `AUTO_RETRY_EN`
- 支持 `FDI_RX_ACTIVE_FOLLOW_EN`
- `ERROR_STOP_EN=0` 时直接回 `STOP`，不上报 `ERROR`

### 3.9 lme_handler

- 使用归一化 sideband message 通道
- 双向消息跨域必须经异步 FIFO
- 实现 `PARAM_REQ/RSP/ACCEPT/REJECT`
- 实现 `ACTIVE_REQ/ACK`
- 未知 opcode 和非法序列进入错误流
- 协商结果寄存并输出到 `neg_*`

### 3.10 regs

- 统一实现全局 CSR
- 正确支持 W1C/W1S
- 状态、电平、事件输入的处理方式与 spec 一致
- `STATUS/ERR_STATUS/INT_STATUS/LINK_CTRL` 字段正确映射
- `irq` 生成逻辑与中断寄存器一致

---

## 4. CDC Checklist

- `fdi_pl_state_sts` 进入 `cxs_fdi_link_ctrl` 前完成同步
- `fdi_pl_rx_active_req` 进入 `cxs_fdi_link_ctrl` 前完成同步
- `lme_handler` 双向消息必须使用异步 FIFO
- 不允许组合跨域直通

---

## 5. 参数约束 Checklist

- `CXS_DATA_WIDTH == FDI_DATA_WIDTH`
- `FIFO_DEPTH >= 2 × MAX_CREDIT`
- `cfg_credit_init <= cfg_credit_max`
- 所有 FIFO 深度建议为 2 的幂
- 零宽可选字段必须采用参数化可综合实现

---

## 6. 集成前自检

- 所有端口方向与 spec 一致
- 所有寄存器字段已接入对应模块
- 所有错误位与中断位映射已闭环
- 所有状态机非法编码已处理
- 所有 CDC 路径均已有设计说明

---

## 7. 相关文档 / Related Documents

- 总体架构规格：`docs/specification/ucie_cxs_fdi_arch_spec.md`
- RTL/TB总检查表：`docs/checklist/rtl_tb_verification_checklist.md`
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
