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

**实现边界说明：**
- 本项目不在LME层复刻协议原生的完整sideband信号全集
- LME模块对外采用**归一化消息通道**建模sideband交互，便于RTL实现与testbench验证
- 归一化消息通道仅用于本项目Bridge内部规格，不替代协议原始文档

**模块在系统中的位置：**
```
+-----------------------------+   +-----------------------------+   +-----------------------------+
| CXS Normalized Sideband    |   | LME Handler                 |   | FDI Normalized Sideband    |
| (cxs_clk domain)           |-->| (link management exchange)  |-->| (fdi_lclk domain)          |
|                             |   |                             |   |                             |
| cxs_sb_rx_*  -------------> |   | cxs_rx_if / tx_if          |   | fdi_sb_tx_*  ------------> |
| cxs_sb_tx_*  <------------- |   | LME Core (cxs_clk)         |   | fdi_sb_rx_*  <------------ |
|                             |   | async msg CDC FIFOs        |   |                             |
+-----------------------------+   +-----------------------------+   +-----------------------------+
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
│   │                    CXS归一化消息接口 (cxs_clk)                          │   │
│   │  cxs_sb_rx_valid/data  ───────────────────────────────────────────►     │   │
│   │  cxs_sb_rx_ready       ◄──────────────────────────────────────────      │   │
│   │  cxs_sb_tx_valid/data  ◄──────────────────────────────────────────      │   │
│   │  cxs_sb_tx_ready       ───────────────────────────────────────────►     │   │
│   └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                              │                                           │
│                                              ▼                                           │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │                         LME核心逻辑 (cxs_clk域)                               │   │
│   │         ┌─────────────────────────────────────────────────────────────┐        │   │
│   │         │   参数解析/比较 (Parameter Parser & Compare)               │        │   │
│   │         │   协商状态机 (Negotiation FSM)                            │        │   │
│   │         │   激活状态机 (Activation FSM)                             │        │   │
│   │         │   协商结果寄存 (Negotiated Parameter Registers)           │        │   │
│   │         └─────────────────────────────────────────────────────────────┘        │   │
│   └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                              │                                           │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │                    异步消息CDC (cxs_clk <-> fdi_lclk)                  │   │
│   │  cxs_to_fdi_msg_fifo / fdi_to_cxs_msg_fifo                            │   │
│   └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                              │                                           │
│                                              ▼                                           │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │                    FDI归一化消息接口 (fdi_lclk)                         │   │
│   │  fdi_sb_rx_valid/data  ───────────────────────────────────────────►     │   │
│   │  fdi_sb_rx_ready       ◄──────────────────────────────────────────      │   │
│   │  fdi_sb_tx_valid/data  ◄──────────────────────────────────────────      │   │
│   │  fdi_sb_tx_ready       ───────────────────────────────────────────►     │   │
│   └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                          │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │                       配置与协商结果接口 (cxs_clk)                         │   │
│   │  lme_enable / local_*       ───────────────────────────────────────►      │   │
│   │  neg_* / lme_init_done      ◄──────────────────────────────────────       │   │
│   │  lme_active / lme_error     ◄──────────────────────────────────────       │   │
│   │  lme_timeout / lme_intr     ◄──────────────────────────────────────       │   │
│   └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                          │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

**子模块列表：**
| 模块名称 | 功能描述 | 关键接口 | 时钟域 | RTL实现要点 |
|----------|----------|----------|--------|-------------|
| CXS Normalized SB IF | CXS归一化消息接口 | `cxs_sb_rx_*`, `cxs_sb_tx_*` | cxs_clk | 握手接入/发出 |
| FDI Normalized SB IF | FDI归一化消息接口 | `fdi_sb_rx_*`, `fdi_sb_tx_*` | fdi_lclk | 握手接入/发出 |
| Async Message CDC | 跨域消息缓冲 | 双向消息FIFO | cxs_clk/fdi_lclk | 异步FIFO，消息保序 |
| LME Core Logic | 参数协商与激活控制 | 参数/状态/消息 | cxs_clk | 状态机、超时、结果寄存 |

### 2.2 数据流 / Data Flow

**主数据通路：**
```
CXS归一化消息 ──▶ CXS SB IF ──▶ cxs_to_fdi_msg_fifo ──▶ FDI SB IF ──▶ FDI归一化消息
FDI归一化消息 ──▶ FDI SB IF ──▶ fdi_to_cxs_msg_fifo ──▶ LME Core   ──▶ 协商/激活决策
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
├── lme_cxs_sb_if (CXS归一化消息接口单元)
│   ├── cxs_rx_accept (接收握手) - **实现关键**: valid/ready
│   ├── cxs_tx_issue (发送握手) - **实现关键**: valid保持
│   └── cxs_msg_reg (消息寄存) - **实现关键**: 消息稳定性
├── lme_fdi_sb_if (FDI归一化消息接口单元)
│   ├── fdi_rx_accept (接收握手) - **实现关键**: valid/ready
│   ├── fdi_tx_issue (发送握手) - **实现关键**: valid保持
│   └── fdi_msg_reg (消息寄存) - **实现关键**: 消息稳定性
├── lme_msg_cdc (消息跨域单元)
│   ├── cxs_to_fdi_fifo (CXS->FDI消息FIFO) - **实现关键**: 保序跨域
│   └── fdi_to_cxs_fifo (FDI->CXS消息FIFO) - **实现关键**: 保序跨域
├── lme_param_parser (参数解析单元)
│   ├── param_decode (参数解码) - **实现关键**: 协议解析
│   ├── param_validate (参数验证) - **实现关键**: 有效性检查
│   └── param_store (参数存储) - **实现关键**: 配置寄存器
├── lme_param_negotiator (参数协商单元)
│   ├── neg_state (协商状态) - **实现关键**: 握手状态机
│   ├── param_compare (参数比较) - **实现关键**: 能力匹配
│   └── neg_result (协商结果) - **实现关键**: 决策逻辑
└── lme_link_fsm (链路状态机单元)
    ├── fsm_state (状态) - **实现关键**: 状态转移
    ├── timeout_counter (超时计数) - **实现关键**: 超时判定
    └── active_ctrl (激活控制) - **实现关键**: ACTIVE_REQ/ACK流程
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
| CXS边带RX | cxs_sb_rx_valid | Input | 1 | CXS SB | cxs_clk | 来自CXS侧的消息有效 |
| CXS边带RX | cxs_sb_rx_data | Input | [SB_MSG_WIDTH] | CXS SB | cxs_clk | 来自CXS侧的消息数据 |
| CXS边带RX | cxs_sb_rx_ready | Output | 1 | CXS SB | cxs_clk | 对CXS侧的消息接收就绪 |
| CXS边带TX | cxs_sb_tx_valid | Output | 1 | CXS SB | cxs_clk | 发往CXS侧的消息有效 |
| CXS边带TX | cxs_sb_tx_data | Output | [SB_MSG_WIDTH] | CXS SB | cxs_clk | 发往CXS侧的消息数据 |
| CXS边带TX | cxs_sb_tx_ready | Input | 1 | CXS SB | cxs_clk | CXS侧接收就绪 |
| FDI边带RX | fdi_sb_rx_valid | Input | 1 | FDI SB | fdi_lclk | 来自FDI侧的消息有效 |
| FDI边带RX | fdi_sb_rx_data | Input | [SB_MSG_WIDTH] | FDI SB | fdi_lclk | 来自FDI侧的消息数据 |
| FDI边带RX | fdi_sb_rx_ready | Output | 1 | FDI SB | fdi_lclk | 对FDI侧的消息接收就绪 |
| FDI边带TX | fdi_sb_tx_valid | Output | 1 | FDI SB | fdi_lclk | 发往FDI侧的消息有效 |
| FDI边带TX | fdi_sb_tx_data | Output | [SB_MSG_WIDTH] | FDI SB | fdi_lclk | 发往FDI侧的消息数据 |
| FDI边带TX | fdi_sb_tx_ready | Input | 1 | FDI SB | fdi_lclk | FDI侧接收就绪 |
| 配置接口 | lme_enable | Input | 1 | 内部 | cxs_clk | LME模块使能 |
| 配置接口 | local_flit_width_sel | Input | [3:0] | 内部 | cxs_clk | 本地Flit宽度能力 |
| 配置接口 | local_max_credit | Input | [7:0] | 内部 | cxs_clk | 本地最大Credit能力 |
| 配置接口 | local_fifo_depth | Input | [7:0] | 内部 | cxs_clk | 本地FIFO深度能力 |
| 配置接口 | local_timeout | Input | [7:0] | 内部 | cxs_clk | 协商超时门限 |
| 状态输出 | neg_flit_width_sel | Output | [3:0] | 内部 | cxs_clk | 协商后Flit宽度 |
| 状态输出 | neg_max_credit | Output | [7:0] | 内部 | cxs_clk | 协商后最大Credit |
| 状态输出 | neg_fifo_depth | Output | [7:0] | 内部 | cxs_clk | 协商后FIFO深度 |
| 状态输出 | lme_init_done | Output | 1 | 内部 | cxs_clk | 协商完成 |
| 状态输出 | lme_active | Output | 1 | 内部 | cxs_clk | LME已进入监控态 |
| 状态输出 | lme_error | Output | 1 | 内部 | cxs_clk | LME错误状态 |
| 状态输出 | lme_timeout | Output | 1 | 内部 | cxs_clk | 协商超时指示 |
| 中断接口 | lme_intr | Output | 1 | 内部 | cxs_clk | 中断输出 |

### 3.2 详细接口定义 / Detailed Interface Specifications

#### 3.2.1 归一化边带消息接口

| 信号名 | 方向 | 位宽 | 描述 | RTL实现要求 |
|--------|------|------|------|-------------|
| cxs_sb_rx_valid | Input | 1 | CXS侧消息输入有效 | `valid && ready` 成功接收 |
| cxs_sb_rx_data | Input | [SB_MSG_WIDTH] | CXS侧消息输入数据 | 与`cxs_sb_rx_valid`同步 |
| cxs_sb_rx_ready | Output | 1 | CXS侧输入接收就绪 | 仅在接收FIFO非满时置高 |
| cxs_sb_tx_valid | Output | 1 | 发往CXS侧消息有效 | 保持到`cxs_sb_tx_ready`握手完成 |
| cxs_sb_tx_data | Output | [SB_MSG_WIDTH] | 发往CXS侧消息数据 | 与`cxs_sb_tx_valid`同步 |
| cxs_sb_tx_ready | Input | 1 | CXS侧输出接收就绪 | 高电平表示对端可接收 |
| fdi_sb_rx_valid | Input | 1 | FDI侧消息输入有效 | `valid && ready` 成功接收 |
| fdi_sb_rx_data | Input | [SB_MSG_WIDTH] | FDI侧消息输入数据 | 与`fdi_sb_rx_valid`同步 |
| fdi_sb_rx_ready | Output | 1 | FDI侧输入接收就绪 | 仅在接收FIFO非满时置高 |
| fdi_sb_tx_valid | Output | 1 | 发往FDI侧消息有效 | 保持到`fdi_sb_tx_ready`握手完成 |
| fdi_sb_tx_data | Output | [SB_MSG_WIDTH] | 发往FDI侧消息数据 | 与`fdi_sb_tx_valid`同步 |
| fdi_sb_tx_ready | Input | 1 | FDI侧输出接收就绪 | 高电平表示对端可接收 |

#### 3.2.2 归一化消息格式

**参数：**
- `SB_MSG_WIDTH = 32`

**消息编码：**
| 位域 | 名称 | 描述 |
|------|------|------|
| [31:28] | OPCODE | 消息类型 |
| [27:24] | TAG | 事务标签，单次协商固定为0 |
| [23:16] | ARG0 | 参数0 |
| [15:8] | ARG1 | 参数1 |
| [7:0] | ARG2 | 参数2/状态码 |

**OPCODE定义：**
| 值 | 名称 | 描述 |
|----|------|------|
| 4'h1 | PARAM_REQ | 参数请求 |
| 4'h2 | PARAM_RSP | 参数响应 |
| 4'h3 | PARAM_ACCEPT | 参数接受 |
| 4'h4 | PARAM_REJECT | 参数拒绝 |
| 4'h5 | ACTIVE_REQ | 链路激活请求 |
| 4'h6 | ACTIVE_ACK | 链路激活确认 |
| 4'h7 | DEACT_HINT | 链路停用提示 |
| 4'h8 | ERROR_MSG | 错误上报 |

**参数负载定义：**
- `ARG0`: `FLIT_WIDTH_SEL`
- `ARG1`: `MAX_CREDIT`
- `ARG2`: `FIFO_DEPTH`

**消息合法性与方向约束：**
| OPCODE | 合法发起方 | 合法响应方 | TAG要求 | 备注 |
|--------|------------|------------|---------|------|
| `PARAM_REQ` | 本地LME或对端LME | 对端LME | 固定为0 | 协商开始消息 |
| `PARAM_RSP` | 收到`PARAM_REQ`的一侧 | 发起`PARAM_REQ`的一侧 | 必须与请求一致 | 仅允许响应最近一次未完成请求 |
| `PARAM_ACCEPT` | 完成参数比较的一侧 | 对端LME | 必须与被接受事务一致 | 表示协商通过 |
| `PARAM_REJECT` | 任一检测到不兼容的一侧 | 对端LME | 必须与被拒绝事务一致 | 收到后进入错误流 |
| `ACTIVE_REQ` | 协商完成的一侧 | 对端LME | 固定为0 | 不允许早于`PARAM_ACCEPT` |
| `ACTIVE_ACK` | 收到`ACTIVE_REQ`的一侧 | 发起`ACTIVE_REQ`的一侧 | 固定为0 | 不允许重复应答 |
| `DEACT_HINT` | 任一已进入MONITOR的一侧 | 对端LME | 固定为0 | 仅MONITOR态合法 |
| `ERROR_MSG` | 任一检测到协议违例的一侧 | 对端LME | 固定为0 | 发出后本地进入`ERROR` |

**非法序列处理规则：**
- 在 `NEGOTIATE` 前收到 `ACTIVE_REQ/ACTIVE_ACK` 视为 `ERR_CXS_PROTO`
- 同一事务收到重复 `PARAM_RSP` 或重复 `ACTIVE_ACK` 视为 `ERR_CXS_PROTO`
- 未知 `OPCODE`、非0 `TAG` 或字段超出本地支持范围时，置 `ERR_CXS_PROTO`
- 收到 `PARAM_REJECT` 或本地比较失败时，进入 `ERROR`，并可选发送 `ERROR_MSG`

#### 3.2.3 配置和状态接口

| 信号名 | 方向 | 位宽 | 描述 | RTL实现要求 |
|--------|------|------|------|-------------|
| lme_enable | Input | 1 | LME使能 | 低时保持IDLE |
| local_flit_width_sel | Input | [3:0] | 本地Flit宽度能力 | 参与参数协商 |
| local_max_credit | Input | [7:0] | 本地最大Credit能力 | 参与参数协商 |
| local_fifo_depth | Input | [7:0] | 本地FIFO深度能力 | 参与参数协商 |
| local_timeout | Input | [7:0] | 协商超时门限 | 驱动超时计数器 |
| neg_flit_width_sel | Output | [3:0] | 协商结果Flit宽度 | 在`lme_init_done`后有效 |
| neg_max_credit | Output | [7:0] | 协商结果最大Credit | 在`lme_init_done`后有效 |
| neg_fifo_depth | Output | [7:0] | 协商结果FIFO深度 | 在`lme_init_done`后有效 |
| lme_init_done | Output | 1 | 初始化完成 | 进入ACTIVE/MONITOR后置高 |
| lme_active | Output | 1 | LME工作中 | MONITOR态置高 |
| lme_error | Output | 1 | LME错误状态 | ERROR态置高 |
| lme_timeout | Output | 1 | 协商超时 | 超时后保持到复位 |
| lme_intr | Output | 1 | 中断信号 | `lme_error || lme_timeout` |

---

## 4. 时钟与复位 / Clocks and Resets

### 4.1 时钟域 / Clock Domains

| 时钟名称 | 频率 | 描述 | RTL实现要求 |
|----------|------|------|-------------|
| cxs_clk | 1.5 GHz | CXS侧时钟 | 边带接口时钟 |
| fdi_lclk | 1.5 GHz | FDI侧时钟 | 边带接口时钟 |

### 4.2 跨时钟域 / Clock Domain Crossings (CDC)

| 源时钟 | 目标时钟 | 信号类型 | 同步方式 | RTL实现 |
|--------|----------|----------|----------|---------|
| cxs_clk | fdi_lclk | 归一化边带消息 | 异步FIFO | 握手缓冲 |
| fdi_lclk | cxs_clk | 归一化边带消息 | 异步FIFO | 握手缓冲 |
| fdi_lclk | cxs_clk | 状态信号 | 2级同步器 | 状态同步 |

**CDC约束补充：**
- 消息通道只允许通过异步FIFO跨域，不允许组合路径直通
- `lme_enable`、本地能力配置和状态输出统一在`cxs_clk`域管理
- FDI侧接收的消息需先进入CDC FIFO，再由`cxs_clk`域LME Core统一处理

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
- **RTL职责**：接收/发送归一化CXS边带消息
- **数据处理**：
  ```systemverilog
  // 边带握手
  assign cxs_sb_rx_ready = !cxs_sb_busy;
  assign cxs_sb_valid_strobe = cxs_sb_rx_valid && cxs_sb_rx_ready;
  
  // 数据解析
  always_ff @(posedge cxs_clk or negedge cxs_rst_n) begin
    if (cxs_sb_valid_strobe) begin
      cxs_sb_msg <= cxs_sb_rx_data;
    end
  end
  ```

#### FDI边带接口单元 (FDI SB Interface Unit)
- **模块名称**: FDI Sideband Interface Unit
- **RTL职责**：接收/发送归一化FDI边带消息
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
    NEG_SEND_REQ  = 3'b001,
    NEG_WAIT_RSP  = 3'b010,
    NEG_SEND_ACC  = 3'b011,
    NEG_WAIT_ACK  = 3'b100,
    NEG_COMPLETE  = 3'b101
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
| IDLE | 000 | 初始状态 | `lme_enable==1` |
| INIT | 001 | 装载本地能力并清空历史状态 | 初始化完成 |
| NEGOTIATE | 010 | 发送`PARAM_REQ`并等待`PARAM_RSP` | 参数协商完成/失败/超时 |
| ACTIVE | 011 | 发送`ACTIVE_REQ`并等待`ACTIVE_ACK` | 激活成功/超时 |
| MONITOR | 100 | 链路监控 | 收到`DEACT_HINT`或错误 |
| ERROR | 101 | 错误状态 | 复位或重新使能 |

**关键转移规则：**
- `IDLE -> INIT`：`lme_enable=1`
- `INIT -> NEGOTIATE`：本地能力寄存完成
- `NEGOTIATE -> ACTIVE`：收到合法`PARAM_RSP`且比较结果通过，已发送`PARAM_ACCEPT`
- `NEGOTIATE -> ERROR`：收到`PARAM_REJECT`、参数非法或超时
- `ACTIVE -> MONITOR`：收到`ACTIVE_ACK`
- `ACTIVE -> ERROR`：超时或收到`ERROR_MSG`
- `MONITOR -> ERROR`：状态不一致、边带协议违例或超时

### 5.3 典型事务流程 / Example Transactions

#### 链路初始化流程
```
时间 ──────────────────────────────────────────────────────▶

CXS_SB_TX:  [PARAM_REQ]──────────────▶
FDI_SB_RX:                 ◀────────[PARAM_RSP]
CXS_SB_TX:  [PARAM_ACCEPT]──────────▶
CXS_SB_TX:  [ACTIVE_REQ]────────────▶
FDI_SB_RX:                 ◀────────[ACTIVE_ACK]
LME:        IDLE→INIT→NEGOTIATE→ACTIVE→MONITOR
```

#### 参数不兼容流程
```
时间 ──────────────────────────────────────────────────────▶

CXS_SB_TX:  [PARAM_REQ]──────────────▶
FDI_SB_RX:                 ◀────────[PARAM_RSP(invalid)]
CXS_SB_TX:  [PARAM_REJECT]──────────▶
LME:        IDLE→INIT→NEGOTIATE→ERROR
```

### 5.4 错误处理 / Error Handling

#### 错误类型（RTL检测）

| 错误代码 | 错误名称 | 描述 | RTL检测方式 |
|----------|----------|------|-------------|
| [5] | ERR_LINK_TIMEOUT | 协商超时 | 计数器超时 |
| [0] | ERR_CXS_PROTO | 协商失败/参数无效/状态不一致 | 参数验证/同步检测 |

**错误触发条件补充：**
- `ERR_LINK_TIMEOUT`：`NEGOTIATE`或`ACTIVE`状态下等待响应超过`local_timeout`
- `ERR_CXS_PROTO`：收到未知`OPCODE`、消息字段非法、重复`ACTIVE_ACK`、未完成协商即进入激活流程

---

## 6. 配置寄存器 / Configuration Registers (CSRs)

本模块不定义独立CSR。所有寄存器由`regs`模块统一管理，地址与字段见：
- `docs/specification/ucie_cxs_fdi_arch_spec.md`
- `docs/specification/regs_spec.md`

**与本模块相关的全局寄存器/字段：**
- `CTRL.FLIT_WIDTH`
- `ERR_STATUS.ERR_LINK_TIMEOUT`、`ERR_STATUS.ERR_CXS_PROTO`

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

### 9.2 关键测试点

| 测试点 | 预期结果 |
|--------|----------|
| `lme_enable` 拉高 | `IDLE -> INIT -> NEGOTIATE` |
| 正常协商流程 | 收到 `PARAM_RSP` 后生成 `PARAM_ACCEPT`，进入 `ACTIVE/MONITOR` |
| 参数不兼容 | 发送/接收 `PARAM_REJECT`，进入 `ERROR` |
| `ACTIVE_REQ/ACTIVE_ACK` 正常握手 | `ACTIVE -> MONITOR` |
| `ACTIVE` 阶段超时 | 置 `lme_timeout`，进入 `ERROR` |
| 未知 `OPCODE` | 置 `ERR_CXS_PROTO`，进入 `ERROR` |
| 重复 `ACTIVE_ACK` | 置 `ERR_CXS_PROTO`，进入 `ERROR` |
| CDC背压 | 消息不丢失、不乱序、`valid` 保持到 `ready` |

### 9.3 推荐断言

- `cxs_sb_tx_valid && !cxs_sb_tx_ready |=> $stable(cxs_sb_tx_data)`
- `fdi_sb_tx_valid && !fdi_sb_tx_ready |=> $stable(fdi_sb_tx_data)`
- `lme_init_done |-> (neg_flit_width_sel != 4'b0000)`
- `lme_active |-> !lme_error`
- `lme_timeout |-> lme_intr`
- 在 `NEGOTIATE` 前不允许接受 `ACTIVE_REQ/ACTIVE_ACK`
- 任一 CDC FIFO 出口消息顺序必须与入口顺序一致

---

**文档结束**

**相关文档：**
- 架构规格：`docs/specification/ucie_cxs_fdi_arch_spec.md`
- CXS TX接口规格：`docs/specification/cxs_tx_if_spec.md`
- FDI TX接口规格：`docs/specification/fdi_tx_if_spec.md`
- 编码规范：`docs/coding_standards/coding_guide.md`
