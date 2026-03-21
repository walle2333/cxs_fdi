# TX Path模块设计规格书 (TX Path Module Design Specification)

**文档编号**: [MOD-TX-PATH-001]  
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

本文档定义了TX Path模块的详细设计规格，作为RTL设计、验证和集成的唯一真实来源(One Source of Truth)。TX Path是UCIe CXS-FDI Bridge的核心数据通路模块，负责将CXS TX Interface输出的数据通过异步FIFO跨时钟域发送到FDI TX Interface。

### 1.2 功能描述 / Functional Description

TX Path模块实现从cxs_clk域到fdi_lclk域的数据传输通道，包含异步FIFO缓冲和错误处理功能。

**主要功能：**
- **异步数据传输**：通过异步FIFO实现cxs_clk域到fdi_lclk域的数据缓冲和传输
- **错误处理**：检测并处理传输过程中的错误，上报错误状态

**模块在系统中的位置：**
```
+---------------------------+     +---------------------------+     +---------------------------+
|    CXS TX Interface        |     |  TX Path                  |     |  FDI TX Interface         |
| (cxs_clk域)               |────▶│ (跨时钟域数据通路)         |────▶│ (fdi_lclk域)              |
|                          |     │                           │     |                           |
| tx_valid_out ────────────│────▶│ TX Async FIFO ────────────│────▶│ tx_valid_in               |
| tx_data_out ────────────│────▶│                           │────▶│                           |
+---------------------------+     +---------------------------+     +---------------------------+
```

**目标应用场景：**
- 多芯片CPU/GPU互连扩展场景下的跨时钟域数据传输
- 服务器SoC的Die-to-Die通信中数据缓冲
- 高性能计算芯片间的低延迟互连

### 1.3 目标与非目标 / Goals and Non-Goals

**目标 (Goals) - 必须实现：**
| 目标 | 描述 | 优先级 | RTL实现要求 |
|------|------|--------|-------------|
| CDC正确性 | 异步FIFO正确实现跨时钟域 | P0 | 格雷码指针，空满判断 |
| 数据一致性 | 确保跨域数据传输不丢失、不重复 | P0 | 握手协议保证 |

**非目标 (Non-Goals) - 明确排除：**
- CXS协议处理：由cxs_tx_if模块负责
- FDI协议处理：由fdi_tx_if模块负责

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
│                                    TX Path (tx_path)                                   │
│                                                                                          │
│   ═══════════════════════════════════════════════════════════════════════════════════   │
│                              [Clock Domain: cxs_clk ↔ fdi_lclk]                         │
│   ═══════════════════════════════════════════════════════════════════════════════════   │
│                                                                                          │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │                              CXS侧接口 (cxs_clk域)                               │   │
│   │  tx_valid_in           ───────────────────────────────────────────────────►   │   │
│   │  tx_data_in[CXS_DATA_WIDTH-1:0]     ───────────────────────────────────────────────────►   │   │
│   │  tx_cntl_in           ──────────────────────────────────────────────────►   │   │
│   │  tx_last_in           ──────────────────────────────────────────────────►   │   │
│   │  *(tx_cntl_in包含ENDERROR位)* ──────────────────────────────────────────►   │   │
│   │  tx_srcid_in/tgtid_in ────────────────────────────────────────────────►   │   │
│   │  tx_ready ◄────────────────────────────────────────────────────────────   │   │
│   └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                              │                                           │
│                                              ▼                                           │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │                    TX Async FIFO (异步FIFO缓冲单元)                              │   │
│   │         ┌─────────────────────────────────────────────────────────────┐        │   │
│   │         │   64-depth Async FIFO                                       │        │   │
│   │         │   Write: cxs_clk    Read: fdi_lclk                         │        │   │
│   │         │   Gray Code Pointer    Full/Empty Detection                │        │   │
│   │         └─────────────────────────────────────────────────────────────┘        │   │
│   └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                              │                                           │
│                                              ▼                                           │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │                    TX Error Handler (错误处理单元)                               │   │
│   │         ┌─────────────────────────────────────────────────────────────┐        │   │
│   │         │   FIFO溢出/下溢检测                                        │        │   │
│   │         │   错误状态上报                                              │        │   │
│   │         │   错误计数统计                                              │        │   │
│   │         └─────────────────────────────────────────────────────────────┘        │   │
│   └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                              │                                           │
│                                              ▼                                           │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │                              FDI侧接口 (fdi_lclk域)                             │   │
│   │  tx_valid_out ◄──────────────────────────────────────────────────────   │   │
│   │  tx_data_out[FDI_DATA_WIDTH-1:0] ◄────────────────────────────────────────────────   │   │
│   │  tx_user_out ◄──────────────────────────────────────────────────────   │   │
│   │  tx_cntl_out ◄──────────────────────────────────────────────────────   │   │
│   │  tx_last_out ◄──────────────────────────────────────────────────────   │   │
│   │  *(tx_cntl_out包含ENDERROR位)* ◄────────────────────────────────────   │   │
│   │  tx_data_ack ────────────────────────────────────────────────────────►   │   │
│   └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                              │                                           │
│   ┌─────────────────────────────────────────┴────────────────────────────────────────┐  │
│   │                              外部模块接口                                        │  │
│   │  link_active ◄───────── CXS-FDI Link Ctrl (独立模块)                         │  │
│   └─────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                          │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

**子模块列表：**
| 模块名称 | 功能描述 | 关键接口 | 时钟域 | RTL实现要点 |
|----------|----------|----------|--------|-------------|
| TX Async FIFO | 异步FIFO缓冲 | 写/读接口 | cxs_clk/fdi_lclk | 格雷码指针，空满判断 |
| TX Error Handler | 错误处理 | 错误检测上报 | cxs_clk | 错误分类 |

### 2.2 数据流 / Data Flow

**主数据通路（RTL实现路径）：**
```
cxs_clk域:                        fdi_lclk域:
                                  
tx_valid_in ──▶ 写FIFO ──▶ FIFO ──▶ 读FIFO ──▶ tx_valid_out
tx_data_in ──▶ 缓冲区    (64-deep)    缓冲区   ──▶ tx_data_out
                              ↓
                        格雷码指针同步
```

**控制流：**
```
链路状态     ←── cxs_fdi_link_ctrl模块
错误检测    ──▶ Error Handler ──▶ 错误上报
```

### 2.3 子模块层次 / Submodule Hierarchy

**说明**: 链路控制已移至独立全局模块:
- 链路控制由 `cxs_fdi_link_ctrl` 独立模块负责 (详见 `cxs_fdi_link_ctrl_spec.md`)

```
tx_path (TX Path - 顶层模块)
├── tx_path_async_fifo (TX异步FIFO缓冲单元)
│   ├── fifo_mem (FIFO存储器) - **实现关键**: 64深度，数据缓冲
│   ├── wr_ptr (写指针) - **实现关键**: 格雷码编码
│   ├── rd_ptr (读指针) - **实现关键**: 格雷码编码
│   ├── full_gen (满信号生成) - **实现关键**: 指针比较
│   └── empty_gen (空信号生成) - **实现关键**: 指针比较
└── tx_path_error_handler (TX错误处理单元)
    ├── error_detect (错误检测) - **实现关键**: 溢出/下溢检测
    ├── error_status (错误状态) - **实现关键**: 状态寄存器
    └── error_counter (错误计数) - **实现关键**: 统计计数
```

---

## 3. 接口定义 / Interface Definitions

### 3.1 顶层接口汇总 / Top-Level Interface Summary

| 接口分类 | 接口名称 | 方向 | 位宽 | 协议 | 时钟域 | RTL实现要求 |
|----------|----------|------|------|------|--------|-------------|
| 时钟复位 | cxs_clk | Input | 1 | - | - | CXS侧时钟，1.5GHz |
| 时钟复位 | cxs_rst_n | Input | 1 | - | - | CXS侧复位 |
| 时钟复位 | fdi_lclk | Input | 1 | - | - | FDI侧时钟，1.5GHz |
| 时钟复位 | fdi_rst_n | Input | 1 | - | - | FDI侧复位 |
| CXS侧输入 | tx_valid_in | Input | 1 | 内部 | cxs_clk | 来自CXS TX IF |
| CXS侧输入 | tx_data_in | Input | [CXS_DATA_WIDTH] | 内部 | cxs_clk | 数据载荷 |
| CXS侧输入 | tx_user_in | Input | [CXS_USER_WIDTH] | 内部 | cxs_clk | 用户位(可选) |
| CXS侧输入 | tx_cntl_in | Input | [CXS_CNTL_WIDTH] | 内部 | cxs_clk | 控制字段(含ENDERROR位) |
| CXS侧输入 | tx_last_in | Input | 1 | 内部 | cxs_clk | 包边界 |
| CXS侧输入 | tx_srcid_in | Input | [CXS_SRCID_WIDTH] | 内部 | cxs_clk | 源ID(可选) |
| CXS侧输入 | tx_tgtid_in | Input | [CXS_TGTID_WIDTH] | 内部 | cxs_clk | 目标ID(可选) |
| CXS侧输出 | tx_ready | Output | 1 | 内部 | cxs_clk | 接收准备就绪(Valid/Ready握手) |
| FDI侧输出 | tx_valid_out | Output | 1 | 内部 | fdi_lclk | 发送给FDI TX IF |
| FDI侧输出 | tx_data_out | Output | [FDI_DATA_WIDTH] | 内部 | fdi_lclk | 数据载荷 |
| FDI侧输出 | tx_user_out | Output | [FDI_USER_WIDTH] | 内部 | fdi_lclk | 用户位(可选) |
| FDI侧输出 | tx_cntl_out | Output | [CXS_CNTL_WIDTH] | 内部 | fdi_lclk | 控制字段(含ENDERROR位) |
| FDI侧输出 | tx_last_out | Output | 1 | 内部 | fdi_lclk | 包边界 |
| FDI侧输入 | tx_data_ack | Input | 1 | 内部 | fdi_lclk | 下游接收确认(来自FDI TX IF) |
| 链路控制 | link_active | Input | 1 | 内部 | cxs_clk | 链路激活状态，来自cxs_fdi_link_ctrl模块 |
| 错误状态 | tx_error | Output | [ERR_WIDTH] | 内部 | cxs_clk | 错误标志 |

**约束**：`CXS_DATA_WIDTH` 必须等于 `FDI_DATA_WIDTH`，保证1:1 Flit映射。

### 3.2 详细接口定义 / Detailed Interface Specifications

#### 3.2.1 CXS侧输入接口

| 信号名 | 方向 | 位宽 | 描述 | RTL实现要求 |
|--------|------|------|------|-------------|
| tx_valid_in | Input | 1 | 输入数据有效 | 上升沿采样 |
| tx_data_in | Input | [CXS_DATA_WIDTH] | 输入数据 | 与valid同步 |
| tx_user_in | Input | [CXS_USER_WIDTH] | 输入用户位 | 与`tx_data_in`同拍入FIFO |
| tx_cntl_in | Input | [CXS_CNTL_WIDTH] | 输入控制字段 | 与`tx_data_in`同拍入FIFO |
| tx_last_in | Input | 1 | 输入包边界 | 与`tx_data_in`同拍入FIFO |
| tx_srcid_in | Input | [CXS_SRCID_WIDTH] | 输入源ID | 与`tx_data_in`同拍入FIFO |
| tx_tgtid_in | Input | [CXS_TGTID_WIDTH] | 输入目标ID | 与`tx_data_in`同拍入FIFO |
| tx_ready | Output | 1 | 接收准备就绪 | 握手响应 |

#### 3.2.2 FDI侧输出接口

| 信号名 | 方向 | 位宽 | 描述 | RTL实现要求 |
|--------|------|------|------|-------------|
| tx_valid_out | Output | 1 | 输出数据有效 | 寄存器输出 |
| tx_data_out | Output | [FDI_DATA_WIDTH] | 输出数据 | 寄存器输出 |
| tx_user_out | Output | [FDI_USER_WIDTH] | 输出用户位 | 与`tx_data_out`同拍出FIFO |
| tx_cntl_out | Output | [CXS_CNTL_WIDTH] | 输出控制字段 | 与`tx_data_out`同拍出FIFO |
| tx_last_out | Output | 1 | 输出包边界 | 与`tx_data_out`同拍出FIFO |
| tx_data_ack | Input | 1 | 下游接收确认 | 下游反馈 |

#### 3.2.3 链路控制接口（与cxs_fdi_link_ctrl模块交互）

| 信号名 | 方向 | 位宽 | 描述 | RTL实现要求 |
|--------|------|------|------|-------------|
| link_active | Input | 1 | 链路激活状态，来自cxs_fdi_link_ctrl模块 | 状态输入 |

#### 3.2.4 错误处理接口

| 信号名 | 方向 | 位宽 | 描述 | RTL实现要求 |
|--------|------|------|------|-------------|
| tx_error | Output | [ERR_WIDTH] | 错误标志 | 错误上报 |

---

## 4. 时钟与复位 / Clocks and Resets

### 4.1 时钟域 / Clock Domains

| 时钟名称 | 频率 | 描述 | RTL实现要求 |
|----------|------|------|-------------|
| cxs_clk | 1.5 GHz | CXS侧协议时钟 | 写端口时钟 |
| fdi_lclk | 1.5 GHz | FDI侧链路时钟 | 读端口时钟 |

### 4.2 跨时钟域 / Clock Domain Crossings (CDC)

| 源时钟 | 目标时钟 | 信号类型 | 同步方式 | RTL实现 |
|--------|----------|----------|----------|---------|
| cxs_clk | fdi_lclk | 数据信号 | 异步FIFO | 格雷码指针 |
| cxs_clk | fdi_lclk | 指针信号 | 2级同步器 | Gray同步 |
| fdi_lclk | cxs_clk | 状态信号 | 2级同步器 | 握手 |

**CDC设计准则：**
1. 异步FIFO使用格雷码指针编码
2. 指针跨域使用2级同步器
3. 禁止组合逻辑直接跨域

### 4.3 复位域 / Reset Domains

| 复位名称 | 有效电平 | 类型 | 作用范围 | RTL实现要求 |
|----------|----------|------|----------|-------------|
| cxs_rst_n | Low | 全局 | CXS侧逻辑 | 异步断言，同步释放 |
| fdi_rst_n | Low | 全局 | FDI侧逻辑 | 异步断言，同步释放 |

### 4.4 参数约束 / Parameter Constraints

| 约束项 | 约束关系 | 说明 |
|--------|----------|------|
| 数据位宽一致性 | `CXS_DATA_WIDTH == FDI_DATA_WIDTH` | 保证1:1 Flit映射 |
| FIFO与Credit关系 | `FIFO_DEPTH >= 2×MAX_CREDIT` | 避免Credit死锁和持续反压振荡 |

---

## 5. 功能描述 / Functional Description

### 5.1 功能概述 / Functional Overview

TX Path模块的核心功能是实现从cxs_clk域到fdi_lclk域的数据传输通道，包含异步FIFO缓冲和错误处理功能。

**核心功能模块RTL说明：**

#### TX异步FIFO缓冲单元 (TX Async FIFO Unit)
- **模块名称**: TX Async FIFO Unit
- **RTL职责**：实现跨时钟域的异步FIFO缓冲
- **输入处理**：cxs_clk域写入数据
- **核心逻辑**：
  ```systemverilog
  // 写指针 - 格雷码编码
  always_ff @(posedge cxs_clk or negedge cxs_rst_n) begin
    if (!cxs_rst_n) begin
      wr_ptr_gray <= '0;
    end else if (tx_valid_in && !fifo_full) begin
      wr_ptr_gray <= (wr_ptr_bin + 1) ^ ((wr_ptr_bin + 1) >> 1);  // 二进制转格雷码
    end
  end
  
  // 读指针 - 格雷码编码
  always_ff @(posedge fdi_lclk or negedge fdi_rst_n) begin
    if (!fdi_rst_n) begin
      rd_ptr_gray <= '0;
    else if (tx_data_req && !fifo_empty) begin
      rd_ptr_gray <= (rd_ptr_bin + 1) ^ ((rd_ptr_bin + 1) >> 1);
    end
  end
  
  // 满信号生成
  assign fifo_full = (wr_ptr_gray == {~rd_ptr_gray[MSB:MSB-1], rd_ptr_gray[MSB-2:0]});
  ```
- **输出生成**：fdi_lclk域读出数据

#### TX错误处理单元 (TX Error Handler Unit)
- **模块名称**: TX Error Handler Unit
- **RTL职责**：检测并处理传输错误
- **错误检测**：
  - FIFO溢出：写请求但FIFO满
  - FIFO下溢：读请求但FIFO空

### 5.2 链路状态与接口管理 / Link State and Interface Management

**链路状态管理说明**：
- 本模块不实现独立的链路状态机
- 链路状态控制由独立的 `cxs_fdi_link_ctrl` 模块统一管理（详见 `cxs_fdi_link_ctrl_spec.md`）

**本模块与外部模块的接口**：
| 模块 | 接口信号 | 描述 |
|------|----------|------|
| cxs_fdi_link_ctrl | link_active | 链路激活状态 |

### 5.3 典型事务流程 / Example Transactions

#### 数据传输流程
```

**字段一致性规则：**
- `tx_user_in/tx_cntl_in/tx_last_in/tx_srcid_in/tx_tgtid_in` 必须与 `tx_data_in` 作为同一FIFO表项写入
- `tx_valid_out` 保持期间，`tx_data_out/tx_user_out/tx_cntl_out/tx_last_out` 必须保持稳定直到 `tx_data_ack=1`
cxs_clk:        __|‾‾‾‾|__|‾‾‾‾|__|‾‾‾‾|__|‾‾‾‾|__
tx_valid_in:    ____|‾‾‾‾|___________________
tx_data_in:     ----< D1 >----< D2 >------------
fifo_wr:        ____|‾‾‾‾|________|‾‾‾‾|________

fdi_lclk:       __|‾‾‾‾|__|‾‾‾‾|__|‾‾‾‾|__|‾‾‾‾|__
fifo_rd:        _________|‾‾‾‾|________|‾‾‾‾|__
tx_valid_out:   __________|‾‾‾‾|________|‾‾‾‾|__
tx_data_out:    -----------< D1 >----< D2 >------
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
- `STATUS.TX_READY`
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
- CXS TX接口规格：`docs/specification/cxs_tx_if_spec.md`
- FDI TX接口规格：`docs/specification/fdi_tx_if_spec.md`
- 编码规范：`docs/coding_standards/coding_guide.md`
