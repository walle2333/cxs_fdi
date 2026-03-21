# FDI RX Interface模块设计规格书 (FDI RX Interface Module Design Specification)

**文档编号**: [MOD-FDI-RX-IF-001]  
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

本文档定义了FDI RX Interface模块的详细设计规格，作为RTL设计、验证和集成的唯一真实来源(One Source of Truth)。FDI RX Interface是UCIe CXS-FDI Bridge的FDI侧接口模块之一，负责接收来自UCIe Adapter的数据，并将其转换为内部格式发送给RX Path Logic。

### 1.2 功能描述 / Functional Description

FDI RX Interface模块实现UCIe FDI协议到Bridge内部数据通路的接口功能，负责数据接收、Ready/Valid流控处理，并与UCIe Adapter完成握手交互。

**主要功能：**
- **数据接收**：接收来自Adapter的FDI格式数据(fdi_pl_valid, fdi_pl_flit, fdi_pl_stream)
- **流控生成**：生成fdi_pl_trdy信号表示接收准备就绪
- **多流解析**：解析fdi_pl_stream信号识别不同的协议流
- **DLLP接收**：可选接收fdi_pl_dllp_valid和fdi_pl_dllp传输链路管理信息（`FDI_DLLP_WIDTH>0`时启用）
- **Flit取消处理**：处理fdi_pl_flit_cancel信号，丢弃有错误的Flit
- **链路状态响应**：响应fdi_pl_state_sts状态变化

**模块在系统中的位置：**
```
+---------------------------+     +---------------------------+     +---------------------------+
|    UCIe Adapter            |     |  FDI RX Interface         |     |  RX Path Logic            |
| (Die-to-Die Interface)    │────▶│ (本模块 - FDI输入)        │────▶│ (RX Async FIFO)           |
|                          |     |                           |     |                           |
| fdi_pl_valid ────────────│────▶│ fdi_pl_* processing ──────│────▶│ rx_* outputs              |
| fdi_pl_trdy ◀────────────│────▶│                          |     |                          |
+---------------------------+     +---------------------------+     +---------------------------+
```

**目标应用场景：**
- 多芯片CPU/GPU互连扩展场景下的Die-to-Die数据接收
- 服务器SoC的UCIe物理层数据接收
- 高性能计算芯片间的物理层互联

### 1.3 目标与非目标 / Goals and Non-Goals

**目标 (Goals) - 必须实现：**
| 目标 | 描述 | 优先级 | RTL实现要求 |
|------|------|--------|-------------|
| FDI协议合规 | 完全遵循UCIe FDI接口规范 | P0 | 信号时序符合规范 |
| 高性能数据接收 | 支持256b/512b/1024b/2048b Flit宽度，满带宽接收 | P0 | Ready/Valid握手效率最大化 |
| 流控正确性 | 正确生成Ready信号，避免数据丢失 | P0 | 握手协议正确实现 |
| DLLP支持 | 支持DLLP接收和处理 | P1 | 与Flit独立处理 |
| Flit取消处理 | 正确处理fdi_pl_flit_cancel | P1 | 错误Flit丢弃 |
| 链路状态处理 | 响应链路状态变化 | P1 | 状态机正确响应 |

**非目标 (Non-Goals) - 明确排除：**
- CXS协议处理：CXS侧接口处理由cxs_rx_if模块负责
- 数据缓冲功能：本模块仅做接口接收
- FDI管理/功耗接口：不支持pl_clk_req/lp_clk_ack、lp_wake_req/pl_wake_ack、lp_state_req/lp_linkerror、pl_cfg/lp_cfg等
- FDI扩展错误/管理信号：不支持pl_cerror、pl_nferror、pl_trainerror、pl_stallreq/lp_stallack、pl_speedmode、pl_lnk_cfg等

### 1.4 关键指标 / Key Metrics

| 指标 | 目标值 | 单位 | 备注 | RTL实现影响 |
|------|--------|------|------|-------------|
| 工作频率 | 1.5 | GHz | 与FDI链路同步 | 时序约束 |
| 吞吐量 | 96 | GB/s | 512b × 1.5GHz | 数据通路需无气泡 |
| 接收延迟 | 1 | 时钟周期 | Valid到数据采样延迟 | 寄存器采样 |
| 面积估算 | < 400 | 门数 | 逻辑面积 | 主要是输入逻辑 |
| 功耗估算 | < 25 | mW | 典型功耗 | 动态功耗 |

---

## 2. 架构设计 / Architecture Design

### 2.1 模块顶层框图 / Module Top-Level Block Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                              FDI RX Interface (fdi_rx_if)                               │
│                                                                                          │
│   ═══════════════════════════════════════════════════════════════════════════════════   │
│                              [Clock Domain: fdi_lclk]                                    │
│   ═══════════════════════════════════════════════════════════════════════════════════   │
│                                                                                          │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │                              FDI输入接口 (来自UCIe Adapter)                        │   │
│   │  fdi_pl_valid    ────────────────────────────────────────────────────►   │   │
│   │  fdi_pl_flit[FDI_DATA_WIDTH-1:0] ◄────────────────────────────────────────────────   │   │
│   │  fdi_pl_trdy ────────────────────────────────────────────────────────►   │   │
│   │  fdi_pl_stream ◄──────────────────────────────────────────────────────   │   │
│   │  fdi_pl_dllp_valid ◄──────────────────────────────────────────────────   │   │
│   │  fdi_pl_dllp ◄────────────────────────────────────────────────────────   │   │
│   │  fdi_pl_flit_cancel ◄──────────────────────────────────────────────────   │   │
│   └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                              │                                           │
│                                              ▼                                           │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │                              数据接收与解析单元 (Data Receive & Parse Unit)        │   │
│   │         ┌─────────────────────────────────────────────────────────────┐        │   │
│   │         │   fdi_pl_valid采样                                      │        │   │
│   │         │   fdi_pl_flit解析                                       │        │   │
│   │         │   fdi_pl_stream解码                                     │        │   │
│   │         │   flit_cancel检测                                       │        │   │
│   │         └─────────────────────────────────────────────────────────────┘        │   │
│   └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                              │                                           │
│                                              ▼                                           │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │                              流控生成单元 (Flow Control Generation Unit)          │   │
│   │         ┌─────────────────────────────────────────────────────────────┐        │   │
│   │         │   fdi_pl_trdy: Ready信号生成                              │        │   │
│   │         │   可提前1-2周期断言                                       │        │   │
│   │         └─────────────────────────────────────────────────────────────┘        │   │
│   └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                              │                                           │
│                                              ▼                                           │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │                              内部输出 (发送到RX Path Logic)                        │   │
│   │  rx_valid_out   ────────────────────────────────────────────────────►   │   │
│   │  rx_data_out[FDI_DATA_WIDTH-1:0] ◄────────────────────────────────────────────────   │   │
│   │  rx_user_out ◄──────────────────────────────────────────────────────   │   │
│   │  rx_cntl_out ◄──────────────────────────────────────────────────────   │   │
│   │  rx_last_out ◄──────────────────────────────────────────────────────   │   │
│   │  *(rx_cntl_out包含ENDERROR位)* ◄────────────────────────────────────   │   │
│   │  rx_ready ◄──────────────────────────────────────────────────────   │   │
│   └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                              │                                           │
│   ┌─────────────────────────────────────────┴────────────────────────────────────────┐  │
│   │                              链路状态响应单元 (Link Status Response Unit)         │  │
│   │  fdi_pl_state_sts ──────────────────────────────────────────────────────►   │  │
│   │  fdi_pl_idle ────────────────────────────────────────────────────────►   │  │
│   │  fdi_pl_error ────────────────────────────────────────────────────────►   │  │
│   │         ┌─────────────────────────────────────────────────────────────┐       │  │
│   │         │   IDLE/AWAKE/ACTIVE/RETRAIN 状态检测                     │       │  │
│   │         │   接收控制                                                  │       │  │
│   │         └─────────────────────────────────────────────────────────────┘       │  │
│   └─────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                          │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

**子模块列表：**
| 模块名称 | 功能描述 | 关键接口 | 时钟域 | RTL实现要点 |
|----------|----------|----------|--------|-------------|
| 数据接收与解析单元 | 接收并解析FDI数据 | fdi_pl_valid, fdi_pl_flit | fdi_lclk | Valid检测，数据解析 |
| 流控生成单元 | 生成Ready信号 | fdi_pl_trdy | fdi_lclk | 提前断言优化 |
| 链路状态响应单元 | 响应链路状态变化 | fdi_pl_state_sts | fdi_lclk | 状态检测和控制 |
| DLLP接收单元 | 处理DLLP接收 | fdi_pl_dllp_valid, fdi_pl_dllp | fdi_lclk | DLLP解析 |

### 2.2 数据流 / Data Flow

**主数据通路（RTL实现路径）：**
```
fdi_pl_valid     ──▶┐
fdi_pl_flit      ──▶├── 数据接收与解析 ──▶ rx_valid_out
fdi_pl_stream    ──▶│  (Valid检测)         rx_data_out
fdi_pl_dllp*     ──▶│                      rx_user_out
                    │                      rx_cntl_out
                    │                      rx_last_out
                    │                      *(rx_cntl_out含ENDERROR)*
                    │
                    ▼
            RX Path Logic
```

**控制流：**
```
fdi_pl_trdy ──▶ 流控生成 ──▶ 接收确认
fdi_pl_state_sts ──▶ 链路状态响应 ──▶ 接收控制
fdi_pl_flit_cancel ──▶ 数据接收与解析 ──▶ 丢弃Flit
```

### 2.3 子模块层次 / Submodule Hierarchy

```
fdi_rx_if (FDI RX Interface - 顶层模块)
├── fdi_rx_if_data_parse (数据接收与解析单元)
│   ├── valid_sample (Valid采样) - **实现关键**: 上升沿采样
│   ├── flit_parse (Flit解析) - **实现关键**: 数据拆分
│   ├── stream_decode (流ID解码) - **实现关键**: 多流识别
│   └── cancel_detect (取消检测) - **实现关键**: 错误Flit检测
├── fdi_rx_if_flow_ctrl (流控生成单元)
│   ├── ready_gen (Ready生成) - **实现关键**: 提前断言
│   └── backpressure (背压处理) - **实现关键**: 响应下游
├── fdi_rx_if_link_resp (链路状态响应单元)
│   ├── state_detect (状态检测) - **实现关键**: Idle/Error检测
│   └── receive_control (接收控制) - **实现关键**: 状态响应
└── fdi_rx_if_dllp (DLLP接收单元)
    ├── dllp_sample (DLLP采样) - **实现关键**: 独立采样
    └── dllp_process (DLLP处理) - **实现关键**: 链路管理
```

---

## 3. 接口定义 / Interface Definitions

### 3.1 顶层接口汇总 / Top-Level Interface Summary

| 接口分类 | 接口名称 | 方向 | 位宽 | 协议 | 时钟域 | RTL实现要求 |
|----------|----------|------|------|------|--------|-------------|
| 时钟复位 | fdi_lclk | Input | 1 | - | - | 全局时钟，上升沿采样，1.5GHz |
| 时钟复位 | fdi_rst_n | Input | 1 | - | - | 低电平异步复位，同步释放 |
| FDI输入 | fdi_pl_valid | Input | 1 | FDI | fdi_lclk | 接收数据有效指示 |
| FDI输入 | fdi_pl_flit | Input | [FDI_DATA_WIDTH] | FDI | fdi_lclk | Flit数据 |
| FDI输入 | fdi_pl_stream | Input | [FDI_STREAM_WIDTH] | FDI | fdi_lclk | 流ID |
| FDI输出 | fdi_pl_trdy | Output | 1 | FDI | fdi_lclk | Ready信号 |
| FDI输入 | fdi_pl_dllp_valid | Input | 1 | FDI | fdi_lclk | DLLP有效(可选) |
| FDI输入 | fdi_pl_dllp | Input | [FDI_DLLP_WIDTH] | FDI | fdi_lclk | DLLP数据(可选) |
| FDI输入 | fdi_pl_flit_cancel | Input | 1 | FDI | fdi_lclk | Flit取消指示 |
| FDI输入 | fdi_pl_state_sts | Input | 4 | FDI | fdi_lclk | 链路状态 |
| FDI输入 | fdi_pl_idle | Input | 1 | FDI | fdi_lclk | Idle指示 |
| FDI输入 | fdi_pl_error | Input | 1 | FDI | fdi_lclk | 错误指示 |
| FDI输入 | fdi_pl_rx_active_req | Input | 1 | FDI | fdi_lclk | Rx_active_req握手 |
| FDI输出 | fdi_lp_rx_active_sts | Output | 1 | FDI | fdi_lclk | Rx_active_sts握手 |
| 内部输出 | rx_valid_out | Output | 1 | 内部 | fdi_lclk | 输出数据有效 |
| 内部输出 | rx_data_out | Output | [FDI_DATA_WIDTH] | 内部 | fdi_lclk | 输出数据 |
| 内部输出 | rx_user_out | Output | [FDI_USER_WIDTH] | 内部 | fdi_lclk | 用户位(可选) |
| 内部输出 | rx_cntl_out | Output | [CXS_CNTL_WIDTH] | 内部 | fdi_lclk | 控制字段(含ENDERROR位) |
| 内部输出 | rx_last_out | Output | 1 | 内部 | fdi_lclk | 包边界 |
| 内部输出 | rx_srcid_out | Output | [CXS_SRCID_WIDTH] | 内部 | fdi_lclk | 源ID(可选) |
| 内部输出 | rx_tgtid_out | Output | [CXS_TGTID_WIDTH] | 内部 | fdi_lclk | 目标ID |
| 内部输入 | rx_ready | Input | 1 | 内部 | fdi_lclk | 数据请求 |

### 3.2 详细接口定义 / Detailed Interface Specifications

#### 3.2.1 FDI数据输入接口

基于 **UCIe Specification (Rev 3.0)** 的FDI接口定义：

| 信号名 | FDI标准名 | 方向 | 位宽 | 描述 | RTL实现要求 |
|--------|-----------|------|------|------|-------------|
| fdi_pl_valid | **fdi_pl_valid** | Input | 1 | Adapter到Protocol Layer的接收数据有效指示 | 与lclk同步 |
| fdi_pl_flit | **fdi_pl_flit** | Input | [FDI_DATA_WIDTH] | 接收Flit数据 | 与fdi_pl_valid同步 |
| fdi_pl_stream | **fdi_pl_stream** | Input | [FDI_STREAM_WIDTH] | 接收流ID | 与fdi_pl_valid同步 |

**时序要求（RTL必须遵守）：**
- 数据传输条件：`fdi_pl_valid && fdi_pl_trdy` 同时高时数据传输
- Rx_active_req/Sts：fdi_pl_rx_active_req 上升沿仅在 fdi_lp_rx_active_sts=0 时有效，fdi_lp_rx_active_sts 需在 fdi_pl_rx_active_req 之后断言且至少隔 1 周期
- 系统参数约束：`FIFO_DEPTH >= 2×MAX_CREDIT`（由TX/RX Path与credit_mgr共同保证）

#### 3.2.2 FDI流控接口

| 信号名 | FDI标准名 | 方向 | 位宽 | 描述 | RTL实现要求 |
|--------|-----------|------|------|------|-------------|
| fdi_pl_trdy | **fdi_pl_trdy** | Output | 1 | Protocol Layer Ready | 可与fdi_pl_valid同时或提前断言 |

#### 3.2.3 DLLP接口

| 信号名 | FDI标准名 | 方向 | 位宽 | 描述 | RTL实现要求 |
|--------|-----------|------|------|------|-------------|
| fdi_pl_dllp_valid | **fdi_pl_dllp_valid** | Input | 1 | 接收DLLP有效(可选) | 可与fdi_pl_flit同时有效 |
| fdi_pl_dllp | **fdi_pl_dllp** | Input | [FDI_DLLP_WIDTH] | 接收DLLP数据(可选) | 与valid同步 |

#### 3.2.4 物理层状态接口

| 信号名 | FDI标准名 | 方向 | 位宽 | 描述 | RTL实现要求 |
|--------|-----------|------|------|------|-------------|
| fdi_pl_state_sts | **fdi_pl_state_sts** | Input | 4 | Physical Layer链路状态 | 编码: 0000=Reset, 0001=LinkUp, 0010=Active, 0011=Retrain |
| fdi_pl_idle | **fdi_pl_idle** | Input | 1 | Idle指示 | 链路空闲 |
| fdi_pl_error | **fdi_pl_error** | Input | 1 | 错误指示 | 物理层错误 |
| fdi_pl_flit_cancel | **fdi_pl_flit_cancel** | Input | 1 | Flit取消指示 | 丢弃接收Flit |

#### 3.2.5 Rx_active_req/Sts握手接口

| 信号名 | FDI标准名 | 方向 | 位宽 | 描述 | RTL实现要求 |
|--------|-----------|------|------|------|-------------|
| fdi_pl_rx_active_req | **fdi_pl_rx_active_req** | Input | 1 | Adapter请求接收通道激活 | 与lclk同步，禁止组合环路 |
| fdi_lp_rx_active_sts | **fdi_lp_rx_active_sts** | Output | 1 | 接收通道就绪状态 | 在fdi_pl_rx_active_req之后断言，至少隔1周期 |

#### 3.2.6 内部输出接口

| 信号名 | 方向 | 位宽 | 描述 | RTL实现要求 |
|--------|------|------|------|-------------|
| rx_valid_out | Output | 1 | 输出数据有效指示 | 寄存器输出 |
| rx_data_out | Output | [FDI_DATA_WIDTH] | 输出数据载荷 | 寄存器输出 |
| rx_ready | Input | 1 | 数据请求信号 | 下游反馈 |

### 3.3 协议规范 / Protocol Specifications

**参考协议文档：**
| 协议名称 | 版本 | 文档编号 | RTL实现要点 |
|----------|------|----------|-------------|
| UCIe Specification | Revision 3.0 | UCIe 3.0 | FDI接口时序 |

---

## 4. 时钟与复位 / Clocks and Resets

### 4.1 时钟域 / Clock Domains

| 时钟名称 | 频率 | 描述 | RTL实现要求 |
|----------|------|------|-------------|
| fdi_lclk | 1.5 GHz (1.5) | FDI侧链路时钟 | 所有时序逻辑使用上升沿 |

### 4.2 跨时钟域 / Clock Domain Crossings (CDC)

本模块为单时钟域模块(fdi_lclk)，不涉及内部CDC。
跨时钟域处理在`rx_path`模块完成。

### 4.3 复位域 / Reset Domains

| 复位名称 | 有效电平 | 类型 | 作用范围 | RTL实现要求 |
|----------|----------|------|----------|-------------|
| fdi_rst_n | Low | 全局 | 本模块 | 异步断言，同步释放 |

---

## 5. 功能描述 / Functional Description

### 5.1 功能概述 / Functional Overview

FDI RX Interface模块的核心功能是实现UCIe FDI协议到Bridge内部数据通路的数据接收，严格遵循FDI的Ready/Valid握手机制和链路状态管理要求。

**核心功能模块RTL说明：**

#### 数据接收与解析单元 (Data Receive & Parse Unit)
- **模块名称**: Data Receive & Parse Unit
- **RTL职责**：接收并解析FDI数据，检测Flit取消
- **输入处理**：采样fdi_pl_valid和fdi_pl_flit
- **核心逻辑**：
  ```systemverilog
  // 数据接收
  always_ff @(posedge fdi_lclk or negedge fdi_rst_n) begin
    if (!fdi_rst_n) begin
      rx_data_reg <= '0;
      rx_valid_reg <= 1'b0;
    end else begin
      if (fdi_pl_valid && fdi_pl_trdy && !fdi_pl_flit_cancel) begin
        rx_data_reg <= fdi_pl_flit;
        rx_valid_reg <= 1'b1;
      end else if (rx_ready) begin
        rx_valid_reg <= 1'b0;
      end
    end
  end
  
  // Flit Cancel检测
  always_ff @(posedge fdi_lclk or negedge fdi_rst_n) begin
    if (!fdi_rst_n) begin
      flit_cancel_pending <= 1'b0;
    end else begin
      if (fdi_pl_valid && fdi_pl_flit_cancel) begin
        flit_cancel_pending <= 1'b1;
      end else begin
        flit_cancel_pending <= 1'b0;
      end
    end
  end
  ```

#### 流控生成单元 (Flow Control Generation Unit)
- **模块名称**: Flow Control Generation Unit
- **RTL职责**：生成Ready信号，响应下游背压
- **数据处理**：
  ```systemverilog
  // Ready生成 - 可提前断言
  // rx_ready来自下游(rx_path)，本模块只消费该输入，不驱动它
  assign fdi_pl_trdy = rx_ready && receive_enable && !flit_cancel_pending;
  ```

#### 链路状态响应单元 (Link Status Response Unit)
- **模块名称**: Link Status Response Unit
- **RTL职责**：响应物理层链路状态变化
- **状态处理**：
  ```systemverilog
  // 链路状态检测
  assign link_active = (fdi_pl_state_sts == 4'b0010);  // Active
  assign link_idle = fdi_pl_idle;
  assign link_error = fdi_pl_error;
  
  // 错误时停止接收
  always_ff @(posedge fdi_lclk or negedge fdi_rst_n) begin
    if (!fdi_rst_n) begin
      receive_enable <= 1'b1;
    end else begin
      receive_enable <= !link_error;
    end
  end
  ```

#### DLLP接收单元 (DLLP Receive Unit)
- **模块名称**: DLLP Receive Unit
- **RTL职责**：接收和处理DLLP
- **数据处理**：
  - 独立采样DLLP
  - 解析链路管理信息

### 5.2 状态机 / State Machines

#### 5.2.1 接收状态机

**状态定义（RTL编码方案）：**
| 状态 | 编码 | 描述 | RTL退出条件 |
|------|------|------|-------------|
| IDLE | 2'b00 | 链路未就绪 | `fdi_pl_state_sts==4'b0010` 且 `fdi_pl_error==0` |
| READY | 2'b01 | 链路就绪，等待数据 | `fdi_pl_valid && fdi_pl_trdy` |
| RECEIVE | 2'b10 | 接收数据 | `rx_valid_reg && rx_ready`，或 `fdi_pl_flit_cancel==1` |
| PAUSE | 2'b11 | 暂停(链路错误或非Active) | `fdi_pl_error==0 && fdi_pl_state_sts==4'b0010` |

**判定信号映射：**
- `link_up` → `fdi_pl_state_sts==4'b0010`
- `valid && ready` → `fdi_pl_valid && fdi_pl_trdy`
- `数据完成` → `rx_valid_reg && rx_ready`
- `error_clear` → `fdi_pl_error==0 && fdi_pl_state_sts==4'b0010`

### 5.3 典型事务流程 / Example Transactions

#### 基本数据接收流程
```
fdi_lclk:         __|‾‾‾‾|__|‾‾‾‾|__|‾‾‾‾|__|‾‾‾‾|__|‾‾‾‾|__
fdi_pl_valid:    ____|‾‾‾‾|___________________
fdi_pl_flit:     ----< DATA1 >---------------
fdi_pl_trdy:     _________|‾‾‾‾|_____________
rx_valid_out:    __________________|‾‾‾‾|___________________
rx_data_out:     -------------------< DATA1 >--------------
```

#### Flit Cancel处理流程
```
fdi_pl_valid:    ____|‾‾‾‾|___________________
fdi_pl_flit:     ----< DATA1 >---------------
fdi_pl_flit_cancel: ___|‾‾|___________________  // CRC错误
rx_valid_out:    _____________________________  // 丢弃，不输出
```

### 5.4 错误处理 / Error Handling

#### 错误类型（RTL检测）

| 错误代码 | 错误名称 | 描述 | RTL检测方式 |
|----------|----------|------|-------------|
| [4] | ERR_LINK_DOWN | 链路断开 | 状态检测 |
| [1] | ERR_FDI_CRC | FDI CRC错误/Flit取消 | fdi_pl_error或flit_cancel检测 |

---

## 6. 配置寄存器 / Configuration Registers (CSRs)

本模块不定义独立CSR。所有寄存器由`regs`模块统一管理，地址与字段见：
- `docs/specification/ucie_cxs_fdi_arch_spec.md`
- `docs/specification/regs_spec.md`

**与本模块相关的全局寄存器/字段：**
- `STATUS.RX_READY`、`STATUS.LINK_STATE`
- `ERR_STATUS.ERR_LINK_DOWN`、`ERR_STATUS.ERR_FDI_CRC`
- `RX_FLIT_CNT_L/H`（接收Flit计数）

---

## 7. 性能规格 / Performance Specifications

### 7.1 性能指标 / Performance Metrics

| 指标 | 目标值 | 单位 | RTL实现约束 |
|------|--------|------|-------------|
| 峰值吞吐量 | 96 | GB/s | 512b × 1.5GHz |
| 持续吞吐量 | 96 | GB/s | 每周期一个Flit |
| Ready响应延迟 | 1 | 时钟周期 | Ready生成延迟 |
| 接收延迟 | 1 | 时钟周期 | Valid到采样延迟 |

---

## 9. 验证与调试 / Verification and Debug

### 9.1 验证策略

| 方法 | 覆盖率目标 | RTL验证要点 |
|------|------------|-------------|
| 随机验证 | > 95% | Valid/Ready组合 |
| 定向测试 | 100% | 边界条件 |
| Flit Cancel测试 | 100% | 错误处理 |
| 链路状态测试 | 100% | 状态响应 |

---

**文档结束**

**相关文档：**
- 架构规格：`docs/specification/ucie_cxs_fdi_arch_spec.md`
- CXS TX接口规格：`docs/specification/cxs_tx_if_spec.md`
- CXS RX接口规格：`docs/specification/cxs_rx_if_spec.md`
- FDI TX接口规格：`docs/specification/fdi_tx_if_spec.md`
- 编码规范：`docs/coding_standards/coding_guide.md`
