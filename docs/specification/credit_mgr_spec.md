# Credit Manager模块设计规格书 (Credit Manager Module Design Specification)

**文档编号**: [MOD-CREDIT-MGR-001]  
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

本文档定义了Credit Manager模块的详细设计规格，作为RTL设计、验证和集成的唯一真实来源(One Source of Truth)。Credit Manager是UCIe CXS-FDI Bridge的全局信用管理模块，负责协调TX和RX方向的Credit计数和流控。

### 1.2 功能描述 / Functional Description

Credit Manager模块实现全双工Credit管理功能，负责TX方向（发送）和RX方向（接收）的Credit计数、分配和回收。

**主要功能：**
- **TX Credit管理**：管理发送给CXS协议层的Credit授权（cxs_tx_crdgnt）
- **RX Credit管理**：管理来自CXS协议层的Credit接收（cxs_rx_crdgnt）
- **Credit计数**：维护可用的Credit数量
- **Explicit Credit Return**：支持链路停用时的Credit退还机制
- **Credit就绪输出**：提供credit_ready指示给链路控制与流控逻辑
- **FDI流控协同**：credit_ready/credit可用信息用于驱动或门控fdi_lp_irdy相关流控

**模块在系统中的位置：**
```
+---------------------------+     +---------------------------+
|    CXS Protocol Layer     |     |  Credit Manager          |
| (Protocol Interface)     │◀───▶│ (独立全局模块)             │
| cxs_*_crdgnt/crdret       │     │                          |
+---------------------------+     +---------------------------+
           │                                   │
           │                                   ▼
           │                         +---------------------------+
           │                         |  Link Control / FDI TX   |
           │                         |  credit_ready / irdy ctl |
           └─────────────────────────▶|  (flow-control inputs)  |
                                     +---------------------------+
```

### 1.3 目标与非目标 / Goals and Non-Goals

**目标 (Goals) - 必须实现：**
| 目标 | 描述 | 优先级 | RTL实现要求 |
|------|------|--------|-------------|
| Credit计数准确 | Credit计数正确无误 | P0 | 原子操作，无竞态 |
| Credit协议合规 | 正确产生cxs_tx_crdgnt信号 | P0 | 禁止与valid组合路径 |
| Explicit Return | 支持Credit退还机制 | P1 | 退还逻辑正确 |

**非目标 (Non-Goals) - 明确排除：**
- 数据通路处理：不参与数据传输

---

## 2. 架构设计 / Architecture Design

### 2.1 模块顶层框图 / Module Top-Level Block Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                              Credit Manager (credit_mgr)                              │
│                                                                                          │
│   ═══════════════════════════════════════════════════════════════════════════════════   │
│                              [Clock Domain: cxs_clk]                                     │
│   ═══════════════════════════════════════════════════════════════════════════════════   │
│                                                                                          │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │                              TX Credit管理                                      │   │
│   │  ┌────────────────┐    ┌────────────────┐    ┌────────────────┐            │   │
│   │  │ TX Credit计数  │◀───│ Credit消耗     │◀───│ 数据发送确认   │            │   │
│   │  │ (tx_credit_cnt)│    │ (tx_decrement) │    │ (tx_data_valid)│            │   │
│   │  └───────┬────────┘    └────────────────┘    └────────────────┘            │   │
│   │          │                                                                   │   │
│   │          ▼                                                                   │   │
│   │  ┌────────────────┐    ┌────────────────┐                                  │   │
│   │  │ TX Credit授权  │───▶│ cxs_tx_crdgnt  │                                  │   │
│   │  │ (tx_credit_gnt)│    │ (输出信号)     │                                  │   │
│   │  └────────────────┘    └────────────────┘                                  │   │
│   │          │                                                                   │   │
│   │          ▼                                                                   │   │
│   │  ┌────────────────┐    ┌────────────────┐                                  │   │
│   │  │ Credit退还      │◀───│ cxs_tx_crdret  │                                  │   │
│   │  │ (tx_increment) │    │ (Explicit Ret) │                                  │   │
│   │  └────────────────┘    └────────────────┘                                  │   │
│   └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                          │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │                              RX Credit管理                                      │   │
│   │  ┌────────────────┐    ┌────────────────┐    ┌────────────────┐            │   │
│   │  │ RX Credit计数  │◀───│ Credit消耗     │◀───│ 数据接收确认   │            │   │
│   │  │ (rx_credit_cnt)│    │ (rx_decrement) │    │ (rx_data_valid)│            │   │
│   │  └───────┬────────┘    └────────────────┘    └────────────────┘            │   │
│   │          │                                                                   │   │
│   │          ▼                                                                   │   │
│   │  ┌────────────────┐    ┌────────────────┐                                  │   │
│   │  │ RX Credit授权  │───▶│ cxs_rx_crdgnt  │                                  │   │
│   │  │ (rx_credit_gnt)│    │ (输出信号)     │                                  │   │
│   │  └────────────────┘    └────────────────┘                                  │   │
│   │          │                                                                   │   │
│   │          ▼                                                                   │   │
│   │  ┌────────────────┐    ┌────────────────┐                                  │   │
│   │  │ Credit退还      │◀───│ cxs_rx_crdret  │                                  │   │
│   │  │ (rx_increment) │    │ (Explicit Ret) │                                  │   │
│   │  └────────────────┘    └────────────────┘                                  │   │
│   └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                          │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │                              配置与状态接口                                       │   │
│   │  cfg_credit_max ◀─────────────────────────────────────────────────   │   │
│   │  status_credit_cnt ◀──────────────────────────────────────────────   │   │
│   └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                          │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

**子模块列表：**
| 模块名称 | 功能描述 | 关键接口 | 时钟域 | RTL实现要点 |
|----------|----------|----------|--------|-------------|
| TX Credit逻辑 | TX方向Credit管理 | cxs_tx_crdgnt | cxs_clk | 计数逻辑 |
| RX Credit逻辑 | RX方向Credit管理 | cxs_rx_crdgnt | cxs_clk | 计数逻辑 |

### 2.2 子模块层次 / Submodule Hierarchy

```
credit_mgr (Credit Manager - 顶层模块)
├── credit_mgr_tx (TX Credit管理单元)
│   ├── tx_credit_counter (TX Credit计数) - **实现关键**: 格雷码计数
│   ├── tx_credit_grant (TX Credit授权) - **实现关键**: 计数>0时授权
│   └── tx_credit_return (TX Credit退还) - **实现关键**: Explicit Return
├── credit_mgr_rx (RX Credit管理单元)
│   ├── rx_credit_counter (RX Credit计数) - **实现关键**: 格雷码计数
│   ├── rx_credit_grant (RX Credit授权) - **实现关键**: 计数>0时授权
│   └── rx_credit_return (RX Credit退还) - **实现关键**: Explicit Return
└── credit_mgr_cfg (配置单元)
    ├── credit_max_cfg (最大Credit配置) - **实现关键**: 参数化
    └── credit_init_cfg (初始Credit配置) - **实现关键**: 启动参数
```

---

## 3. 接口定义 / Interface Definitions

### 3.1 顶层接口汇总 / Top-Level Interface Summary

| 接口分类 | 接口名称 | 方向 | 位宽 | 时钟域 | RTL实现要求 |
|----------|----------|------|------|--------|-------------|
| 时钟复位 | cxs_clk | Input | 1 | - | 全局时钟 |
| 时钟复位 | cxs_rst_n | Input | 1 | - | 异步复位 |
| TX输入 | tx_data_valid | Input | 1 | cxs_clk | 数据发送有效 |
| TX输入 | cxs_tx_crdret | Input | 1 | cxs_clk | Credit退还 |
| TX输出 | cxs_tx_crdgnt | Output | 1 | cxs_clk | Credit授权 |
| RX输入 | rx_data_valid | Input | 1 | cxs_clk | 数据接收有效 |
| RX输入 | cxs_rx_crdret | Input | 1 | cxs_clk | Credit退还 |
| RX输出 | cxs_rx_crdgnt | Output | 1 | cxs_clk | Credit授权 |
| 状态 | credit_ready | Output | 1 | cxs_clk | Credit可用(用于Link Ctrl) |
| 配置 | cfg_credit_max | Input | [5:0] | cxs_clk | 最大Credit数 |
| 配置 | cfg_credit_init | Input | [5:0] | cxs_clk | 初始Credit数 |
| 状态 | status_tx_credit_cnt | Output | [5:0] | cxs_clk | TX当前Credit数 |
| 状态 | status_rx_credit_cnt | Output | [5:0] | cxs_clk | RX当前Credit数 |

---

## 4. 功能描述 / Functional Description

### 4.1 TX Credit管理

```systemverilog
// TX Credit计数
always_ff @(posedge cxs_clk or negedge cxs_rst_n) begin
  if (!cxs_rst_n) begin
    tx_credit_cnt <= CFG_CREDIT_INIT;
  end else begin
    if (tx_data_valid) begin
      tx_credit_cnt <= tx_credit_cnt - 1;  // 消耗Credit
    end
    if (cxs_tx_crdret) begin
      tx_credit_cnt <= tx_credit_cnt + 1;  // 退还Credit
    end
  end
end

// Credit ready indication (example policy)
assign credit_ready = (tx_credit_cnt > 0) && (rx_credit_cnt > 0);

// TX Credit授权 - 必须通过寄存器输出，禁止组合路径
always_ff @(posedge cxs_clk or negedge cxs_rst_n) begin
  if (!cxs_rst_n) begin
    cxs_tx_crdgnt <= 1'b0;
  end else begin
    cxs_tx_crdgnt <= (tx_credit_cnt > 0);
  end
end
```

### 4.2 RX Credit管理

```systemverilog
// RX Credit计数
always_ff @(posedge cxs_clk or negedge cxs_rst_n) begin
  if (!cxs_rst_n) begin
    rx_credit_cnt <= CFG_CREDIT_INIT;
  end else begin
    if (rx_data_valid) begin
      rx_credit_cnt <= rx_credit_cnt - 1;
    end
    if (cxs_rx_crdret) begin
      rx_credit_cnt <= rx_credit_cnt + 1;
    end
  end
end

// RX Credit授权
always_ff @(posedge cxs_clk or negedge cxs_rst_n) begin
  if (!cxs_rst_n) begin
    cxs_rx_crdgnt <= 1'b0;
  end else begin
    cxs_rx_crdgnt <= (rx_credit_cnt > 0);
  end
end
```

---

## 5. 状态机 / State Machines

本模块无独立状态机，Credit管理基于计数器状态。

---

## 6. 配置寄存器 / Configuration Registers (CSRs)

| 寄存器名 | 地址偏移 | 大小 | 访问类型 | 描述 |
|----------|----------|------|----------|------|
| CREDIT_MGR_CTRL | 0x00 | 32-bit | R/W | Credit管理控制 |
| CREDIT_MGR_TX_CFG | 0x04 | 32-bit | R/W | TX Credit配置 |
| CREDIT_MGR_RX_CFG | 0x08 | 32-bit | R/W | RX Credit配置 |
| CREDIT_MGR_TX_STATUS | 0x0C | 32-bit | R | TX Credit状态 |
| CREDIT_MGR_RX_STATUS | 0x10 | 32-bit | R | RX Credit状态 |

---

**文档结束**

**相关文档：**
- 架构规格：`docs/specification/ucie_cxs_fdi_arch_spec.md`
- CXS TX接口规格：`docs/specification/cxs_tx_if_spec.md`
- CXS RX接口规格：`docs/specification/cxs_rx_if_spec.md`
- 编码规范：`docs/coding_standards/coding_guide.md`
