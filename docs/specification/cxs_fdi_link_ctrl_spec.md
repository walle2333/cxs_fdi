# CXS-FDI Link Control模块设计规格书 (CXS-FDI Link Control Module Design Specification)

**文档编号**: [MOD-CXS-FDI-LINK-CTRL-001]  
**版本**: v0.1  
**日期**: 2026-03-15  
**作者**: [待填写]  
**审核人**: [待填写]  
**状态**: Draft

---

## 变更记录 / Change Log

| 版本 | 日期 | 变更描述 | 作者 | 审核人 |
|------|------|----------|------|--------|
| v0.1 | 2026-03-15 | 初始版本，基于UCIe CXS-FDI Bridge架构规格书 | [待填写] | [待填写] |

---

## 1. 概述 / Overview

### 1.1 目的 / Purpose

本文档定义了CXS-FDI Link Control模块的详细设计规格，作为RTL设计、验证和集成的唯一真实来源(One Source of Truth)。CXS-FDI Link Control是UCIe CXS-FDI Bridge的全局链路控制模块，负责协调CXS和FDI两端的链路状态，管理链路激活/停用流程，并响应物理层Retrain状态。

### 1.2 功能描述 / Functional Description

CXS-FDI Link Control模块实现跨CXS和FDI两端的链路状态协调，管理链路激活/停用流程，并响应物理层链路状态变化。

**主要功能：**
- **链路激活协调**：接收CXS侧的激活请求，与FDI侧协商，完成链路激活
- **链路停用协调**：接收CXS侧的停用提示，协调两端停止数据传输
- **Retrain响应**：响应FDI物理层的Retrain状态，暂停数据流并在恢复后自动继续
- **状态同步**：协调CXS和FDI两侧的链路状态
- **Credit就绪协同**：接收来自credit_mgr的credit_ready指示，用于控制进入RUN状态

**模块在系统中的位置：**
```
+---------------------------+     +---------------------------+
|    CXS侧链路请求           │     |  CXS-FDI Link Control    │
|                          │     │ (独立全局模块)             │
| cxs_tx_active_req ──────│────▶│                          │
| cxs_tx_deact_hint ──────│────▶│    链路状态机             │
| cxs_tx_active ◀─────────│────◀│                          │
+---------------------------+     +---------------------------+
           │                                   │
           │                                   ▼
           │                         +---------------------------+
           │                         |    FDI侧链路状态          │
           │                         |                          │
           └─────────────────────────│ fdi_pl_state_sts ───────▶
                                     | fdi_pl_state_sts[Retrain] ─▶
                                     +---------------------------+
```

### 1.3 目标与非目标 / Goals and Non-Goals

**目标 (Goals) - 必须实现：**
| 目标 | 描述 | 优先级 | RTL实现要求 |
|------|------|--------|-------------|
| 链路激活完成 | 正确完成激活流程 | P0 | 状态机完整 |
| 链路停用完成 | 正确完成停用流程 | P0 | 状态机完整 |
| Retrain响应 | 响应Retrain并恢复 | P0 | 状态响应正确 |

**非目标 (Non-Goals) - 明确排除：**
- 数据传输：不参与数据通路

---

## 2. 架构设计 / Architecture Design

### 2.1 模块顶层框图 / Module Top-Level Block Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                        CXS-FDI Link Control (cxs_fdi_link_ctrl)                      │
│                                                                                          │
│   ═══════════════════════════════════════════════════════════════════════════════════   │
│                              [Clock Domain: cxs_clk]                                   │
│   ═══════════════════════════════════════════════════════════════════════════════════   │
│                                                                                          │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │                              CXS侧接口                                          │   │
│   │  cxs_tx_active_req ───────────────────────────────────────────────────►   │   │
│   │  cxs_tx_deact_hint ──────────────────────────────────────────────────►   │   │
│   │  cxs_tx_active ◄────────────────────────────────────────────────────   │   │
│   │  cxs_rx_active_req ─────────────────────────────────────────────────►   │   │
│   │  cxs_rx_active ◄────────────────────────────────────────────────────   │   │
│   └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                              │                                           │
│                                              ▼                                           │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │                              链路状态机 (Link State Machine)                       │   │
│   │         ┌─────────────────────────────────────────────────────────────┐        │   │
│   │         │   STOP ──▶ ACTIV_REQ ──▶ ACTIV_ACK ──▶ RUN ──▶ DEACT    │        │   │
│   │         │                                                      │           │        │   │
│   │         │                                                      ▼           │        │   │
│   │         │                                                   RETRAIN ──────┘        │   │
│   │         └─────────────────────────────────────────────────────────────┘        │   │
│   └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                              │                                           │
│                                              ▼                                           │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │                              FDI侧接口                                          │   │
│   │  fdi_pl_state_sts[3:0] ◄────────────────────────────────────────────   │   │
│   │  fdi_pl_state_sts[Retrain] ─────────────────────────────────────────►   │   │
│   │  credit_ready  ◄───────────────────────────────────────────────────   │   │
│   │  link_tx_ready ◄────────────────────────────────────────────────────   │   │
│   │  link_rx_ready ◄────────────────────────────────────────────────────   │   │
│   └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                          │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │                              状态输出                                           │   │
│   │  link_active ◄──────────────────────────────────────────────────────   │   │
│   │  link_error ◄───────────────────────────────────────────────────────   │   │
│   │  link_status ◄──────────────────────────────────────────────────────   │   │
│   └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                          │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 子模块层次 / Submodule Hierarchy

```
cxs_fdi_link_ctrl (CXS-FDI Link Control - 顶层模块)
├── cxs_fdi_link_fsm (链路状态机单元)
│   ├── state_reg (状态寄存器) - **实现关键**: 3-bit状态编码
│   ├── state_trans (状态转移) - **实现关键**: 完整状态转移逻辑
│   └── output_gen (输出生成) - **实现关键**: 状态输出
├── cxs_fdi_link_cxs_if (CXS侧接口单元)
│   ├── active_req_detect (激活请求检测) - **实现关键**: 边沿检测
│   ├── deact_hint_detect (停用提示检测) - **实现关键**: 边沿检测
│   └── active_ack_gen (激活确认生成) - **实现关键**: 握手响应
├── cxs_fdi_link_fdi_if (FDI侧接口单元)
│   ├── state_sts_decode (状态解码) - **实现关键**: FDI状态解析
│   ├── retrain_detect (Retrain检测) - **实现关键**: 链路训练检测
│   └── link_ready_gen (链路就绪生成) - **实现关键**: 状态判断
└── cxs_fdi_link_intr (中断单元)
    ├── timeout_detect (超时检测) - **实现关键**: 超时判断
    └── error_detect (错误检测) - **实现关键**: 链路错误判断
```

---

## 3. 接口定义 / Interface Definitions

### 3.1 顶层接口汇总 / Top-Level Interface Summary

| 接口分类 | 接口名称 | 方向 | 位宽 | 时钟域 | RTL实现要求 |
|----------|----------|------|------|--------|-------------|
| 时钟复位 | cxs_clk | Input | 1 | - | 全局时钟 |
| 时钟复位 | cxs_rst_n | Input | 1 | - | 异步复位 |
| CXS输入 | cxs_tx_active_req | Input | 1 | cxs_clk | TX激活请求 |
| CXS输入 | cxs_tx_deact_hint | Input | 1 | cxs_clk | TX停用提示 |
| CXS输出 | cxs_tx_active | Output | 1 | cxs_clk | TX激活确认 |
| CXS输入 | cxs_rx_active_req | Input | 1 | cxs_clk | RX激活请求 |
| CXS输入 | cxs_rx_deact_hint | Input | 1 | cxs_clk | RX停用提示 |
| CXS输出 | cxs_rx_active | Output | 1 | cxs_clk | RX激活确认 |
| FDI输入 | fdi_pl_state_sts | Input | 4 | cxs_clk | FDI链路状态 |
| FDI输入 | fdi_pl_rx_active_req | Input | 1 | cxs_clk | Rx_active_req握手 |
| FDI输出 | fdi_lp_rx_active_sts | Output | 1 | cxs_clk | Rx_active_sts握手 |
| Credit输入 | credit_ready | Input | 1 | cxs_clk | Credit可用指示(来自credit_mgr) |
| 配置输入 | cfg_timeout | Input | [7:0] | cxs_clk | 激活超时门限(来自regs.CONFIG.TIMEOUT) |
| 配置输入 | cfg_retry_cnt | Input | [6:0] | cxs_clk | 最大重试次数(来自regs.CONFIG.RETRY_CNT) |
| 配置输入 | link_ctrl_reg | Input | [31:0] | cxs_clk | LINK_CTRL寄存器镜像(来自regs) |
| 状态输出 | link_active | Output | 1 | cxs_clk | 链路激活状态 |
| 状态输出 | link_tx_ready | Output | 1 | cxs_clk | TX就绪 |
| 状态输出 | link_rx_ready | Output | 1 | cxs_clk | RX就绪 |
| 状态输出 | link_error | Output | 1 | cxs_clk | 链路错误 |
| 状态输出 | link_status | Output | [2:0] | cxs_clk | 链路状态码 |

### 3.2 详细接口定义 / Detailed Interface Specifications

| 信号名 | 方向 | 位宽 | 描述 | RTL实现要求 |
|--------|------|------|------|-------------|
| cxs_tx_active_req | Input | 1 | CXS TX侧激活请求 | 电平请求；在`STOP`态采样有效 |
| cxs_tx_deact_hint | Input | 1 | CXS TX侧停用提示 | 电平提示；在`RUN`态触发停用流程 |
| cxs_tx_active | Output | 1 | 对CXS TX侧的激活状态指示 | 仅在`ACTIV_ACK/RUN`态置高，`DEACT/STOP/ERROR`态拉低 |
| cxs_rx_active_req | Input | 1 | CXS RX侧激活请求 | 电平请求；与`cxs_tx_active_req`共同参与激活判定 |
| cxs_rx_deact_hint | Input | 1 | CXS RX侧停用提示 | 电平提示；与`cxs_tx_deact_hint`共同参与停用判定 |
| cxs_rx_active | Output | 1 | 对CXS RX侧的激活状态指示 | 仅在`ACTIV_ACK/RUN`态置高，`DEACT/STOP/ERROR`态拉低 |
| fdi_pl_state_sts | Input | 4 | FDI物理层链路状态 | 进入模块前必须完成2级同步；编码见4.2 |
| fdi_pl_rx_active_req | Input | 1 | FDI侧Rx激活请求 | 仅在`FDI_RX_ACTIVE_FOLLOW_EN=1`时参与桥侧激活 |
| fdi_lp_rx_active_sts | Output | 1 | 桥侧返回给FDI的Rx激活状态 | 在`ACTIV_ACK/RUN`态置高；其余状态拉低 |
| credit_ready | Input | 1 | Credit可用指示 | 必须来自寄存器化的credit_mgr输出，禁止组合直通 |
| cfg_timeout | Input | [7:0] | 激活超时门限 | 仅在进入`ACTIV_REQ`首拍装载到本地计数器 |
| cfg_retry_cnt | Input | [6:0] | 自动重试最大次数 | `AUTO_RETRY_EN=1`时生效，达到上限后停止重试 |
| link_ctrl_reg | Input | [31:0] | LINK_CTRL寄存器镜像 | 由`regs`稳定输出；`SW_*`字段需在本模块内做沿检测 |
| link_active | Output | 1 | 链路已激活 | 仅在`RUN`态置高 |
| link_tx_ready | Output | 1 | TX路径允许发送 | 仅在`RUN`态置高 |
| link_rx_ready | Output | 1 | RX路径允许接收 | 仅在`RUN`态置高 |
| link_error | Output | 1 | 链路错误告警 | 仅在`ERROR`态置高 |
| link_status | Output | [2:0] | 当前链路状态编码 | 必须直接镜像状态机当前状态 |

---

## 4. 时钟与复位 / Clocks and Resets

### 4.1 时钟域 / Clock Domains

| 时钟名称 | 频率 | 描述 |
|----------|------|------|
| cxs_clk | 1.5 GHz | 本模块唯一时钟域 |

### 4.2 跨时钟域 / Clock Domain Crossings (CDC)

FDI侧状态信号(fdi_pl_state_sts、fdi_pl_rx_active_req)进入本模块前需经过2级同步器。credit_ready来自cxs_clk域的credit_mgr，无需CDC。
fdi_pl_state_sts编码：0000=Reset，0001=LinkUp，0010=Active，0011=Retrain。

---

## 5. 功能描述 / Functional Description

### 5.1 链路状态机定义

**状态定义（3-bit编码）：**
| 状态 | 编码 | 描述 | 进入条件 | 退出条件 |
|------|------|------|----------|----------|
| STOP | 3'b000 | 链路停止，无数据传输 | 复位/停用完成 | active_req==1 |
| ACTIV_REQ | 3'b001 | 激活请求已发送 | active_req==1 | ack==1 |
| ACTIV_ACK | 3'b010 | 激活确认，已分配资源 | ack==1 | credit_ready==1 |
| RUN | 3'b011 | 正常运行，数据传输中 | credit_ready==1 | deact_hint==1 |
| DEACT | 3'b100 | 停用处理中 | deact_hint==1 | complete==1 |
| RETRAIN | 3'b101 | 链路训练中，暂停传输 | fdi_pl_state_sts==Retrain | retrain_done==1 |
| ERROR | 3'b110 | 链路错误状态 | error_detected | reset |

**状态转移判定信号定义：**
- `link_ctrl_ack`：本地资源已分配完成，且TX/RX路径均允许进入激活确认
- `timeout`：在`ACTIV_REQ`状态持续超过`cfg_timeout`
- `deact_complete`：TX/RX路径均已停止发送/接收，且无待处理激活握手
- `retrain_done`：`fdi_pl_state_sts`退出`Retrain`且链路重新可用
- `error_detected`：检测到超时、链路断开或上层请求的错误停机

**计时与判定规则补充：**
- `timeout_counter` 在进入 `ACTIV_REQ` 的首拍清零，并从下一拍开始计数
- 当 `timeout_counter == cfg_timeout` 时置位 `timeout`
- 离开 `ACTIV_REQ` 状态时必须清零 `timeout_counter`
- `deact_complete` 必须由 TX/RX 路径空闲确认共同产生，不允许仅凭单侧空闲结束停用流程
- `retrain_done` 的唯一判定为：前一拍 `fdi_pl_state_sts==4'b0011`，当前拍 `fdi_pl_state_sts!=4'b0011`

**软件控制源定义：**
- `sw_activate_req`：`link_ctrl_reg[0]` 的0->1沿，作为软件激活请求
- `sw_deact_req`：`link_ctrl_reg[1]` 的0->1沿，作为软件停用请求
- `sw_retrain_req`：`link_ctrl_reg[2]` 的0->1沿，作为软件重训练请求
- `auto_retry_en`：`link_ctrl_reg[8]`，允许超时后按`cfg_retry_cnt`执行自动重试
- `fdi_rx_active_follow_en`：`link_ctrl_reg[9]`，允许`fdi_pl_rx_active_req`触发链路激活
- `error_stop_en`：`link_ctrl_reg[10]`，错误时进入ERROR/STOP停机

**请求合成规则：**
- `activation_req = cxs_tx_active_req || cxs_rx_active_req || sw_activate_req || (fdi_pl_rx_active_req && fdi_rx_active_follow_en)`
- `deactivation_req = cxs_tx_deact_hint || cxs_rx_deact_hint || sw_deact_req`
- `retrain_req = (fdi_pl_state_sts == RETRAIN_STS) || sw_retrain_req`

### 5.2 状态转移图

```
                    ┌─────────────┐
              ┌─────│    STOP    │◄─────┐
              │     └──────┬──────┘      │
              │            │             │
              │            ▼             │
              │     ┌─────────────┐     │
              │     │ ACTIV_REQ   │     │
              │     └──────┬──────┘     │
              │            │             │
              │            ▼             │
              │     ┌─────────────┐     │
              │     │ ACTIV_ACK   │     │
              │     └──────┬──────┘     │
              │            │             │
              │            ▼             │
              │     ┌─────────────┐     │
              └─────│    RUN     │──────┘
                    └──────┬──────┘
                           │
            ┌──────────────┼──────────────┐
            │              │              │
            ▼              ▼              ▼
     ┌───────────┐  ┌───────────┐  ┌───────────┐
     │   DEACT   │  │ RETRAIN   │  │  ERROR   │
     └─────┬─────┘  └─────┬─────┘  └─────┬─────┘
           │              │              │
           └──────────────┴──────────────┘
```

### 5.3 RTL实现

```systemverilog
// 状态定义
typedef enum logic [2:0] {
  ST_STOP      = 3'b000,
  ST_ACTIV_REQ = 3'b001,
  ST_ACTIV_ACK = 3'b010,
  ST_RUN       = 3'b011,
  ST_DEACT     = 3'b100,
  ST_RETRAIN   = 3'b101,
  ST_ERROR     = 3'b110
} link_state_t;

link_state_t curr_state, next_state;
localparam logic [3:0] RETRAIN_STS = 4'b0011;
logic [31:0] link_ctrl_reg_d;
logic        sw_activate_req, sw_deact_req, sw_retrain_req;
logic        auto_retry_en, fdi_rx_active_follow_en, error_stop_en;

assign sw_activate_req         =  link_ctrl_reg[0]  & ~link_ctrl_reg_d[0];
assign sw_deact_req            =  link_ctrl_reg[1]  & ~link_ctrl_reg_d[1];
assign sw_retrain_req          =  link_ctrl_reg[2]  & ~link_ctrl_reg_d[2];
assign auto_retry_en           =  link_ctrl_reg[8];
assign fdi_rx_active_follow_en =  link_ctrl_reg[9];
assign error_stop_en           =  link_ctrl_reg[10];

// 状态转移逻辑
always_comb begin
  next_state = curr_state;
  case (curr_state)
    ST_STOP: begin
      if (cxs_tx_active_req || cxs_rx_active_req || sw_activate_req ||
          (fdi_pl_rx_active_req && fdi_rx_active_follow_en))
        next_state = ST_ACTIV_REQ;
    end
    ST_ACTIV_REQ: begin
      if (link_ctrl_ack) next_state = ST_ACTIV_ACK;
      else if (timeout && error_stop_en) next_state = ST_ERROR;
      else if (timeout && auto_retry_en) next_state = ST_STOP;
    end
    ST_ACTIV_ACK: begin
      if (credit_ready) next_state = ST_RUN;
    end
    ST_RUN: begin
      if (cxs_tx_deact_hint || cxs_rx_deact_hint || sw_deact_req)
        next_state = ST_DEACT;
      else if ((fdi_pl_state_sts == RETRAIN_STS) || sw_retrain_req)
        next_state = ST_RETRAIN;
    end
    ST_DEACT: begin
      if (deact_complete) next_state = ST_STOP;
    end
    ST_RETRAIN: begin
      if (fdi_pl_state_sts != RETRAIN_STS) next_state = ST_RUN;
    end
    ST_ERROR: begin
      if (!cxs_rst_n) next_state = ST_STOP;
    end
  endcase
end

// 状态寄存器
always_ff @(posedge cxs_clk or negedge cxs_rst_n) begin
  if (!cxs_rst_n) begin
    curr_state <= ST_STOP;
    link_ctrl_reg_d <= '0;
  end else begin
    curr_state <= next_state;
    link_ctrl_reg_d <= link_ctrl_reg;
  end
end

// 输出信号
assign cxs_tx_active = (curr_state == ST_RUN) || (curr_state == ST_ACTIV_ACK);
assign cxs_rx_active = (curr_state == ST_RUN) || (curr_state == ST_ACTIV_ACK);
assign fdi_lp_rx_active_sts = (curr_state == ST_RUN) || (curr_state == ST_ACTIV_ACK);
assign link_active = (curr_state == ST_RUN);
assign link_error = (curr_state == ST_ERROR);
```

---

## 6. 配置寄存器 / Configuration Registers (CSRs)

本模块不定义独立CSR。所有寄存器由`regs`模块统一管理，地址与字段见：
- `docs/specification/ucie_cxs_fdi_arch_spec.md`
- `docs/specification/regs_spec.md`

**与本模块相关的全局寄存器/字段：**
- `LINK_CTRL`
- `STATUS.LINK_STATE`
- `ERR_STATUS.ERR_LINK_TIMEOUT`、`ERR_STATUS.ERR_LINK_RETRY_FAIL`、`ERR_STATUS.ERR_LINK_DOWN`
- `INT_STATUS.LINK_UP_INT`、`INT_STATUS.LINK_DOWN_INT`

### 6.1 LINK_CTRL字段定义

`LINK_CTRL` 由 `regs` 模块存储，由本模块解释。除特别说明外，未定义位保留并应写0。

| 位域 | 名称 | 访问建议 | 默认值 | 描述 | 本模块行为 |
|------|------|----------|--------|------|------------|
| [0] | SW_ACTIVATE_REQ | R/W | 0 | 软件激活请求 | 对 `0->1` 沿采样为 `sw_activate_req`，请求进入 `ACTIV_REQ` |
| [1] | SW_DEACT_REQ | R/W | 0 | 软件停用请求 | 对 `0->1` 沿采样为 `sw_deact_req`，请求进入 `DEACT` |
| [2] | SW_RETRAIN_REQ | R/W | 0 | 软件重训练请求 | 对 `0->1` 沿采样为 `sw_retrain_req`，请求进入 `RETRAIN` |
| [7:3] | RESERVED0 | R/W | 0 | 保留 | 写0 |
| [8] | AUTO_RETRY_EN | R/W | 1 | 超时自动重试使能 | `ACTIV_REQ` 超时时允许返回 `STOP` 并重新尝试激活 |
| [9] | FDI_RX_ACTIVE_FOLLOW_EN | R/W | 1 | FDI Rx_active_req跟随使能 | 允许 `fdi_pl_rx_active_req` 参与激活请求合成 |
| [10] | ERROR_STOP_EN | R/W | 1 | 错误停机使能 | 超时/错误时进入 `ERROR`/`STOP` 路径 |
| [31:11] | RESERVED1 | R/W | 0 | 保留 | 写0 |

**字段使用规则：**
- `SW_*` 命令位采用 **沿触发** 语义：软件写 `0->1` 触发一次动作，保持为1不会重复触发
- 软件在观察到命令被采样后应主动将对应位写回0，为下一次命令做准备
- `AUTO_RETRY_EN=1` 时，`ACTIV_REQ` 超时优先返回 `STOP` 并等待下一次激活尝试；重试次数上限由 `cfg_retry_cnt` 约束
- `FDI_RX_ACTIVE_FOLLOW_EN=0` 时，`fdi_pl_rx_active_req` 不再触发桥侧激活，但 `fdi_lp_rx_active_sts` 仍由状态机输出
- `ERROR_STOP_EN=1` 时，超时/严重错误进入 `ERROR`
- `ERROR_STOP_EN=0` 时，超时/严重错误的唯一行为定义为：直接返回 `STOP`，拉低 `cxs_tx_active/cxs_rx_active/fdi_lp_rx_active_sts`，且不上报 `ERROR` 状态编码

### 6.2 实现约束

- `link_ctrl_reg` 必须先在 `cxs_clk` 域稳定后再参与状态机判断
- `SW_*` 命令位必须做边沿检测，禁止直接把电平作为持续状态条件
- `cfg_timeout` 与 `cfg_retry_cnt` 由 `regs.CONFIG` 提供，本模块不得复制另一套独立可编程超时寄存器
- `STATUS.LINK_STATE` 必须直接镜像 `curr_state`

---

## 7. 性能规格 / Performance Specifications

### 7.1 性能指标

| 指标 | 目标值 | 单位 |
|------|--------|------|
| 激活延迟 | < 100 | 周期 |
| 停用延迟 | < 50 | 周期 |
| Retrain响应 | < 10 | 周期 |

---

## 9. 验证与调试 / Verification and Debug

### 9.1 验证策略

| 方法 | 覆盖率目标 | RTL验证要点 |
|------|------------|-------------|
| 定向测试 | 100% | STOP/ACTIV_REQ/ACTIV_ACK/RUN/DEACT/RETRAIN/ERROR 全状态覆盖 |
| 随机测试 | > 95% | 激活/停用/重训练/超时交叉场景 |
| 断言验证 | 100% | 状态唯一性、输出与状态一致、超时计数正确 |

### 9.2 关键测试点

| 测试点 | 预期结果 |
|--------|----------|
| 复位释放后默认状态 | `link_status==STOP`，所有 active/ready/error 输出为0 |
| CXS侧激活请求 | `STOP -> ACTIV_REQ -> ACTIV_ACK -> RUN` |
| `credit_ready` 延迟到达 | 保持在`ACTIV_ACK`，直到`credit_ready=1`才进入`RUN` |
| `cxs_*_deact_hint` 触发停用 | `RUN -> DEACT -> STOP`，active/ready 输出依次拉低 |
| FDI Retrain进入/退出 | `RUN -> RETRAIN -> RUN`，数据通路准备信号暂停后恢复 |
| 超时且允许自动重试 | 在`cfg_retry_cnt`范围内回到`STOP`并重新尝试 |
| 超时且禁止自动重试 | 进入`ERROR`或按`ERROR_STOP_EN=0`回到`STOP` |
| `FDI_RX_ACTIVE_FOLLOW_EN=1` | `fdi_pl_rx_active_req` 可独立触发激活流程 |
| `FDI_RX_ACTIVE_FOLLOW_EN=0` | `fdi_pl_rx_active_req` 不触发激活流程 |
| `ERROR_STOP_EN=0` | 直接回到`STOP`且不上报`ERROR`编码 |

### 9.3 推荐断言

- `link_active |-> (link_status == 3'b011)`
- `(link_tx_ready || link_rx_ready) |-> (link_status == 3'b011)`
- `link_error |-> (link_status == 3'b110)`
- `(link_status == 3'b000) |-> (!cxs_tx_active && !cxs_rx_active && !fdi_lp_rx_active_sts)`
- `timeout` 仅允许在 `ACTIV_REQ` 状态下置位
- `SW_ACTIVATE_REQ/SW_DEACT_REQ/SW_RETRAIN_REQ` 必须经沿检测后只触发一次状态机事件

---

**文档结束**

**相关文档：**
- 架构规格：`docs/specification/ucie_cxs_fdi_arch_spec.md`
- Credit管理规格：`docs/specification/credit_mgr_spec.md`
- 编码规范：`docs/coding_standards/coding_guide.md`
