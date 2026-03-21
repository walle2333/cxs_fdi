# UCIe CXS-FDI Bridge 设计规格书

**文档编号**: [DOC-UCIE-CXS-FDI-001]  
**版本**: v0.1  
**日期**: 2026-03-15  
**作者**: [待填写]  
**审核人**: [待填写]  
**状态**: Draft

---

## 变更记录 / Change Log

| 版本 | 日期 | 变更描述 | 作者 | 审核人 |
|------|------|----------|------|--------|
| v0.1 | 2026-03-15 | 初始版本：按IC设计模板重构架构规格，包含前七章和第九章；基于官方协议规格完善CXS/FDI接口信号定义；补充CHI C2C协议层映射；完善Link Activation/Deactivation流程；补充实现细节和设计约束 | [待填写] | [待填写] |
| v0.2 | 2026-03-19 | 一致性修订：统一1.5GHz频率与性能指标；明确CXS/FDI信号子集与Non-Goals；补充FDI Rx_active_req/sts握手；修正CXS_CNTL_WIDTH/MAX_CREDIT与协议对齐；完善FIFO溢出/错误恢复与重试规则；新增协议条款可追溯性 | [待填写] | [待填写] |

---

## 1. 概述 / Overview
### 1.1 目的 / Purpose

本文档定义了UCIe CXS-FDI Bridge模块的详细设计规格，作为RTL设计、验证、物理实现和软件开发的唯一真实来源(One Source of Truth)。该模块是CHI Chip-to-Chip (C2C) 互联架构中的关键组件，实现上层协议层（通过AMBA CXS接口）与下层UCIe物理适配层（通过FDI接口）的无缝对接。

**本文档基于以下官方协议规格编写：**
- AMBA CXS Protocol Specification, Issue D (ARM IHI 0079)
- AMBA CHI Chip-to-Chip (C2C) Architecture Specification (ARM IHI 0098)
- UCIe Specification, Revision 3.0, Version 1.0

### 1.2 功能描述 / Functional Description
UCIe CXS-FDI Bridge是一个全双工桥接模块，在CHI C2C协议栈中承担链路扩展层功能。该模块实现AMBA CXS协议与UCIe FDI协议之间的透明转换，包括流控机制、时钟域处理、数据透传和链路状态管理等关键功能。

**主要功能：**
- **协议转换**: 实现CXS基于信用(Credit)的流控与FDI基于握手(Ready/Valid)流控的无损转换
- **高性能传输**: 支持可配置Flit宽度(256b/512b/1024b/2048b)，保证满带宽传输，最小化跨桥延迟
- **时钟兼容性**: 支持同频不同相时钟域，解决Die-to-Die之间的时钟偏移(Skew)
- **RAS支持**: 完整透传数据错误标记(ENDERROR通过CXSCNTL)和用户自定义位(User bits)，支持CHI协议的一致性扩展
- **链路健壮性**: 支持Link Activation/Deactivation，响应物理层Retrain状态，自动阻塞数据流并在链路恢复后自动恢复

**系统位置：**
```
+---------------------------+     +---------------------------+     +---------------------------+
|    CHI Protocol Layer     |-----|  UCIe CXS-FDI Bridge      |-----|  UCIe Physical Adapter   |
| (C2C Node Interface)      | CXS | (Link Extension Layer)   | FDI | (Die-to-Die Interface)  |
+---------------------------+     +---------------------------+     +---------------------------+
```

**目标应用场景：**
- 多芯片CPU/GPU互连扩展
- 服务器SoC的Die-to-Die通信
- 高性能计算芯片间的低延迟互连

### 1.3 目标与非目标 / Goals and Non-Goals

**目标 (Goals) - 必须实现：**
| 目标 | 描述 | 优先级 |
|------|------|--------|
| 协议层透明转换 | 实现CXS与FDI协议的无损转换，确保端到端数据完整性 | P0 |
| 全双工高性能 | 支持256b/512b/1024b/2048b Flit宽度，满带宽传输 | P0 |
| 时钟域处理 | 支持同频异相时钟，内置相位补偿FIFO | P0 |
| 链路状态管理 | 响应Retrain状态，自动流控与恢复 | P0 |
| RAS功能支持 | 完整透传User bits和ENDERROR标记(通过CXSCNTL) | P1 |
| 多节点扩展 | 支持Source/Target ID信号，预留拓扑扩展能力 | P1 |

**非目标 (Non-Goals) - 明确排除：**
- 协议层处理：Bridge不处理CHI协议层的具体事务，仅做链路层透传
- 加密功能：不提供数据加密或安全通道功能
- 复杂QoS调度：不支持复杂的服务质量调度，仅提供基本优先级支持
- CXS-Lite/Packetless：不支持CXS-Lite与packetless模式
- CXS Protocol Type/Protection：不支持CXSPRCLTYPE及相关校验/保护(CHK)信号
- FDI可选侧带/管理/时钟门控接口：不支持pl_clk_req/lp_clk_ack、lp_wake_req/pl_wake_ack、lp_state_req/lp_linkerror、pl_cfg/lp_cfg等管理与功耗接口
- FDI扩展错误/管理信号：不支持pl_cerror、pl_nferror、pl_trainerror、pl_stallreq/lp_stallack、pl_speedmode、pl_lnk_cfg等扩展信号

### 1.4 关键指标 / Key Metrics

| 指标 | 目标值 | 单位 | 备注 |
|------|--------|------|------|
| 工艺节点 | 7nm | - | TSMC 7nm工艺 |
| 工作频率 | 1.5 | GHz | 固定频率，与CXS/FDI接口同步 |
| 核心电压 | 0.7~1.1 | V | 自适应电压调节 |
| 峰值功耗 | < 500 | mW | 全带宽传输时 |
| 典型功耗 | < 200 | mW | 50%负载时 |
| 总面积 | < 0.5 | mm² | 包括FIFO和逻辑 |
| SRAM容量 | 8KB | - | FIFO缓冲存储（默认2×64×512b） |
| 可测性 | > 99% | % | 覆盖率目标 |

---

## 2. 架构设计 / Architecture Design

### 2.1 顶层框图 / Top-Level Block Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                   UCIe CXS-FDI Bridge                                            │
│                                                                                                  │
│  ══════════════════════════════════════════════════════════════════════════════════════════════   │
│                              [Clock Domain: cxs_clk]                                             │
│  ══════════════════════════════════════════════════════════════════════════════════════════════   │
│                                                                                                  │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────┐   │
│  │                                     CXS TX Interface                                        │   │
│  │  cxs_tx_valid    ──────┐                                                                  │   │
│  │  cxs_tx_data[CXS_DATA_WIDTH-1:0] ───┼──►                                                                   │   │
│  │  cxs_tx_user[CXS_USER_WIDTH-1:0] ────┤      ┌──────────────┐                                           │   │
│  │  cxs_tx_cntl ──────────┼──────▶│   TX Path   │                                           │   │
│  │  cxs_tx_last ──────────┤      └──────┬───────┘                                           │   │
│  │  cxs_tx_srcid/tgtid ───┘             │                                                   │   │
│  │  (可选信号: CXSLAST, CXSUSER, CXSSRCID, CXSTGTID, CXSACTIVEREQ, CXSACTIVEACK, CXSDEACTHINT)
│  │  cxs_tx_active_req ─────────────────│▶ (送至Link Control)                                │   │
│  │  cxs_tx_active ◄─────────────────────│ (来自Link Control)                                 │   │
│  │  cxs_tx_deact_hint ─────────────────│▶ (送至Link Control)                                │   │
│  └───────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                              │                                                   │
│  ┌──────────────────────────────────────────┼───────────────────────────────────────────────┐    │
│  │                                     CXS RX Interface                                        │    │
│  │  cxs_rx_valid ◄──────┐                  │                                                   │    │
│  │  cxs_rx_data ◄───────┼──────────────────│                                                   │    │
│  │  cxs_rx_user ◄───────┤                  │                                                   │    │
│  │  cxs_rx_cntl ◄───────┤                  │                                                   │    │
│  │  cxs_rx_last ◄───────┤      ┌──────────────┐                                           │    │
│  │  cxs_rx_active_req ───▶│             │                                                   │    │
│  │  cxs_rx_deact_hint ───▶│             │                                                   │    │
│  │  cxs_rx_active ◄──────│             │                                                   │    │
│  │  cxs_rx_srcid/tgtid ──┘             │                                                   │    │
│  │  (可选信号: CXSLAST, CXSUSER, CXSSRCID, CXSTGTID, CXSACTIVEREQ, CXSACTIVEACK, CXSDEACTHINT)
│  └───────────────────────────────────────┴───────────────────────────────────────────────────┘    │
│                                              │                                                   │
│  ┌──────────────────────────────────────────┼───────────────────────────────────────────────┐    │
│  │                                  Credit Manager (独立全局模块)                              │    │
│  │  ┌────────────────────────────┐  ┌────────────────────────────┐                       │    │
│  │  │    TX Credit管理           │  │    RX Credit管理           │                       │    │
│  │  │  cxs_tx_crdgnt ──────────▶│  │  cxs_rx_crdgnt ◄─────────│                       │    │
│  │  │  cxs_tx_crdret ◀─────────│  │  cxs_rx_crdret ◀─────────│                       │    │
│  │  │  tx_credit_cnt ──────────▶│  │  rx_credit_cnt ──────────▶│                       │    │
│  │  └────────────────────────────┘  └────────────────────────────┘                       │    │
│  │  (cxs_*_crd* 信号与协议层直连，不经过CXS TX/RX Interface)                                 │    │
│  └──────────────────────────────────────────┬───────────────────────────────────────────────┘    │
│                                              │                                                   │
│  ┌──────────────────────────────────────────┼───────────────────────────────────────────────┐    │
│  │                              CXS-FDI Link Control (独立全局模块)                          │    │
│  │  ┌──────────────────────────────────────────────────────────────────┐                 │    │
│  │  │                    链路状态机 (3-bit, 7状态)                       │                 │    │
│  │  │   STOP → ACTIV_REQ → ACTIV_ACK → RUN → DEACT                     │                 │    │
│  │  │                      ↑           ↓                                 │                 │    │
│  │  │                   RETRAIN ←─────┘   (响应FDI Retrain)              │                 │    │
│  │  │                                                          ↓         │                 │    │
│  │  │                                                        ERROR ──────┘                 │    │
│  │  └──────────────────────────────────────────────────────────────────┘                 │    │
│  │                                                                                          │    │
│  │  cxs_tx_active_req ──▶│    │◄── cxs_tx_active                                     │    │
│  │  cxs_rx_active_req ──▶│    │◄── cxs_rx_active                                     │    │
│  │  cxs_tx_deact_hint ──▶│    │                                                     │    │
│  │  fdi_pl_state_sts ────▶│    │──▶ link_active                                       │    │
│  │  fdi_pl_state_sts[Retrain] ─▶│    │                                              │    │
│  └──────────────────────────────────────────┬───────────────────────────────────────────────┘    │
│                                              │                                                   │
│  ═══════════════════════════════════════════╪═══════════════════════════════════════════════════   │
│                              [Clock Domain Boundary - CDC]                                        │
│                                        │                                                          │
│                              ┌─────────┴─────────┐                                               │
│                              │   Async FIFO      │    64-depth, Gray Code                       │
│                              │   (TX Path)       │    Write: cxs_clk                            │
│                              │                   │    Read:  fdi_lclk                           │
│                              └─────────┬─────────┘                                               │
│                                        │                                                          │
│                              ┌─────────┴─────────┐                                               │
│                              │   Async FIFO      │    64-depth, Gray Code                       │
│                              │   (RX Path)       │    Write: fdi_lclk                          │
│                              │                   │    Read:  cxs_clk                           │
│                              └─────────┬─────────┘                                               │
│                                        │                                                          │
│  ══════════════════════════════════════╪═════════════════════════════════════════════════════   │
│                              [Clock Domain: fdi_lclk]                                            │
│  ══════════════════════════════════════╪═════════════════════════════════════════════════════   │
│                                                                                                  │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │                                      FDI TX Interface                                       │  │
│  │                          ┌──────────────┐    fdi_lp_valid ──────────────────────────────┐      │  │
│  │                          │    TX Path   │    fdi_lp_irdy ◄──────────────────────────────┼──┐   │  │
│  │                          │    Logic     │───▶fdi_lp_flit[FDI_DATA_WIDTH-1:0]──────────────────────────┘  │   │  │
│  │                          └──────────────┘    fdi_lp_stream                                 │      │  │
│  │                                               fdi_lp_dllp_valid                             │      │  │
│  │                                               fdi_lp_dllp                                   │      │  │
│  └───────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                                  │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │                                      FDI RX Interface                                       │  │
│  │                          ┌──────────────┐    fdi_pl_valid ───────────────────────────────┐      │  │
│  │                          │    RX Path   │◀───fdi_pl_flit[FDI_DATA_WIDTH-1:0]──────────────────────────┘      │  │
│  │                          │    Logic     │    fdi_pl_trdy ──────────────────────────────────│──┐   │  │
│  │                          └──────────────┘    fdi_pl_stream                                 │  │  │
│  │                                            fdi_pl_dllp_valid                               │  │  │
│  │                                            fdi_pl_dllp                                     │  │  │
│  │                                            fdi_pl_rx_active_req                            │  │  │
│  │                                            fdi_lp_rx_active_sts                            │  │  │
│  └───────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                                  │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │                                 Physical Layer Status (Input)                              │  │
│  │    fdi_pl_state_sts[3:0]    fdi_pl_error    fdi_pl_idle    fdi_pl_inband_pres    fdi_pl_flit_cancel         │  │
│  └───────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                                  │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │                              Sideband Logic                                                │  │
│  │   ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                              │  │
│  │   │  CXS SB      │    │    LME       │    │   FDI SB     │  ← LME = Link Management   │  │
│  │   │  Interface   │◄──▶│   Handler    │◄──▶│   Interface  │      Exchange (See 2.1.1) │  │
│  │   │  (cxs_clk)   │    │              │    │  (fdi_lclk)  │                              │  │
│  │   └──────────────┘    └──────────────┘    └──────────────┘                              │  │
│  └───────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                                  │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │                              Configuration & Debug (apb_clk)                              │  │
│  │   ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                              │  │
│  │   │     APB      │───▶│     CSR      │◄───│    Perf      │                              │  │
│  │   │   Interface  │    │   Regfile    │    │   Counters   │                              │  │
│  │   │  (apb_clk)   │    │              │    │              │                              │  │
│  │   └──────────────┘    └──────────────┘    └──────────────┘                              │  │
│  └───────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

**模块列表：**
| 模块名称 | 功能描述 | 关键接口 | 时钟域 | 备注 |
|----------|----------|----------|--------|------|
| CXS TX Interface | CXS发送接口 | cxs_tx_* 信号 | cxs_clk | 协议层输入接口 |
| CXS RX Interface | CXS接收接口 | cxs_rx_* 信号 | cxs_clk | 协议层输出接口 |
| TX Path Logic | 发送通路处理 | 数据缓冲 | cxs_clk | 核心数据发送单元 |
| RX Path Logic | 接收通路处理 | 数据缓冲 | cxs_clk | 核心数据接收单元 |
| TX Async FIFO | 跨时钟域缓冲 | 写接口(cxs_clk)，读接口(fdi_lclk) | 异步 | 64深度，格雷码指针 |
| RX Async FIFO | 跨时钟域缓冲 | 写接口(fdi_lclk)，读接口(cxs_clk) | 异步 | 64深度，格雷码指针 |
| Credit Manager | 信用管理 | CXS credit信号 | cxs_clk | **独立全局模块**，TX/RX统一管理 |
| CXS-FDI Link Control | 链路控制状态机 | Activation/Deactivation/Retrain | cxs_clk | **独立全局模块**，3-bit 7状态 |
| Error Handler | 错误处理逻辑 | 错误状态寄存器 | cxs_clk | 错误检测与上报 |
| FDI TX Interface | FDI发送接口 | fdi_lp_valid, fdi_lp_flit, fdi_lp_irdy | fdi_lclk | UCIe Adapter输入接口 |
| FDI RX Interface | FDI接收接口 | fdi_pl_valid, fdi_pl_flit, fdi_pl_trdy | fdi_lclk | UCIe Adapter输出接口 |
| LME Handler | 链路管理交换 | CXS/FDI Sideband接口 | cxs_clk/fdi_lclk | LME = Link Management Exchange |
| APB Interface | 配置调试接口 | CSR寄存器访问 | apb_clk | 100MHz配置时钟 |

### 2.2 数据流 / Data Flow

**主数据通路：**
```
TX Path: cxs_tx_data → TX Path Logic (含 TX Async FIFO) → FDI TX Interface → fdi_lp_flit
RX Path: fdi_pl_flit → FDI RX Interface → RX Path Logic (含 RX Async FIFO) → cxs_rx_data
```

**控制流：**
```
Link Control: Activation Request → CXS-FDI Link Control (独立模块) → Activation Ack/Timeout
Credit Flow: CXS Credit Grant/Return → Credit Manager (独立模块) → Flow Control Signals
Error Handling: Error Detection → Error Registers → Status/Interrupt Reporting
```

**数据流描述：**
1. **CXS TX Interface (cxs_clk域)**：接收来自协议层的Flit数据，包括cxs_tx_valid, cxs_tx_data, cxs_tx_user, cxs_tx_cntl等
2. **TX Path Logic (cxs_clk域)**：数据缓冲准备
3. **TX Async FIFO (CDC边界)**：跨时钟域缓冲，写端口连接cxs_clk，读端口连接fdi_lclk
4. **FDI TX Interface (fdi_lclk域)**：将数据封装为fdi_lp_valid, fdi_lp_flit, fdi_lp_stream发送给UCIe Adapter；可选支持fdi_lp_dllp(_valid)
5. **FDI RX Interface (fdi_lclk域)**：接收来自Adapter的fdi_pl_valid, fdi_pl_flit, fdi_pl_stream；可选支持fdi_pl_dllp(_valid)
6. **RX Async FIFO (CDC边界)**：跨时钟域缓冲，写端口连接fdi_lclk，读端口连接cxs_clk
7. **RX Path Logic (cxs_clk域)**：CXS协议封装
8. **CXS RX Interface (cxs_clk域)**：发送cxs_rx_valid, cxs_rx_data, cxs_rx_user给协议层

### 2.3 子模块层次 / Submodule Hierarchy

```
ucie_cxs_fdi_top
├── cxs_tx_if (CXS TX接口)
│   └── cxs_tx_* 信号解析与处理
├── cxs_rx_if (CXS RX接口)
│   └── cxs_rx_* 信号封装
├── tx_path (TX Path Logic)
│   ├── tx_path_async_fifo (异步FIFO缓冲)
│   └── tx_path_error_handler (错误处理)
├── rx_path (RX Path Logic)
│   ├── rx_path_async_fifo (异步FIFO缓冲)
│   └── rx_path_error_handler (错误处理)
├── credit_mgr (Credit Manager - 独立全局模块)
│   ├── tx_credit_mgr (发送信用管理)
│   └── rx_credit_mgr (接收信用管理)
├── cxs_fdi_link_ctrl (Link Control FSM - 独立全局模块)
│   └── 链路激活/停用/Retrain状态管理
├── fdi_tx_if (FDI TX接口)
│   └── fdi_lp_* 信号封装
├── fdi_rx_if (FDI RX接口)
│   └── fdi_pl_* 信号解析
├── lme (LME Handler)
│   ├── cxs_sb_if (CXS边带接口)
│   └── fdi_sb_if (FDI边带接口)
└── regs (寄存器模块)
    ├── apb_if (APB接口)
    ├── csr_regfile (控制状态寄存器文件)
    └── perf_counters (性能计数器)
```

---

## 3. 接口定义 / Interface Definitions

### 3.1 时钟和复位接口

| 接口名称 | 方向 | 位宽 | 时钟域 | 描述 |
|----------|------|------|--------|------|
| cxs_clk | Input | 1 | - | CXS侧协议时钟，1.5GHz |
| cxs_rst_n | Input | 1 | cxs_clk | CXS侧异步复位，低电平有效，同步释放 |
| fdi_lclk | Input | 1 | - | FDI侧链路时钟，与cxs_clk同频(1.5GHz)，相位独立 |
| fdi_rst_n | Input | 1 | fdi_lclk | FDI侧异步复位，低电平有效，同步释放 |
| apb_clk | Input | 1 | - | APB配置时钟，100MHz |
| apb_rst_n | Input | 1 | apb_clk | APB复位，低电平有效 |
| rst_sw | Input | 1 | apb_clk | 软件复位，高电平有效 |

### 3.2 CXS接口

**CXS信号子集说明：**
- 本设计仅实现CXS信号列表中的必要子集，未列出的校验/保护/协议类型等信号按Non-Goals处理
- 支持信号：CXSVALID、CXSDATA、CXSCNTL(条件)、CXSLAST(条件)、CXSUSER(条件)、CXSSRCID/CXSTGTID(条件)、CXSCRDGNT/CXSCRDRTN、CXSACTIVEREQ/CXSACTIVEACK/CXSDEACTHINT

**CXS信号支持列表（摘要）**:
| 信号 | 支持情况 | 备注 |
|------|----------|------|
| CXSVALID/CXSDATA | 支持 | 必需数据通道 |
| CXSCNTL | 条件支持 | CXS_CNTL_WIDTH>0 |
| CXSLAST | 条件支持 | CXS_HAS_LAST=1 且 CXS_MAX_PKT_PER_FLIT>1 |
| CXSUSER | 条件支持 | CXS_USER_WIDTH>0 |
| CXSSRCID/CXSTGTID | 条件支持 | *_WIDTH>0 |
| CXSCRDGNT/CXSCRDRTN | 支持 | Credit流控 |
| CXSACTIVEREQ/CXSACTIVEACK/CXSDEACTHINT | 支持 | Link control |
| CXSPRCLTYPE/CXS_PROTOCOL_TYPE | 不支持 | Non-Goals（见1.3） |
| CHK校验信号 | 不支持 | Non-Goals（见1.3） |

#### 3.2.1 CXS TX接口 (协议层→Bridge)

基于 **AMBA CXS Protocol Specification, Issue D** 标准信号定义：

**注意**: CXS协议中错误标记(Poison)不是独立信号，而是通过CXSCNTL字段中的ENDERROR位来实现。

| 信号名 | CXS标准名 | 方向 | 位宽 | 必需性 | 描述 |
|--------|-----------|------|------|--------|------|
| cxs_tx_valid | **CXSVALID** | Input | 1 | 必需 | 发送端Flit有效指示。高电平时表示CXSDATA有效 |
| cxs_tx_data | **CXSDATA** | Input | [CXS_DATA_WIDTH] | 必需 | 数据载荷。支持256-2048位，本设计默认512位 |
| cxs_tx_user | **CXSUSER** | Input | [CXS_USER_WIDTH] | 可选 | 用户定义位。用于传递协议层扩展信息 |
| cxs_tx_cntl | **CXSCNTL** | Input | [CXS_CNTL_WIDTH] | 条件必需 | 控制字段。包含START[x:0]、END[x:0]、ENDERROR[x:0]、STARTxPTR、ENDxPTR等子字段。ENDERROR位用于错误标记(替代独立POISON信号)。当CXS_CNTL_WIDTH=0时该信号不存在 |
| cxs_tx_last | **CXSLAST** | Input | 1 | 条件可选 | 包边界指示。表示当前Flit后可插入其他协议数据，或表示包结束。当CXS_HAS_LAST=0时该信号不存在 |
| cxs_tx_srcid | **CXSSRCID** | Input | [CXS_SRCID_WIDTH] | 可选 | 源ID标识。用于多节点拓扑，可配置宽度0-8位 |
| cxs_tx_tgtid | **CXSTGTID** | Input | [CXS_TGTID_WIDTH] | 可选 | 目标ID标识。用于路由，可配置宽度0-8位 |
| cxs_tx_active_req | **CXSACTIVEREQ** | Input | 1 | 可选 | 链路激活请求（来自协议层） |
| cxs_tx_active | **CXSACTIVEACK** | Output | 1 | 可选 | 链路激活确认（TX路径就绪） |
| cxs_tx_deact_hint | **CXSDEACTHINT** | Input | 1 | 可选 | 链路停用提示（来自协议层） |

**CXSCNTL位宽说明**:
- `CXS_CNTL_WIDTH` 由 `CXS_DATA_WIDTH`、`CXS_MAX_PKT_PER_FLIT` 和 `CXS_START_ALIGNMENT` 决定
- 默认配置：`CXS_DATA_WIDTH=512b`、`CXS_MAX_PKT_PER_FLIT=2`、`CXS_START_ALIGNMENT=16B` 时，`CXS_CNTL_WIDTH=18`
- 合法取值集合：`0, 14, 18, 22, 27, 33, 36, 44`（详见协议表格）

**支持范围说明**:
- 本设计仅支持 `CXSDATAFLITWIDTH` 为 256/512/1024/2048（不支持 packetless 8..2048 的全范围模式）

**CXS TX时序关键要求：**
1. **Credit授权到数据发送**: Master必须在CXSCRDGNT断言后的下一个周期才能使用Credit发送数据（不允许CXSCRDGNT到CXSVALID的组合路径）
2. **Credit退还**: 当使用Explicit Credit Return模式时，Master通过CXSCRDRTN显式退还Credit，同样不允许到CXSCRDGNT的组合路径
3. **链路激活**: 完整的激活流程为: ACTIVEREQ → ACTIVEACK → (发送数据) → DEACTHINT → (停止发送) → 返回STOP状态
4. **互斥约束**: CXSCRDRTN与CXSVALID不得在同一周期同时断言

**实现说明**:
- `cxs_tx_crdgnt`/`cxs_tx_crdret` 由独立的 `credit_mgr` 模块直接与协议层交互
- `cxs_tx_if` 模块不包含 Credit 信号端口

#### 3.2.2 CXS RX接口 (Bridge→协议层)

基于 **AMBA CXS Protocol Specification (Issue D)** 定义，信号映射遵循CXS协议标准命名。

| 信号名 | CXS标准名 | 方向 | 位宽 | 描述 | 时序要求 |
|--------|-----------|------|------|------|----------|
| cxs_rx_valid | **CXSVALID** | Output | 1 | 接收方向Flit有效指示。高电平时表示CXSDATA有效 | 必须在数据有效前建立，保持到数据结束 |
| cxs_rx_data | **CXSDATA** | Output | [CXS_DATA_WIDTH] | 数据载荷。支持256-2048位，本设计默认512位 | 与CXSVALID同步 |
| cxs_rx_user | **CXSUSER** | Output | [CXS_USER_WIDTH] | 可选 | 用户定义位。用于传递协议层扩展信息 | 与CXSVALID同步 |
| cxs_rx_cntl | **CXSCNTL** | Output | [CXS_CNTL_WIDTH] | 条件必需 | 控制字段。包含START[x:0]、END[x:0]、ENDERROR[x:0]、STARTxPTR、ENDxPTR等子字段，用于包边界指示和错误标记。当CXS_CNTL_WIDTH=0时该信号不存在 | 与CXSVALID同步，位宽由CXS_DATA_WIDTH/CXS_MAX_PKT_PER_FLIT/CXS_START_ALIGNMENT决定 |
| cxs_rx_last | **CXSLAST** | Output | 1 | 条件可选 | 包边界指示。表示当前Flit后可插入其他协议数据，或表示包结束。当CXS_HAS_LAST=0时该信号不存在 | 由包边界逻辑驱动；未启用时为0 |
| cxs_rx_active | **CXSACTIVEACK** | Output | 1 | 可选 | 链路激活确认。表示RX路径已就绪可接收数据 | 高电平有效 |
| cxs_rx_active_req | **CXSACTIVEREQ** | Input | 1 | 可选 | 链路激活请求（来自协议层） | 高电平有效 |
| cxs_rx_deact_hint | **CXSDEACTHINT** | Input | 1 | 可选 | 链路停用提示（来自协议层） | 高电平有效 |
| cxs_rx_srcid | **CXSSRCID** | Output | [CXS_SRCID_WIDTH] | 可选 | 源ID标识。用于多节点拓扑 | 与CXSVALID同步 |
| cxs_rx_tgtid | **CXSTGTID** | Output | [CXS_TGTID_WIDTH] | 可选 | 目标ID标识。用于路由 | 与CXSVALID同步 |

#### 3.2.3 CXS Credit信号 (协议层 ↔ credit_mgr)

Credit相关信号由 `credit_mgr` 模块直接与协议层交互，不经过 `cxs_rx_if`：

| 信号名 | CXS标准名 | 方向 | 位宽 | 描述 | 时序要求 |
|--------|-----------|------|------|------|----------|
| cxs_tx_crdgnt | **CXSCRDGNT** | Output | 1 | Credit授权信号（TX方向） | 高电平有效，每周期可授权一个Credit |
| cxs_tx_crdret | **CXSCRDRTN** | Input | 1 | Credit退还信号（TX方向） | 高电平有效 |
| cxs_rx_crdgnt | **CXSCRDGNT** | Output | 1 | Credit授权信号（RX方向） | 高电平有效，每周期可授权一个Credit |
| cxs_rx_crdret | **CXSCRDRTN** | Input | 1 | Credit退还信号（RX方向） | 高电平有效 |

**CXS TX时序关键要求：**
1. **Credit授权到数据发送**: Master必须在CXSCRDGNT断言后的下一个周期才能使用Credit发送数据（不允许CXSCRDGNT到CXSVALID的组合路径）
2. **Credit退还**: 当使用Explicit Credit Return模式时，Master通过CXSCRDRTN显式退还Credit，同样不允许到CXSCRDGNT的组合路径
3. **链路激活**: 完整的激活流程为: ACTIVEREQ → ACTIVEACK → (发送数据) → DEACTHINT → (停止发送) → 返回STOP状态

**实现说明**:
- `cxs_rx_crdgnt`/`cxs_rx_crdret` 由独立的 `credit_mgr` 模块直接与协议层交互
- `cxs_rx_if` 模块不包含 Credit 信号端口
- Credit退还模式仅参数化配置，运行时不支持切换（CSR只读反映）

### 3.3 FDI接口

#### 3.3.1 FDI TX接口 (Bridge→UCIe Adapter)

基于 **UCIe Specification (Rev 3.0)** 的FDI (Flit-aware Die-to-Die Interface) 定义。

**FDI信号子集说明：**
- 本设计仅实现FDI信号列表中的必要子集（见下表），未列出的管理/功耗/扩展错误信号按Non-Goals处理
- 支持信号：fdi_lp_valid/fdi_lp_irdy/fdi_lp_flit/fdi_lp_stream/fdi_lp_dllp(_valid)，fdi_pl_valid/fdi_pl_trdy/fdi_pl_flit/fdi_pl_stream/fdi_pl_dllp(_valid)/fdi_pl_flit_cancel，fdi_pl_state_sts/fdi_pl_inband_pres/fdi_pl_error/fdi_pl_idle，fdi_pl_rx_active_req/fdi_lp_rx_active_sts

**FDI信号支持列表（摘要）**:
| 信号 | 支持情况 | 备注 |
|------|----------|------|
| fdi_lp_valid/fdi_lp_irdy/fdi_lp_flit | 支持 | TX主数据通道 |
| fdi_pl_valid/fdi_pl_trdy/fdi_pl_flit | 支持 | RX主数据通道 |
| fdi_lp_stream/fdi_pl_stream | 条件支持 | FDI_STREAM_WIDTH>0 |
| fdi_lp_dllp(_valid)/fdi_pl_dllp(_valid) | 条件支持 | FDI_DLLP_WIDTH>0 |
| fdi_pl_flit_cancel | 支持 | 错误/重试处理 |
| fdi_pl_state_sts/fdi_pl_inband_pres/fdi_pl_error/fdi_pl_idle | 支持 | 链路状态/错误 |
| fdi_pl_rx_active_req/fdi_lp_rx_active_sts | 支持 | Rx_active_req/Sts握手 |
| pl_clk_req/lp_clk_ack/lp_wake_req/pl_wake_ack | 不支持 | Non-Goals（见1.3） |
| pl_cfg/lp_cfg | 不支持 | Non-Goals（见1.3） |
| pl_cerror/pl_nferror/pl_trainerror | 不支持 | Non-Goals（见1.3） |
| pl_stallreq/lp_stallack | 不支持 | Non-Goals（见1.3） |
| pl_speedmode/pl_lnk_cfg | 不支持 | Non-Goals（见1.3） |

| 信号名 | FDI标准名 | 方向 | 位宽 | 描述 | 时序要求 |
|--------|-----------|------|------|------|----------|
| fdi_lp_valid | **fdi_lp_valid** | Output | 1 | Protocol Layer到Adapter的数据有效指示。高电平时表示fdi_lp_flit数据有效 | 与lclk上升沿同步，必须在数据有效前建立 |
| fdi_lp_irdy | **fdi_lp_irdy** | Input | 1 | Link Interface Ready。Adapter表示已准备好接收数据，可提前2周期或同时断言 | 可提前fdi_lp_valid 2个周期或同时断言。当fdi_lp_valid、fdi_lp_irdy同时高时数据传输 |
| fdi_lp_flit | **fdi_lp_flit** | Output | [FDI_DATA_WIDTH] | Flit数据。支持256b/512b/1024b/2048b Flit格式，本设计默认512b | 与fdi_lp_valid同步，在fdi_lp_valid&&fdi_lp_irdy高时采样 |
| fdi_lp_stream | **fdi_lp_stream** | Output | [FDI_STREAM_WIDTH] | 流ID。用于多协议堆栈标识，映射到唯一的协议和堆栈。仅在fdi_lp_valid=1时有效 | 与fdi_lp_valid同步，用于区分不同协议流 |
| fdi_lp_dllp_valid | **fdi_lp_dllp_valid** | Output | 1 | DLLP有效指示（可选）。用于低延迟DLLP传输，可与Flit同时有效 | 与fdi_lp_valid同时或独立断言 |
| fdi_lp_dllp | **fdi_lp_dllp** | Output | [FDI_DLLP_WIDTH] | DLLP数据（可选）。用于链路管理DLLP传输 | 与fdi_lp_dllp_valid同步 |

**FDI TX时序说明：**
1. **fdi_lp_irdy 提前断言**: 根据UCIe Spec，Adapter可以提前最多2个周期断言fdi_lp_irdy，表示准备接收数据。
2. **数据传输条件**: `fdi_lp_valid && fdi_lp_irdy` 同时高时数据传输

#### 3.3.2 FDI RX接口 (UCIe Adapter→Bridge)

| 信号名 | FDI标准名 | 方向 | 位宽 | 描述 | 时序要求 |
|--------|-----------|------|------|------|----------|
| fdi_pl_valid | **fdi_pl_valid** | Input | 1 | Adapter到Protocol Layer的接收数据有效指示 | 与lclk同步，高电平时fdi_pl_flit有效 |
| fdi_pl_trdy | **fdi_pl_trdy** | Output | 1 | Protocol Layer Ready。Bridge表示已准备好接收数据 | 可与fdi_pl_valid同时或提前断言 |
| fdi_pl_flit | **fdi_pl_flit** | Input | [FDI_DATA_WIDTH] | 接收Flit数据 | 与fdi_pl_valid同步，在fdi_pl_valid&&fdi_pl_trdy时采样 |
| fdi_pl_stream | **fdi_pl_stream** | Input | [FDI_STREAM_WIDTH] | 接收流ID | 与fdi_pl_valid同步 |
| fdi_pl_dllp_valid | **fdi_pl_dllp_valid** | Input | 1 | 接收DLLP有效（可选） | 可与fdi_pl_flit同时有效 |
| fdi_pl_dllp | **fdi_pl_dllp** | Input | [FDI_DLLP_WIDTH] | 接收DLLP数据（可选） | 与fdi_pl_dllp_valid同步 |
| fdi_pl_rx_active_req | **fdi_pl_rx_active_req** | Input | 1 | Adapter请求接收通道激活（FDI握手） | 与lclk同步 |
| fdi_lp_rx_active_sts | **fdi_lp_rx_active_sts** | Output | 1 | Bridge接收通道就绪状态（FDI握手） | 与lclk同步，需与fdi_pl_rx_active_req保持至少1周期时序隔离 |

**FDI RX时序说明：**
1. **数据传输条件**: `fdi_pl_valid && fdi_pl_trdy` 同时高时数据传输
2. **Rx_active_req/Sts握手**: fdi_pl_rx_active_req 上升沿仅在 fdi_lp_rx_active_sts=0 时有效，且需与 fdi_lp_rx_active_sts 保持至少 1 个周期的时序隔离，禁止组合环路
3. **就绪条件**: fdi_lp_rx_active_sts 仅在Bridge接收通道已就绪时断言，且需在 fdi_pl_rx_active_req 之后断言

#### 3.3.3 Physical Layer接口 (UCIe Adapter→Bridge)

| 信号名 | FDI标准名 | 方向 | 位宽 | 描述 | 时序要求 |
|--------|-----------|------|------|------|----------|
| fdi_pl_state_sts | **fdi_pl_state_sts** | Input | 4 | Physical Layer链路状态。编码: 0000=Reset, 0001=LinkUp, 0010=Active, 0011=Retrain, ... | 实时更新，用于链路状态管理 |
| fdi_pl_inband_pres | **fdi_pl_inband_pres** | Input | 1 | 带内存在检测。表示远端物理层已上电并可通信 | 用于初始链路建立 |
| fdi_pl_error | **fdi_pl_error** | Input | 1 | 物理层错误指示 | 高电平时表示物理层检测到错误 |
| fdi_pl_flit_cancel | **fdi_pl_flit_cancel** | Input | 1 | Flit取消指示。Adapter要求Protocol Layer丢弃部分接收的Flit | 在最后一个Flit chunk后1-2周期断言，用于CRC错误或Retry场景 |
| fdi_pl_idle | **fdi_pl_idle** | Input | 1 | Idle指示。表示链路处于空闲状态，可进入低功耗模式 | 用于功耗管理 |

**Physical Layer状态响应：**
- Reset状态: 停止所有传输，复位内部状态
- LinkUp: 准备激活，可进行参数协商
- Active: 正常数据传输
- Retrain: 暂停发送，等待链路训练完成
- 其他状态: 视为异常状态，进入ERROR/STOP并记录错误

### 3.4 APB接口

#### 3.4.1 APB接口信号定义

基于 **AMBA APB Protocol Specification** 定义，用于配置和调试。

| 信号名 | APB标准名 | 方向 | 位宽 | 描述 |
|--------|-----------|------|------|------|
| apb_paddr | **PADDR** | Input | [31:0] | 地址信号 |
| apb_pwdata | **PWDATA** | Input | [31:0] | 写数据 |
| apb_prdata | **PRDATA** | Output | [31:0] | 读数据 |
| apb_penable | **PENABLE** | Input | 1 | 使能信号 |
| apb_psel | **PSEL** | Input | 1 | 选择信号 |
| apb_pwrite | **PWRITE** | Input | 1 | 写信号，1=写，0=读 |
| apb_pready | **PREADY** | Output | 1 | 就绪信号 |
| apb_pslverr | **PSLVERR** | Output | 1 | 错误响应 |

#### 3.4.2 寄存器访问时序

**读操作时序：**
1. SETUP阶段: PSEL=1, PWRITE=0, PADDR有效
2. ACCESS阶段: PENABLE=1, PRDATA在PREADY高时有效

**写操作时序：**
1. SETUP阶段: PSEL=1, PWRITE=1, PADDR和PWDATA有效
2. ACCESS阶段: PENABLE=1, PWDATA在PREADY高时写入

### 3.5 协议规范 / Protocol Specifications

#### 3.5.1 参考协议文档

| 协议名称 | 版本 | 文档编号 | 来源 |
|----------|------|----------|------|
| AMBA CXS Protocol Specification | Issue D | ARM IHI 0079 | ARM Limited |
| AMBA CHI Chip-to-Chip (C2C) Architecture Specification | Issue A | ARM IHI 0098 | ARM Limited |
| UCIe Specification | Revision 3.0, Version 1.0 | UCIe 3.0 | UCIe Consortium |

#### 3.5.2 CXS到FDI协议映射表

基于AMBA CXS Spec和UCIe FDI Spec定义的完整信号映射：

| CXS信号 | CXS Spec章节 | FDI信号 | FDI Spec章节 | 映射说明 |
|---------|--------------|---------|--------------|----------|
| CXSVALID | 3.1 | fdi_lp_valid | 10.2 | 直接映射，Flit有效指示 |
| CXSDATA | 3.1 | fdi_lp_flit | 10.2 | 直接映射，Flit数据透传 |
| CXSCNTL | 3.1, 4.2 | - | - | 映射到Flit内部Header字段(含ENDERROR位用于错误标记) |
| CXSLAST | 3.1 | fdi_lp_flit[Last] | 10.2 | 映射到Flit Header的Last指示(可选) |
| CXSUSER | 3.1 | fdi_lp_flit[User] | 10.2 | 映射到Flit User字段(可选) |
| CXSCRDGNT | 3.1 | fdi_lp_valid (门控) | 10.2 | Credit→Valid门控(由credit_mgr驱动) |
| CXSCRDRTN | 3.1 | - | - | Explicit Return模式支持(由credit_mgr处理) |
| CXSACTIVEREQ | 3.1 | - | - | 通过FDI sideband映射 |
| CXSACTIVEACK | 3.1 | - | - | 通过FDI sideband映射 |
| CXSDEACTHINT | 3.1 | - | - | 通过FDI sideband映射 |

**流控机制映射详情：**

1. **CXS Credit机制 → FDI Ready/Valid握手：**
   - CXS使用基于Credit的流控：Receiver通过CXSCRDGNT授予Credit，Transmitter每周期最多发送等于Credit数量的Flit
   - FDI使用Ready/Valid握手：当Adapter的fdi_lp_irdy为高时，表示已准备好接收数据
   - 映射关系：`credit_mgr` 维护Credit计数器，当Credit>0时门控fdi_lp_valid相关流控

2. **Explicit Credit Return模式：**
   - 当CXS配置为Explicit Return模式时，Transmitter通过CXSCRDRTN显式退还Credit
   - 在链路停用(Deactivation)期间必须使用此模式，确保所有Credit正确回收
   - `credit_mgr` 在收到CXSCRDRTN后更新Credit计数，并影响fdi_lp_valid相关流控

#### 3.5.3 CHI C2C协议层映射

基于 **AMBA CHI C2C Architecture Specification (IHI0098A)** 的协议层映射：

| CHI C2C概念 | CXS对应 | FDI对应 | 说明 |
|-------------|---------|---------|------|
| C2C Node | CXS Endpoint | FDI Protocol Layer | CHI C2C节点对应到协议层接口 |
| C2C Link | CXS Link | FDI Link | 链路层映射到接口连接 |
| Credit Grant | CXSCRDGNT | fdi_lp_valid门控 + Credit Count | C2C Credit映射到CXS和FDI流控(由credit_mgr维护) |
| Link Activation | ACTIVEREQ/ACTIVEACK | fdi_pl_state_sts + Sideband | 链路激活状态映射 |
| LME (Link Management Exchange) | Sideband | Sideband | 链路管理属性交换 |

**关键CHI C2C映射规则：**

1. **C2C-Specific Message映射**：
   - CHI C2C定义了C2C-specific消息类(MiscU/MiscC)，包括Credit Grant、Link State等消息
   - 这些消息由协议层产生/解析，通过CXS的User bits或专用sideband通道传递
   - Bridge不解析消息语义，仅按既定映射透传对应字段/信号

2. **Credit管理映射**：
   - CHI C2C Credit机制与CXS Credit机制直接对应
   - C2C Credit Grant消息映射到CXSCRDGNT信号
   - FDI方向使用fdi_lp_valid门控与`credit_mgr`维护的Credit计数器实现等效流控
   - 注意：CHI C2C Credit是针对消息类型的，Bridge需要维护多个Credit计数器(由credit_mgr承担)

3. **Link State管理**：
   - CHI C2C Link State与FDI fdi_pl_state_sts有直接映射关系
   - STOP/ACTIVREQ/ACTIVE/DEACT等C2C状态对应到FDI链路状态（Reset/LinkUp/Active/Retrain等）
   - Bridge的Link Control FSM需要处理这些状态转换

#### 3.5.4 协议转换关键规则

**1. Flit格式映射：**
- CXS Flit和FDI Flit在数据 payload 层面保持1:1透传
- CXS的CXSDATA直接映射到FDI的fdi_lp_flit/fdi_pl_flit数据字段
- CXS的User bits映射到FDI Flit的User/Metadata字段
- CXS的错误标记通过CXSCNTL的ENDERROR位实现，映射到FDI Flit的Error字段

**2. 流控转换：**
- Credit-based (CXS) ↔ Ready/Valid (FDI) 的转换是Bridge的核心功能
- `credit_mgr` 维护Credit计数器，根据可用Credit驱动/门控fdi_lp_valid相关流控
- `credit_mgr` 根据FIFO可用空间更新CXSCRDGNT，保证Credit与缓冲资源一致

**3. 错误处理：**
- CXS错误标记通过CXSCNTL的ENDERROR位实现，需要映射到FDI的相应错误指示
- FDI的fdi_pl_flit_cancel和fdi_pl_error需要正确映射回CXS的错误响应
- Bridge需要维护错误计数器和状态寄存器

**4. 链路管理：**
- Link Activation/Deactivation流程需要跨CXS和FDI协调
- FDI的fdi_pl_state_sts变化需要正确映射到CXS的Link状态
- Retrain处理需要暂停数据传输，等待链路恢复

### 3.5.5 可选信号设计处理方案

根据AMBA CXS Protocol Specification，部分信号为可选信号。本设计通过以下方式处理：

#### 3.5.5.1 可选信号列表与处理方案

| 信号类别 | 信号名称 | CXS协议属性 | 本设计处理方案 |
|----------|----------|-------------|----------------|
| 数据信号 | CXSLAST | 可选 (Y) | **配置选择**: 通过参数 `CXS_HAS_LAST` 决定是否包含；当CXS_MAX_PKT_PER_FLIT=1时必须为0 |
| 数据信号 | CXSUSER | 可选 (Y) | **配置选择**: 通过参数 `CXS_USER_WIDTH` 决定位宽，0表示不使用(端口可保留并置0) |
| ID信号 | CXSSRCID | 可选 (Y) | **配置选择**: 通过参数 `CXS_SRCID_WIDTH` 决定位宽，0表示不使用(端口可保留并置0) |
| ID信号 | CXSTGTID | 可选 (Y) | **配置选择**: 通过参数 `CXS_TGTID_WIDTH` 决定位宽，0表示不使用(端口可保留并置0) |
| 流控信号 | CXSCRDRTN | 可选 (Y) | **默认支持**: 本设计始终支持Explicit Credit Return模式，由credit_mgr处理 |
| 链路控制 | CXSACTIVEREQ | 可选 (通过CXSLINKCONTROL) | **默认支持**: 本设计实现完整链路激活/停用流程 |
| 链路控制 | CXSACTIVEACK | 可选 (通过CXSLINKCONTROL) | **默认支持**: 本设计实现完整链路激活/停用流程 |
| 链路控制 | CXSDEACTHINT | 可选 (通过CXSLINKCONTROL) | **默认支持**: 本设计实现完整链路激活/停用流程 |

#### 3.5.5.2 错误标记处理 (替代POISON信号)

CXS协议中错误标记不是独立的POISON信号，而是通过CXSCNTL字段中的ENDERROR位实现：

| 字段 | 位宽 | 描述 | 本设计处理 |
|------|------|------|-----------|
| START[x:0] | x=CXS_MAX_PKT_PER_FLIT-1 | 包开始指示 | 直接透传到FDI Flit Header |
| END[x:0] | x=CXS_MAX_PKT_PER_FLIT-1 | 包结束指示 | 直接透传到FDI Flit Header |
| ENDERROR[x:0] | x=CXS_MAX_PKT_PER_FLIT-1 | 包错误标记 (替代POISON) | **映射到FDI Flit的Error字段** |

**ENDERROR到FDI的映射**:
- 当ENDERROR[n]=1时，表示第n个在该周期结束的包有错误
- 本设计将ENDERROR位映射到FDI Flit Header中的Error指示
- FDI侧通过 `fdi_pl_flit_cancel` 或独立的Error指示传递错误信息

#### 3.5.5.3 RTL参数化设计

```systemverilog
// CXS接口参数化配置
module cxs_tx_if #(
    // 必需参数
    parameter int CXS_DATA_WIDTH        = 512,
    parameter int CXS_CNTL_WIDTH        = 18,    // 512b, MAX_PKT_PER_FLIT=2, 16B对齐的默认值
    parameter int CXS_MAX_PKT_PER_FLIT  = 2,
    parameter int CXS_START_ALIGNMENT   = 16,    // 单位: Byte (4或16)
    
    // 可选信号配置
    parameter bit CXS_HAS_LAST          = 1'b1,  // 1=使用CXSLAST, 0=忽略
    parameter int CXS_USER_WIDTH        = 64,    // 0=不使用(端口可保留并置0)
    parameter int CXS_SRCID_WIDTH       = 8,     // 0=不使用(端口可保留并置0)
    parameter int CXS_TGTID_WIDTH       = 8,     // 0=不使用(端口可保留并置0)
    parameter int CXS_USER_WIDTH_E      = (CXS_USER_WIDTH > 0)  ? CXS_USER_WIDTH  : 1,
    parameter int CXS_SRCID_WIDTH_E     = (CXS_SRCID_WIDTH > 0) ? CXS_SRCID_WIDTH : 1,
    parameter int CXS_TGTID_WIDTH_E     = (CXS_TGTID_WIDTH > 0) ? CXS_TGTID_WIDTH : 1,
    
    // 链路控制配置 (默认启用)
    parameter bit CXS_HAS_LINK_CTRL     = 1'b1   // 1=包含链路控制信号
) (
    // 必需信号
    input  logic                      cxs_clk,
    input  logic                      cxs_rst_n,
    input  logic                      cxs_tx_valid,
    input  logic [CXS_DATA_WIDTH-1:0] cxs_tx_data,
    
    // 可选信号 (端口保留，未使用时置0)
    input  logic [CXS_USER_WIDTH_E-1:0]  cxs_tx_user,
    input  logic                         cxs_tx_last,
    input  logic [CXS_SRCID_WIDTH_E-1:0] cxs_tx_srcid,
    input  logic [CXS_TGTID_WIDTH_E-1:0] cxs_tx_tgtid,
    input  logic                         cxs_tx_active_req,
    output logic                         cxs_tx_active,
    input  logic                         cxs_tx_deact_hint
);

    // 可选信号处理：禁用时置0或忽略
    logic [CXS_USER_WIDTH_E-1:0]  cxs_tx_user_i;
    logic                         cxs_tx_last_i;
    logic [CXS_SRCID_WIDTH_E-1:0] cxs_tx_srcid_i;
    logic [CXS_TGTID_WIDTH_E-1:0] cxs_tx_tgtid_i;

    assign cxs_tx_user_i  = (CXS_USER_WIDTH  > 0) ? cxs_tx_user  : '0;
    assign cxs_tx_last_i  = CXS_HAS_LAST ? cxs_tx_last : 1'b0;
    assign cxs_tx_srcid_i = (CXS_SRCID_WIDTH > 0) ? cxs_tx_srcid : '0;
    assign cxs_tx_tgtid_i = (CXS_TGTID_WIDTH > 0) ? cxs_tx_tgtid : '0;
    
    // ... 其他可选信号类似处理
endmodule
```

#### 3.5.5.4 ENDERROR处理RTL实现

```systemverilog
// CXSCNTL字段解析
// CXSCNTL格式 (以CXS_MAX_PKT_PER_FLIT=2为例):
// CXSCNTL[5:3] = START[1:0], PTR_START
// CXSCNTL[2:0] = END[1:0], PTR_END
// 当包含ENDERROR时，额外增加2位:
// CXSCNTL[7:6] = ENDERROR[1:0]

// ENDERROR位提取
// 注：ENDERROR_LSB/ERROR_POS 为设计相关常量，这里给出示例占位值
localparam bit CXS_CNTL_HAS_ENDERROR = 1'b1;
localparam int ENDERROR_LSB          = 0;
localparam int ERROR_POS             = 0;

logic [CXS_MAX_PKT_PER_FLIT-1:0] enderror_bits;
assign enderror_bits = CXS_CNTL_HAS_ENDERROR ? cxs_tx_cntl[ENDERROR_LSB +: CXS_MAX_PKT_PER_FLIT] : '0;

// ENDERROR到FDI映射
// 将ENDERROR映射到FDI Flit Header的Error字段（示例：错误位段位于ERROR_POS）
assign fdi_lp_flit[ERROR_POS +: CXS_MAX_PKT_PER_FLIT] = enderror_bits;
```

### 3.6 协议条款可追溯性 / Protocol Traceability

本节用于将三份协议关键规则与本规格对应章节建立映射，便于一致性审核。

| 来源协议 | 关键规则（摘要） | 本规格覆盖位置 |
|----------|------------------|----------------|
| AMBA CXS (IHI0079D) | CXSCRDGNT→CXSVALID 必须隔离至少 1 周期，禁止组合路径 | 3.2.1 CXS TX时序关键要求 |
| AMBA CXS (IHI0079D) | CXSCRDRTN 与 CXSVALID 不得同周期同时断言 | 3.2.1 CXS TX时序关键要求 |
| AMBA CXS (IHI0079D) | 当 CXS_MAX_PKT_PER_FLIT=1 时，CXSCNTLWIDTH=0 且 CXSLAST/CXS_PROTOCOL_TYPE 禁用 | 11.1 参数规则；3.2 CXS信号子集说明；1.3 Non-Goals |
| AMBA CXS (IHI0079D) | 复位期间 CXSVALID/CXSCRDGNT/CXSCRDRTN 必须为低 | 4.3 复位时序要求 |
| UCIe FDI (Rev 3.0) | Rx_active_req/Sts 需握手，禁止组合环路，至少 1 周期隔离 | 3.3.2 FDI RX时序说明 |
| UCIe FDI (Rev 3.0) | Rx_active_req 仅影响接收通道激活，不改变发送通道 | 3.3.2 FDI RX时序说明；5.1.8 FDI RX Interface |
| UCIe FDI (Rev 3.0) | FDI 信号列表包含管理/功耗/扩展错误信号（本设计子集支持） | 1.3 Non-Goals；3.3 FDI信号子集说明与支持表 |
| UCIe FDI (Rev 3.0) | Rx_active_req/Sts 规则1：pl_rx_active_req 上升沿仅在 lp_rx_active_sts=0 且 pl_state_sts 为 Reset/Retrain/Active | 3.3.2 FDI RX时序说明；3.3.3 Physical Layer接口 |
| UCIe FDI (Rev 3.0) | Rx_active_req/Sts 规则2：lp_rx_active_sts 在 pl_rx_active_req 之后断言，至少 1 周期隔离 | 3.3.2 FDI RX时序说明 |
| UCIe FDI (Rev 3.0) | Rx_active_req/Sts 规则4：pl_rx_active_req 下降沿仅在 lp_rx_active_sts=1 时有效，触发 lp_rx_active_sts 解除 | 5.1.4 Link Control；5.3.2 Retrain处理流程 |
| UCIe FDI (Rev 3.0) | Rx_active_req/Sts 规则5：退出 Active 前 pl_rx_active_req 与 lp_rx_active_sts 必须先去断言 | 5.2 状态机；5.3.2 Retrain处理流程 |
| UCIe FDI (Rev 3.0) | Rx_active_req/Sts 规则6：pl_rx_active_req=0 时 Adapter 不得向 Protocol 发送 Flit | 3.3.2 FDI RX时序说明 |
| CHI C2C (IHI0098A.b) | C2C-specific 消息由协议层生成/解析，Bridge不解析语义 | 3.5.3 CHI C2C协议层映射 |
| CHI C2C (IHI0098A.b) | Credit 与消息类型绑定，需多 Credit 计数器 | 3.5.3 CHI C2C协议层映射 |
| CHI C2C (IHI0098A.b) | Activation/Deactivation 受 Link State 约束 | 5.2 状态机；3.5.3 映射说明 |

---

## 4. 时钟与复位 / Clocks and Resets

### 4.1 时钟域 / Clock Domains

| 时钟名称 | 频率 | 频率范围 | 描述 | 所属模块 |
|----------|------|----------|------|----------|
| cxs_clk | 1.5 GHz | 1.5 GHz | CXS侧协议时钟，与CXS接口同步 | CXS TX/RX接口、TX/RX Path Logic、Credit Manager、Link Ctrl FSM |
| fdi_lclk | 1.5 GHz | 1.5 GHz | FDI侧链路时钟，与UCIe链路同步 | FDI TX/RX接口 |
| apb_clk | 100 MHz | - | APB配置/调试时钟 | Register Module |

**时钟关系：**
- cxs_clk与fdi_lclk频率相同，相位不固定
- apb_clk用于低速配置和调试接口
- 异步FIFO位于cxs_clk与fdi_lclk时钟域边界，实现跨时钟域数据传递

### 4.2 跨时钟域 / Clock Domain Crossings (CDC)

| 源时钟 | 目标时钟 | 信号类型 | 同步方式 | 描述 |
|--------|----------|----------|----------|------|
| cxs_clk | fdi_lclk | 数据信号 | 异步FIFO (格雷码) | TX方向数据传输 |
| fdi_lclk | cxs_clk | 数据信号 | 异步FIFO (格雷码) | RX方向数据传输 |
| fdi_lclk | cxs_clk | 状态信号 | 2级同步器 | FDI状态反馈（fdi_pl_state_sts/fdi_pl_error/fdi_pl_idle等） |
| fdi_lclk | cxs_clk | 控制信号 | 2级同步器 | fdi_pl_rx_active_req 同步到cxs_clk |
| cxs_clk | fdi_lclk | 控制信号 | 2级同步器 | fdi_lp_rx_active_sts 同步到fdi_lclk |

**CDC设计准则：**
1. 所有数据信号必须通过异步FIFO进行跨时钟域传输
2. 控制/状态信号使用2级同步器进行同步
3. FIFO指针使用格雷码编码，防止指针跳变错误
4. 复位信号使用异步断言、同步释放机制
5. Link Control FSM仅运行在cxs_clk域，所有来自FDI侧的状态信号必须先同步到cxs_clk

### 4.3 复位域 / Reset Domains

| 复位名称 | 有效电平 | 类型 | 同步/异步 | 作用范围 | 描述 |
|----------|----------|------|-----------|----------|------|
| cxs_rst_n | Low | 局部 | 异步断言，同步释放 | cxs_clk域 | CXS接口复位 |
| fdi_rst_n | Low | 局部 | 异步断言，同步释放 | fdi_lclk域 | FDI接口复位 |
| apb_rst_n | Low | 局部 | 同步 | apb_clk域 | APB复位 |
| rst_sw | High | 软件 | 同步 | apb_clk域 | 软件复位 |

**复位顺序：**
1. 异步复位断言 (cxs_rst_n/fdi_rst_n = 0)
2. 同步释放 cxs_rst_n (延迟3个时钟周期)
3. 同步释放 fdi_rst_n (延迟3个时钟周期)
4. 释放 apb_rst_n (延迟1个时钟周期)

**复位时序要求：**
- 复位脉冲宽度：最小4个时钟周期
- 复位释放到功能启动：最大20个时钟周期
- 异步FIFO复位：需要确保FIFO空满状态正确初始化
- 复位期间CXS侧控制信号(CXSVALID/CXSCRDGNT/CXSCRDRTN)必须保持低电平

---

## 5. 功能描述 / Functional Description

### 5.1 功能概述 / Functional Overview

UCIe CXS-FDI Bridge的核心功能是实现CXS协议与FDI协议之间的透明转换，同时处理时钟域差异、流量控制、链路状态管理和错误处理。模块采用全双工架构，TX和RX路径独立工作，通过异步FIFO实现时钟域隔离。

**核心功能模块说明：**

#### 5.1.1 TX Path Logic (发送通道)
- **职责**: 处理从CXS接口到FDI接口的数据发送，包含TX Async FIFO实现跨时钟域缓冲
- **输入**: cxs_tx_valid, cxs_tx_data, cxs_tx_user, cxs_tx_cntl等
- **输出**: fdi_lp_valid, fdi_lp_flit, fdi_lp_stream等 (FDI TX Interface输出)，可选fdi_lp_dllp(_valid)
- **处理流程**: CXS TX Interface → TX Path Logic (含 TX Async FIFO) → FDI TX Interface → 发送到UCIe Adapter
- **子模块**:
  - TX Async FIFO: 异步FIFO缓冲，64-depth，格雷码指针
  - TX Error Handler: 错误检测与处理

#### 5.1.2 RX Path Logic (接收通道)
- **职责**: 处理从FDI接口到CXS接口的数据接收，包含RX Async FIFO实现跨时钟域缓冲
- **输入**: fdi_pl_valid, fdi_pl_flit, fdi_pl_stream等 (FDI RX Interface输入)，可选fdi_pl_dllp(_valid)
- **输出**: cxs_rx_valid, cxs_rx_data, cxs_rx_user等
- **处理流程**: FDI RX Interface → RX Path Logic (含 RX Async FIFO) → CXS RX Interface → 发送到协议层
- **子模块**:
  - RX Async FIFO: 异步FIFO缓冲，64-depth，格雷码指针
  - RX Error Handler: 错误检测与处理

#### 5.1.3 Credit Manager (信用管理器)
- **职责**: 管理CXS协议的信用机制
- **输入**: credit grant/return信号
- **输出**: 流控信号
- **处理流程**: 信用计数 → 信用分配 → 流控决策
- **子模块**:
  - TX Credit Manager: 发送方向信用管理
  - RX Credit Manager: 接收方向信用管理
  - **时序约束**: credit授权输出为寄存器信号，允许1-cycle延迟；禁止CXSCRDGNT到CXSVALID组合路径
  - **强节流说明**: Retrain期间强制CXSCRDGNT拉低，直到链路恢复

#### 5.1.4 CXS-FDI Link Control (链路控制状态机)
- **职责**: 管理链路激活/停用状态
- **输入**: activation/deactivation请求, FDI状态信号, fdi_pl_rx_active_req
- **输出**: 链路状态信号, fdi_lp_rx_active_sts
- **处理流程**: 状态转换 → 超时处理 → 重试机制
- **子模块**:
  - Link Control FSM: 链路状态机 (3-bit, 7状态)
  - Retrain Handler: 链路重训练处理
  - FDI握手：通过 fdi_pl_rx_active_req/fdi_lp_rx_active_sts 与Adapter完成接收通道激活协商

#### 5.1.5 CXS TX Interface (CXS发送接口)
- **职责**: 接收来自CXS协议层的数据，完成信号解析与处理
- **输入**: cxs_tx_valid, cxs_tx_data, cxs_tx_user, cxs_tx_cntl, cxs_tx_last, cxs_tx_srcid/tgtid等
- **输出**: tx_valid_out, tx_data_out等
- **关键特性**: 
  - 错误标记通过CXSCNTL的ENDERROR位传递
  - 可选信号支持(CXSUSER, CXSLAST, CXSSRCID, CXSTGTID)

#### 5.1.6 CXS RX Interface (CXS接收接口)
- **职责**: 将数据封装为CXS协议格式发送给协议层
- **输入**: rx_valid_in, rx_data_in, rx_user_in等
- **输出**: cxs_rx_valid, cxs_rx_data, cxs_rx_user, cxs_rx_cntl等
- **关键特性**: 
  - 包边界处理(CXSLAST)
  - 可选信号支持

#### 5.1.7 FDI TX Interface (FDI发送接口)
- **职责**: 将数据封装为FDI协议格式发送给UCIe Adapter
- **输入**: tx_valid_in, tx_data_in, tx_cntl_in等
- **输出**: fdi_lp_valid, fdi_lp_flit, fdi_lp_stream, fdi_lp_dllp等
- **关键特性**: 
  - Ready/Valid握手流控
  - DLLP支持
  - 多流ID支持(FDI_STREAM_WIDTH)

#### 5.1.8 FDI RX Interface (FDI接收接口)
- **职责**: 接收来自UCIe Adapter的FDI数据，完成解析
- **输入**: fdi_pl_valid, fdi_pl_flit, fdi_pl_stream, fdi_pl_dllp, fdi_pl_flit_cancel, fdi_pl_rx_active_req等
- **输出**: rx_valid_out, rx_data_out, rx_user_out, fdi_lp_rx_active_sts等
- **关键特性**: 
  - Ready/Valid握手接收
  - Flit Cancel处理
  - DLLP支持
  - Rx_active_req/sts握手

#### 5.1.9 LME Handler (链路管理交换)
- **职责**: 实现CXS和FDI两侧的边带接口交互，完成链路参数协商
- **输入**: CXS边带信号, FDI边带信号
- **输出**: 链路协商结果
- **关键特性**: 
  - CXS边带接口(cxs_sb_*)
  - FDI边带接口(fdi_sb_*)
  - 链路参数交换
  - **说明**: 本规格仅定义边带交换的存在性，具体信号集合和时序需参考协议规范并在后续章节补充

#### 5.1.10 APB Interface & Registers (配置调试接口)
- **职责**: 提供APB配置接口和状态寄存器访问
- **输入**: APB信号(apb_paddr, apb_pwdata, apb_pwrite等)
- **输出**: apb_prdata, apb_pready, apb_pslverr
- **关键特性**: 
  - CSR寄存器文件
  - 性能计数器
  - 错误状态寄存器

### 5.2 状态机 / State Machines

#### 5.2.1 Link Activation状态机

**状态图（3-bit编码，7状态）：**
```
                     ┌─────────────┐
               ┌─────│    STOP    │◄─────┐
               │     └──────┬──────┘      │
               │            │             │
               │            ▼             │
               │     ┌─────────────┐     │
               │     │ ACTIV_REQ   │     │
               │     └──────┬──────┘     │
               │            │             │
               │            ▼             │
               │     ┌─────────────┐     │
               │     │ ACTIV_ACK   │     │
               │     └──────┬──────┘     │
               │            │             │
               │            ▼             │
               │     ┌─────────────┐     │
               └─────│    RUN     │──────┘
                     └──────┬──────┘
                            │
            ┌───────────────┼───────────────┐
            │               │               │
            ▼               ▼               ▼
     ┌───────────┐   ┌───────────┐   ┌───────────┐
     │   DEACT   │   │ RETRAIN   │   │  ERROR    │
     └─────┬─────┘   └─────┬─────┘   └─────┬─────┘
           │               │               │
           └───────────────┴───────────────┘
```

**状态定义（3-bit编码）：**
| 状态 | 编码 | 描述 | 退出条件 |
|------|------|------|----------|
| STOP | 3'b000 | 链路停止，无数据传输 | active_req==1 |
| ACTIV_REQ | 3'b001 | 激活请求已发送 | ack==1 |
| ACTIV_ACK | 3'b010 | 激活确认，已分配资源 | credit_ready==1 |
| RUN | 3'b011 | 正常运行，数据传输中 | deact_hint==1 |
| DEACT | 3'b100 | 停用处理中 | complete==1 |
| RETRAIN | 3'b101 | 链路训练中 | retrain_done==1 |
| ERROR | 3'b110 | 链路错误状态 | reset 或 软件复位(rst_sw) |

**状态转移表：**
| 当前状态 | 输入条件 | 下一状态 | 输出动作 |
|----------|----------|----------|----------|
| STOP | activation_req==1 | ACTIV_REQ | 发送激活请求 |
| ACTIV_REQ | activation_ack==1 | ACTIV_ACK | 确认激活 |
| ACTIV_REQ | timeout==1 | ERROR | 超时进入错误 |
| ACTIV_ACK | credit_ready==1 | RUN | 开始数据传输 |
| RUN | deactivation_hint==1 | DEACT | 发送停用确认 |
| RUN | retrain==1 | RETRAIN | 链路训练暂停 |
| RUN | fifo_overflow==1 | ERROR | FIFO溢出停机 |
| DEACT | deactivation_complete==1 | STOP | 返回停止状态 |
| RETRAIN | retrain_done==1 | RUN | 恢复数据传输 |
| RETRAIN | fifo_overflow==1 | ERROR | FIFO溢出停机 |
| ERROR | reset==1 或 rst_sw==1 | STOP | 复位返回停止 |

**信号说明：**
- `activation_req` 包含来自 CXS 侧请求以及 `fdi_pl_rx_active_req` 的接收通道激活请求
- `activation_ack` 由 Link Control 统一产生，并通过 `cxs_*_active` 与 `fdi_lp_rx_active_sts` 同步到各接口

### 5.3 典型事务流程 / Example Transactions

#### 5.3.1 基本数据传输流程

**时序图：**
```
cxs_clk:     __|‾‾‾‾|__|‾‾‾‾|__|‾‾‾‾|__|‾‾‾‾|__|‾‾‾‾|__
cxs_tx_valid: ____|‾‾‾‾|___________________
cxs_tx_data:  ----< DATA1 >---------------
fdi_lclk:     __|‾‾‾‾|__|‾‾‾‾|__|‾‾‾‾|__|‾‾‾‾|__|‾‾‾‾|__
fdi_lp_valid: __________________|‾‾‾‾|____
fdi_lp_flit:  ------------------< DATA1 >--
fdi_lp_irdy:  ____|‾‾‾‾|__________________
```

**流程描述：**
1. 协议层发送Flit (cxs_tx_valid=1, cxs_tx_data=DATA1)
2. Bridge接收数据
3. 数据进入TX FIFO缓冲
4. FIFO非空时，Bridge向FDI接口发送数据
5. FDI接口接收数据 (fdi_lp_irdy=1)
6. Bridge完成本次发送

#### 5.3.2 Retrain处理流程

**场景描述**: 物理层链路训练期间的数据处理

**流程：**
1. 检测到fdi_pl_state_sts = Retrain
2. 立即停止FDI发送 (fdi_lp_valid = 0)
3. 阻断CXS侧数据 (通过credit_mgr停止授权)
4. 数据在FIFO中缓冲，不丢弃
5. 若FIFO溢出：置ERR_FIFO_OVERFLOW并进入ERROR/STOP停机
6. 等待链路恢复 (fdi_pl_state_sts = Active)
7. 恢复数据发送，FIFO数据按序发送
8. **fifo_overflow定义**: 当FIFO满时仍发生写入尝试即置位，可配置为保持至复位/软件复位清除

### 5.4 错误处理 / Error Handling

#### 5.4.1 错误类型

| 错误代码 | 错误名称 | 描述 | 严重程度 | 处理方式 |
|----------|----------|------|----------|----------|
| 0x01 | ERR_CXS_PROTO | CXS协议违例 | 高 | 停止传输，记录错误 |
| 0x02 | ERR_FDI_CRC | FDI CRC校验错误 | 高 | 标记数据中毒，记录错误 |
| 0x03 | ERR_FIFO_OVERFLOW | FIFO溢出 | 中 | 停止写入，记录错误并进入ERROR/STOP |
| 0x04 | ERR_FIFO_UNDERFLOW | FIFO下溢 | 中 | 停止读取，记录错误 |
| 0x05 | ERR_LINK_DOWN | 链路断开 | 高 | 进入停止状态，记录错误 |
| 0x06 | ERR_LINK_TIMEOUT | 链路激活超时 | 中 | 记录错误并上报中断（必要时进入重试流程） |
| 0x07 | ERR_LINK_RETRY_FAIL | 链路重试失败 | 中 | 记录错误并上报中断 |

#### 5.4.2 错误处理流程

```
┌─────────────┐
│  错误检测    │ ← 硬件检测/软件配置
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  错误记录    │ ← 写入错误状态寄存器
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  错误报告    │ ← 中断/状态上报
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  错误恢复    │ ← 重试/复位/忽略
└─────────────┘
```

**恢复规则补充：**
- ERR_FIFO_OVERFLOW 的功能恢复仅通过复位或软件复位；状态位可W1C清零

#### 5.4.3 恢复机制

| 错误场景 | 恢复动作 | 恢复时间 | 预期结果 |
|----------|----------|----------|----------|
| CXS协议违例 | 停止传输，等待复位 | 立即 | 避免错误传播 |
| FDI CRC错误 | 标记数据中毒，继续传输 | 1周期 | 数据标记，协议层处理 |
| FIFO溢出 | 进入ERROR/STOP，需复位或软件复位恢复 | 可变 | 防止数据丢失 |
| 链路断开 | 进入停止状态，等待恢复 | 可变 | 链路恢复后继续 |

---

## 6. 配置寄存器 / Configuration Registers (CSRs)

### 6.1 寄存器地址映射 / Register Address Map

**基地址**: `0x[系统分配]`

| 寄存器名 | 地址偏移 | 大小 | 访问类型 | 描述 |
|----------|----------|------|----------|------|
| CTRL | 0x00 | 32-bit | R/W | 控制寄存器 |
| STATUS | 0x04 | 32-bit | R | 状态寄存器 |
| CONFIG | 0x08 | 32-bit | R/W | 配置寄存器 |
| INT_EN | 0x0C | 32-bit | R/W | 中断使能寄存器 |
| INT_STATUS | 0x10 | 32-bit | R/W1C | 中断状态寄存器 |
| ERR_STATUS | 0x14 | 32-bit | R/W1C | 错误状态寄存器 |
| LINK_CTRL | 0x18 | 32-bit | R/W | 链路控制寄存器 |
| TX_FLIT_CNT_L | 0x20 | 32-bit | R | 发送Flit计数低32位 |
| TX_FLIT_CNT_H | 0x24 | 32-bit | R | 发送Flit计数高32位 |
| RX_FLIT_CNT_L | 0x28 | 32-bit | R | 接收Flit计数低32位 |
| RX_FLIT_CNT_H | 0x2C | 32-bit | R | 接收Flit计数高32位 |
| VERSION | 0x30 | 32-bit | R | 版本寄存器 |

### 6.2 寄存器详细定义 / Detailed Register Definitions

#### 6.2.1 控制寄存器 (CTRL) - 偏移: 0x00

| 位域 | 名称 | 访问 | 默认值 | 描述 |
|------|------|------|--------|------|
| [31] | ENABLE | R/W | 0 | 模块使能：1=使能，0=禁用 |
| [30:24] | RESERVED1 | R/W | 0x00 | 保留 |
| [23:16] | MODE | R/W | 0x00 | 工作模式：0=正常，1=测试，2=低功耗 |
| [15:8] | RESERVED2 | R/W | 0x00 | 保留 |
| [7:4] | FLIT_WIDTH | R/W | 0x1 | Flit宽度：0=256b,1=512b,2=1024b,3=2048b |
| [3:1] | RESERVED3 | R/W | 0x00 | 保留 |
| [0] | RESET | R/W1S | 0 | 软件复位：写1复位模块（自清零） |

**字段详细说明：**
- **ENABLE**: 模块全局使能信号。禁用时所有输出保持复位状态
- **MODE**: 工作模式选择
  - 0x00: 正常工作模式
  - 0x01: 测试模式(用于BIST)
  - 0x02: 低功耗模式
- **FLIT_WIDTH**: Flit宽度配置，需与硬件参数匹配
- **RESET**: 写1触发软件复位，自清零

#### 6.2.2 状态寄存器 (STATUS) - 偏移: 0x04

| 位域 | 名称 | 访问 | 默认值 | 描述 |
|------|------|------|--------|------|
| [31:16] | RESERVED | R | 0 | 保留 |
| [15:8] | LINK_STATE | R | 0 | 链路状态 |
| [7:4] | RESERVED2 | R | 0 | 保留 |
| [3] | BUSY | R | 0 | 忙标志：1=操作进行中 |
| [2] | TX_READY | R | 0 | TX路径就绪：1=就绪 |
| [1] | RX_READY | R | 0 | RX路径就绪：1=就绪 |
| [0] | INIT_DONE | R | 0 | 初始化完成：1=完成 |

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

#### 6.2.3 配置寄存器 (CONFIG) - 偏移: 0x08

| 位域 | 名称 | 访问 | 默认值 | 描述 |
|------|------|------|--------|------|
| [31:24] | MAX_CREDIT | R/W | 0x20 | 最大Credit数 (1-63) |
| [23:16] | FIFO_DEPTH | R/W | 0x40 | FIFO深度配置 (8-256) |
| [15:8] | TIMEOUT | R/W | 0xFF | 超时计数(单位：时钟周期) |
| [7:1] | RETRY_CNT | R/W | 0x03 | 最大重试次数 |
| [0] | CREDIT_MODE | R | 1 | Credit退还模式：0=Implicit，1=Explicit（仅参数化，不支持运行时切换） |

#### 6.2.4 中断状态寄存器 (INT_STATUS) - 偏移: 0x10

| 位域 | 名称 | 访问 | 默认值 | 描述 |
|------|------|------|--------|------|
| [31:8] | RESERVED | R | 0 | 保留 |
| [7] | ERR_INT | R/W1C | 0 | 错误中断，写1清除 |
| [6] | LINK_UP_INT | R/W1C | 0 | 链路激活中断，写1清除 |
| [5] | LINK_DOWN_INT | R/W1C | 0 | 链路断开中断，写1清除 |
| [4] | FIFO_ALMOST_FULL | R/W1C | 0 | FIFO接近满中断 |
|     |                  |       |   | 触发条件：FIFO水位≥反压阈值（默认56项） |
| [3:0] | RESERVED2 | R | 0 | 保留 |

#### 6.2.5 错误状态寄存器 (ERR_STATUS) - 偏移: 0x14

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

#### 6.2.6 链路控制寄存器 (LINK_CTRL) - 偏移: 0x18

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

**字段说明：**
- `SW_*` 命令位采用 `0->1` 沿触发语义，软件应在命令被采样后写回0
- `AUTO_RETRY_EN=1` 时，`ACTIV_REQ` 超时可返回 `STOP` 并按 `CONFIG.RETRY_CNT` 限制重试次数
- `FDI_RX_ACTIVE_FOLLOW_EN=0` 时，`fdi_pl_rx_active_req` 不再触发桥侧激活
- `ERROR_STOP_EN=1` 时，严重错误或超时进入 `ERROR/STOP` 路径
- `LINK_CTRL` 由 `regs` 模块存储、由 `cxs_fdi_link_ctrl` 模块解释

### 6.3 寄存器访问规则 / Register Access Rules

**访问类型说明：**
| 类型 | 全称 | 说明 |
|------|------|------|
| R | Read-only | 只读，软件无法修改 |
| W | Write-only | 只写，软件无法读取 |
| R/W | Read/Write | 可读可写 |
| R/W1C | Read/Write-1-to-Clear | 写1清零，写0无效 |
| R/W1S | Read/Write-1-to-Set | 写1置位，写0无效 |

**保留位处理规则：**
1. 软件读取时应忽略保留位的值
2. 软件写入时应写入0以确保向前兼容
3. 硬件应忽略写入保留位的值

**寄存器访问时序：**
- 读延迟：1个时钟周期
- 写延迟：立即生效，下一个周期可读取更新后的值
- 错误状态寄存器：写1清零操作需要1个周期完成

---

## 7. 性能规格 / Performance Specifications

### 7.1 性能指标 / Performance Metrics

#### 7.1.1 稳态性能 / Steady-State Performance

| 指标 | 目标值 | 单位 | 测试条件 | 测试方法 |
|------|--------|------|----------|----------|
| 峰值吞吐量 | 96 | GB/s | 512b Flit, 1.5GHz | 持续满带宽传输 |
| 持续吞吐量 | 90 | GB/s | 长时间运行 | 压力测试 |
| 跨桥延迟 | 10 | ns | 无竞争 | 端到端测量 |
| 带宽利用率 | > 95% | % | 满载 | 统计计数器 |
| Credit周转时间 | 5 | 时钟周期 | 典型场景 | 时序分析 |

#### 7.1.2 瞬态性能 / Transient Performance

| 指标 | 目标值 | 单位 | 条件 |
|------|--------|------|------|
| 突发带宽 | 96 | GB/s | 512b Flit, 突发长度=16 |
| 突发延迟 | 20 | ns | 突发长度=16 |
| 启动延迟 | 15 | 时钟周期 | 从STOP到RUN |
| 关闭延迟 | 10 | 时钟周期 | 从RUN到STOP |
| Retrain恢复时间 | 100 | ns | 链路训练完成 |

#### 7.1.3 队列/缓冲性能

| 指标 | 目标值 | 单位 | 描述 |
|------|--------|------|------|
| TX FIFO深度 | 64 | 项 | 默认配置 |
| RX FIFO深度 | 64 | 项 | 默认配置 |
| 最大Outstanding | 32 | 个 | 未完成请求数 |
| 反压阈值 | 56 | 项 | 触发反压信号（对应FIFO_ALMOST_FULL中断） |
| 缓冲容量 | 8 | KB | 总缓冲存储（默认2×64×512b） |

### 7.2 仲裁与QoS / Arbitration and QoS

**仲裁策略：**
- TX vs RX路径：独立工作，无仲裁
- 多个数据流：基于CXS User bits的简单优先级
- Credit分配：公平轮询，避免饥饿

**优先级定义：**
| 优先级 | 流量类型 | 带宽保证 | 延迟保证 |
|--------|----------|----------|----------|
| 3 (最高) | 控制/状态 | 保证10% | < 50ns |
| 2 (高) | 实时数据 | 保证40% | < 100ns |
| 1 (中) | 普通数据 | 保证30% | < 200ns |
| 0 (最低) | 尽力而为 | 剩余带宽 | 无保证 |

### 7.3 前向进度保证 / Forward Progress Guarantees

**死锁避免：**
- Credit机制确保无死锁：每个Credit对应一个缓冲位置
- 超时机制：链路激活超时自动返回停止状态，并置ERR_LINK_TIMEOUT
- 资源有序分配：FIFO指针使用格雷码，避免竞争

**活锁避免：**
- 有限重试：链路激活最多重试3次，失败置ERR_LINK_RETRY_FAIL
- 退避算法：重试间隔指数增长

**饥饿避免：**
- 公平Credit分配：每个请求者获得公平的Credit份额
- 最小带宽保证：高优先级流量有最小带宽保证

**超时设置：**
| 条件 | 超时值 | 处理动作 |
|------|--------|----------|
| 链路激活超时 | 1024周期 | 返回STOP，置ERR_LINK_TIMEOUT并按重试策略执行 |
| 数据发送超时 | 4096周期 | 错误上报，复位 |
| FIFO满超时 | 512周期 | 流控升级，警告 |

---

## 9. 验证与调试 / Verification and Debug

### 9.1 验证策略 / Verification Strategy

**验证方法：**
| 方法 | 覆盖率目标 | 描述 |
|------|------------|------|
| 随机验证 | > 95% | 基于约束的随机测试，覆盖所有协议场景 |
| 定向测试 | 100% | 关键功能点验证，包括边界条件 |
| 形式验证 | 关键路径 | 断言验证CDC、FSM和协议一致性 |
| FPGA原型 | 100% | 系统级验证，性能测试 |
| 硅后验证 | N/A | 实际芯片测试，参数测量 |

**验证层次：**
1. **模块级验证**：子模块单独验证，包括TX/RX Channel、FIFO、Credit Manager等
2. **集成验证**：模块间集成验证，接口协议一致性
3. **系统级验证**：与CHI协议层和UCIe物理层联合验证
4. **性能验证**：吞吐量、延迟、功耗等性能指标验证
5. **RAS验证**：错误注入与恢复机制验证

### 9.2 测试点 / Testpoints

#### 功能测试点
| 测试项 | 测试方法 | 通过标准 | 优先级 |
|--------|----------|----------|--------|
| 基本数据透传 | 定向 | 数据正确，无丢失 | P0 |
| Flit宽度配置 | 定向 | 256b/512b/1024b/2048b均正确 | P0 |
| CXS Credit机制 | 随机+定向 | Credit计数正确，无死锁 | P0 |
| FDI握手协议 | 定向 | Ready/Valid时序正确 | P0 |
| 时钟域跨越 | 随机 | 异步FIFO无数据丢失 | P0 |
| Retrain处理 | 定向 | 数据缓冲，自动恢复 | P1 |
| Link Activation | 定向 | 状态机转换正确 | P1 |
| 错误检测与上报 | 错误注入 | 错误寄存器记录正确 | P1 |
| 性能测试 | 性能仿真 | 达到性能指标 | P0 |
| 功耗测试 | 功耗分析 | 符合功耗预算 | P1 |

#### 覆盖点
| 覆盖类型 | 目标 | 描述 |
|----------|------|------|
| 功能覆盖 | > 95% | 所有功能场景，包括正常和错误路径 |
| 条件覆盖 | > 90% | 所有条件分支，包括边界条件 |
| 路径覆盖 | 100% | 关键时序路径，包括CDC路径 |
| 断言覆盖 | > 95% | 形式验证断言覆盖 |
| 代码覆盖 | > 90% | RTL代码覆盖率 |

### 9.3 调试功能 / Debug Features

| 调试功能 | 描述 | 访问方式 | 优先级 |
|----------|------|----------|--------|
| 状态寄存器 | 读取当前状态，包括链路状态、FIFO状态 | CSR读取 | P0 |
| 错误计数器 | 统计各类错误发生次数 | CSR读取 | P1 |
| 性能计数器 | 统计Flit计数、Credit使用、带宽等 | CSR读取 | P1 |
| FIFO水位监测 | 实时监测FIFO使用情况 | CSR读取/探针 | P2 |
| 链路状态跟踪 | 记录链路状态转换历史 | CSR读取 | P2 |
| 内部探针 | 关键内部信号观测 | JTAG/LA接口 | P2 |
| 断点控制 | 设置条件断点，暂停数据流 | JTAG调试 | P3 |
| 数据捕获 | 捕获特定数据流进行分析 | 调试接口 | P3 |

**调试接口：**
- **APB调试接口**：用于CSR访问，支持标准APB协议
- **JTAG接口**：用于扫描链调试和内部信号观测
- **逻辑分析仪接口**：预留调试信号引脚，用于硅后调试
- **性能监控接口**：实时性能数据输出，用于系统优化

**调试流程：**
1. **初始化调试**：通过APB接口配置调试模式
2. **状态监测**：读取状态寄存器，了解模块状态
3. **错误诊断**：检查错误寄存器，定位问题根源
4. **性能分析**：读取性能计数器，分析瓶颈
5. **内部信号观测**：通过JTAG/LA观测内部信号
6. **问题复现**：设置断点或条件触发，复现问题
7. **修复验证**：修改配置后验证问题是否解决

---

## 11. 实现细节 / Implementation Details

### 11.1 设计参数 / Design Parameters

UCIe CXS-FDI Bridge采用参数化设计，支持多种配置以满足不同应用场景需求。所有参数在模块实例化时配置，确保设计的灵活性和可重用性。

**核心设计参数：**

| 参数名称 | 类型 | 默认值 | 范围 | 描述 |
|----------|------|--------|------|------|
| CXS_DATA_WIDTH | integer | 512 | [256, 512, 1024, 2048] | CXS数据位宽，对应CXS Flit宽度 |
| CXS_HAS_LAST | bit | 1 | [0, 1] | 是否使用CXSLAST信号 |
| CXS_USER_WIDTH | integer | 64 | [0-128] | CXS用户定义位宽度，0表示不使用 |
| CXS_SRCID_WIDTH | integer | 8 | [0-8] | CXS源ID位宽，0表示不包含 |
| CXS_TGTID_WIDTH | integer | 8 | [0-8] | CXS目标ID位宽，0表示不包含 |
| CXS_CNTL_WIDTH | integer | 18 | [0, 14, 18, 22, 27, 33, 36, 44] | CXS控制字段宽度，取值由CXS_DATA_WIDTH/CXS_MAX_PKT_PER_FLIT/CXS_START_ALIGNMENT决定 |
| CXS_MAX_PKT_PER_FLIT | integer | 2 | >=1 | CXS每Flit最大包数 (用于CXSCNTL位宽计算) |
| CXS_START_ALIGNMENT | integer | 16 | [4, 16] | 包起始对齐粒度(Byte)，影响CXSCNTL位宽 |
| CXS_HAS_LINK_CTRL | bit | 1 | [0, 1] | 是否包含链路控制信号 |
| FDI_DATA_WIDTH | integer | 512 | [256, 512, 1024, 2048] | FDI Flit宽度 |
| FDI_USER_WIDTH | integer | 64 | [0, 32, 64, 128] | FDI用户定义位宽度，0表示不使用 |
| FDI_STREAM_WIDTH | integer | 4 | [0, 2, 4, 8] | FDI流ID位宽，0表示不使用 |
| FDI_DLLP_WIDTH | integer | 32 | [0, 16, 32, 64] | FDI DLLP数据位宽，0表示不使用 |
| FIFO_DEPTH | integer | 64 | [32, 64, 128, 256] | 异步FIFO深度 |
| MAX_CREDIT | integer | 32 | [8, 16, 32, 63] | 最大Credit数量 |
| NUM_CHANNELS | integer | 1 | [1, 2, 4] | 通道数量（预留） |

**参数配置规则：**
1. **CXS_DATA_WIDTH必须等于FDI_DATA_WIDTH**：确保1:1 Flit映射
2. **FIFO_DEPTH ≥ 2×MAX_CREDIT**：避免Credit死锁
3. **时钟频率与数据宽度匹配**：
   - 256b @ 1.5GHz = 48GB/s
   - 512b @ 1.5GHz = 96GB/s
   - 1024b @ 1.5GHz = 192GB/s
   - 2048b @ 1.5GHz = 384GB/s
4. **当CXS_MAX_PKT_PER_FLIT=1时**：`CXS_CNTL_WIDTH` 必须为0，`CXS_HAS_LAST` 必须为0

---

## 15. 设计约束与实现指导 / Design Constraints and Implementation Guidelines

### 15.1 时序约束 / Timing Constraints

UCIe CXS-FDI Bridge工作在高速接口（1.5GHz），需要严格的时序约束以确保信号完整性。

#### 15.1.1 时钟约束

| 时钟名 | 频率 | 周期 | 占空比 | 不确定性 | 抖动 | 源延迟 |
|--------|------|------|--------|----------|------|--------|
| cxs_clk | 1.5 GHz | 667 ps | 50% ± 5% | 20 ps | 10 ps | 50 ps |
| fdi_lclk | 1.5 GHz | 667 ps | 50% ± 5% | 20 ps | 10 ps | 50 ps |
| apb_clk | 100 MHz | 10 ns | 50% ± 10% | 100 ps | 50 ps | 200 ps |

**时钟关系约束：**
- cxs_clk与fdi_lclk为异步时钟，必须通过异步FIFO进行数据传递
- apb_clk用于低速配置接口，与高速时钟异步

#### 15.1.2 输入输出延迟约束

**CXS接口约束：**
- **输入延迟**：数据信号最大200ps，控制信号最大100ps
- **输出延迟**：数据信号最大150ps，控制信号最大80ps
- **建立/保持时间**：满足CXS协议规范要求

**FDI接口约束：**
- **输入延迟**：数据信号最大250ps，控制信号最大120ps
- **输出延迟**：数据信号最大180ps，控制信号最大100ps
- **建立/保持时间**：满足UCIe FDI协议规范要求

#### 15.1.3 跨时钟域约束

**异步FIFO路径约束：**
- **TX路径 (cxs_clk → fdi_lclk)**：最大延迟2.0ns
- **RX路径 (fdi_lclk → cxs_clk)**：最大延迟2.0ns
- **格雷码指针同步**：多周期路径设置（建立时间2周期，保持时间1周期）

#### 15.1.4 关键路径约束

**识别的关键路径：**
1. **Credit计算路径**：Credit计数器→流控信号（目标：< 300ps）
2. **FIFO指针比较路径**：空满判断逻辑（目标：< 250ps）
3. **状态机解码路径**：状态寄存器→输出控制（目标：< 200ps）
4. **数据通路路径**：输入寄存器→FIFO写入（目标：< 350ps）

**流水化指导：**
- Credit授权与FIFO空满比较允许1-cycle流水化，以满足1.5GHz时序
- Link Control相关输出必须寄存器化，禁止跨模块组合路径

### 15.2 实现指导 / Implementation Guidelines

#### 15.2.1 时钟树综合指导

**时钟树结构：**
- **cxs_clk树**：覆盖CXS TX接口、CXS RX接口、TX Path Logic、RX Path Logic、Credit Manager、Link Ctrl FSM、Error Handler
- **fdi_lclk树**：覆盖FDI TX接口、FDI RX接口
- **apb_clk树**：覆盖配置寄存器、APB接口、性能计数器

**时钟树约束：**
- **目标偏差**：cxs_clk/fdi_lclk < 20ps，apb_clk < 50ps
- **时钟门控**：支持精细粒度时钟门控，降低动态功耗
- **时钟域边界**：异步FIFO跨cxs_clk和fdi_lclk时钟域，需要特殊处理

#### 15.2.2 布局布线指导

**模块布局约束：**
- **CXS接口区域**：靠近cxs_clk时钟域，包含CXS TX/RX接口
- **FDI接口区域**：靠近fdi_lclk时钟域，包含FDI TX/RX接口
- **FIFO区域**：位于cxs_clk和fdi_lclk时钟域边界
- **FIFO区域**：异步FIFO靠近时钟域边界
- **接口区域**：CXS/FDI接口信号分组布线

**布线层分配：**
- **水平层**：M1, M3, M5
- **垂直层**：M2, M4, M6
- **电源网络**：VDD_CORE (0.8V), VDD_IO (0.9V), VSS (0.0V)

#### 15.2.3 可测试性设计指导

**扫描链插入：**
- **扫描时钟**：cxs_clk作为主扫描时钟
- **扫描使能**：独立扫描使能信号
- **扫描链顺序**：按模块功能分组，优化测试覆盖率

**MBIST插入：**
- **FIFO存储器BIST**：TX/RX异步FIFO支持MBIST
- **BIST控制器**：独立BIST控制器实例

---

## 文档补充说明

本文档已根据IC设计架构模板补充了关键的实现细节和设计约束章节：

1. **第11章 实现细节**：添加了参数化设计指导
2. **第15章 设计约束**：添加了完整的时序约束和实现指导

**后续可补充内容（根据项目需要）**：
- 第8章：物理设计考虑（面积/功耗估算）
- 第10章：可靠性与安全性
- 第12章：术语表
- 第13章：参考文档
- 第14章：系统集成与时钟域管理（电源管理部分）

当前文档已包含UCIe CXS-FDI Bridge设计的核心规格，可作为RTL实现和物理设计的依据。
