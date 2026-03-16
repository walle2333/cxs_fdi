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
                                     | fdi_pl_retrain ─────────▶
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
│   │  fdi_pl_retrain ───────────────────────────────────────────────────►   │   │
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
| CXS输出 | cxs_rx_active | Output | 1 | cxs_clk | RX激活确认 |
| FDI输入 | fdi_pl_state_sts | Input | 4 | cxs_clk | FDI链路状态 |
| FDI输入 | fdi_pl_retrain | Input | 1 | cxs_clk | Retrain指示 |
| Credit输入 | credit_ready | Input | 1 | cxs_clk | Credit可用指示(来自credit_mgr) |
| 状态输出 | link_active | Output | 1 | cxs_clk | 链路激活状态 |
| 状态输出 | link_tx_ready | Output | 1 | cxs_clk | TX就绪 |
| 状态输出 | link_rx_ready | Output | 1 | cxs_clk | RX就绪 |
| 状态输出 | link_error | Output | 1 | cxs_clk | 链路错误 |
| 状态输出 | link_status | Output | [2:0] | cxs_clk | 链路状态码 |

---

## 4. 时钟与复位 / Clocks and Resets

### 4.1 时钟域 / Clock Domains

| 时钟名称 | 频率 | 描述 |
|----------|------|------|
| cxs_clk | 2.0 GHz | 本模块唯一时钟域 |

### 4.2 跨时钟域 / Clock Domain Crossings (CDC)

FDI侧状态信号(fdi_pl_state_sts)进入本模块前需经过2级同步器。credit_ready来自cxs_clk域的credit_mgr，无需CDC。

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
| RETRAIN | 3'b101 | 链路训练中，暂停传输 | fdi_retrain==1 | retrain_done==1 |
| ERROR | 3'b110 | 链路错误状态 | error_detected | reset |

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

// 状态转移逻辑
always_comb begin
  next_state = curr_state;
  case (curr_state)
    ST_STOP: begin
      if (cxs_tx_active_req || cxs_rx_active_req)
        next_state = ST_ACTIV_REQ;
    end
    ST_ACTIV_REQ: begin
      if (link_ctrl_ack) next_state = ST_ACTIV_ACK;
      else if (timeout) next_state = ST_ERROR;
    end
    ST_ACTIV_ACK: begin
      if (credit_ready) next_state = ST_RUN;
    end
    ST_RUN: begin
      if (cxs_tx_deact_hint || cxs_rx_deact_hint)
        next_state = ST_DEACT;
      else if (fdi_pl_retrain)
        next_state = ST_RETRAIN;
    end
    ST_DEACT: begin
      if (deact_complete) next_state = ST_STOP;
    end
    ST_RETRAIN: begin
      if (!fdi_pl_retrain) next_state = ST_RUN;
    end
    ST_ERROR: begin
      if (!cxs_rst_n) next_state = ST_STOP;
    end
  endcase
end

// 状态寄存器
always_ff @(posedge cxs_clk or negedge cxs_rst_n) begin
  if (!cxs_rst_n) curr_state <= ST_STOP;
  else curr_state <= next_state;
end

// 输出信号
assign cxs_tx_active = (curr_state == ST_RUN) || (curr_state == ST_ACTIV_ACK);
assign cxs_rx_active = (curr_state == ST_RUN) || (curr_state == ST_ACTIV_ACK);
assign link_active = (curr_state == ST_RUN);
assign link_error = (curr_state == ST_ERROR);
```

---

## 6. 配置寄存器 / Configuration Registers (CSRs)

### 6.1 寄存器地址映射

| 寄存器名 | 地址偏移 | 大小 | 访问类型 | 描述 |
|----------|----------|------|----------|------|
| LINK_CTRL | 0x00 | 32-bit | R/W | 链路控制 |
| LINK_STATUS | 0x04 | 32-bit | R | 链路状态 |
| LINK_CONFIG | 0x08 | 32-bit | R/W | 链路配置 |
| LINK_TIMEOUT | 0x0C | 32-bit | R/W | 超时配置 |

---

## 7. 性能规格 / Performance Specifications

### 7.1 性能指标

| 指标 | 目标值 | 单位 |
|------|--------|------|
| 激活延迟 | < 100 | 周期 |
| 停用延迟 | < 50 | 周期 |
| Retrain响应 | < 10 | 周期 |

---

**文档结束**

**相关文档：**
- 架构规格：`docs/specification/ucie_cxs_fdi_arch_spec.md`
- Credit管理规格：`docs/specification/credit_mgr_spec.md`
- 编码规范：`docs/coding_standards/coding_guide.md`
