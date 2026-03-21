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
| 寄存器数量 | 32 | 个 | CSR总数(含保留) | 解码复杂度 |
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
| 状态输入 | status_link_state | Input | [2:0] | 内部 | apb_clk | 当前链路状态 |
| 状态输入 | status_busy | Input | 1 | 内部 | apb_clk | 忙标志 |
| 状态输入 | status_tx_ready | Input | 1 | 内部 | apb_clk | TX路径就绪 |
| 状态输入 | status_rx_ready | Input | 1 | 内部 | apb_clk | RX路径就绪 |
| 状态输入 | status_init_done | Input | 1 | 内部 | apb_clk | 初始化完成 |
| 错误输入 | err_status_in | Input | [6:0] | 内部 | apb_clk | 错误状态位图，对应ERR_STATUS[6:0] |
| 事件输入 | evt_link_up | Input | 1 | 内部 | apb_clk | 链路上升事件脉冲 |
| 事件输入 | evt_link_down | Input | 1 | 内部 | apb_clk | 链路下降事件脉冲 |
| 事件输入 | evt_fifo_almost_full | Input | 1 | 内部 | apb_clk | FIFO高水位事件脉冲 |
| 计数输入 | stat_tx_flit_pulse | Input | 1 | 内部 | apb_clk | TX Flit计数脉冲 |
| 计数输入 | stat_rx_flit_pulse | Input | 1 | 内部 | apb_clk | RX Flit计数脉冲 |
| 配置输出 | cfg_enable | Output | 1 | 内部 | apb_clk | CTRL.ENABLE配置输出 |
| 配置输出 | cfg_mode | Output | [7:0] | 内部 | apb_clk | CTRL.MODE配置输出 |
| 配置输出 | cfg_flit_width_sel | Output | [3:0] | 内部 | apb_clk | CTRL.FLIT_WIDTH配置输出 |
| 配置输出 | sw_reset_pulse | Output | 1 | 内部 | apb_clk | CTRL.RESET单周期脉冲 |
| 配置输出 | cfg_max_credit | Output | [7:0] | 内部 | apb_clk | CONFIG.MAX_CREDIT |
| 配置输出 | cfg_fifo_depth | Output | [7:0] | 内部 | apb_clk | CONFIG.FIFO_DEPTH |
| 配置输出 | cfg_timeout | Output | [7:0] | 内部 | apb_clk | CONFIG.TIMEOUT |
| 配置输出 | cfg_retry_cnt | Output | [6:0] | 内部 | apb_clk | CONFIG.RETRY_CNT |
| 配置输出 | link_ctrl_reg | Output | [31:0] | 内部 | apb_clk | LINK_CTRL寄存器镜像输出 |
| 中断输出 | irq | Output | 1 | 内部 | apb_clk | 全局中断请求 |

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

#### 3.2.2 运行状态与错误输入

| 信号名 | 方向 | 位宽 | 描述 | RTL实现要求 |
|--------|------|------|------|-------------|
| status_link_state | Input | [2:0] | 当前链路状态 | 直接映射到`STATUS.LINK_STATE` |
| status_busy | Input | 1 | 忙标志 | 直接映射到`STATUS.BUSY` |
| status_tx_ready | Input | 1 | TX路径就绪 | 直接映射到`STATUS.TX_READY` |
| status_rx_ready | Input | 1 | RX路径就绪 | 直接映射到`STATUS.RX_READY` |
| status_init_done | Input | 1 | 初始化完成 | 直接映射到`STATUS.INIT_DONE` |
| err_status_in | Input | [6:0] | 错误状态位图 | 分别映射到`ERR_STATUS[6:0]`，置位后保持至W1C清除 |
| evt_link_up | Input | 1 | 链路进入RUN事件 | 置位`INT_STATUS.LINK_UP_INT` |
| evt_link_down | Input | 1 | 链路离开RUN或断链事件 | 置位`INT_STATUS.LINK_DOWN_INT` |
| evt_fifo_almost_full | Input | 1 | FIFO高水位事件 | 置位`INT_STATUS.FIFO_ALMOST_FULL` |

#### 3.2.3 配置输出接口

| 信号名 | 方向 | 位宽 | 描述 | RTL实现要求 |
|--------|------|------|------|-------------|
| cfg_enable | Output | 1 | 模块总使能 | 由`CTRL.ENABLE`驱动 |
| cfg_mode | Output | [7:0] | 工作模式 | 由`CTRL.MODE`驱动 |
| cfg_flit_width_sel | Output | [3:0] | Flit宽度选择 | 由`CTRL.FLIT_WIDTH`驱动 |
| sw_reset_pulse | Output | 1 | 软件复位脉冲 | `CTRL.RESET`写1后在`apb_clk`域产生1周期脉冲 |
| cfg_max_credit | Output | [7:0] | 最大Credit数 | 由`CONFIG.MAX_CREDIT`驱动 |
| cfg_fifo_depth | Output | [7:0] | FIFO深度 | 由`CONFIG.FIFO_DEPTH`驱动 |
| cfg_timeout | Output | [7:0] | 超时门限 | 由`CONFIG.TIMEOUT`驱动 |
| cfg_retry_cnt | Output | [6:0] | 重试次数门限 | 由`CONFIG.RETRY_CNT`驱动 |
| link_ctrl_reg | Output | [31:0] | LINK_CTRL寄存器镜像 | 供`cxs_fdi_link_ctrl`解释使用 |

#### 3.2.4 计数器与中断接口

| 信号名 | 方向 | 位宽 | 描述 | RTL实现要求 |
|--------|------|------|------|-------------|
| stat_tx_flit_pulse | Input | 1 | 发送Flit计数事件 | 每个脉冲使`TX_FLIT_CNT`加1 |
| stat_rx_flit_pulse | Input | 1 | 接收Flit计数事件 | 每个脉冲使`RX_FLIT_CNT`加1 |
| irq | Output | 1 | 全局中断请求 | `INT_STATUS & INT_EN` 非零时置高 |

---

## 4. 时钟与复位 / Clocks and Resets

### 4.1 时钟域 / Clock Domains

| 时钟名称 | 频率 | 描述 | RTL实现要求 |
|----------|------|------|-------------|
| apb_clk | 100 MHz | APB配置时钟 | 标准APB时钟 |

### 4.2 跨时钟域 / Clock Domain Crossings (CDC)

| 源时钟 | 目标时钟 | 信号类型 | 同步方式 | RTL实现 |
|--------|----------|----------|----------|---------|
| cxs_clk | apb_clk | 电平状态 | 2级同步器 | `status_*`、`err_status_in`同步采样 |
| fdi_lclk | apb_clk | 电平状态 | 2级同步器 | 链路/错误状态同步采样 |
| cxs_clk/fdi_lclk | apb_clk | 单周期事件 | toggle/pulse同步 | `evt_*`与`stat_*_pulse`需在模块边界前完成同步 |

**CDC约束补充：**
- `regs`模块不负责将异步窄脉冲直接可靠采样为计数事件
- 所有`evt_*`与`stat_*_pulse`输入必须在进入`regs`前转换为`apb_clk`域单周期脉冲
- 对于电平型状态，`regs`只做状态镜像；对于事件型状态，`regs`只做置位锁存与W1C清除

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
  // TX Flit计数器（输入脉冲已同步到apb_clk域）
  always_ff @(posedge apb_clk or negedge apb_rst_n) begin
    if (!apb_rst_n) begin
      tx_flit_cnt <= '0;
    end else if (stat_tx_flit_pulse) begin
      tx_flit_cnt <= tx_flit_cnt + 1;
    end
  end
  
  // 错误状态锁存
  always_ff @(posedge apb_clk or negedge apb_rst_n) begin
    if (!apb_rst_n) begin
      err_status_reg <= '0;
    end else begin
      err_status_reg <= err_status_reg | err_status_in;
    end
  end
  ```

#### 中断管理单元 (Interrupt Management Unit)
- **模块名称**: Interrupt Management Unit
- **RTL职责**：统一管理中断
- **中断处理**：
  ```systemverilog
  // 中断源检测
  assign intr_raw[7] = |err_status_reg;
  assign intr_raw[6] = evt_link_up;
  assign intr_raw[5] = evt_link_down;
  assign intr_raw[4] = evt_fifo_almost_full;
  
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

错误状态寄存器与架构规格保持一致（详见`ucie_cxs_fdi_arch_spec.md`中的ERR_STATUS定义）：

| 位 | 错误名称 | 描述 | RTL检测方式 |
|----|----------|------|-------------|
| [6] | ERR_LINK_RETRY_FAIL | 链路重试失败 | 重试计数器超限 |
| [5] | ERR_LINK_TIMEOUT | 链路激活超时 | 超时检测 |
| [4] | ERR_LINK_DOWN | 链路断开 | 状态检测 |
| [3] | ERR_FIFO_UNDERFLOW | FIFO下溢 | 读空检测 |
| [2] | ERR_FIFO_OVERFLOW | FIFO溢出 | 写满检测 |
| [1] | ERR_FDI_CRC | FDI CRC错误 | CRC错误指示 |
| [0] | ERR_CXS_PROTO | CXS协议违例 | 协议检查 |

---

## 6. 配置寄存器 / Configuration Registers (CSRs)

### 6.1 寄存器地址映射 / Register Address Map

**基地址**: `0x[系统分配]`

| 地址偏移 | 寄存器名 | 访问 | 描述 |
|----------|----------|------|------|
| 0x00 | CTRL | R/W | 控制寄存器 |
| 0x04 | STATUS | R | 状态寄存器 |
| 0x08 | CONFIG | R/W | 配置寄存器 |
| 0x0C | INT_EN | R/W | 中断使能寄存器 |
| 0x10 | INT_STATUS | R/W1C | 中断状态寄存器 |
| 0x14 | ERR_STATUS | R/W1C | 错误状态寄存器 |
| 0x18 | LINK_CTRL | R/W | 链路控制寄存器 |
| 0x20 | TX_FLIT_CNT_L | R | 发送Flit计数低32位 |
| 0x24 | TX_FLIT_CNT_H | R | 发送Flit计数高32位 |
| 0x28 | RX_FLIT_CNT_L | R | 接收Flit计数低32位 |
| 0x2C | RX_FLIT_CNT_H | R | 接收Flit计数高32位 |
| 0x30 | VERSION | R | 版本寄存器 |
| 0x34-0x7C | RESERVED | - | 保留 |

### 6.2 寄存器详细定义

#### 控制寄存器 (CTRL) - 0x00

| 位域 | 名称 | 访问 | 默认值 | 描述 |
|------|------|------|--------|------|
| [31] | ENABLE | R/W | 0 | 模块使能：1=使能，0=禁用 |
| [30:24] | RESERVED1 | R/W | 0x00 | 保留 |
| [23:16] | MODE | R/W | 0x00 | 工作模式：0=正常，1=测试，2=低功耗 |
| [15:8] | RESERVED2 | R/W | 0x00 | 保留 |
| [7:4] | FLIT_WIDTH | R/W | 0x1 | Flit宽度：0=256b,1=512b,2=1024b,3=2048b |
| [3:1] | RESERVED3 | R/W | 0x00 | 保留 |
| [0] | RESET | R/W1S | 0 | 软件复位：写1复位模块（自清零） |

**字段到模块接口映射：**
- `CTRL.ENABLE` → `cfg_enable`
- `CTRL.MODE` → `cfg_mode`
- `CTRL.FLIT_WIDTH` → `cfg_flit_width_sel`
- `CTRL.RESET` → `sw_reset_pulse`

#### 状态寄存器 (STATUS) - 0x04

| 位域 | 名称 | 访问 | 默认值 | 描述 |
|------|------|------|--------|------|
| [31:16] | RESERVED | R | 0 | 保留 |
| [15:8] | LINK_STATE | R | 0 | 链路状态 |
| [7:4] | RESERVED2 | R | 0 | 保留 |
| [3] | BUSY | R | 0 | 忙标志：1=操作进行中 |
| [2] | TX_READY | R | 0 | TX路径就绪：1=就绪 |
| [1] | RX_READY | R | 0 | RX路径就绪：1=就绪 |
| [0] | INIT_DONE | R | 0 | 初始化完成：1=完成 |

**字段到模块接口映射：**
- `STATUS.LINK_STATE` ← `status_link_state[2:0]`
- `STATUS.BUSY` ← `status_busy`
- `STATUS.TX_READY` ← `status_tx_ready`
- `STATUS.RX_READY` ← `status_rx_ready`
- `STATUS.INIT_DONE` ← `status_init_done`

**LINK_STATE编码：**
| 值 | 状态 |
|----|------|
| 0x00 | STOP |
| 0x01 | ACTIV_REQ |
| 0x02 | ACTIV_ACK |
| 0x03 | RUN |
| 0x04 | DEACT |
| 0x05 | RETRAIN |
| 0x06 | ERROR |

#### 配置寄存器 (CONFIG) - 0x08

| 位域 | 名称 | 访问 | 默认值 | 描述 |
|------|------|------|--------|------|
| [31:24] | MAX_CREDIT | R/W | 0x20 | 最大Credit数 (1-63) |
| [23:16] | FIFO_DEPTH | R/W | 0x40 | FIFO深度配置 (8-256)，约束：`FIFO_DEPTH >= 2×MAX_CREDIT` |
| [15:8] | TIMEOUT | R/W | 0xFF | 超时计数(单位：时钟周期) |
| [7:1] | RETRY_CNT | R/W | 0x03 | 最大重试次数 |
| [0] | CREDIT_MODE | R | 1 | Credit退还模式：0=Implicit，1=Explicit（仅参数化，不支持运行时切换） |

**字段到模块接口映射：**
- `CONFIG.MAX_CREDIT` → `cfg_max_credit`
- `CONFIG.FIFO_DEPTH` → `cfg_fifo_depth`
- `CONFIG.TIMEOUT` → `cfg_timeout`
- `CONFIG.RETRY_CNT` → `cfg_retry_cnt`
- `CONFIG.CREDIT_MODE` 为只读镜像，不单独输出控制信号

#### 中断使能寄存器 (INT_EN) - 0x0C

| 位域 | 名称 | 访问 | 默认值 | 描述 |
|------|------|------|--------|------|
| [31:8] | RESERVED | R/W | 0 | 保留 |
| [7] | ERR_INT_EN | R/W | 0 | 错误中断使能 |
| [6] | LINK_UP_INT_EN | R/W | 0 | 链路激活中断使能 |
| [5] | LINK_DOWN_INT_EN | R/W | 0 | 链路断开中断使能 |
| [4] | FIFO_ALMOST_FULL_EN | R/W | 0 | FIFO高水位中断使能 |
| [3:0] | RESERVED2 | R/W | 0 | 保留 |

#### 中断状态寄存器 (INT_STATUS) - 0x10

| 位域 | 名称 | 访问 | 默认值 | 描述 |
|------|------|------|--------|------|
| [31:8] | RESERVED | R | 0 | 保留 |
| [7] | ERR_INT | R/W1C | 0 | 错误中断，写1清除 |
| [6] | LINK_UP_INT | R/W1C | 0 | 链路激活中断，写1清除 |
| [5] | LINK_DOWN_INT | R/W1C | 0 | 链路断开中断，写1清除 |
| [4] | FIFO_ALMOST_FULL | R/W1C | 0 | FIFO接近满中断 |
| [3:0] | RESERVED2 | R | 0 | 保留 |

**置位来源：**
- `INT_STATUS.ERR_INT`：`err_status_in` 任一位为1时置位
- `INT_STATUS.LINK_UP_INT`：`evt_link_up` 脉冲置位
- `INT_STATUS.LINK_DOWN_INT`：`evt_link_down` 脉冲置位
- `INT_STATUS.FIFO_ALMOST_FULL`：`evt_fifo_almost_full` 脉冲置位

#### 错误状态寄存器 (ERR_STATUS) - 0x14

| 位域 | 名称 | 访问 | 默认值 | 描述 |
|------|------|------|--------|------|
| [31:7] | RESERVED | R | 0 | 保留 |
| [6] | ERR_LINK_RETRY_FAIL | R/W1C | 0 | 链路重试失败 |
| [5] | ERR_LINK_TIMEOUT | R/W1C | 0 | 链路激活超时 |
| [4] | ERR_LINK_DOWN | R/W1C | 0 | 链路断开 |
| [3] | ERR_FIFO_UNDERFLOW | R/W1C | 0 | FIFO下溢 |
| [2] | ERR_FIFO_OVERFLOW | R/W1C | 0 | FIFO溢出（状态位可W1C清零，ERROR退出需复位/软件复位） |
| [1] | ERR_FDI_CRC | R/W1C | 0 | FDI CRC错误 |
| [0] | ERR_CXS_PROTO | R/W1C | 0 | CXS协议违例 |

**字段到模块接口映射：**
- `ERR_STATUS[6:0]` ← `err_status_in[6:0]`

#### 链路控制寄存器 (LINK_CTRL) - 0x18

| 位域 | 名称 | 访问 | 默认值 | 描述 |
|------|------|------|--------|------|
| [0] | SW_ACTIVATE_REQ | R/W | 0 | 软件激活请求 |
| [1] | SW_DEACT_REQ | R/W | 0 | 软件停用请求 |
| [2] | SW_RETRAIN_REQ | R/W | 0 | 软件重训练请求 |
| [7:3] | RESERVED0 | R/W | 0 | 保留 |
| [8] | AUTO_RETRY_EN | R/W | 1 | 激活超时自动重试使能 |
| [9] | FDI_RX_ACTIVE_FOLLOW_EN | R/W | 1 | 允许 `fdi_pl_rx_active_req` 参与激活请求合成 |
| [10] | ERROR_STOP_EN | R/W | 1 | 错误停机使能 |
| [31:11] | RESERVED1 | R/W | 0 | 保留 |

本寄存器由`regs`模块存储、由`cxs_fdi_link_ctrl`模块解释；`regs`模块负责输出`link_ctrl_reg[31:0]`镜像。

**模块边界约束：**
- `regs`不解释`LINK_CTRL`字段语义
- `cxs_fdi_link_ctrl`必须给出对`link_ctrl_reg`各位的最终解释与使用规则
- `SW_*` 命令位采用 `0->1` 沿触发语义，软件应在命令被采样后写回0

#### 版本寄存器 (VERSION) - 0x30

| 位域 | 名称 | 访问 | 默认值 | 描述 |
|------|------|------|--------|------|
| [31:24] | MAJOR | R | 0x00 | 主版本号 |
| [23:16] | MINOR | R | 0x01 | 次版本号 |
| [15:0] | PATCH | R | 0x0000 | 修订号 |

### 6.3 寄存器访问与置位规则

**访问类型说明：**
| 类型 | 说明 |
|------|------|
| R | 只读，软件无法改写 |
| R/W | 可读可写 |
| R/W1C | 写1清零，写0无效 |
| R/W1S | 写1触发，自清零 |

**时序与优先级规则：**
- `STATUS` 为只读镜像寄存器，不允许软件改写
- `ERR_STATUS` 为置位保持型寄存器：硬件置位、软件W1C清除；若硬件置位与W1C同周期发生，硬件置位优先
- `INT_STATUS` 为置位保持型寄存器：事件脉冲置位、软件W1C清除；若事件置位与W1C同周期发生，事件置位优先
- `CTRL.RESET` 仅产生 `sw_reset_pulse`，不在CSR中保持为1
- APB读访问延迟1周期；写访问在下一个`apb_clk`周期可见

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
