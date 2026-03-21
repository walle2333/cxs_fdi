# RX Path模块设计规格书 (RX Path Module Design Specification)

**文档编号**: [MOD-RX-PATH-001]  
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

本文档定义了RX Path模块的详细设计规格，作为RTL设计、验证和集成的唯一真实来源(One Source of Truth)。RX Path是UCIe CXS-FDI Bridge的核心数据通路模块，负责将FDI RX Interface输出的数据通过异步FIFO跨时钟域发送到CXS RX Interface。

### 1.2 功能描述 / Functional Description

RX Path模块实现从fdi_lclk域到cxs_clk域的数据传输通道，包含异步FIFO缓冲和错误处理功能。

**主要功能：**
- **异步数据传输**：通过异步FIFO实现fdi_lclk域到cxs_clk域的数据缓冲和传输
- **错误处理**：检测并处理接收过程中的错误，上报错误状态

**模块在系统中的位置：**
```
+---------------------------+     +---------------------------+     +---------------------------+
|    FDI RX Interface        |     |  RX Path                  |     |  CXS RX Interface         |
| (fdi_lclk域)              |────▶│ (跨时钟域数据通路)         |────▶│ (cxs_clk域)              |
|                          |     │                           │     |                           |
| rx_valid_out ────────────│────▶│ RX Async FIFO ────────────│────▶│ rx_valid_in               |
| rx_data_out ────────────│────▶│ Error Handler ────────────│────▶│                           |
+---------------------------+     +---------------------------+     +---------------------------+
```

**目标应用场景：**
- 多芯片CPU/GPU互连扩展场景下的跨时钟域数据接收
- 服务器SoC的Die-to-Die通信中数据缓冲
- 高性能计算芯片间的低延迟互连

### 1.3 目标与非目标 / Goals and Non-Goals

**目标 (Goals) - 必须实现：**
| 目标 | 描述 | 优先级 | RTL实现要求 |
|------|------|--------|-------------|
| CDC正确性 | 异步FIFO正确实现跨时钟域 | P0 | 格雷码指针，空满判断 |
| 数据一致性 | 确保跨域数据传输不丢失、不重复 | P0 | 握手协议保证 |

**非目标 (Non-Goals) - 明确排除：**
- FDI协议处理：由fdi_rx_if模块负责
- CXS协议处理：由cxs_rx_if模块负责
- 链路控制：由独立的cxs_fdi_link_ctrl模块负责

### 1.4 关键指标 / Key Metrics

| 指标 | 目标值 | 单位 | 备注 | RTL实现影响 |
|------|--------|------|------|-------------|
| FIFO深度 | 64 | 项 | 异步FIFO深度 | 缓冲能力 |
| 吞吐量 | 96 | GB/s | 512bit × 1.5GHz | 满带宽传输 |
| CDC延迟 | 2-3 | 时钟周期 | 跨域延迟 | FIFO级数 |
| 面积估算 | < 2K | 门数 | 含FIFO | SRAM/FF选择 |

---

## 2. 架构设计 / Architecture Design

### 2.1 模块顶层框图 / Module Top-Level Block Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                    RX Path (rx_path)                                   │
│                                                                                          │
│   ═══════════════════════════════════════════════════════════════════════════════════   │
│                              [Clock Domain: fdi_lclk ↔ cxs_clk]                         │
│   ═══════════════════════════════════════════════════════════════════════════════════   │
│                                                                                          │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │                              FDI侧接口 (fdi_lclk域)                               │   │
│   │  rx_valid_in           ───────────────────────────────────────────────────►   │   │
│   │  rx_data_in[FDI_DATA_WIDTH-1:0]     ───────────────────────────────────────────────────►   │   │
│   │  rx_cntl_in           ──────────────────────────────────────────────────►   │   │
│   │  rx_last_in           ──────────────────────────────────────────────────►   │   │
│   │  *(rx_cntl_in包含ENDERROR位)* ──────────────────────────────────────────►   │   │
│   │  rx_srcid_in/tgtid_in ────────────────────────────────────────────────►   │   │
│   │  rx_data_ack ◄────────────────────────────────────────────────────────   │   │
│   └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                              │                                           │
│                                              ▼                                           │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │                    RX Async FIFO (异步FIFO缓冲单元)                              │   │
│   │         ┌─────────────────────────────────────────────────────────────┐        │   │
│   │         │   64-depth Async FIFO                                       │        │   │
│   │         │   Write: fdi_lclk    Read: cxs_clk                         │        │   │
│   │         │   Gray Code Pointer    Full/Empty Detection               │        │   │
│   │         └─────────────────────────────────────────────────────────────┘        │   │
│   └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                              │                                           │
│                                              ▼                                           │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │           Link Ctrl状态输入 (来自cxs_fdi_link_ctrl)                               │   │
│   │         ┌─────────────────────────────────────────────────────────────┐        │   │
│   │         │   link_active同步/门控                                     │        │   │
│   │         │   状态变化响应                                             │        │   │
│   │         └─────────────────────────────────────────────────────────────┘        │   │
│   └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                              │                                           │
│                                              ▼                                           │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │                    RX Error Handler (错误处理单元)                                │   │
│   │         ┌─────────────────────────────────────────────────────────────┐        │   │
│   │         │   FIFO溢出/下溢检测                                        │        │   │
│   │         │   错误状态上报                                              │        │   │
│   │         │   错误计数统计                                              │        │   │
│   │         └─────────────────────────────────────────────────────────────┘        │   │
│   └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                              │                                           │
│                                              ▼                                           │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │                              CXS侧接口 (cxs_clk域)                               │   │
│   │  rx_valid_out ◄──────────────────────────────────────────────────────   │   │
│   │  rx_data_out[CXS_DATA_WIDTH-1:0] ◄────────────────────────────────────────────────   │   │
│   │  rx_user_out ◄──────────────────────────────────────────────────────   │   │
│   │  rx_cntl_out ◄──────────────────────────────────────────────────────   │   │
│   │  rx_last_out ◄──────────────────────────────────────────────────────   │   │
│   │  *(rx_cntl_out包含ENDERROR位)* ◄────────────────────────────────────   │   │
│   │  rx_srcid_out/tgtid_out ◄────────────────────────────────────────   │   │
│   │  rx_ready ◄──────────────────────────────────────────────────────   │   │
│   └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                          │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

**子模块列表：**
| 模块名称 | 功能描述 | 关键接口 | 时钟域 | RTL实现要点 |
|----------|----------|----------|--------|-------------|
| RX Async FIFO | 异步FIFO缓冲 | 写/读接口 | fdi_lclk/cxs_clk | 格雷码指针，空满判断 |
| RX Error Handler | 错误处理 | 错误检测上报 | fdi_lclk | 错误分类 |

### 2.2 数据流 / Data Flow

**主数据通路（RTL实现路径）：**
```
fdi_lclk域:                        cxs_clk域:

rx_valid_in ──▶ 写FIFO ──▶ FIFO ──▶ 读FIFO ──▶ rx_valid_out
rx_data_in ──▶ 缓冲区    (64-deep)   缓冲区   ──▶ rx_data_out
                               ↓
                         格雷码指针同步
```

**控制流：**
```
链路状态     ──▶ cxs_fdi_link_ctrl ──▶ link_active ──▶ 数据流控制
错误检测    ──▶ Error Handler ──▶ 错误上报
```

### 2.3 子模块层次 / Submodule Hierarchy

**说明**: 链路控制已移至独立全局模块:
- 链路控制由 `cxs_fdi_link_ctrl` 独立模块负责 (详见 `cxs_fdi_link_ctrl_spec.md`)

```
rx_path (RX Path - 顶层模块)
├── rx_path_async_fifo (RX异步FIFO缓冲单元)
│   ├── fifo_mem (FIFO存储器) - **实现关键**: 64深度，数据缓冲
│   ├── wr_ptr (写指针) - **实现关键**: 格雷码编码
│   ├── rd_ptr (读指针) - **实现关键**: 格雷码编码
│   ├── full_gen (满信号生成) - **实现关键**: 指针比较
│   └── empty_gen (空信号生成) - **实现关键**: 指针比较
└── rx_path_error_handler (RX错误处理单元)
    ├── error_detect (错误检测) - **实现关键**: 溢出/下溢检测
    ├── error_status (错误状态) - **实现关键**: 状态寄存器
    └── error_counter (错误计数) - **实现关键**: 统计计数
```

---

## 3. 接口定义 / Interface Definitions

### 3.1 顶层接口汇总 / Top-Level Interface Summary

| 接口分类 | 接口名称 | 方向 | 位宽 | 协议 | 时钟域 | RTL实现要求 |
|----------|----------|------|------|------|--------|-------------|
| 时钟复位 | fdi_lclk | Input | 1 | - | - | FDI侧时钟，1.5GHz |
| 时钟复位 | fdi_rst_n | Input | 1 | - | - | FDI侧复位 |
| 时钟复位 | cxs_clk | Input | 1 | - | - | CXS侧时钟，1.5GHz |
| 时钟复位 | cxs_rst_n | Input | 1 | - | - | CXS侧复位 |
| FDI侧输入 | rx_valid_in | Input | 1 | 内部 | fdi_lclk | 来自FDI RX IF |
| FDI侧输入 | rx_data_in | Input | [FDI_DATA_WIDTH] | 内部 | fdi_lclk | 数据载荷 |
| FDI侧输入 | rx_user_in | Input | [FDI_USER_WIDTH] | 内部 | fdi_lclk | 用户位(可选) |
| FDI侧输入 | rx_cntl_in | Input | [CXS_CNTL_WIDTH] | 内部 | fdi_lclk | 控制字段(含ENDERROR位) |
| FDI侧输入 | rx_last_in | Input | 1 | 内部 | fdi_lclk | 包边界 |
| FDI侧输出 | rx_data_ack | Output | 1 | 内部 | fdi_lclk | 数据接收确认 |
| CXS侧输出 | rx_valid_out | Output | 1 | 内部 | cxs_clk | 发送给CXS RX IF |
| CXS侧输出 | rx_data_out | Output | [CXS_DATA_WIDTH] | 内部 | cxs_clk | 数据载荷 |
| CXS侧输出 | rx_user_out | Output | [CXS_USER_WIDTH] | 内部 | cxs_clk | 用户位(可选) |
| CXS侧输出 | rx_cntl_out | Output | [CXS_CNTL_WIDTH] | 内部 | cxs_clk | 控制字段(含ENDERROR位) |
| CXS侧输出 | rx_last_out | Output | 1 | 内部 | cxs_clk | 包边界 |
| CXS侧输出 | rx_srcid_out | Output | [CXS_SRCID_WIDTH] | 内部 | cxs_clk | 源ID(可选) |
| CXS侧输出 | rx_tgtid_out | Output | [CXS_TGTID_WIDTH] | 内部 | cxs_clk | 目标ID(可选) |
| CXS侧输入 | rx_ready | Input | 1 | 内部 | cxs_clk | 数据请求 |
| 链路控制 | link_active | Input | 1 | 内部 | fdi_lclk | 链路激活状态(需从cxs_clk同步) |
| 错误状态 | rx_error | Output | [ERR_WIDTH] | 内部 | fdi_lclk | 错误标志 |

**约束**：`CXS_DATA_WIDTH` 必须等于 `FDI_DATA_WIDTH`，保证1:1 Flit映射。

### 3.2 详细接口定义 / Detailed Interface Specifications

#### 3.2.1 FDI侧输入接口

| 信号名 | 方向 | 位宽 | 描述 | RTL实现要求 |
|--------|------|------|------|-------------|
| rx_valid_in | Input | 1 | 输入数据有效 | 上升沿采样 |
| rx_data_in | Input | [FDI_DATA_WIDTH] | 输入数据 | 与valid同步 |
| rx_user_in | Input | [FDI_USER_WIDTH] | 输入用户位 | 与`rx_data_in`同拍入FIFO |
| rx_cntl_in | Input | [CXS_CNTL_WIDTH] | 输入控制字段 | 与`rx_data_in`同拍入FIFO |
| rx_last_in | Input | 1 | 输入包边界 | 与`rx_data_in`同拍入FIFO |
| rx_data_ack | Output | 1 | 数据接收确认 | 握手响应 |

#### 3.2.2 CXS侧输出接口

| 信号名 | 方向 | 位宽 | 描述 | RTL实现要求 |
|--------|------|------|------|-------------|
| rx_valid_out | Output | 1 | 输出数据有效 | 寄存器输出 |
| rx_data_out | Output | [CXS_DATA_WIDTH] | 输出数据 | 寄存器输出 |
| rx_user_out | Output | [CXS_USER_WIDTH] | 输出用户位 | 与`rx_data_out`同拍出FIFO |
| rx_cntl_out | Output | [CXS_CNTL_WIDTH] | 输出控制字段 | 与`rx_data_out`同拍出FIFO |
| rx_last_out | Output | 1 | 输出包边界 | 与`rx_data_out`同拍出FIFO |
| rx_srcid_out | Output | [CXS_SRCID_WIDTH] | 输出源ID | 与`rx_data_out`同拍出FIFO |
| rx_tgtid_out | Output | [CXS_TGTID_WIDTH] | 输出目标ID | 与`rx_data_out`同拍出FIFO |
| rx_ready | Input | 1 | 数据请求 | 下游反馈 |

#### 3.2.3 链路控制接口

| 信号名 | 方向 | 位宽 | 描述 | RTL实现要求 |
|--------|------|------|------|-------------|
| link_active | Input | 1 | 链路激活状态(需CDC) | 状态输入 |

---

## 4. 时钟与复位 / Clocks and Resets

### 4.1 时钟域 / Clock Domains

| 时钟名称 | 频率 | 描述 | RTL实现要求 |
|----------|------|------|-------------|
| fdi_lclk | 1.5 GHz | FDI侧链路时钟 | 写端口时钟 |
| cxs_clk | 1.5 GHz | CXS侧协议时钟 | 读端口时钟 |

### 4.2 跨时钟域 / Clock Domain Crossings (CDC)

| 源时钟 | 目标时钟 | 信号类型 | 同步方式 | RTL实现 |
|--------|----------|----------|----------|---------|
| fdi_lclk | cxs_clk | 数据信号 | 异步FIFO | 格雷码指针 |
| fdi_lclk | cxs_clk | 指针信号 | 2级同步器 | Gray同步 |
| cxs_clk | fdi_lclk | 状态信号 | 2级同步器 | 握手 |

**CDC设计准则：**
1. 异步FIFO使用格雷码指针编码
2. 指针跨域使用2级同步器
3. 禁止组合逻辑直接跨域

### 4.3 复位域 / Reset Domains

| 复位名称 | 有效电平 | 类型 | 作用范围 | RTL实现要求 |
|----------|----------|------|----------|-------------|
| fdi_rst_n | Low | 全局 | FDI侧逻辑 | 异步断言，同步释放 |
| cxs_rst_n | Low | 全局 | CXS侧逻辑 | 异步断言，同步释放 |

### 4.4 参数约束 / Parameter Constraints

| 约束项 | 约束关系 | 说明 |
|--------|----------|------|
| 数据位宽一致性 | `CXS_DATA_WIDTH == FDI_DATA_WIDTH` | 保证1:1 Flit映射 |
| FIFO与Credit关系 | `FIFO_DEPTH >= 2×MAX_CREDIT` | 避免Credit死锁和持续反压振荡 |

---

## 5. 功能描述 / Functional Description

### 5.1 功能概述 / Functional Overview

RX Path模块的核心功能是实现从fdi_lclk域到cxs_clk域的数据传输通道，包含异步FIFO缓冲和错误处理功能。

**核心功能模块RTL说明：**

#### RX异步FIFO缓冲单元 (RX Async FIFO Unit)
- **模块名称**: RX Async FIFO Unit
- **RTL职责**：实现跨时钟域的异步FIFO缓冲
- **输入处理**：fdi_lclk域写入数据
- **核心逻辑**：与TX Async FIFO对称实现，方向相反
- **输出生成**：cxs_clk域读出数据

#### 链路状态门控接口 (Link Gating Interface)
- **模块名称**: Link Gating Interface
- **RTL职责**：接收`cxs_fdi_link_ctrl`输出的`link_active`状态用于数据门控
- **状态处理**：
  - `link_active`跨域同步
  - 链路未激活时输出门控
  - 激活后恢复数据可见

#### RX错误处理单元 (RX Error Handler Unit)
- **模块名称**: RX Error Handler Unit
- **RTL职责**：检测并处理接收错误
- **错误检测**：
  - FIFO溢出：写请求但FIFO满
  - FIFO下溢：读请求但FIFO空

### 5.2 链路状态管理 / Link State Management

**链路状态管理说明**：
- 本模块不实现独立的链路状态机
- 链路状态控制由独立的 `cxs_fdi_link_ctrl` 模块统一管理（详见 `cxs_fdi_link_ctrl_spec.md`）
- 本模块主要负责FDI到CXS的数据转发和时钟域转换

**本模块与外部模块的接口**：
| 模块 | 接口信号 | 描述 |
|------|----------|------|
| cxs_fdi_link_ctrl | link_active | 链路激活状态 |
| cxs_rx_if | rx_valid_out | 数据有效输出 |
| cxs_rx_if | rx_ready | 接收就绪信号 |

### 5.3 典型事务流程 / Example Transactions

#### 数据接收流程
```

**字段一致性规则：**
- `rx_user_in/rx_cntl_in/rx_last_in` 必须与 `rx_data_in` 作为同一FIFO表项写入
- `rx_valid_out` 保持期间，`rx_data_out/rx_user_out/rx_cntl_out/rx_last_out/rx_srcid_out/rx_tgtid_out` 必须保持稳定直到 `rx_ready=1`
fdi_lclk:       __|‾‾‾‾|__|‾‾‾‾|__|‾‾‾‾|__|‾‾‾‾|__
rx_valid_in:    ____|‾‾‾‾|___________________
rx_data_in:     ----< D1 >----< D2 >------------
fifo_wr:        ____|‾‾‾‾|________|‾‾‾‾|________

cxs_clk:        __|‾‾‾‾|__|‾‾‾‾|__|‾‾‾‾|__|‾‾‾‾|__
fifo_rd:        _________|‾‾‾‾|________|‾‾‾‾|__
rx_valid_out:   __________|‾‾‾‾|________|‾‾‾‾|__
rx_data_out:    -----------< D1 >----< D2 >------
```

### 5.4 错误处理 / Error Handling

#### 错误类型（RTL检测）

| 错误代码 | 错误名称 | 描述 | RTL检测方式 |
|----------|----------|------|-------------|
| [2] | ERR_FIFO_OVERFLOW | FIFO溢出 | 满时写检测 |
| [3] | ERR_FIFO_UNDERFLOW | FIFO下溢 | 空时读检测 |
| [4] | ERR_LINK_DOWN | 链路断开 | 状态检测 |

---

## 6. 配置寄存器 / Configuration Registers (CSRs)

本模块不定义独立CSR。所有寄存器由`regs`模块统一管理，地址与字段见：
- `docs/specification/ucie_cxs_fdi_arch_spec.md`
- `docs/specification/regs_spec.md`

**与本模块相关的全局寄存器/字段：**
- `STATUS.RX_READY`
- `ERR_STATUS.ERR_FIFO_OVERFLOW`、`ERR_STATUS.ERR_FIFO_UNDERFLOW`

---

## 7. 性能规格 / Performance Specifications

### 7.1 性能指标 / Performance Metrics

| 指标 | 目标值 | 单位 | RTL实现约束 |
|------|--------|------|-------------|
| FIFO深度 | 64 | 项 | 异步缓冲 |
| 吞吐量 | 96 | GB/s | 满带宽 |
| CDC延迟 | 2-3 | 周期 | 跨域延迟 |
| FIFO利用率 | > 90 | % | 效率优化 |

---

## 9. 验证与调试 / Verification and Debug

### 9.1 验证策略

| 方法 | 覆盖率目标 | RTL验证要点 |
|------|------------|-------------|
| CDC验证 | 100% | 异步FIFO正确性 |
| 随机验证 | > 95% | 数据一致性 |
| 定向测试 | 100% | 边界条件 |

---

**文档结束**

**相关文档：**
- 架构规格：`docs/specification/ucie_cxs_fdi_arch_spec.md`
- FDI RX接口规格：`docs/specification/fdi_rx_if_spec.md`
- CXS RX接口规格：`docs/specification/cxs_rx_if_spec.md`
- 编码规范：`docs/coding_standards/coding_guide.md`
