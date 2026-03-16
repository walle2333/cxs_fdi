# CXS RX Interface模块设计规格书 (CXS RX Interface Module Design Specification)

**文档编号**: [MOD-CXS-RX-IF-001]  
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

本文档定义了CXS RX Interface模块的详细设计规格，作为RTL设计、验证和集成的唯一真实来源(One Source of Truth)。CXS RX Interface是UCIe CXS-FDI Bridge的核心接口模块之一，负责接收来自内部RX Path Logic的数据，并将其转换为CXS协议格式发送给上层协议层。

### 1.2 功能描述 / Functional Description

CXS RX Interface模块实现Bridge内部数据通路到CXS协议层的协议接口功能，负责数据封装，并与下游RX Path Logic完成握手交互。Credit管理由独立的credit_mgr模块负责，本模块不包含Credit授予/退还逻辑。

**主要功能：**
- **数据发送**：将内部RX数据封装为CXS格式发送给协议层，包括cxs_rx_valid、cxs_rx_data、cxs_rx_user、cxs_rx_cntl等
- **链路状态交互**：处理链路激活请求(cxs_rx_active_req)和停用提示(cxs_rx_deact_hint)，接收激活确认(cxs_rx_active)用于发送门控
- **错误标记透传**：通过CXSCNTL的ENDERROR位传递错误标记，用于RAS功能支持

**模块在系统中的位置：**
```
+---------------------------+     +---------------------------+     +---------------------------+
|    CXS RX Interface       | CXS |  CXS RX Interface         |     |  RX Path Logic            |
| (本模块 - Link Term)      |<────| (协议层输出)               |     | (RX Async FIFO)           |
|                          |     |                           |     |                           |
| cxs_rx_* ◀───────────────│────│ cxs_rx_* outputs  ◀───────│────│                          |
|                           |     |                           │     |                          |
+---------------------------+     +---------------------------+     +---------------------------+
```

**目标应用场景：**
- 多芯片CPU/GPU互连扩展场景下的下行数据接收
- 服务器SoC的Die-to-Die通信中CXS协议数据输出
- 高性能计算芯片间的低延迟互连，协议层数据接收

### 1.3 目标与非目标 / Goals and Non-Goals

**目标 (Goals) - 必须实现：**
| 目标 | 描述 | 优先级 | RTL实现要求 |
|------|------|--------|-------------|
| CXS协议合规 | 完全遵循AMBA CXS Protocol Specification Issue D信号定义和时序要求 | P0 | 信号必须与CXS标准命名一致 |
| 高性能数据发送 | 支持512位Flit宽度，每周期处理一个Flit | P0 | 输出通路无流水线停顿 |
| 链路状态机集成 | 正确响应链路激活/停用请求 | P1 | 状态机与Link Control FSM交互 |
| RAS支持 | 正确透传ENDERROR标记(通过CXSCNTL)和User bits | P1 | CXSCNTL寄存器传递 |

**非目标 (Non-Goals) - 明确排除：**
- 数据缓冲功能：本模块仅做接口封装，数据缓冲由RX Path Logic负责
- CXS协议层事务解析：本模块不透传具体的CHI事务内容
- FDI协议处理：FDI侧接口处理由fdi_rx_if模块负责

### 1.4 关键指标 / Key Metrics

| 指标 | 目标值 | 单位 | 备注 | RTL实现影响 |
|------|--------|------|------|-------------|
| 工作频率 | 2.0 | GHz | 与CXS接口同步 | 时序关键路径约束 |
| 吞吐量 | 128 | GB/s | 512bit × 2.0GHz | 数据通路需无气泡 |
| 输出延迟 | 1 | 时钟周期 | 数据到valid延迟 | 输出寄存器优化 |
| 面积估算 | < 500 | 门数 | 逻辑面积 | 主要是输出寄存器 |
| 功耗估算 | < 30 | mW | 典型功耗 | 动态功耗为主 |

---

## 2. 架构设计 / Architecture Design

### 2.1 模块顶层框图 / Module Top-Level Block Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                              CXS RX Interface (cxs_rx_if)                               │
│                                                                                          │
│   ═══════════════════════════════════════════════════════════════════════════════════   │
│                              [Clock Domain: cxs_clk]                                     │
│   ═══════════════════════════════════════════════════════════════════════════════════   │
│                                                                                          │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │                              来自RX Path Logic的输入                                │   │
│   │  rx_data_in[CXS_DATA_WIDTH-1:0]    ───────────────────────────────────────────────────►   │   │
│   │  rx_user_in[CXS_USER_WIDTH-1:0]     ───────────────────────────────────────────────►   │   │
│   │  rx_cntl_in           ───────────────────────────────────────────────────►   │   │
│   │  rx_last_in           ───────────────────────────────────────────────────►   │   │
│   │  *(rx_cntl_in包含ENDERROR位)* ───────────────────────────────────────────►   │   │
│   │  rx_srcid_in/tgtid_in ────────────────────────────────────────────────►   │   │
│   │  rx_valid_in          ──────────────────────────────────────────────────►   │   │
│   │  rx_data_ack ◄─────────────────────────────────────────────────────────   │   │
│   └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                              │                                           │
│                                              ▼                                           │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │                              数据缓冲与调度单元 (Data Buffer & Scheduler)          │   │
│   │         ┌─────────────────────────────────────────────────────────────┐        │   │
│   │         │   rx_data_reg: 接收数据寄存器组                            │        │   │
│   │         │   rx_valid_reg: 数据有效标志                               │        │   │
│   │         │   sched_valid: 发送调度允许                               │        │   │
│   │         └─────────────────────────────────────────────────────────────┘        │   │
│   └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                              │                                           │
│                                              ▼                                           │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │                              CXS输出接口 (发送给协议层)                           │   │
│   │  cxs_rx_valid    ◄──────────────────────────────────────────────────   │   │
│   │  cxs_rx_data    ◄──────────────────────────────────────────────────   │   │
│   │  cxs_rx_user    ◄──────────────────────────────────────────────────   │   │
│   │  cxs_rx_cntl    ◄──────────────────────────────────────────────────   │   │
│   │  *(cxs_rx_cntl包含ENDERROR位)* ◄────────────────────────────────────   │   │
│   │  cxs_rx_last    ◄──────────────────────────────────────────────────   │   │
│   │  cxs_rx_srcid/tgtid ◄────────────────────────────────────────────   │   │
│   └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                              │                                           │
│   ┌─────────────────────────────────────────┴────────────────────────────────────────┐  │
│   │                              链路状态控制接口                                      │  │
│   │  cxs_rx_active_req ──────┐                                                        │  │
│   │  cxs_rx_deact_hint ──────┼──►  ┌────────────────────────────────────────────┐    │  │
│   │  cxs_rx_active ◄──────────┘     │      链路状态处理逻辑                      │    │  │
│   │                                 │  (传递给Link Control FSM或直接输出)       │    │  │
│   │                                 └────────────────────────────────────────────┘    │  │
│   └─────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                          │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

**子模块列表：**
| 模块名称 | 功能描述 | 关键接口 | 时钟域 | RTL实现要点 |
|----------|----------|----------|--------|-------------|
| 数据缓冲与调度单元 | 接收并缓冲RX数据，调度发送 | rx_data_in, cxs_rx_valid等 | cxs_clk | 流水线缓冲 |
| 链路状态处理单元 | 处理激活/停用请求 | active_req, deact_hint, active_ack | cxs_clk | 握手协议实现 |
| CXS输出封装单元 | 格式化输出信号 | cxs_rx_data, cxs_rx_valid等 | cxs_clk | 协议信号封装 |

### 2.2 数据流 / Data Flow

**主数据通路（RTL实现路径）：**
```
rx_valid_in      ──▶┐
rx_data_in       ──▶├── 数据缓冲与调度 ──▶ CXS输出封装 ──▶ cxs_rx_valid
rx_user_in       ──▶│  (调度)           (协议格式)       cxs_rx_data
rx_cntl_in[含ENDERROR] ──▶│                               cxs_rx_user
rx_last_in       ──▶┘                               cxs_rx_cntl(含ENDERROR)
                                              cxs_rx_last
                                               │
                                               ▼
                                      协议层接收
```

**控制流（RTL状态机）：**
```
cxs_rx_active_req ──▶ 链路状态处理 ──▶ cxs_rx_active
cxs_rx_deact_hint ──▶ 链路状态处理 ──▶ 停止发送
```

**数据流详细描述（RTL设计指导）：**

1. **输入阶段**：
   - RX Path Logic通过rx_valid_in信号发送数据
   - 本模块通过rx_data_ack反馈接收状态
   - 数据在rx_valid_in为高期间保持稳定

2. **处理阶段**：
   - 数据缓冲单元接收数据，存入内部寄存器
   - 调度单元检查是否有可发送数据

3. **输出阶段**：
   - CXS输出封装单元将数据转换为CXS协议格式
   - cxs_rx_valid信号指示数据有效
   - 协议层通过CXS接收数据

### 2.3 子模块层次 / Submodule Hierarchy

```
cxs_rx_if (CXS RX Interface - 顶层模块)
├── cxs_rx_if_data_buffer (数据缓冲与调度单元)
│   ├── rx_data_reg (输入数据寄存) - **实现关键**: 上升沿采样
│   ├── rx_valid_reg (有效标志寄存) - **实现关键**: 状态保持
│   └── scheduler (调度逻辑) - **实现关键**: 有效/就绪调度
├── cxs_rx_if_link_ctrl (链路状态处理单元)
│   ├── active_req_handler (激活请求处理) - **实现关键**: 请求响应
│   └── deact_hint_handler (停用提示处理) - **实现关键**: 优雅停机
└── cxs_rx_if_output_pack (CXS输出封装单元)
    ├── output_reg (输出寄存器) - **实现关键**: 协议格式封装
    └── valid_gen (Valid生成) - **实现关键**: 握手时序
```

---

## 3. 接口定义 / Interface Definitions

### 3.1 顶层接口汇总 / Top-Level Interface Summary

| 接口分类 | 接口名称 | 方向 | 位宽 | 协议 | 时钟域 | RTL实现要求 |
|----------|----------|------|------|------|--------|-------------|
| 时钟复位 | cxs_clk | Input | 1 | - | - | 全局时钟，上升沿采样，2.0GHz |
| 时钟复位 | cxs_rst_n | Input | 1 | - | - | 低电平异步复位，同步释放 |
| 内部输入 | rx_valid_in | Input | 1 | 内部 | cxs_clk | 来自RX Path Logic的数据有效 |
| 内部输入 | rx_data_in | Input | [CXS_DATA_WIDTH] | 内部 | cxs_clk | 数据载荷 |
| 内部输入 | rx_user_in | Input | [CXS_USER_WIDTH] | 内部 | cxs_clk | 用户定义位(可选) |
| 内部输入 | rx_last_in | Input | 1 | 内部 | cxs_clk | 包边界指示 |
| 内部输入 | rx_cntl_in | Input | [CXS_CNTL_WIDTH] | 内部 | cxs_clk | 控制字段(含ENDERROR位) |
| 内部输入 | rx_srcid_in | Input | [CXS_SRCID_WIDTH] | 内部 | cxs_clk | 源ID(可选) |
| 内部输入 | rx_tgtid_in | Input | [CXS_TGTID_WIDTH] | 内部 | cxs_clk | 目标ID(可选) |
| 内部输出 | rx_data_ack | Output | 1 | 内部 | cxs_clk | 数据接收确认 |
| CXS输出 | cxs_rx_valid | Output | 1 | CXS | cxs_clk | 发送端数据有效指示 |
| CXS输出 | cxs_rx_data | Output | [CXS_DATA_WIDTH] | CXS | cxs_clk | 数据载荷 |
| CXS输出 | cxs_rx_user | Output | [CXS_USER_WIDTH] | CXS | cxs_clk | 用户定义位(可选)，位宽0-64可配置 |
| CXS输出 | cxs_rx_cntl | Output | [CXS_CNTL_WIDTH] | CXS | cxs_clk | 控制字段(含ENDERROR位) |
| CXS输出 | cxs_rx_last | Output | 1 | CXS | cxs_clk | 包边界指示(可选) |
| CXS输出 | cxs_rx_srcid | Output | [CXS_SRCID_WIDTH] | CXS | cxs_clk | 源ID(可选) |
| CXS输出 | cxs_rx_tgtid | Output | [CXS_TGTID_WIDTH] | CXS | cxs_clk | 目标ID(可选) |
| CXS输入 | cxs_rx_active_req | Input | 1 | CXS | cxs_clk | 链路激活请求(可选) |
| CXS输入 | cxs_rx_active | Input | 1 | CXS | cxs_clk | 链路激活确认(可选) |
| CXS输入 | cxs_rx_deact_hint | Input | 1 | CXS | cxs_clk | 链路停用提示(可选) |

### 3.2 详细接口定义 / Detailed Interface Specifications

#### 3.2.1 CXS数据输出接口

| 信号名 | CXS标准名 | 方向 | 位宽 | 描述 | RTL实现要求 |
|--------|-----------|------|------|------|-------------|
| cxs_rx_valid | **CXSVALID** | Output | 1 | 发送端Flit有效指示。高电平时表示CXSDATA有效 | 寄存器输出，与clk同步 |
| cxs_rx_data | **CXSDATA** | Output | [CXS_DATA_WIDTH] | 数据载荷。支持8-2048位，本设计默认512位 | 寄存器输出，与valid同步 |
| cxs_rx_user | **CXSUSER** | Output | [CXS_USER_WIDTH] | 用户定义位。**可选信号**，用于传递协议层扩展信息。位宽0-64位可配置，0表示不包含 | 寄存器输出 |
| cxs_rx_cntl | **CXSCNTL** | Output | [CXS_CNTL_WIDTH] | 控制字段(含ENDERROR位用于错误标记) | 寄存器输出 |
| cxs_rx_last | **CXSLAST** | Output | 1 | 包边界指示(可选) | 寄存器输出，默认高 |

#### 3.2.2 CXS链路控制接口

| 信号名 | CXS标准名 | 方向 | 位宽 | 描述 | RTL实现要求 |
|--------|-----------|------|------|------|-------------|
| cxs_rx_active_req | **CXSACTIVEREQ** | Input | 1 | 链路激活请求 | 高电平有效 |
| cxs_rx_active | **CXSACTIVEACK** | Input | 1 | 链路激活确认 | 高电平有效 |
| cxs_rx_deact_hint | **CXSDEACTHINT** | Input | 1 | 链路停用提示 | 高电平有效 |

#### 3.2.4 内部输入接口

| 信号名 | 方向 | 位宽 | 描述 | RTL实现要求 |
|--------|------|------|------|-------------|
| rx_valid_in | Input | 1 | 输入数据有效指示 | 上升沿采样 |
| rx_data_in | Input | [CXS_DATA_WIDTH] | 输入数据载荷 | 与valid同步 |
| rx_data_ack | Output | 1 | 数据接收确认 | 握手响应 |

### 3.3 协议规范 / Protocol Specifications

**参考协议文档：**
| 协议名称 | 版本 | 文档编号 | RTL实现要点 |
|----------|------|----------|-------------|
| AMBA CXS Protocol Specification | Issue D | ARM IHI 0079 | CXSVALID时序要求 |
| AMBA CHI Chip-to-Chip (C2C) Architecture Specification | Issue A | ARM IHI 0098 | 协议层时序约束 |

---

## 4. 时钟与复位 / Clocks and Resets

### 4.1 时钟域 / Clock Domains

| 时钟名称 | 频率 | 描述 | RTL实现要求 |
|----------|------|------|-------------|
| cxs_clk | 2.0 GHz (1.5~2.0) | CXS侧协议时钟 | 所有时序逻辑使用上升沿 |

### 4.2 跨时钟域 / Clock Domain Crossings (CDC)

本模块为单时钟域模块(cxs_clk)，不涉及内部CDC。

### 4.3 复位域 / Reset Domains

| 复位名称 | 有效电平 | 类型 | 作用范围 | RTL实现要求 |
|----------|----------|------|----------|-------------|
| cxs_rst_n | Low | 全局 | 本模块 | 异步断言，同步释放 |

---

## 5. 功能描述 / Functional Description

### 5.1 功能概述 / Functional Overview

CXS RX Interface模块的核心功能是实现Bridge内部RX数据通路到CXS协议层的数据传输，严格遵循CXS协议的握手机制与时序要求。

**核心功能模块RTL说明：**

#### 数据缓冲与调度单元 (Data Buffer & Scheduler Unit)
- **模块名称**: Data Buffer & Scheduler Unit
- **RTL职责**：接收并缓冲RX数据，根据内部有效状态调度发送
- **输入处理**：采样rx_valid_in和rx_data_in
- **核心逻辑**：
  ```systemverilog
  // 数据接收
  always_ff @(posedge cxs_clk or negedge cxs_rst_n) begin
    if (!cxs_rst_n) begin
      rx_data_reg <= '0;
      rx_valid_reg <= 1'b0;
    end else begin
      if (rx_valid_in && rx_data_ack) begin
        rx_data_reg <= rx_data_in;
        rx_valid_reg <= 1'b1;
      end else if (cxs_rx_valid) begin
        rx_valid_reg <= 1'b0;  // 数据发送后清除
      end
    end
  end
  
  // 调度发送
  assign cxs_rx_valid = rx_valid_reg;
  assign rx_data_ack = !rx_valid_reg;
  ```

#### 链路状态处理单元 (Link Status Handler Unit)
- **模块名称**: Link Status Handler Unit
- **RTL职责**：处理链路激活/停用请求
- **状态管理**：与cxs_tx_if对称的状态机

#### CXS输出封装单元 (CXS Output Packing Unit)
- **模块名称**: CXS Output Packing Unit
- **RTL职责**：将数据封装为CXS协议格式输出

### 5.2 状态机 / State Machines

#### 5.2.1 链路状态处理状态机

**状态定义（RTL编码方案）：**
| 状态 | 编码 | 描述 | RTL退出条件 |
|------|------|------|-------------|
| IDLE | 2'b00 | 链路未激活，不发送数据 | active_req==1 |
| ACTIV_REQ | 2'b01 | 激活请求已发送 | active_ack==1 |
| ACTIVE | 2'b10 | 链路激活，正常发送数据 | deact_hint==1 |
| DEACT | 2'b11 | 停用处理中 | deact_complete==1 |

### 5.3 典型事务流程 / Example Transactions

#### 基本数据发送流程
```
cxs_clk:           __|‾‾‾‾|__|‾‾‾‾|__|‾‾‾‾|__|‾‾‾‾|__|‾‾‾‾|__
rx_valid_in:      ____|‾‾‾‾|___________________
rx_data_in:       ----< DATA1 >---------------
rx_data_ack:      _________|‾‾‾‾|_____________
cxs_rx_valid:      __________________|‾‾‾‾|__________________
cxs_rx_data:      -------------------< DATA1 >--------------
```

### 5.4 错误处理 / Error Handling

#### 错误类型（RTL检测）

| 错误代码 | 错误名称 | 描述 | RTL检测方式 |
|----------|----------|------|-------------|
| 0x01 | ERR_LINK_DOWN | 链路断开 | 状态检测 |

---

## 6. 配置寄存器 / Configuration Registers (CSRs)

### 6.1 寄存器地址映射 / Register Address Map

| 寄存器名 | 地址偏移 | 大小 | 访问类型 | 描述 |
|----------|----------|------|----------|------|
| RX_IF_CTRL | 0x00 | 32-bit | R/W | RX接口控制寄存器 |
| RX_IF_STATUS | 0x04 | 32-bit | R | RX接口状态寄存器 |
| RX_IF_CONFIG | 0x08 | 32-bit | R/W | RX接口配置寄存器 |
| RX_IF_ERR_STATUS | 0x14 | 32-bit | R/W1C | 错误状态寄存器 |

---

## 7. 性能规格 / Performance Specifications

### 7.1 性能指标 / Performance Metrics

| 指标 | 目标值 | 单位 | RTL实现约束 |
|------|--------|------|-------------|
| 峰值吞吐量 | 128 | GB/s | 512bit × 2.0GHz |
| 持续吞吐量 | 128 | GB/s | 每周期一个Flit |
| 输出延迟 | 1 | 时钟周期 | 寄存器输出 |

---

## 9. 验证与调试 / Verification and Debug

### 9.1 验证策略

| 方法 | 覆盖率目标 | RTL验证要点 |
|------|------------|-------------|
| 随机验证 | > 95% | 数据组合 |
| 定向测试 | 100% | 边界条件 |
| 形式验证 | 关键路径 | 协议合规 |

---

**文档结束**

**相关文档：**
- 架构规格：`docs/specification/ucie_cxs_fdi_arch_spec.md`
- CXS TX接口规格：`docs/specification/cxs_tx_if_spec.md`
- 编码规范：`docs/coding_standards/coding_guide.md`
