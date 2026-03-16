# LME Handler模块设计规格书 (LME Handler Module Design Specification)

**文档编号**: [MOD-LME-001]  
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

本文档定义了LME Handler模块的详细设计规格，作为RTL设计、验证和集成的唯一真实来源(One Source of Truth)。LME (Link Management Exchange) Handler是UCIe CXS-FDI Bridge的链路管理模块，负责实现CXS和FDI两侧的边带接口交互，完成链路参数协商和状态管理。

### 1.2 功能描述 / Functional Description

LME Handler模块实现链路管理交换功能，负责CXS边带接口和FDI边带接口之间的协议转换和状态同步，管理链路激活、参数协商和状态监控。

**主要功能：**
- **边带接口管理**：实现CXS边带接口(CXS SB)和FDI边带接口(FDI SB)的协议处理
- **链路参数协商**：在链路初始化阶段交换和协商链路参数
- **链路状态同步**：协调CXS和FDI两侧的链路状态
- **链路激活/停用协调**：协调两侧的链路激活和停用流程

**模块在系统中的位置：**
```
+---------------------------+     +---------------------------+     +---------------------------+
|    CXS Sideband            |     |  LME Handler              |     |  FDI Sideband             |
| (cxs_clk域)               │────▶│ (链路管理交换)             │────▶│ (fdi_lclk域)              |
|                          │     │                           │     |                           |
| cxs_sb_* ───────────────│────▶│ CXS SB Interface ─────────│────▶│ fdi_sb_*                  |
|                          │     │ LME Core Logic ───────────│────▶│                          |
|                          │     │ FDI SB Interface ◄────────│────◀│                          |
+---------------------------+     +---------------------------+     +---------------------------+
```

**目标应用场景：**
- 多芯片CPU/GPU互连的链路初始化
- 服务器SoC的Die-to-Die链路参数协商
- 高性能计算芯片间的链路管理

### 1.3 目标与非目标 / Goals and Non-Goals

**目标 (Goals) - 必须实现：**
| 目标 | 描述 | 优先级 | RTL实现要求 |
|------|------|--------|-------------|
| 边带协议合规 | 正确实现CXS和FDI边带协议 | P0 | 协议解析正确 |
| 参数协商 | 完成链路参数协商 | P1 | 握手协议 |
| 状态同步 | 正确同步两侧链路状态 | P1 | 状态机协调 |

**非目标 (Non-Goals) - 明确排除：**
- 数据通路处理：仅处理边带信号，不参与数据通道

### 1.4 关键指标 / Key Metrics

| 指标 | 目标值 | 单位 | 备注 | RTL实现影响 |
|------|--------|------|------|-------------|
| 协商延迟 | < 100 | 周期 | 参数协商时间 | 状态机复杂度 |
| 边带频率 | 100 | MHz | 边带时钟 | 协议要求 |
| 面积估算 | < 300 | 门数 | 逻辑面积 | 状态机+接口 |

---

## 2. 架构设计 / Architecture Design

### 2.1 模块顶层框图 / Module Top-Level Block Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                LME Handler (lme)                                        │
│                                                                                          │
│   ═══════════════════════════════════════════════════════════════════════════════════   │
│                    [Clock Domain: cxs_clk ↔ fdi_lclk (异步)]                           │
│   ═══════════════════════════════════════════════════════════════════════════════════   │
│                                                                                          │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │                         CXS边带接口 (CXS SB Interface)                           │   │
│   │  cxs_sb_valid    ────────────────────────────────────────────────────►   │   │
│   │  cxs_sb_data    ◄──────────────────────────────────────────────────   │   │
│   │  cxs_sb_ready   ◄──────────────────────────────────────────────────   │   │
│   │  cxs_sb_* (其他)                                                       │   │
│   └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                              │                                           │
│                                              ▼                                           │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │                         LME核心逻辑 (LME Core Logic)                            │   │
│   │         ┌─────────────────────────────────────────────────────────────┐        │   │
│   │         │   参数解析器 (Parameter Parser)                            │        │   │
│   │         │   链路状态机 (Link State Machine)                          │        │   │
│   │         │   参数协商器 (Parameter Negotiator)                       │        │   │
│   │         │   状态同步器 (Status Synchronizer)                        │        │   │
│   │         └─────────────────────────────────────────────────────────────┘        │   │
│   └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                              │                                           │
│                                              ▼                                           │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │                         FDI边带接口 (FDI SB Interface)                            │   │
│   │  fdi_sb_valid    ◄──────────────────────────────────────────────────   │   │
│   │  fdi_sb_data    ────────────────────────────────────────────────────►   │   │
│   │  fdi_sb_ready   ────────────────────────────────────────────────────►   │   │
│   │  fdi_sb_* (其他)                                                       │   │
│   └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                          │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │                         配置与状态接口                                            │   │
│   │  lme_cfg_* ──────────────────────────────────────────────────────►   │   │
│   │  lme_status ◄────────────────────────────────────────────────────   │   │
│   │  lme_intr   ◄────────────────────────────────────────────────────   │   │
│   └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                          │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

**子模块列表：**
| 模块名称 | 功能描述 | 关键接口 | 时钟域 | RTL实现要点 |
|----------|----------|----------|--------|-------------|
| CXS SB Interface | CXS边带接口 | cxs_sb_* 信号 | cxs_clk | 协议解析 |
| FDI SB Interface | FDI边带接口 | fdi_sb_* 信号 | fdi_lclk | 协议封装 |
| LME Core Logic | 核心逻辑 | 参数/状态 | 混合 | 状态机 |

### 2.2 数据流 / Data Flow

**主数据通路：**
```
CXS边带 ──▶ CXS SB Interface ──▶ LME Core ──▶ FDI SB Interface ──▶ FDI边带
                  ↓                    ↓                   ↓
            参数解析            参数处理           参数封装
```

**控制流：**
```
链路初始化请求 ──▶ 参数协商 ──▶ 协商完成 ──▶ 链路激活
                                               ↓
                                      状态同步到两侧
```

### 2.3 子模块层次 / Submodule Hierarchy

```
lme (LME Handler - 顶层模块)
├── lme_cxs_sb_if (CXS边带接口单元)
│   ├── sb_valid_gen (Valid生成) - **实现关键**: 握手协议
│   ├── sb_data_parse (数据解析) - **实现关键**: 参数解析
│   └── sb_ready_detect (Ready检测) - **实现关键**: 响应检测
├── lme_fdi_sb_if (FDI边带接口单元)
│   ├── sb_valid_detect (Valid检测) - **实现关键**: 握手协议
│   ├── sb_data_gen (数据生成) - **实现关键**: 参数封装
│   └── sb_ready_gen (Ready生成) - **实现关键**: 响应生成
├── lme_param_parser (参数解析单元)
│   ├── param_decode (参数解码) - **实现关键**: 协议解析
│   ├── param_validate (参数验证) - **实现关键**: 有效性检查
│   └── param_store (参数存储) - **实现关键**: 配置寄存器
├── lme_param_negotiator (参数协商单元)
│   ├── neg_state (协商状态) - **实现关键**: 握手状态机
│   ├── param_compare (参数比较) - **实现关键**: 能力匹配
│   └── neg_result (协商结果) - **实现关键**: 决策逻辑
├── lme_link_fsm (链路状态机单元)
│   ├── fsm_state (状态) - **实现关键**: 状态转移
│   ├── init_seq (初始化序列) - **实现关键**: 协商流程
│   └── active_ctrl (激活控制) - **实现关键**: 激活逻辑
└── lme_status_sync (状态同步单元)
    ├── cxs_status_sync (CXS状态) - **实现关键**: 跨域同步
    └── fdi_status_sync (FDI状态) - **实现关键**: 跨域同步
```

---

## 3. 接口定义 / Interface Definitions

### 3.1 顶层接口汇总 / Top-Level Interface Summary

| 接口分类 | 接口名称 | 方向 | 位宽 | 协议 | 时钟域 | RTL实现要求 |
|----------|----------|------|------|------|--------|-------------|
| 时钟复位 | cxs_clk | Input | 1 | - | - | CXS侧时钟 |
| 时钟复位 | cxs_rst_n | Input | 1 | - | - | CXS侧复位 |
| 时钟复位 | fdi_lclk | Input | 1 | - | - | FDI侧时钟 |
| 时钟复位 | fdi_rst_n | Input | 1 | - | - | FDI侧复位 |
| CXS边带 | cxs_sb_valid | Input | 1 | CXS SB | cxs_clk | 边带有效 |
| CXS边带 | cxs_sb_data | Output | [SB_WIDTH] | CXS SB | cxs_clk | 边带数据 |
| CXS边带 | cxs_sb_ready | Output | 1 | CXS SB | cxs_clk | 边带就绪 |
| CXS边带 | cxs_sb_* | Input/Output | - | CXS SB | cxs_clk | 其他边带信号 |
| FDI边带 | fdi_sb_valid | Input | 1 | FDI SB | fdi_lclk | 边带有效 |
| FDI边带 | fdi_sb_data | Input | [SB_WIDTH] | FDI SB | fdi_lclk | 边带数据 |
| FDI边带 | fdi_sb_ready | Output | 1 | FDI SB | fdi_lclk | 边带就绪 |
| FDI边带 | fdi_sb_* | Input/Output | - | FDI SB | fdi_lclk | 其他边带信号 |
| 配置接口 | lme_cfg_* | Input | - | 内部 | cxs_clk | 配置输入 |
| 状态接口 | lme_status | Output | - | 内部 | cxs_clk | 状态输出 |
| 中断接口 | lme_intr | Output | - | 内部 | cxs_clk | 中断输出 |

### 3.2 详细接口定义 / Detailed Interface Specifications

#### 3.2.1 CXS边带接口

| 信号名 | 方向 | 位宽 | 描述 | RTL实现要求 |
|--------|------|------|------|-------------|
| cxs_sb_valid | Input | 1 | 边带有效 | 握手信号 |
| cxs_sb_data | Output | [SB_WIDTH] | 边带数据 | 协议数据 |
| cxs_sb_ready | Output | 1 | 边带就绪 | 握手响应 |

#### 3.2.2 FDI边带接口

| 信号名 | 方向 | 位宽 | 描述 | RTL实现要求 |
|--------|------|------|------|-------------|
| fdi_sb_valid | Input | 1 | 边带有效 | 握手信号 |
| fdi_sb_data | Input | [SB_WIDTH] | 边带数据 | 协议数据 |
| fdi_sb_ready | Output | 1 | 边带就绪 | 握手响应 |

#### 3.2.3 配置和状态接口

| 信号名 | 方向 | 描述 | RTL实现要求 |
|--------|------|------|-------------|
| lme_cfg_enable | Input | LME使能 | 配置输入 |
| lme_cfg_params | Input | 协商参数 | 配置输入 |
| lme_status_active | Output | 链路激活状态 | 状态输出 |
| lme_status_error | Output | 错误状态 | 状态输出 |
| lme_intr | Output | 中断信号 | 中断输出 |

---

## 4. 时钟与复位 / Clocks and Resets

### 4.1 时钟域 / Clock Domains

| 时钟名称 | 频率 | 描述 | RTL实现要求 |
|----------|------|------|-------------|
| cxs_clk | 2.0 GHz | CXS侧时钟 | 边带接口时钟 |
| fdi_lclk | 2.0 GHz | FDI侧时钟 | 边带接口时钟 |

### 4.2 跨时钟域 / Clock Domain Crossings (CDC)

| 源时钟 | 目标时钟 | 信号类型 | 同步方式 | RTL实现 |
|--------|----------|----------|----------|---------|
| cxs_clk | fdi_lclk | 边带数据 | 异步FIFO | 握手缓冲 |
| fdi_lclk | cxs_clk | 边带数据 | 异步FIFO | 握手缓冲 |
| cxs_clk | fdi_lclk | 状态信号 | 2级同步器 | 状态同步 |

### 4.3 复位域 / Reset Domains

| 复位名称 | 有效电平 | 类型 | 作用范围 | RTL实现要求 |
|----------|----------|------|----------|-------------|
| cxs_rst_n | Low | 全局 | CXS侧逻辑 | 异步断言，同步释放 |
| fdi_rst_n | Low | 全局 | FDI侧逻辑 | 异步断言，同步释放 |

---

## 5. 功能描述 / Functional Description

### 5.1 功能概述 / Functional Overview

LME Handler模块的核心功能是实现CXS和FDI两侧边带接口的链路管理交换，包括参数协商、状态同步和链路激活协调。

**核心功能模块RTL说明：**

#### CXS边带接口单元 (CXS SB Interface Unit)
- **模块名称**: CXS Sideband Interface Unit
- **RTL职责**：解析CXS边带信号，生成响应
- **数据处理**：
  ```systemverilog
  // 边带握手
  assign cxs_sb_ready = !cxs_sb_busy;
  assign cxs_sb_valid_strobe = cxs_sb_valid && cxs_sb_ready;
  
  // 数据解析
  always_ff @(posedge cxs_clk or negedge cxs_rst_n) begin
    if (cxs_sb_valid_strobe) begin
      cxs_sb_msg <= cxs_sb_data;
    end
  end
  ```

#### FDI边带接口单元 (FDI SB Interface Unit)
- **模块名称**: FDI Sideband Interface Unit
- **RTL职责**：封装FDI边带信号，解析输入
- **数据处理**：
  - 解析FDI边带消息
  - 生成FDI边带响应

#### 参数解析单元 (Parameter Parser Unit)
- **模块名称**: Parameter Parser Unit
- **RTL职责**：解析链路参数
- **数据处理**：
  - 解码边带消息
  - 验证参数有效性
  - 存储协商参数

#### 参数协商单元 (Parameter Negotiator Unit)
- **模块名称**: Parameter Negotiator Unit
- **RTL职责**：执行参数协商
- **状态处理**：
  ```systemverilog
  typedef enum logic [2:0] {
    NEG_IDLE      = 3'b000,
    NEG_OFFER     = 3'b001,
    NEG_ACCEPT    = 3'b010,
    NEG_REJECT    = 3'b011,
    NEG_COMPLETE  = 3'b100
  } neg_state_t;
  ```

#### 链路状态机单元 (Link State Machine Unit)
- **模块名称**: Link State Machine Unit
- **RTL职责**：管理链路状态转换
- **状态处理**：
  - 链路初始化
  - 参数协商
  - 链路激活
  - 链路监控

#### 状态同步单元 (Status Synchronizer Unit)
- **模块名称**: Status Synchronizer Unit
- **RTL职责**：同步两侧链路状态
- **数据处理**：
  - 跨时钟域状态同步
  - 状态一致性检查

### 5.2 状态机 / State Machines

#### 5.2.1 LME主状态机

**状态定义（RTL编码方案）：**
| 状态 | 编码 | 描述 | RTL退出条件 |
|------|------|------|-------------|
| IDLE | 000 | 初始状态 | cfg_enable==1 |
| INIT | 001 | 链路初始化 | 初始化完成 |
| NEGOTIATE | 010 | 参数协商 | 协商完成 |
| ACTIVE | 011 | 链路激活 | 激活完成 |
| MONITOR | 100 | 链路监控 | 错误/停用 |
| ERROR | 101 | 错误状态 | 复位 |

### 5.3 典型事务流程 / Example Transactions

#### 链路初始化流程
```
时间 ──────────────────────────────────────────────────────▶

CXS_SB:     [PARAM_REQ]──▶[PARAM_ACK]────▶[ACTIVE_REQ]
                                    ↓
FDI_SB:                      [PARAM_RSP]──▶[ACTIVE_ACK]
                                    ↓
LME:        IDLE→INIT→NEGOTIATE→ACTIVE→MONITOR
```

### 5.4 错误处理 / Error Handling

#### 错误类型（RTL检测）

| 错误代码 | 错误名称 | 描述 | RTL检测方式 |
|----------|----------|------|-------------|
| 0x01 | ERR_NEG_TIMEOUT | 协商超时 | 计数器超时 |
| 0x02 | ERR_NEG_FAIL | 协商失败 | 参数不兼容 |
| 0x03 | ERR_PARAM_INVALID | 参数无效 | 验证失败 |
| 0x04 | ERR_SYNC_MISMATCH | 状态不一致 | 同步检测 |

---

## 6. 配置寄存器 / Configuration Registers (CSRs)

### 6.1 寄存器地址映射 / Register Address Map

| 寄存器名 | 地址偏移 | 大小 | 访问类型 | 描述 |
|----------|----------|------|----------|------|
| LME_CTRL | 0x00 | 32-bit | R/W | LME控制 |
| LME_STATUS | 0x04 | 32-bit | R | LME状态 |
| LME_CONFIG | 0x08 | 32-bit | R/W | LME配置 |
| LME_PARAM | 0x0C | 32-bit | R/W | 协商参数 |
| LME_ERR_STATUS | 0x14 | 32-bit | R/W1C | 错误状态 |

---

## 7. 性能规格 / Performance Specifications

### 7.1 性能指标 / Performance Metrics

| 指标 | 目标值 | 单位 | RTL实现约束 |
|------|--------|------|-------------|
| 协商时间 | < 100 | 周期 | 状态机效率 |
| 边带带宽 | 100 | Mb/s | 边带频率 |
| 状态同步延迟 | < 10 | 周期 | CDC延迟 |

---

## 9. 验证与调试 / Verification and Debug

### 9.1 验证策略

| 方法 | 覆盖率目标 | RTL验证要点 |
|------|------------|-------------|
| 协议验证 | 100% | 边带协议合规 |
| 协商验证 | 100% | 参数协商流程 |
| 状态验证 | 100% | 状态机覆盖 |

---

**文档结束**

**相关文档：**
- 架构规格：`docs/specification/ucie_cxs_fdi_arch_spec.md`
- CXS TX接口规格：`docs/specification/cxs_tx_if_spec.md`
- FDI TX接口规格：`docs/specification/fdi_tx_if_spec.md`
- 编码规范：`docs/coding_standards/coding_guide.md`
