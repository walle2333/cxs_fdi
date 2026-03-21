# FDI TX Interface模块设计规格书 (FDI TX Interface Module Design Specification)

**文档编号**: [MOD-FDI-TX-IF-001]  
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

本文档定义了FDI TX Interface模块的详细设计规格，作为RTL设计、验证和集成的唯一真实来源(One Source of Truth)。FDI TX Interface是UCIe CXS-FDI Bridge的FDI侧接口模块之一，负责接收来自内部TX Path Logic的数据，并将其转换为FDI协议格式发送给UCIe Adapter。

### 1.2 功能描述 / Functional Description

FDI TX Interface模块实现Bridge内部数据通路到UCIe FDI协议的接口功能，负责数据封装、Ready/Valid流控处理，并与UCIe Adapter完成握手交互。

**主要功能：**
- **数据发送**：将内部数据封装为FDI格式(fdi_lp_valid, fdi_lp_flit, fdi_lp_stream)发送给Adapter
- **流控处理**：检测fdi_lp_irdy信号，判断数据传输完成；发送许可由link_active/credit_ready门控
- **多流支持**：通过fdi_lp_stream信号标识不同的协议流
- **DLLP传输**：可选支持fdi_lp_dllp_valid和fdi_lp_dllp传输链路管理信息（`FDI_DLLP_WIDTH>0`时启用）
- **链路状态响应**：响应fdi_pl_state_sts状态变化，处理Retrain等链路状态

**模块在系统中的位置：**
```
+---------------------------+     +---------------------------+     +---------------------------+
|    TX Path Logic           |     |  FDI TX Interface         |     |  UCIe Adapter             |
| (TX Async FIFO)           |────▶│ (本模块 - FDI输出)        |────▶│ (Die-to-Die Interface)    |
|                          |     |                           |     |                           |
| tx_* signals ────────────│────▶│ fdi_lp_* outputs  ────────│────▶│ fdi_lp_irdy (Ready)       |
|                          |     | fdi_lp_valid ◄────────────│────▶│                          |
+---------------------------+     +---------------------------+     +---------------------------+
```

**目标应用场景：**
- 多芯片CPU/GPU互连扩展场景下的Die-to-Die数据发送
- 服务器SoC的UCIe物理层数据传输
- 高性能计算芯片间的物理层互联

### 1.3 目标与非目标 / Goals and Non-Goals

**目标 (Goals) - 必须实现：**
| 目标 | 描述 | 优先级 | RTL实现要求 |
|------|------|--------|-------------|
| FDI协议合规 | 完全遵循UCIe FDI接口规范 | P0 | 信号时序符合规范 |
| 高性能数据发送 | 支持256b/512b/1024b/2048b Flit宽度，满带宽传输 | P0 | Ready/Valid握手效率最大化 |
| 流控正确性 | 正确响应Ready信号，避免数据丢失 | P0 | 握手协议正确实现 |
| DLLP支持 | 支持DLLP传输 | P1 | 与Flit独立传输 |
| 链路状态处理 | 响应Retrain状态，暂停/恢复发送 | P1 | 状态机正确响应 |

**非目标 (Non-Goals) - 明确排除：**
- CXS协议处理：CXS侧接口处理由cxs_tx_if模块负责
- 数据缓冲功能：本模块仅做接口封装
- 协议解析：本模块不透传具体的协议内容
- FDI管理/功耗接口：不支持pl_clk_req/lp_clk_ack、lp_wake_req/pl_wake_ack、lp_state_req/lp_linkerror、pl_cfg/lp_cfg等
- FDI扩展错误/管理信号：不支持pl_cerror、pl_nferror、pl_trainerror、pl_stallreq/lp_stallack、pl_speedmode、pl_lnk_cfg等

### 1.4 关键指标 / Key Metrics

| 指标 | 目标值 | 单位 | 备注 | RTL实现影响 |
|------|--------|------|------|-------------|
| 工作频率 | 1.5 | GHz | 与FDI链路同步 | 时序约束 |
| 吞吐量 | 96 | GB/s | 512b × 1.5GHz | 数据通路需无气泡 |
| 握手延迟 | 1 | 时钟周期 | Ready响应延迟 | 组合逻辑输出 |
| 面积估算 | < 400 | 门数 | 逻辑面积 | 主要是输出逻辑 |
| 功耗估算 | < 25 | mW | 典型功耗 | 动态功耗 |

---

## 2. 架构设计 / Architecture Design

### 2.1 模块顶层框图 / Module Top-Level Block Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                              FDI TX Interface (fdi_tx_if)                               │
│                                                                                          │
│   ═══════════════════════════════════════════════════════════════════════════════════   │
│                              [Clock Domain: fdi_lclk]                                    │
│   ═══════════════════════════════════════════════════════════════════════════════════   │
│                                                                                          │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │                              来自TX Path Logic的输入                              │   │
│   │  tx_data_in[FDI_DATA_WIDTH-1:0]    ───────────────────────────────────────────────────►   │   │
│   │  tx_user_in[FDI_USER_WIDTH-1:0]     ───────────────────────────────────────────────►   │   │
│   │  tx_cntl_in           ───────────────────────────────────────────────────►   │   │
│   │  tx_last_in           ───────────────────────────────────────────────────►   │   │
│   │  tx_valid_in          ──────────────────────────────────────────────────►   │   │
│   │  tx_data_ack ◄─────────────────────────────────────────────────────────   │   │
│   └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                              │                                           │
│                                              ▼                                           │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │                              数据缓冲与流控单元 (Data Buffer & Flow Ctrl)        │   │
│   │         ┌─────────────────────────────────────────────────────────────┐        │   │
│   │         │   tx_data_reg: 发送数据寄存器                               │        │   │
│   │         │   tx_valid_reg: 数据有效标志                                │        │   │
│   │         │   ready_check: Ready状态检测                                │        │   │
│   │         └─────────────────────────────────────────────────────────────┘        │   │
│   └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                              │                                           │
│                                              ▼                                           │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │                              FDI输出接口 (发送到UCIe Adapter)                    │   │
│   │  fdi_lp_valid ◄───────────────────────────────────────────────────────   │   │
│   │  fdi_lp_flit[FDI_DATA_WIDTH-1:0] ◄────────────────────────────────────────────────   │   │
│   │  fdi_lp_stream ◄──────────────────────────────────────────────────────   │   │
│   │  fdi_lp_irdy ────────────────────────────────────────────────────────►   │   │
│   │  fdi_lp_dllp_valid ◄──────────────────────────────────────────────────   │   │
│   │  fdi_lp_dllp ◄────────────────────────────────────────────────────────   │   │
│   └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                              │                                           │
│   ┌─────────────────────────────────────────┴────────────────────────────────────────┐  │
│   │                              链路状态响应单元 (Link Status Response Unit)         │  │
│   │  fdi_pl_state_sts ──────────────────────────────────────────────────────►   │  │
│   │         ┌─────────────────────────────────────────────────────────────┐       │  │
│   │         │   IDLE/RUN/RETRAIN/AWAKE 状态检测                          │       │  │
│   │         │   数据发送控制                                              │       │  │
│   │         └─────────────────────────────────────────────────────────────┘       │  │
│   └─────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                          │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

**子模块列表：**
| 模块名称 | 功能描述 | 关键接口 | 时钟域 | RTL实现要点 |
|----------|----------|----------|--------|-------------|
| 数据缓冲与流控单元 | 接收并缓冲TX数据，控制发送时机 | tx_data_in, fdi_lp_valid | fdi_lclk | Ready检测，数据缓冲 |
| FDI输出封装单元 | 格式化FDI输出信号 | fdi_lp_flit, fdi_lp_valid | fdi_lclk | 协议格式封装 |
| 链路状态响应单元 | 响应链路状态变化 | fdi_pl_state_sts | fdi_lclk | 状态检测和控制 |
| DLLP处理单元 | 处理DLLP传输 | fdi_lp_dllp_valid, fdi_lp_dllp | fdi_lclk | DLLP生成/转发 |

### 2.2 数据流 / Data Flow

**主数据通路（RTL实现路径）：**
```
tx_valid_in      ──▶┐
tx_data_in       ──▶├── 数据缓冲与流控 ──▶ FDI输出封装 ──▶ fdi_lp_valid
tx_user_in       ──▶│  (Ready检测)       (协议格式)       fdi_lp_flit
tx_cntl_in       ──▶│                                        fdi_lp_stream
tx_last_in       ──▶┘                                        fdi_lp_dllp
                                              │
                                              ▼
                                     UCIe Adapter接收
```

**控制流：**
```
fdi_lp_irdy ──▶ Ready检测 ──▶ 数据发送许可
fdi_pl_state_sts ──▶ 链路状态响应 ──▶ 发送控制
```

### 2.3 子模块层次 / Submodule Hierarchy

```
fdi_tx_if (FDI TX Interface - 顶层模块)
├── fdi_tx_if_data_buffer (数据缓冲与流控单元)
│   ├── tx_data_reg (输入数据寄存) - **实现关键**: 握手缓冲
│   ├── tx_valid_reg (有效标志寄存) - **实现关键**: 状态保持
│   └── ready_check (Ready检测) - **实现关键**: 提前检测
├── fdi_tx_if_output_pack (FDI输出封装单元)
│   ├── flit_gen (Flit生成) - **实现关键**: 数据封装
│   ├── stream_enc (流ID编码) - **实现关键**: 多流支持
│   └── output_reg (输出寄存器) - **实现关键**: 稳定输出
├── fdi_tx_if_link_resp (链路状态响应单元)
│   ├── state_detect (状态检测) - **实现关键**: Retrain检测
│   └── flow_control (流控) - **实现关键**: 状态响应
└── fdi_tx_if_dllp (DLLP处理单元)
    ├── dllp_gen (DLLP生成) - **实现关键**: 链路管理
    └── dllp_mux (DLLP复用) - **实现关键**: 与Flit复用
```

---

## 3. 接口定义 / Interface Definitions

### 3.1 顶层接口汇总 / Top-Level Interface Summary

| 接口分类 | 接口名称 | 方向 | 位宽 | 协议 | 时钟域 | RTL实现要求 |
|----------|----------|------|------|------|--------|-------------|
| 时钟复位 | fdi_lclk | Input | 1 | - | - | 全局时钟，上升沿采样，1.5GHz |
| 时钟复位 | fdi_rst_n | Input | 1 | - | - | 低电平异步复位，同步释放 |
| 内部输入 | tx_valid_in | Input | 1 | 内部 | fdi_lclk | 来自TX Path Logic的数据有效 |
| 内部输入 | tx_data_in | Input | [FDI_DATA_WIDTH] | 内部 | fdi_lclk | 数据载荷 |
| 内部输入 | tx_user_in | Input | [FDI_USER_WIDTH] | 内部 | fdi_lclk | 用户定义位(可选) |
| 内部输入 | tx_cntl_in | Input | [CXS_CNTL_WIDTH] | 内部 | fdi_lclk | 控制字段 |
| 内部输入 | tx_last_in | Input | 1 | 内部 | fdi_lclk | 包边界指示 |
| 内部输入 | credit_ready | Input | 1 | 内部 | fdi_lclk | 发送许可(由credit_mgr经CDC/Link Ctrl提供) |
| 内部输出 | tx_data_ack | Output | 1 | 内部 | fdi_lclk | 数据接收确认 |
| FDI输出 | fdi_lp_valid | Output | 1 | FDI | fdi_lclk | 数据有效指示 |
| FDI输出 | fdi_lp_flit | Output | [FDI_DATA_WIDTH] | FDI | fdi_lclk | Flit数据 |
| FDI输出 | fdi_lp_stream | Output | [FDI_STREAM_WIDTH] | FDI | fdi_lclk | 流ID |
| FDI输入 | fdi_lp_irdy | Input | 1 | FDI | fdi_lclk | Ready信号 |
| FDI输出 | fdi_lp_dllp_valid | Output | 1 | FDI | fdi_lclk | DLLP有效(可选) |
| FDI输出 | fdi_lp_dllp | Output | [FDI_DLLP_WIDTH] | FDI | fdi_lclk | DLLP数据(可选) |
| 物理层输入 | fdi_pl_state_sts | Input | 4 | FDI | fdi_lclk | 链路状态 |

### 3.2 详细接口定义 / Detailed Interface Specifications

#### 3.2.1 FDI数据输出接口

基于 **UCIe Specification (Rev 3.0)** 的FDI接口定义：

| 信号名 | FDI标准名 | 方向 | 位宽 | 描述 | RTL实现要求 |
|--------|-----------|------|------|------|-------------|
| fdi_lp_valid | **fdi_lp_valid** | Output | 1 | Protocol Layer到Adapter的数据有效指示 | 与lclk上升沿同步，必须在数据有效前建立 |
| fdi_lp_flit | **fdi_lp_flit** | Output | [FDI_DATA_WIDTH] | Flit数据。支持256b/512b/1024b/2048b | 与fdi_lp_valid同步 |
| fdi_lp_stream | **fdi_lp_stream** | Output | [FDI_STREAM_WIDTH] | 流ID | 与fdi_lp_valid同步 |

**时序要求（RTL必须遵守）：**
- 数据传输条件：`fdi_lp_valid && fdi_lp_irdy` 同时高时数据传输
- fdi_lp_irdy可提前fdi_lp_valid最多2个周期断言（Adapter可提前准备）
- fdi_lp_valid 由本模块驱动，可受 credit_mgr 的 credit_ready 许可门控（经CDC/Link Ctrl同步）
- 系统参数约束：`FIFO_DEPTH >= 2×MAX_CREDIT`（由TX/RX Path与credit_mgr共同保证）

#### 3.2.2 FDI流控接口

| 信号名 | FDI标准名 | 方向 | 位宽 | 描述 | RTL实现要求 |
|--------|-----------|------|------|------|-------------|
| fdi_lp_irdy | **fdi_lp_irdy** | Input | 1 | Link Interface Ready | 可提前valid 2周期断言 |

#### 3.2.3 DLLP接口

| 信号名 | FDI标准名 | 方向 | 位宽 | 描述 | RTL实现要求 |
|--------|-----------|------|------|------|-------------|
| fdi_lp_dllp_valid | **fdi_lp_dllp_valid** | Output | 1 | DLLP有效指示(可选) | 可与Flit同时有效 |
| fdi_lp_dllp | **fdi_lp_dllp** | Output | [FDI_DLLP_WIDTH] | DLLP数据(可选) | 与valid同步 |

#### 3.2.4 物理层状态接口

| 信号名 | FDI标准名 | 方向 | 位宽 | 描述 | RTL实现要求 |
|--------|-----------|------|------|------|-------------|
| fdi_pl_state_sts | **fdi_pl_state_sts** | Input | 4 | Physical Layer链路状态 | 编码: 0000=Reset, 0001=LinkUp, 0010=Active, 0011=Retrain |

#### 3.2.5 内部控制接口

| 信号名 | 方向 | 位宽 | 描述 | RTL实现要求 |
|--------|------|------|------|-------------|
| credit_ready | Input | 1 | 发送许可(由credit_mgr提供) | 需与fdi_lclk同步，禁止组合环路 |

**链路状态响应：**
| 状态 | 编码 | 本模块动作 |
|------|------|-----------|
| Reset | 0000 | 停止所有传输，复位状态 |
| LinkUp | 0001 | 准备激活 |
| Active | 0010 | 正常数据传输 |
| Retrain | 0011 | 暂停发送，等待恢复 |

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

**时钟关系：**
- fdi_lclk与cxs_clk频率相同，相位独立
- 与cxs_clk的跨域处理由TX Async FIFO完成

### 4.2 跨时钟域 / Clock Domain Crossings (CDC)

本模块为单时钟域模块(fdi_lclk)。模块内部不执行CDC；
跨域信号（如`credit_ready`）需在模块边界前完成同步后再输入本模块。

### 4.3 复位域 / Reset Domains

| 复位名称 | 有效电平 | 类型 | 作用范围 | RTL实现要求 |
|----------|----------|------|----------|-------------|
| fdi_rst_n | Low | 全局 | 本模块 | 异步断言，同步释放 |

---

## 5. 功能描述 / Functional Description

### 5.1 功能概述 / Functional Overview

FDI TX Interface模块的核心功能是实现Bridge内部数据通路到UCIe FDI协议的数据传输，严格遵循FDI的Ready/Valid握手机制和链路状态管理要求。

**核心功能模块RTL说明：**

#### 数据缓冲与流控单元 (Data Buffer & Flow Control Unit)
- **模块名称**: Data Buffer & Flow Control Unit
- **RTL职责**：接收并缓冲TX数据，根据Ready状态控制发送时机
- **输入处理**：采样tx_valid_in和tx_data_in
- **核心逻辑**：
  ```systemverilog
  // 数据接收
  always_ff @(posedge fdi_lclk or negedge fdi_rst_n) begin
    if (!fdi_rst_n) begin
      tx_data_reg <= '0;
      tx_valid_reg <= 1'b0;
    end else begin
      if (tx_valid_in && tx_data_ack) begin
        tx_data_reg <= tx_data_in;
        tx_valid_reg <= 1'b1;
      end else if (fdi_lp_valid && fdi_lp_irdy) begin
        tx_valid_reg <= 1'b0;  // 数据发送后清除
      end
    end
  end
  
  // Ready检测和数据发送
  assign tx_data_ack = !tx_valid_reg || fdi_lp_irdy;
  assign fdi_lp_valid = tx_valid_reg && (fdi_pl_state_sts == 4'b0010) && credit_ready;
  assign fdi_lp_flit = tx_data_reg;
  ```
- **关键特性**：支持fdi_lp_irdy提前断言的握手优化

#### FDI输出封装单元 (FDI Output Packing Unit)
- **模块名称**: FDI Output Packing Unit
- **RTL职责**：将数据封装为FDI协议格式输出
- **数据处理**：
  - Flit格式组装
  - 流ID编码
  - 输出寄存器驱动

#### 链路状态响应单元 (Link Status Response Unit)
- **模块名称**: Link Status Response Unit
- **RTL职责**：响应物理层链路状态变化
- **状态处理**：
  ```systemverilog
  // 链路状态检测
  assign link_active = (fdi_pl_state_sts == 4'b0010);  // Active状态
  assign link_retrain = (fdi_pl_state_sts == 4'b0011);  // Retrain状态
  
  // Retrain时暂停发送
  always_ff @(posedge fdi_lclk or negedge fdi_rst_n) begin
    if (!fdi_rst_n) begin
      send_pause <= 1'b0;
    end else begin
      send_pause <= link_retrain;
    end
  end
  
  assign fdi_lp_valid = tx_valid_reg && !send_pause && credit_ready;
  ```

#### DLLP处理单元 (DLLP Processing Unit)
- **模块名称**: DLLP Processing Unit
- **RTL职责**：处理DLLP传输
- **数据处理**：
  - 生成DLLP用于链路管理
  - 复用Flit和DLLP传输

### 5.2 状态机 / State Machines

#### 5.2.1 发送状态机

**状态定义（RTL编码方案）：**
| 状态 | 编码 | 描述 | RTL退出条件 |
|------|------|------|-------------|
| IDLE | 2'b00 | 链路未激活 | `fdi_pl_state_sts==4'b0010` |
| READY | 2'b01 | 链路已激活，等待可发送数据 | `tx_valid_reg && credit_ready && fdi_lp_irdy` |
| SEND | 2'b10 | 正在发送数据 | `fdi_lp_valid && fdi_lp_irdy` 握手完成，或 `fdi_pl_state_sts==4'b0011` |
| PAUSE | 2'b11 | Retrain暂停发送 | `fdi_pl_state_sts!=4'b0011` |

**判定信号映射：**
- `link_up` → `fdi_pl_state_sts==4'b0010`
- `valid && ready` → `tx_valid_reg && credit_ready && fdi_lp_irdy`
- `retrain` → `fdi_pl_state_sts==4'b0011`
- `retrain_clear` → `fdi_pl_state_sts!=4'b0011`

### 5.3 典型事务流程 / Example Transactions

#### 基本数据发送流程
```
fdi_lclk:         __|‾‾‾‾|__|‾‾‾‾|__|‾‾‾‾|__|‾‾‾‾|__|‾‾‾‾|__
fdi_lp_irdy:      ____|‾‾‾‾|_________________________  // Ready提前断言
tx_valid_in:      ________________|‾‾‾‾|___________________
tx_data_in:       ------------------< DATA1 >---------------
fdi_lp_valid:    __________________|‾‾‾‾|___________________
fdi_lp_flit:      -------------------< DATA1 >--------------
```

#### Retrain处理流程
```
fdi_pl_state_sts:  ___0010___0011___0010___
                                    ↑Retrain ↑恢复
fdi_lp_valid:      ______|‾‾‾|___________|‾‾‾|___
                  发送    暂停       恢复发送
```

### 5.4 错误处理 / Error Handling

#### 错误类型（RTL检测）

| 错误代码 | 错误名称 | 描述 | RTL检测方式 |
|----------|----------|------|-------------|
| [4] | ERR_LINK_DOWN | 链路断开 | 状态检测 |
| [5] | ERR_LINK_TIMEOUT | 链路激活/恢复超时 | 计数器超时 |

---

## 6. 配置寄存器 / Configuration Registers (CSRs)

本模块不定义独立CSR。所有寄存器由`regs`模块统一管理，地址与字段见：
- `docs/specification/ucie_cxs_fdi_arch_spec.md`
- `docs/specification/regs_spec.md`

**与本模块相关的全局寄存器/字段：**
- `STATUS.LINK_STATE`、`STATUS.TX_READY`
- `ERR_STATUS.ERR_LINK_DOWN`、`ERR_STATUS.ERR_LINK_TIMEOUT`
- `TX_FLIT_CNT_L/H`（发送Flit计数）

---

## 7. 性能规格 / Performance Specifications

### 7.1 性能指标 / Performance Metrics

| 指标 | 目标值 | 单位 | RTL实现约束 |
|------|--------|------|-------------|
| 峰值吞吐量 | 96 | GB/s | 512b × 1.5GHz |
| 持续吞吐量 | 96 | GB/s | 每周期一个Flit |
| 握手效率 | > 95 | % | Ready响应效率 |
| 延迟 | 1 | 时钟周期 | 数据到valid延迟 |

---

## 9. 验证与调试 / Verification and Debug

### 9.1 验证策略

| 方法 | 覆盖率目标 | RTL验证要点 |
|------|------------|-------------|
| 随机验证 | > 95% | Ready/Valid组合 |
| 定向测试 | 100% | 边界条件 |
| 链路状态测试 | 100% | Retrain响应 |

---

**文档结束**

**相关文档：**
- 架构规格：`docs/specification/ucie_cxs_fdi_arch_spec.md`
- CXS TX接口规格：`docs/specification/cxs_tx_if_spec.md`
- CXS RX接口规格：`docs/specification/cxs_rx_if_spec.md`
- 编码规范：`docs/coding_standards/coding_guide.md`
