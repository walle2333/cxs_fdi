# CXS TX Interface模块设计规格书 (CXS TX Interface Module Design Specification)

**文档编号**: [MOD-CXS-TX-IF-001]  
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

本文档定义了CXS TX Interface模块的详细设计规格，作为RTL设计、验证和集成的唯一真实来源(One Source of Truth)。CXS TX Interface是UCIe CXS-FDI Bridge的核心接口模块之一，负责接收来自上层协议层(CHI Protocol Layer)的CXS格式数据，并将其传递给内部TX Path Logic进行后续处理。**重点描述模块如何实现**，为RTL编码提供明确指导。

### 1.2 功能描述 / Functional Description

CXS TX Interface模块实现CXS协议层到Bridge内部数据通路的协议接口功能，负责解析CXS信号、提取数据载荷，并与上游协议层完成握手交互。Credit管理由独立的credit_mgr模块负责，本模块不包含Credit授予/退还逻辑。

**主要功能：**
- **数据接收**：接收来自协议层的CXS格式数据(CXSDATA)，包括有效指示(CXSVALID)、数据载荷、控制字段(CXSCNTL)、用户定义位(CXSUSER)、包边界指示(CXSLAST)
- **链路状态交互**：处理链路激活请求(CXSACTIVEREQ)和停用提示(CXSDEACTHINT)，接收激活确认(CXSACTIVEACK)用于发送门控
- **错误标记透传**：接收并传递数据错误标记(ENDERROR，通过CXSCNTL)，用于RAS功能支持
- **ID路由支持**：解析源ID(CXSSRCID)和目标ID(CXSTGTID)用于多节点拓扑

**模块在系统中的位置：**
```
+---------------------------+     +---------------------------+     +---------------------------+
|    CHI Protocol Layer     |-----|  CXS TX Interface         |-----|  TX Path Logic            |
| (C2C Node Interface)      | CXS | (本模块 - Link Init)      |     | (TX Async FIFO)           |
|                          |     |                           |     |                           |
| cxs_tx_* signals ────────│────▶│ cxs_tx_* processing  ─────│────▶│                           |
|                          |     |                           │     |                           |
+---------------------------+     +---------------------------+     +---------------------------+
```

**目标应用场景：**
- 多芯片CPU/GPU互连扩展场景下的上行数据发送
- 服务器SoC的Die-to-Die通信中CXS协议数据注入
- 高性能计算芯片间的低延迟互连，协议层数据首发

### 1.3 目标与非目标 / Goals and Non-Goals

**目标 (Goals) - 必须实现：**
| 目标 | 描述 | 优先级 | RTL实现要求 |
|------|------|--------|-------------|
| CXS协议合规 | 完全遵循AMBA CXS Protocol Specification Issue D信号定义和时序要求 | P0 | 信号必须与CXS标准命名一致(CXSVALID→cxs_tx_valid)，时序满足协议要求 |
| 高性能数据接收 | 支持512位Flit宽度，每周期处理一个Flit，吞吐量达到满带宽 | P0 | 数据通路无流水线停顿，输入寄存器直接采样 |
| 链路状态机集成 | 正确响应链路激活/停用请求，状态转移符合规范 | P1 | 状态机与Link Control FSM无缝交互 |
| RAS支持 | 正确透传ENDERROR标记(通过CXSCNTL)和User bits，不丢失协议信息 | P1 | CXSCNTL寄存器，伴随数据一起传递 |

**非目标 (Non-Goals) - 明确排除：**
- 数据缓冲功能：本模块仅做接口解析，数据缓冲由TX Path Logic负责
- FDI协议处理：FDI侧接口处理由fdi_tx_if模块负责，本模块不涉及
- 协议层事务解析：本模块不透传具体的CHI事务内容，仅做链路层数据透传
- 复杂QoS调度：不做优先级调度

### 1.4 关键指标 / Key Metrics

| 指标 | 目标值 | 单位 | 备注 | RTL实现影响 |
|------|--------|------|------|-------------|
| 工作频率 | 2.0 | GHz | 与CXS接口同步 | 时序关键路径约束在单周期内 |
| 吞吐量 | 128 | GB/s | 512bit × 2.0GHz | 数据通路需无气泡 |
| 输入延迟 | 1 | 时钟周期 | valid到数据采样 | 输入寄存器采样 |
| 面积估算 | < 500 | 门数 | 逻辑面积 | 主要是输入寄存器 |
| 功耗估算 | < 30 | mW | 典型功耗 | 动态功耗为主 |

---

## 2. 架构设计 / Architecture Design

### 2.1 模块顶层框图 / Module Top-Level Block Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                              CXS TX Interface (cxs_tx_if)                               │
│                                                                                          │
│   ═══════════════════════════════════════════════════════════════════════════════════════════   │
│                              [Clock Domain: cxs_clk]                                     │
│   ═══════════════════════════════════════════════════════════════════════════════════════════   │
│                                                                                          │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │                              输入接口 (来自协议层)                                │   │
│   │  cxs_tx_valid    ──────┐                                                         │   │
│   │  cxs_tx_data[CXS_DATA_WIDTH-1:0] ───┼──►  ┌────────────────────────────────────────────┐    │   │
│   │  cxs_tx_user[CXS_USER_WIDTH-1:0] ────┤     │         输入采样单元                         │    │   │
│   │  cxs_tx_cntl ──────────┤     │  (cxs_tx_data_reg, cxs_tx_user_reg,        │    │   │
│   │  cxs_tx_last ──────────┤     │   cxs_tx_cntl_reg, cxs_tx_last_reg,        │    │   │
│   │  (可选: CXSUSER, CXSLAST)     │   cxs_tx_srcid_reg, cxs_tx_tgtid_reg)     │    │   │
│   │  cxs_tx_srcid/tgtid ───┘     │   注意: 错误标记通过CXSCNTL的ENDERROR位     │    │   │
│   └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                              │                                           │
│                                              ▼                                           │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │                              数据接收判定单元                                      │   │
│   │         ┌─────────────────────────────────────────────────────────────┐        │   │
│   │         │   cxs_tx_valid && tx_ready  →  data_accept                │        │   │
│   │         │   组合逻辑：计算当前周期是否接受数据                       │        │   │
│   │         └─────────────────────────────────────────────────────────────┘        │   │
│   └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                              │                                           │
│                                              ▼                                           │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │                              输出格式化单元                                      │   │
│   │  tx_data_out[CXS_DATA_WIDTH-1:0]   ────────────────────────────────────────────────────►   │   │
│   │  tx_user_out[CXS_USER_WIDTH-1:0]    ────────────────────────────────────────────────────►   │   │
│   │  tx_cntl_out          ────────────────────────────────────────────────────►   │   │
│   │  tx_last_out          ────────────────────────────────────────────────────►   │   │
│   │  (错误标记通过cntl_out的ENDERROR位传递)                                     │   │
│   │  tx_srcid_out/tgtid_out ────────────────────────────────────────────────►   │   │
│   │  tx_valid_out         ────────────────────────────────────────────────────►   │   │
│   │  tx_ready ◄──────────────────────────────────────────────────────────────   │   │
│   └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                              │                                           │
│   ┌─────────────────────────────────────────┴────────────────────────────────────────┐  │
│   │                              外部模块接口                                        │  │
│   │  cxs_tx_active_req ──────▶ CXS-FDI Link Ctrl (独立模块)                      │  │
│   │  cxs_tx_active ◄─────────                                                    │  │
│   │  cxs_tx_deact_hint ──────▶                                                  │  │
│   └─────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                          │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

**子模块列表：**
| 模块名称 | 功能描述 | 关键接口 | 时钟域 | RTL实现要点 |
|----------|----------|----------|--------|-------------|
| 输入采样单元 | 同步CXS输入信号 | cxs_tx_data, cxs_tx_user等 | cxs_clk | 上升沿采样，保持稳定 |
| 数据接收判定单元 | 判断当前周期是否可接受数据 | cxs_tx_valid, tx_ready | cxs_clk | 组合逻辑，时序关键 |
| 输出格式化单元 | 整理输出数据给TX Path | tx_data_out, tx_valid_out | cxs_clk | 流水线输出可选 |

### 2.2 数据流 / Data Flow

**主数据通路（RTL实现路径）：**
```
cxs_tx_valid    ──▶┐
cxs_tx_data     ──▶├── 输入寄存器 ──▶ 数据有效检测 ──▶ 输出格式化 ──▶ tx_valid_out
cxs_tx_user     ──▶│  (同步采样)     (组合逻辑)      (寄存器输出)     tx_data_out
cxs_tx_cntl     ──▶│
cxs_tx_last     ──▶│
cxs_tx_cntl   ──▶┘
cxs_tx_srcid    ──▶┐
cxs_tx_tgtid    ──▶┘     (伴随数据一起传递)
                                              │
                                              ▼
                                     TX Path Logic
```

**控制流（RTL状态机）：**
```
cxs_tx_active_req ──▶ cxs_fdi_link_ctrl模块 ──▶ cxs_tx_active (ACK)
                                          │
cxs_tx_deact_hint ──▶ (外部模块处理) ──▶ 停止数据发送
                                          │
```

**数据流详细描述（RTL设计指导）：**

1. **输入阶段**：
   - 所有cxs_tx_*输入信号在cxs_clk上升沿被采样到输入寄存器
   - 输入寄存器用于：同步外部信号、保持稳定供内部逻辑使用
   - CXSVALID高电平表示当前周期CXSDATA有效

2. **处理阶段**：
   - 数据有效检测逻辑组合逻辑判断：`data_accept = cxs_tx_valid && tx_ready`
- Credit管理由外部credit_mgr模块负责，本模块不包含Credit信号
- 链路状态处理由外部cxs_fdi_link_ctrl模块负责

3. **输出阶段**：
   - 输出数据经过格式化后送给TX Path Logic
   - tx_valid_out = data_accept (在下游就绪且协议层有数据时)
   - TX Path Logic通过tx_ready反馈流控状态

### 2.3 子模块层次 / Submodule Hierarchy

```
cxs_tx_if (CXS TX Interface - 顶层模块)
├── cxs_tx_if_input_sampling (输入采样单元)
│   ├── data_reg (cxs_tx_data采样) - **实现关键**: 上升沿采样，与valid同步
│   ├── user_reg (cxs_tx_user采样) - **实现关键**: 64位用户数据保持
│   ├── cntl_reg (cxs_tx_cntl采样) - **实现关键**: START/END/PTR字段解析
│   ├── last_reg (cxs_tx_last采样) - **实现关键**: 包边界标志
│   ├── cntl_reg (cxs_tx_cntl采样) - **实现关键**: START/END/ENDERROR字段解析
│   └── id_reg (cxs_tx_srcid/tgtid采样) - **实现关键**: 路由信息保持
├── cxs_tx_if_accept_detect (数据接收判定单元)
│   └── accept_comb (接受判断组合逻辑) - **实现关键**: 无组合逻辑冒险
└── cxs_tx_if_output_fmt (输出格式化单元)
    └── output_reg (输出寄存器) - **实现关键**: 稳定输出给下游
```

---

## 3. 接口定义 / Interface Definitions

### 3.1 顶层接口汇总 / Top-Level Interface Summary

| 接口分类 | 接口名称 | 方向 | 位宽 | 协议 | 时钟域 | RTL实现要求 |
|----------|----------|------|------|------|--------|-------------|
| 时钟复位 | cxs_clk | Input | 1 | - | - | 全局时钟，上升沿采样，2.0GHz |
| 时钟复位 | cxs_rst_n | Input | 1 | - | - | 低电平异步复位，同步释放 |
| CXS输入 | cxs_tx_valid | Input | 1 | CXS | cxs_clk | 协议层数据有效指示 |
| CXS输入 | cxs_tx_data | Input | [CXS_DATA_WIDTH] | CXS | cxs_clk | 数据载荷，与valid同步 |
| CXS输入 | cxs_tx_user | Input | [CXS_USER_WIDTH] | 可选 | CXS | cxs_clk | 用户定义位，位宽0-64可配置 |
| CXS输入 | cxs_tx_cntl | Input | [CXS_CNTL_WIDTH] | CXS | cxs_clk | 控制字段，包含START/END/ENDERROR |
| CXS输入 | cxs_tx_last | Input | 1 | 可选 | CXS | cxs_clk | 包边界指示 |
| CXS输入 | cxs_tx_srcid | Input | [CXS_SRCID_WIDTH] | 可选 | CXS | cxs_clk | 源ID |
| CXS输入 | cxs_tx_tgtid | Input | [CXS_TGTID_WIDTH] | 可选 | CXS | cxs_clk | 目标ID |
| 内部输出 | tx_srcid_out | Output | [CXS_SRCID_WIDTH] | 可选 | 内部 | cxs_clk | 源ID输出 |
| 内部输出 | tx_tgtid_out | Output | [CXS_TGTID_WIDTH] | 可选 | 内部 | cxs_clk | 目标ID输出 |
| 内部输入 | tx_ready | Input | 1 | 内部 | cxs_clk | 下游接收准备就绪 |

### 3.2 详细接口定义 / Detailed Interface Specifications

#### 3.2.1 CXS数据输入接口

基于 **AMBA CXS Protocol Specification, Issue D** 标准信号定义：

| 信号名 | CXS标准名 | 方向 | 位宽 | 描述 | RTL实现要求 |
|--------|-----------|------|------|------|-------------|
| cxs_tx_valid | **CXSVALID** | Input | 1 | 发送端Flit有效指示。高电平时表示CXSDATA有效 | 在clk上升沿采样，必须在数据有效前建立，保持到数据结束 |
| cxs_tx_data | **CXSDATA** | Input | [CXS_DATA_WIDTH] | 数据载荷。支持8-2048位，本设计默认512位 | 与CXSVALID同步，在CXSVALID高时采样 |
| cxs_tx_user | **CXSUSER** | Input | [CXS_USER_WIDTH] | 用户定义位。**可选信号**，用于传递协议层扩展信息。位宽0-64位可配置，0表示不包含 | 与CXSVALID同步采样 |
| cxs_tx_cntl | **CXSCNTL** | Input | [CXS_CNTL_WIDTH] | 控制字段。包含START[x:0]、END[x:0]、ENDERROR[x:0]、STARTxPTR、ENDxPTR等子字段。**ENDERROR位用于错误标记(替代独立POISON信号)** | 与CXSVALID同步，位宽根据CXS_DATA_WIDTH和CXS_MAX_PKT_PER_FLIT确定 |
| cxs_tx_last | **CXSLAST** | Input | 1 | 包边界指示。表示当前Flit后可插入其他协议数据，或表示包结束。**可选信号**，不存在时默认为高 | 与CXSVALID同步 |
| cxs_tx_srcid | **CXSSRCID** | Input | [CXS_SRCID_WIDTH] | 源ID标识。**可选信号**，用于多节点拓扑 | 与CXSVALID同步 |
| cxs_tx_tgtid | **CXSTGTID** | Input | [CXS_TGTID_WIDTH] | 目标ID标识。**可选信号**，用于路由 | 与CXSVALID同步 |

**错误标记说明**:
- CXS协议中错误标记不是独立的CXSPOISON信号
- 错误通过CXSCNTL字段中的ENDERROR位来实现
- ENDERROR[n]=1表示第n个在该周期结束的包有错误

**时序要求（RTL必须遵守）：**
- 数据握手：`cxs_tx_valid && tx_ready` 同时为高时数据传输
- 数据对齐：cxs_tx_data在cxs_tx_valid=1时保持稳定

#### 3.2.2 CXS链路控制接口

| 信号名 | CXS标准名 | 方向 | 位宽 | 描述 | RTL实现要求 |
|--------|-----------|------|------|------|-------------|
| cxs_tx_active_req | **CXSACTIVEREQ** | Input | 1 | 链路激活请求。协议层请求激活链路。触发链路激活流程 | 高电平有效，触发后保持直到被确认 |
| cxs_tx_active | **CXSACTIVEACK** | Input | 1 | 链路激活确认。表示TX路径已就绪可接收数据 | 高电平有效，来自Link Control FSM |
| cxs_tx_deact_hint | **CXSDEACTHINT** | Input | 1 | 链路停用提示。协议层建议停用链路。触发链路停用流程 | 高电平有效，建议性信号 |

**链路激活流程时序（RTL实现）：**
```
cxs_tx_active_req: ───┬────────────────────────────────────────
                      │
cxs_tx_active:        └───────────────────▄───────────────────
                                         │ (链路就绪)
cxs_tx_deact_hint: ──────────────────────────────────────┬──
                                                          │
cxs_tx_active: ───────────────────────────────────────────┘
                                                          │ (取消确认)
```

#### 3.2.4 CXS ID路由接口

| 信号名 | CXS标准名 | 方向 | 位宽 | 描述 | RTL实现要求 |
|--------|-----------|------|------|------|-------------|
| cxs_tx_srcid | **CXSSRCID** | Input | [CXS_SRCID_WIDTH] | 源ID标识。用于多节点拓扑，可配置宽度0-16位 | 与CXSVALID同步，可选信号 |
| cxs_tx_tgtid | **CXSTGTID** | Input | [CXS_TGTID_WIDTH] | 目标ID标识。用于路由，可配置宽度0-16位 | 与CXSVALID同步，可选信号 |
| tx_srcid_out | Output | [CXS_SRCID_WIDTH] | 可选 | 输出源ID | 寄存器输出 |
| tx_tgtid_out | Output | [CXS_TGTID_WIDTH] | 可选 | 输出目标ID | 寄存器输出 |
| tx_ready | Input | 1 | 下游接收确认 | TX Path Logic反馈 |

**输出握手时序（RTL实现）：**
```
cxs_clk:        __|‾‾‾‾|__|‾‾‾‾|__|‾‾‾‾|__|‾‾‾‾|__|‾‾‾‾|__
tx_valid_out:   ____|‾‾‾‾|___________________
tx_data_out:    ----< DATA1 >---------------
tx_ready: _________|‾‾‾‾|_____________
```

### 3.3 协议规范 / Protocol Specifications

**参考协议文档：**
| 协议名称 | 版本 | 文档编号 | RTL实现要点 |
|----------|------|----------|-------------|
| AMBA CXS Protocol Specification | Issue D | ARM IHI 0079 | CXSVALID时序与稳定性要求 |
| AMBA CHI Chip-to-Chip (C2C) Architecture Specification | Issue A | ARM IHI 0098 | 协议层约束 |
| UCIe Specification | Revision 3.0 | UCIe 3.0 | FDI接口映射 |

**自定义信号时序（CXS协议关键时序）：**
```
cxs_clk:           __|‾‾‾‾|__|‾‾‾‾|__|‾‾‾‾|__|‾‾‾‾|__|‾‾‾‾|__
cxs_tx_valid:      ________________|‾‾‾‾|___________________
cxs_tx_data:       ------------------< DATA1 >---------------
tx_ready:          _________|‾‾‾‾|_________________________
```

---

## 4. 时钟与复位 / Clocks and Resets

### 4.1 时钟域 / Clock Domains

| 时钟名称 | 频率 | 描述 | RTL实现要求 |
|----------|------|------|-------------|
| cxs_clk | 2.0 GHz (1.5~2.0) | CXS侧协议时钟，与CXS接口同步 | 所有时序逻辑使用上升沿 |

**时钟关系：**
- cxs_clk由外部时钟源提供，频率范围1.5~2.0GHz
- 本模块所有逻辑都在cxs_clk域
- 与fdi_lclk的跨域处理由TX Async FIFO完成（不在本模块内）

### 4.2 跨时钟域 / Clock Domain Crossings (CDC)

本模块为单时钟域模块(cxs_clk)，不涉及内部CDC。

| 源时钟 | 目标时钟 | 信号类型 | 同步方式 | RTL实现 |
|--------|----------|----------|----------|---------|
| cxs_clk | (内部) | 数据信号 | 直通 | 不需要同步器 |
| (外部) | cxs_clk | cxs_tx_* 输入 | 输入寄存器 | 外部保证同步 |

**CDC设计准则（RTL必须遵守）：**
1. cxs_tx_*输入信号由外部协议层保证同步到cxs_clk
2. 本模块内部不产生跨时钟域信号
3. 输出给TX Path Logic的信号仍在cxs_clk域

### 4.3 复位域 / Reset Domains

| 复位名称 | 有效电平 | 类型 | 作用范围 | RTL实现要求 |
|----------|----------|------|----------|-------------|
| cxs_rst_n | Low | 全局 | 本模块 | 异步断言，同步释放 |

**复位时序（RTL实现）：**
```
             ____/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
cxs_rst_n: ‾‾‾‾‾\________________________________________________
cxs_clk:   __|‾‾‾‾|__|‾‾‾‾|__|‾‾‾‾|__|‾‾‾‾|__|‾‾‾‾|__|‾‾‾‾|
                  ↑ 复位释放  ↑ 功能开始
```

**RTL复位实现规范：**
```systemverilog
// 推荐写法
always_ff @(posedge cxs_clk or negedge cxs_rst_n) begin
  if (!cxs_rst_n) begin
    // 复位逻辑
    cxs_tx_active_reg <= 1'b0;
    // 其他寄存器复位
  end else begin
    // 正常工作逻辑
    // 其他逻辑
  end
end
```

**复位时序要求：**
- 复位脉冲宽度：最小4个cxs_clk周期
- 复位释放到功能启动：最大20个cxs_clk周期

---

## 5. 功能描述 / Functional Description

### 5.1 功能概述 / Functional Overview

CXS TX Interface模块的核心功能是实现CXS协议层数据到Bridge内部TX数据通路的无缝对接，同时严格遵循CXS协议的时序与链路状态管理要求。Credit管理由独立模块负责。

**核心功能模块RTL说明：**

#### 输入采样单元 (Input Sampling Unit)
- **模块名称**: Input Sampling Unit
- **RTL职责**：同步采样所有CXS输入信号，为内部逻辑提供稳定的数据视图
- **输入处理**：
  - 每个cxs_tx_*信号在cxs_clk上升沿采样到对应的寄存器
  - 数据在valid为高期间保持稳定供组合逻辑使用
- **核心逻辑**：
  ```systemverilog
  // 输入寄存器采样
  // 注意: CXS协议中错误标记通过CXSCNTL的ENDERROR位实现，无独立的POISON信号
  always_ff @(posedge cxs_clk or negedge cxs_rst_n) begin
    if (!cxs_rst_n) begin
      cxs_tx_data_reg <= '0;
      cxs_tx_cntl_reg <= '0;
      cxs_tx_last_reg <= 1'b1;  // 默认高
      // 可选信号: CXSUSER, CXSSRCID, CXSTGTID
    end else begin
      if (cxs_tx_valid) begin
        cxs_tx_data_reg <= cxs_tx_data;
        cxs_tx_user_reg <= cxs_tx_user;
        cxs_tx_cntl_reg <= cxs_tx_cntl;
        cxs_tx_last_reg <= cxs_tx_last;
        // ENDERROR位包含在cxs_tx_cntl_reg中，通过cntl透传到下游
        cxs_tx_srcid_reg <= cxs_tx_srcid;
        cxs_tx_tgtid_reg <= cxs_tx_tgtid;
      end
    end
  end
  ```
- **输出生成**：寄存器输出供下游组合逻辑使用

#### 数据接收判定单元 (Data Accept Detection Unit)
- **模块名称**: Data Accept Detection Unit
- **RTL职责**：判断当前周期是否可以接收来自协议层的数据
- **核心逻辑**：
  ```systemverilog
  // 数据接受条件
  // 关键：不能有从cxs_tx_valid到输出的组合路径
  assign data_accept = cxs_tx_valid & tx_ready;
  ```
- **输出生成**：data_accept信号传递给输出格式化

### 5.2 链路状态接口 / Link Status Interface

**链路状态管理说明**：
- 本模块不实现独立的链路状态机
- 链路状态控制由独立的 `cxs_fdi_link_ctrl` 模块统一管理
- 本模块通过以下信号与 cxs_fdi_link_ctrl 模块交互：

**与cxs_fdi_link_ctrl模块的接口**：
| 信号名 | 方向 | 描述 |
|--------|------|------|
| cxs_tx_active_req | → | 链路激活请求（来自上游协议层） |
| cxs_tx_active | ← | 链路激活确认（来自cxs_fdi_link_ctrl） |
| cxs_tx_deact_hint | → | 链路停用提示（来自上游协议层） |

**链路状态响应逻辑（简化版）**：
```systemverilog
// 本模块仅响应链路状态，不实现完整状态机
// 详细链路状态机定义见 cxs_fdi_link_ctrl_spec.md

// 输出信号生成 - 响应链路激活状态
assign tx_valid_enable = cxs_tx_active;  // 仅在链路激活时允许发送数据
```

**链路状态响应**：
| cxs_tx_active | tx_valid_enable | 描述 |
|---------------|------------------|------|
| 0 | 0 | 链路未激活，不允许发送 |
| 1 | 1 | 链路激活，允许发送数据 |

### 5.3 典型事务流程 / Example Transactions

#### 5.3.1 基本数据接收事务

**时序图（RTL时序）：**
```
cxs_clk:           __|‾‾‾‾|__|‾‾‾‾|__|‾‾‾‾|__|‾‾‾‾|__|‾‾‾‾|__|‾‾‾‾|__
cxs_tx_valid:      ________________|‾‾‾‾|___________________  // 数据有效
cxs_tx_data:       ------------------< DATA1 >---------------  // 数据采样
tx_valid_out:      __________________|‾‾‾‾|__________________  // 输出有效
tx_data_out:       -------------------< DATA1 >--------------  // 输出数据
```

**流程描述（RTL操作）：**
1. 周期1：模块初始化，tx_valid_out=0
2. 周期2：协议层发送cxs_tx_valid=1和DATA1
3. 周期3：输入寄存器采样DATA1，data_accept=1
4. 周期4：tx_valid_out=1，输出DATA1给TX Path Logic

### 5.4 错误处理 / Error Handling

#### 5.4.1 错误类型（RTL检测）

| 错误代码 | 错误名称 | 描述 | RTL检测方式 |
|----------|----------|------|-------------|
| 0x01 | ERR_PROTOCOL_VIOLATION | CXS协议违例 | 时序/稳定性检查 |
| 0x02 | ERR_LINK_TIMEOUT | 链路激活超时 | 激活请求超时计数器 |

#### 5.4.2 错误处理流程（RTL实现）

```
┌─────────────┐
│  错误检测    │ ← 硬件检测逻辑(计数器边界检测)
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  错误记录    │ ← 写入错误状态寄存器(通过输出到CSR)
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  错误报告    │ ← 中断信号输出(通过link_ctrl接口)
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  错误恢复    │ ← 复位/软件干预/状态机恢复
└─────────────┘
```

---

## 6. 配置寄存器 / Configuration Registers (CSRs)

### 6.1 寄存器地址映射 / Register Address Map

**基地址**: `0x[系统分配]` - 本模块CSR由顶层统一编址

| 寄存器名 | 地址偏移 | 大小 | 访问类型 | 描述 | RTL实现要点 |
|----------|----------|------|----------|------|-------------|
| TX_IF_CTRL | 0x00 | 32-bit | R/W | TX接口控制寄存器 | 模块使能/软复位 |
| TX_IF_STATUS | 0x04 | 32-bit | R | TX接口状态寄存器 | 链路状态/错误状态 |
| TX_IF_CONFIG | 0x08 | 32-bit | R/W | TX接口配置寄存器 | ID宽度等 |
| TX_IF_FC_CNT | 0x10 | 32-bit | R | Flow Control计数器 | 发送/接收计数 |
| TX_IF_ERR_STATUS | 0x14 | 32-bit | R/W1C | 错误状态寄存器 | 错误记录 |

### 6.2 寄存器详细定义 / Detailed Register Definitions

#### 6.2.1 TX接口控制寄存器 (TX_IF_CTRL) - 偏移: 0x00

| 位域 | 名称 | 访问 | 默认值 | 描述 | RTL实现 |
|------|------|------|--------|------|----------|
| [31] | ENABLE | R/W | 0 | 模块使能 | 时钟门控 |
| [30] | RST_SW | R/W1S | 0 | 软件复位 | 脉冲触发复位 |
| [29:1] | RESERVED | R/W | 0 | 保留 | 写0，读忽略 |
| [0] | LINK_FORCE_ACTIVE | R/W | 0 | 强制链路激活 | 调试用 |

**RTL实现说明：**
- **ENABLE**: 控制模块功能使能，影响所有输出
- **RST_SW**: 写1产生单周期复位脉冲

#### 6.2.2 TX接口状态寄存器 (TX_IF_STATUS) - 偏移: 0x04

| 位域 | 名称 | 访问 | 默认值 | 描述 | RTL源信号 |
|------|------|------|--------|------|-----------|
| [31:18] | RESERVED | R | 0 | 保留 | - |
| [17:16] | LINK_STATE | R | 0 | 链路状态 | curr_state |
| [15:8] | RESERVED2 | R | 0 | 保留 | - |
| [6] | TX_BUSY | R | 0 | 发送忙标志 | tx_valid_out & !tx_ready |
| [5] | ACTIVE_REQ_PEND | R | 0 | 激活请求挂起 | active_req_pending |
| [4] | DEACT_PEND | R | 0 | 停用请求挂起 | deact_hint & !deact_complete |
| [3:0] | RESERVED3 | R | 0 | 保留 | - |

**RTL连接：**
- LINK_STATE: 直接连接状态机当前状态编码

#### 6.2.3 TX接口配置寄存器 (TX_IF_CONFIG) - 偏移: 0x08

| 位域 | 名称 | 访问 | 默认值 | 描述 | RTL实现 |
|------|------|------|--------|------|----------|
| [23:20] | SRCID_WIDTH | R/W | 8 | 源ID位宽 | 可配置0-16 |
| [19:16] | TGTID_WIDTH | R/W | 8 | 目标ID位宽 | 可配置0-16 |
| [15:8] | CNTLOFFSET_START | R/W | 0 | CNTL START字段偏移 | 配置解析 |
| [7:4] | CNTLOFFSET_END | R/W | 8 | CNTL END字段偏移 | 配置解析 |
| [3:0] | RESERVED | R/W | 0 | 保留 | - |

#### 6.2.4 Flow Control计数器寄存器 (TX_IF_FC_CNT) - 偏移: 0x10

| 位域 | 名称 | 访问 | 默认值 | 描述 | RTL源信号 |
|------|------|------|--------|------|-----------|
| [31:16] | FLIT_SENT_CNT | R | 0 | 已发送Flit计数 | flit_sent_counter |
| [15:0] | FLIT_ACCEPT_CNT | R | 0 | 被接受Flit计数 | flit_accept_counter |

#### 6.2.5 错误状态寄存器 (TX_IF_ERR_STATUS) - 偏移: 0x14

| 位域 | 名称 | 访问 | 默认值 | 描述 | RTL源信号 |
|------|------|------|--------|------|-----------|
| [31:4] | RESERVED | R | 0 | 保留 | - |
| [3] | ERR_TIMEOUT | R/W1C | 0 | 激活超时错误 | timeout_error |
| [2] | ERR_PROTOCOL | R/W1C | 0 | 协议违例错误 | protocol_error |

### 6.3 寄存器访问规则 / Register Access Rules

**访问类型说明（RTL实现）：**
| 类型 | RTL实现方式 |
|------|-------------|
| R | 只输出寄存器值 |
| W | 只接收写入，无输出 |
| R/W | 可读可写寄存器 |
| R/W1C | 写1清零，需要清零逻辑 |
| R/W1S | 写1置位，需要置位逻辑 |

**寄存器访问时序（RTL要求）：**
- 读延迟：1个时钟周期（寄存器输出）
- 写生效：下一个时钟周期生效
- 地址解码：组合逻辑解码

---

## 7. 性能规格 / Performance Specifications

### 7.1 性能指标 / Performance Metrics

#### 7.1.1 稳态性能 / Steady-State Performance

| 指标 | 目标值 | 单位 | RTL实现约束 |
|------|--------|------|-------------|
| 峰值吞吐量 | 128 | GB/s | 512bit × 2.0GHz = 128GB/s |
| 持续吞吐量 | 128 | GB/s | 每周期一个Flit，无气泡 |
| 接收延迟(典型) | 1 | 时钟周期 | 输入寄存器采样延迟 |
| 带宽利用率 | > 95 | % | 下游握手效率 |

#### 7.1.2 瞬态性能 / Transient Performance

| 指标 | 目标值 | 单位 | RTL实现方式 |
|------|--------|------|-------------|
| 启动延迟 | 2 | 时钟周期 | 复位释放后到第一笔有效数据 |
| 关闭延迟 | 1 | 时钟周期 | Deact后停止发送 |

#### 7.1.3 接口配置性能

| 指标 | 目标值 | 单位 | RTL实现 |
|------|--------|------|----------|
| ID宽度配置 | 可配置 | bit | 与CSR一致 |
| CNTL字段偏移 | 可配置 | bit | 与协议定义一致 |

### 7.2 仲裁与QoS / Arbitration and QoS

**本模块仲裁策略：**
- 本模块不涉及仲裁，所有CXS输入共享同一数据通路

**优先级定义：**
- 本模块不实现优先级，所有CXS事务同等对待
- 协议层QoS由上游处理

### 7.3 前向进度保证 / Forward Progress Guarantees

**死锁避免（RTL机制）：**
- 超时机制：激活请求设置超时计数器，超时后上报错误

**超时设置：**
| 条件 | 超时值 | RTL处理动作 |
|------|--------|--------------|
| 激活请求超时 | 1024周期 | 上报ERR_TIMEOUT，状态回IDLE |

---

## 9. 验证与调试 / Verification and Debug

### 9.1 验证策略 / Verification Strategy

**验证方法（RTL验证重点）：**
| 方法 | 覆盖率目标 | RTL验证要点 |
|------|------------|-------------|
| 随机验证 | > 95% | 约束随机数据/控制组合 |
| 定向测试 | 100% | 边界条件测试 |
| 形式验证 | 关键路径 | 协议合规断言 |
| FPGA原型 | 系统级 | 实际硬件验证 |

**验证层次（RTL测试重点）：**
1. **模块级验证**：数据通路、输入采样独立验证
2. **接口时序验证**：CXS协议时序合规性
3. **异常验证**：错误检测和恢复验证

### 9.2 测试点 / Testpoints

#### 功能测试点（RTL验证）
| 测试项 | 测试方法 | 通过标准 | RTL验证重点 |
|--------|----------|----------|-------------|
| 基本数据接收 | 定向 | 数据正确 | 接口时序 |
| 链路激活流程 | 定向 | 状态转移正确 | FSM |
| 链路停用流程 | 定向 | 优雅停止 | 停机处理 |
| 边界条件 | 定向 | 正确处理 | 无效输入/空闲场景 |

#### 覆盖点（RTL覆盖率）
| 覆盖类型 | 目标 | RTL验证方法 |
|----------|------|-------------|
| 功能覆盖 | > 95% | 场景覆盖 |
| 条件覆盖 | > 90% | 分支覆盖 |
| 状态覆盖 | 100% | 状态机状态转换 |
| 断言覆盖 | > 98% | 协议合规断言 |

### 9.3 调试功能 / Debug Features

| 调试功能 | 描述 | 访问方式 | RTL实现 |
|----------|------|----------|----------|
| 状态寄存器 | 读取链路状态 | CSR读取 | link_state输出 |
| 错误状态 | 错误类型记录 | CSR读取 | 错误标志寄存器 |
| 性能计数器 | Flit统计 | CSR读取 | 计数器输出 |
| 内部探针 | 关键信号观测 | JTAG/LA | 调试端口(可选) |

**调试接口（RTL实现）：**
- CSR接口：标准APB接口读取状态和配置
- 调试探针：可选信号引出到顶层

### 9.4 调试流程 / RTL调试流程

1. **问题定位**：通过TX_IF_STATUS确定链路状态和错误状态
2. **数据捕获**：使用性能计数器收集Flit统计数据
3. **信号追踪**：通过内部探针观察关键信号
4. **问题分析**：分析错误状态和时序
5. **修复验证**：修改后重新验证功能

**典型调试场景：**
1. **数据丢失**：检查tx_ready反馈与数据有效时序
2. **链路激活失败**：检查active_req和timeout计数器
3. **协议违例**：检查cxs_tx_valid与cxs_tx_data稳定性

---

## 附录A：参数定义 / Parameter Definitions

```systemverilog
// 模块参数定义
// 注意: CXS协议中错误标记通过CXSCNTL的ENDERROR位实现，无独立的POISON信号
module cxs_tx_if #(
  parameter integer CXS_DATA_WIDTH     = 512,  // CXS数据宽度
  parameter integer CXS_USER_WIDTH     = 64,   // 用户位宽度 (0=不包含)
  parameter integer CXS_CNTL_WIDTH     = 16,   // 控制字段宽度
  parameter integer CXS_SRCID_WIDTH   = 8,    // 源ID位宽 (0=不包含)
  parameter integer CXS_TGTID_WIDTH   = 8,    // 目标ID位宽 (0=不包含)
  parameter integer CXS_HAS_LAST      = 1     // 1=包含CXSLAST, 0=不包含
) (
  // 时钟复位
  input  logic                 cxs_clk,
  input  logic                 cxs_rst_n,
  
  // CXS输入接口
  input  logic                 cxs_tx_valid,
  input  logic [CXS_DATA_WIDTH-1:0] cxs_tx_data,
  input  logic [CXS_USER_WIDTH-1:0] cxs_tx_user,
  input  logic [CXS_CNTL_WIDTH-1:0]  cxs_tx_cntl,  // 包含ENDERROR位
  input  logic                 cxs_tx_last,
  input  logic [CXS_SRCID_WIDTH-1:0] cxs_tx_srcid,
  input  logic [CXS_TGTID_WIDTH-1:0] cxs_tx_tgtid,
  
  // CXS链路控制接口
  input  logic                 cxs_tx_active_req,
  input  logic                 cxs_tx_active,
  input  logic                 cxs_tx_deact_hint,
  
  // 内部输出到TX Path Logic
  output logic                 tx_valid_out,
  output logic [CXS_DATA_WIDTH-1:0] tx_data_out,
  output logic [CXS_USER_WIDTH-1:0] tx_user_out,
  output logic [CXS_CNTL_WIDTH-1:0]  tx_cntl_out,  // 包含ENDERROR位透传
  output logic                 tx_last_out,
  output logic [CXS_SRCID_WIDTH-1:0] tx_srcid_out,
  output logic [CXS_TGTID_WIDTH-1:0] tx_tgtid_out,
  input  logic                 tx_ready,
  
  // 链路控制状态交互
  output logic                 link_ctrl_active_req,
  input  logic                 link_ctrl_active_ack,
  output logic                 link_ctrl_deact_req,
  input  logic                 link_ctrl_deact_ack
);
```

---

**文档结束**

**相关文档：**
- 架构规格：`docs/specification/ucie_cxs_fdi_arch_spec.md`
- 模板文档：`docs/templates/ic_design_module_spec_template.md`
- 编码规范：`docs/coding_standards/coding_guide.md`
