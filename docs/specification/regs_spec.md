# Registers模块设计规格书 (Registers Module Design Specification)

**文档编号**: [MOD-REGS-001]  
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

本文档定义了Registers模块的详细设计规格，作为RTL设计、验证和集成的唯一真实来源(One Source of Truth)。Registers模块是UCIe CXS-FDI Bridge的配置和状态管理模块，包含APB接口、CSR寄存器文件和性能计数器。

### 1.2 功能描述 / Functional Description

Registers模块实现Bridge的完整配置和状态管理功能，包括APB接口访问、CSR寄存器读写、性能统计和中断管理。

**主要功能：**
- **APB接口**：提供标准APB协议访问接口，用于软件配置和状态读取
- **CSR寄存器文件**：包含所有模块的控制、状态和配置寄存器
- **性能计数器**：统计TX/RX数据流量、错误计数等性能指标
- **中断管理**：统一管理各模块的中断请求

**模块在系统中的位置：**
```
+---------------------------+     +---------------------------+
|    APB Master             │     |  Registers (regs)         │
| (CPU/Software)            │────▶│ (APB接口+CSR+计数器)       │
|                          │     │                           │
| apb_paddr ───────────────│────▶│ CSR_decode ──────────────▶│
| apb_pwdata ──────────────│────▶│ Module registers ◄────────│
| apb_prdata ◄──────────────│────◀│                          │
+---------------------------+     +---------------------------+
           │                               │
           │                               ▼
           │                      +---------------------------+
           │                      |  Performance Counters    │
           │                      │  TX/RX flit counters     │
           │                      │  Error counters          │
           │                      │  Link status counters    │
           │                      +---------------------------+
           │                               │
           ▼                               ▼
    [Software Access]            [Internal Module Access]
```

**目标应用场景：**
- 软件启动配置
- 运行时状态监控
- 性能分析
- 错误诊断

### 1.3 目标与非目标 / Goals and Non-Goals

**目标 (Goals) - 必须实现：**
| 目标 | 描述 | 优先级 | RTL实现要求 |
|------|------|--------|-------------|
| APB合规 | 完整实现APB协议 | P0 | 协议时序正确 |
| 寄存器覆盖 | 覆盖所有模块CSR | P0 | 完整寄存器映射 |
| 计数器准确 | 性能计数准确 | P1 | 无计数丢失 |

**非目标 (Non-Goals) - 明确排除：**
- 数据通路处理：仅处理配置和状态

### 1.4 关键指标 / Key Metrics

| 指标 | 目标值 | 单位 | 备注 | RTL实现影响 |
|------|--------|------|------|-------------|
| APB频率 | 100 | MHz | APB时钟 | 访问延迟 |
| 寄存器数量 | 64 | 个 | CSR总数 | 解码复杂度 |
| 计数器位宽 | 32 | bit | 性能计数器 | 计数范围 |
| 面积估算 | < 1K | 门数 | 逻辑面积 | 寄存器文件 |

---

## 2. 架构设计 / Architecture Design

### 2.1 模块顶层框图 / Module Top-Level Block Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                   Registers (regs)                                      │
│                                                                                          │
│   ═══════════════════════════════════════════════════════════════════════════════════   │
│                              [Clock Domain: apb_clk]                                     │
│   ═══════════════════════════════════════════════════════════════════════════════════   │
│                                                                                          │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │                         APB接口单元 (APB Interface Unit)                          │   │
│   │  apb_paddr[31:0]   ───────────────────────────────────────────────────►   │   │
│   │  apb_pwdata[31:0]  ──────────────────────────────────────────────────►   │   │
│   │  apb_prdata[31:0]  ◄─────────────────────────────────────────────────   │   │
│   │  apb_penable       ──────────────────────────────────────────────────►   │   │
│   │  apb_psel          ──────────────────────────────────────────────────►   │   │
│   │  apb_pwrite        ──────────────────────────────────────────────────►   │   │
│   │  apb_pready        ◄─────────────────────────────────────────────────   │   │
│   │  apb_pslverr       ◄─────────────────────────────────────────────────   │   │
│   └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                              │                                           │
│                                              ▼                                           │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │                         地址解码与寄存器访问单元                                   │   │
│   │         ┌─────────────────────────────────────────────────────────────┐        │   │
│   │         │   Address Decoder                                        │        │   │
│   │         │   Write Enable Generation                                │        │   │
│   │         │   Read Data Multiplexing                                 │        │   │
│   │         └─────────────────────────────────────────────────────────────┘        │   │
│   └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                              │                                           │
│                                              ▼                                           │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │                         寄存器组 (Register Bank)                                  │   │
│   │  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐                   │   │
│   │  │ CTRL Registers │  │ STATUS Registers│ │ CONFIG Registers│                   │   │
│   │  │ (控制寄存器)    │  │ (状态寄存器)     │  │ (配置寄存器)    │                   │   │
│   │  └────────────────┘  └────────────────┘  └────────────────┘                   │   │
│   │  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐                   │   │
│   │  │ Counter Registers│ │ ERR Registers  │ │ Interrupt Registers│                │   │
│   │  │ (计数器寄存器)  │  │ (错误寄存器)    │  │ (中断寄存器)    │                   │   │
│   │  └────────────────┘  └────────────────┘  └────────────────┘                   │   │
│   └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                              │                                           │
│                                              ▼                                           │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │                         性能计数器单元 (Performance Counters Unit)                │   │
│   │  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐                   │   │
│   │  │ TX_Flit_Counter│  │ RX_Flit_Counter│  │ Error_Counter  │                   │   │
│   │  │ (发送计数)     │  │ (接收计数)      │  │ (错误计数)      │                   │   │
│   │  └────────────────┘  └────────────────┘  └────────────────┘                   │   │
│   │  ┌────────────────┐  ┌────────────────┐                                      │   │
│   │  │ Link_Up_Counter│  │ Credit_Counter │                                      │   │
│   │  │ (链路UP计数)   │  │ (来自credit_mgr)│                                     │   │
│   │  └────────────────┘  └────────────────┘                                      │   │
│   └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                              │                                           │
│                                              ▼                                           │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │                         中断管理单元 (Interrupt Management Unit)                 │   │
│   │  ┌────────────────┐  ┌────────────────┐                                      │   │
│   │  │ Intr_Sources  │  │ Intr_Enable    │                                      │   │
│   │  │ (中断源)       │  │ (中断使能)     │                                      │   │
│   │  └────────────────┘  └────────────────┘                                      │   │
│   └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                          │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

**子模块列表：**
| 模块名称 | 功能描述 | 关键接口 | 时钟域 | RTL实现要点 |
|----------|----------|----------|--------|-------------|
| APB Interface | APB协议接口 | apb_* 信号 | apb_clk | 协议实现 |
| CSR Register File | 寄存器文件 | 寄存器组 | apb_clk | 读写控制 |
| Performance Counters | 性能计数 | 计数更新 | apb_clk | 计数逻辑 |
| Interrupt Manager | 中断管理 | 中断信号 | apb_clk | 中断控制 |

### 2.2 数据流 / Data Flow

**配置访问流：**
```
APB Write: apb_pwrite=1 → Address Decode → Write Enable → Register Write
APB Read:  apb_pwrite=0 → Address Decode → Read Data Mux → apb_prdata
```

**计数器更新流：**
```
模块中断言计数 → 计数更新逻辑 → 计数器寄存器 → APB读取
```

**中断流：**
```
错误/状态变化 → 中断源检测 → 中断使能检查 → 全局中断输出
```

### 2.3 子模块层次 / Submodule Hierarchy

```
regs (Registers - 顶层模块)
├── regs_apb_if (APB接口单元)
│   ├── apb_protocol (APB协议) - **实现关键**: SETUP/ACCESS时序
│   ├── addr_decode (地址解码) - **实现关键**: 寄存器选择
│   └── data_mux (数据复用) - **实现关键**: 读数据选择
├── regs_csr_file (CSR寄存器文件单元)
│   ├── ctrl_regs (控制寄存器) - **实现关键**: 模块使能/复位
│   ├── status_regs (状态寄存器) - **实现关键**: 状态反映
│   ├── config_regs (配置寄存器) - **实现关键**: 参数配置
│   ├── err_regs (错误寄存器) - **实现关键**: 错误记录
│   └── intr_regs (中断寄存器) - **实现关键**: 中断控制
├── regs_perf_counters (性能计数器单元)
│   ├── tx_flit_cnt (TX Flit计数) - **实现关键**: 发送计数
│   ├── rx_flit_cnt (RX Flit计数) - **实现关键**: 接收计数
│   ├── err_cnt (错误计数) - **实现关键**: 错误统计
│   ├── link_sts_cnt (链路状态计数) - **实现关键**: 状态统计
│   └── credit_cnt_in (来自credit_mgr) - **实现关键**: Credit统计
└── regs_intr_mgr (中断管理单元)
    ├── intr_source (中断源) - **实现关键**: 源检测
    ├── intr_enable (中断使能) - **实现关键**: 使能控制
    ├── intr_status (中断状态) - **实现关键**: 状态记录
    └── intr_output (中断输出) - **实现关键**: 全局中断
```

---

## 3. 接口定义 / Interface Definitions

### 3.1 顶层接口汇总 / Top-Level Interface Summary

| 接口分类 | 接口名称 | 方向 | 位宽 | 协议 | 时钟域 | RTL实现要求 |
|----------|----------|------|------|------|--------|-------------|
| 时钟复位 | apb_clk | Input | 1 | - | - | APB时钟，100MHz |
| 时钟复位 | apb_rst_n | Input | 1 | - | - | APB复位 |
| APB接口 | apb_paddr | Input | 32 | APB | apb_clk | 地址信号 |
| APB接口 | apb_pwdata | Input | 32 | APB | apb_clk | 写数据 |
| APB接口 | apb_prdata | Output | 32 | APB | apb_clk | 读数据 |
| APB接口 | apb_penable | Input | 1 | APB | apb_clk | 使能信号 |
| APB接口 | apb_psel | Input | 1 | APB | apb_clk | 选择信号 |
| APB接口 | apb_pwrite | Input | 1 | APB | apb_clk | 写信号 |
| APB接口 | apb_pready | Output | 1 | APB | apb_clk | 就绪信号 |
| APB接口 | apb_pslverr | Output | 1 | APB | apb_clk | 错误响应 |
| 模块输入 | mod_ctrl_* | Input | - | 内部 | apb_clk | 模块控制信号 |
| 模块输入 | mod_status_* | Input | - | 内部 | apb_clk | 模块状态信号 |
| 模块输入 | mod_err_* | Input | - | 内部 | apb_clk | 模块错误信号 |
| 模块输出 | mod_cfg_* | Output | - | 内部 | apb_clk | 模块配置信号 |
| 中断输出 | irq | Output | [IRQ_WIDTH] | 内部 | apb_clk | 中断请求 |

### 3.2 详细接口定义 / Detailed Interface Specifications

#### 3.2.1 APB接口信号

| 信号名 | 方向 | 位宽 | 描述 | RTL实现要求 |
|--------|------|------|------|-------------|
| apb_paddr | Input | 32 | 地址信号 | 寄存器地址 |
| apb_pwdata | Input | 32 | 写数据 | 写入数据 |
| apb_prdata | Output | 32 | 读数据 | 读出数据 |
| apb_penable | Input | 1 | 使能信号 | APB使能 |
| apb_psel | Input | 1 | 选择信号 | 模块选择 |
| apb_pwrite | Input | 1 | 写信号 | 1=写，0=读 |
| apb_pready | Output | 1 | 就绪信号 | 访问完成 |
| apb_pslverr | Output | 1 | 错误响应 | 错误标志 |

#### 3.2.2 模块接口信号

| 信号名 | 方向 | 描述 | RTL实现要求 |
|--------|------|------|-------------|
| mod_tx_enable | Input | TX模块使能 | 状态输入 |
| mod_rx_enable | Input | RX模块使能 | 状态输入 |
| mod_tx_err | Input | TX错误标志 | 错误输入 |
| mod_rx_err | Input | RX错误标志 | 错误输入 |
| mod_link_status | Input | 链路状态 | 状态输入 |
| mod_cfg | Output | 模块配置 | 配置输出 |

#### 3.2.3 中断接口

| 信号名 | 方向 | 位宽 | 描述 | RTL实现要求 |
|--------|------|------|------|-------------|
| irq | Output | [N] | 中断请求 | 全局中断 |

---

## 4. 时钟与复位 / Clocks and Resets

### 4.1 时钟域 / Clock Domains

| 时钟名称 | 频率 | 描述 | RTL实现要求 |
|----------|------|------|-------------|
| apb_clk | 100 MHz | APB配置时钟 | 标准APB时钟 |

### 4.2 跨时钟域 / Clock Domain Crossings (CDC)

| 源时钟 | 目标时钟 | 信号类型 | 同步方式 | RTL实现 |
|--------|----------|----------|----------|---------|
| cxs_clk | apb_clk | 状态信号 | 2级同步器 | 跨域同步 |
| fdi_lclk | apb_clk | 状态信号 | 2级同步器 | 跨域同步 |

### 4.3 复位域 / Reset Domains

| 复位名称 | 有效电平 | 类型 | 作用范围 | RTL实现要求 |
|----------|----------|------|----------|-------------|
| apb_rst_n | Low | 全局 | 本模块 | 异步断言，同步释放 |
| rst_sw | High | 软件 | 可选 | 同步复位 |

---

## 5. 功能描述 / Functional Description

### 5.1 功能概述 / Functional Overview

Registers模块的核心功能是提供完整的配置和状态管理，包括APB接口访问、CSR寄存器文件、性能计数和中断管理。

**核心功能模块RTL说明：**

#### APB接口单元 (APB Interface Unit)
- **模块名称**: APB Interface Unit
- **RTL职责**：实现标准APB协议访问
- **核心逻辑**：
  ```systemverilog
  // APB状态机
  typedef enum logic [1:0] {
    IDLE   = 2'b00,
    SETUP  = 2'b01,
    ACCESS = 2'b10
  } apb_state_t;
  
  // 写访问
  always_ff @(posedge apb_clk or negedge apb_rst_n) begin
    if (!apb_rst_n) begin
      apb_pready <= 1'b0;
    end else begin
      if (apb_psel && apb_penable && apb_pwrite) begin
        // 写寄存器
        apb_pready <= 1'b1;
      end else begin
        apb_pready <= 1'b0;
      end
    end
  end
  
  // 读访问
  always_ff @(posedge apb_clk or negedge apb_rst_n) begin
    if (apb_psel && apb_penable && !apb_pwrite) begin
      apb_prdata <= regs_rdata[apb_paddr[6:2]];  // 32-bit对齐
    end
  end
  ```

#### CSR寄存器文件单元 (CSR Register File Unit)
- **模块名称**: CSR Register File Unit
- **RTL职责**：实现所有CSR寄存器
- **寄存器组**：
  - 控制寄存器：模块使能、软复位
  - 状态寄存器：链路状态、运行状态
  - 配置寄存器：参数配置
  - 错误寄存器：错误状态记录
  - 中断寄存器：中断使能/状态

#### 性能计数器单元 (Performance Counters Unit)
- **模块名称**: Performance Counters Unit
- **RTL职责**：统计性能数据
- **计数器**：
  ```systemverilog
  // TX Flit计数器
  always_ff @(posedge apb_clk or negedge apb_rst_n) begin
    if (!apb_rst_n) begin
      tx_flit_cnt <= '0;
    end else if (mod_tx_flit) begin
      tx_flit_cnt <= tx_flit_cnt + 1;
    end
  end
  
  // 错误计数器
  always_ff @(posedge apb_clk or negedge apb_rst_n) begin
    if (!apb_rst_n) begin
      err_cnt <= '0;
    end else if (mod_err) begin
      err_cnt <= err_cnt + 1;
    end
  end
  ```

#### 中断管理单元 (Interrupt Management Unit)
- **模块名称**: Interrupt Management Unit
- **RTL职责**：统一管理中断
- **中断处理**：
  ```systemverilog
  // 中断源检测
  assign intr_raw = (tx_err || rx_err || link_down);
  
  // 中断使能
  assign intr_enabled = intr_raw & intr_enable;
  
  // 全局中断
  assign irq = |intr_enabled;
  ```

### 5.2 状态机 / State Machines

#### 5.2.1 APB访问状态机

**状态定义（RTL编码方案）：**
| 状态 | 编码 | 描述 | RTL退出条件 |
|------|------|------|-------------|
| IDLE | 00 | 空闲 | psel==1 |
| SETUP | 01 | 设置 | penable==1 |
| ACCESS | 10 | 访问 | ready==1 |

### 5.3 典型事务流程 / Example Transactions

#### APB读操作
```
apb_clk:      __|‾‾‾|__|‾‾‾|__|‾‾‾|__|‾‾‾|__
apb_psel:     ___|‾‾‾|__________________
apb_pwrite:   ___|‾‾‾|__________________
apb_paddr:    ___|ADDR|__________________
apb_penable:  _______|‾‾‾|________________
apb_prdata:   ___________|DATA|__________
apb_pready:   ___________|‾‾‾|__________
```

#### APB写操作
```
apb_clk:      __|‾‾‾|__|‾‾‾|__|‾‾‾|__|‾‾‾|__
apb_psel:     ___|‾‾‾|__________________
apb_pwrite:   ___|‾‾‾‾‾|_________________
apb_paddr:    ___|ADDR|__________________
apb_pwdata:   ___|DATA|__________________
apb_penable:  _______|‾‾‾|________________
apb_pready:   ___________|‾‾‾|__________
```

### 5.4 错误处理 / Error Handling

#### 错误类型（RTL检测）

| 错误代码 | 错误名称 | 描述 | RTL检测方式 |
|----------|----------|------|-------------|
| 0x01 | ERR_APB_TIMEOUT | APB访问超时 | 超时检测 |
| 0x02 | ERR_ADDR_INVALID | 无效地址 | 解码检测 |
| 0x03 | ERR_WRITE_PROTECT | 写保护违规 | 保护位检测 |

---

## 6. 配置寄存器 / Configuration Registers (CSRs)

### 6.1 寄存器地址映射 / Register Address Map

**基地址**: 0x0000_0000

| 地址偏移 | 寄存器名 | 访问 | 描述 |
|----------|----------|------|------|
| 0x00 | REVISION | RO | 版本寄存器 |
| 0x04 | CTRL | R/W | 全局控制 |
| 0x08 | STATUS | RO | 全局状态 |
| 0x0C | CONFIG | R/W | 全局配置 |
| 0x10 | INT_EN | R/W | 中断使能 |
| 0x14 | INT_STATUS | R/W1C | 中断状态 |
| 0x18 | ERR_STATUS | R/W1C | 错误状态 |
| 0x1C | LINK_CTRL | R/W | 链路控制 |
| 0x20 | TX_CTRL | R/W | TX控制 |
| 0x24 | TX_STATUS | RO | TX状态 |
| 0x28 | RX_CTRL | R/W | RX控制 |
| 0x2C | RX_STATUS | RO | RX状态 |
| 0x30 | TX_FLIT_CNT_L | RO | TX Flit计数低 |
| 0x34 | TX_FLIT_CNT_H | RO | TX Flit计数高 |
| 0x38 | RX_FLIT_CNT_L | RO | RX Flit计数低 |
| 0x3C | RX_FLIT_CNT_H | RO | RX Flit计数高 |
| 0x40 | ERR_CNT_L | RO | 错误计数低 |
| 0x44 | ERR_CNT_H | RO | 错误计数高 |
| 0x48-0x7C | RESERVED | - | 保留 |

### 6.2 寄存器详细定义

#### 控制寄存器 (CTRL) - 0x04

| 位域 | 名称 | 访问 | 描述 |
|------|------|------|------|
| [0] | ENABLE | R/W | 模块使能 |
| [1] | RST_SW | R/W1S | 软件复位 |
| [31:2] | RESERVED | RO | 保留 |

#### 状态寄存器 (STATUS) - 0x08

| 位域 | 名称 | 访问 | 描述 |
|------|------|------|------|
| [0] | TX_READY | RO | TX就绪 |
| [1] | RX_READY | RO | RX就绪 |
| [2] | LINK_UP | RO | 链路UP |
| [31:3] | RESERVED | RO | 保留 |

---

## 7. 性能规格 / Performance Specifications

### 7.1 性能指标 / Performance Metrics

| 指标 | 目标值 | 单位 | RTL实现约束 |
|------|--------|------|-------------|
| APB频率 | 100 | MHz | 访问速率 |
| 访问延迟 | 1-2 | 周期 | 读延迟 |
| 计数器位宽 | 32 | bit | 计数范围 |
| 中断响应 | < 5 | 周期 | 响应时间 |

---

## 9. 验证与调试 / Verification and Debug

### 9.1 验证策略

| 方法 | 覆盖率目标 | RTL验证要点 |
|------|------------|-------------|
| APB协议验证 | 100% | 时序合规 |
| 寄存器验证 | 100% | 读写正确 |
| 计数器验证 | > 95% | 计数准确 |
| 中断验证 | 100% | 触发正确 |

---

**文档结束**

**相关文档：**
- 架构规格：`docs/specification/ucie_cxs_fdi_arch_spec.md`
- TX Path规格：`docs/specification/tx_path_spec.md`
- RX Path规格：`docs/specification/rx_path_spec.md`
- LME Handler规格：`docs/specification/lme_handler_spec.md`
- 编码规范：`docs/coding_standards/coding_guide.md`
