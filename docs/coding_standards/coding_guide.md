# SystemVerilog 编码规范

## 1. 概述

本文档定义了项目SystemVerilog代码的编码风格指南，旨在提高代码可读性、可维护性和跨工具兼容性。

> **原则**: 代码阅读次数远多于编写次数。保持一致的编码风格是节省工程时间的最简单方法之一。

---

## 2. 命名规范

### 2.1 通用规则

| 类型 | 命名规则 | 示例 |
|------|---------|------|
| 文件名 | lowercase_with_underscore | `fifo_controller.sv` |
| 模块名 | lowercase_with_underscore | `packet_parser_engine` |
| 类名 | lowercase_with_underscore | `eth_agent` |
| 信号/变量 | lowercase_with_underscore | `count_packets`, `data_valid` |
| 参数/常量 | UPPERCASE_WITH_UNDERSCORE | `ADDR_WIDTH`, `DATA_DEPTH` |
| typedef | camelCase + 后缀 | `mode_t`, `config_s`, `state_e` |
| Interface定义 | lowercase + `_io` 结尾 | `axi4lite_io` |
| Interface实例 | `_if` 结尾 | `axi_if` |
| Clocking block | camelCase | `ioDrv` |
| modport | lowercase (单字) | `dut`, `tb` |

### 2.2 信号后缀规则

```systemverilog
// 时钟和复位
input  logic clk,
input  logic rst_n,              // 低电平有效复位
input  logic sys_clk,            // 系统时钟
input  logic pll_locked,         // 锁定信号

// 协议信号
output logic data_valid,
output logic data_ready,
input  logic [31:0] wr_data,
```

### 2.3 常用后缀

| 后缀 | 含义 | 示例 |
|------|------|------|
| `_n` | 低电平有效 | `rst_n`, `enable_n` |
| `_t` | 类型定义 | `state_t`, `config_t` |
| `_s` | 结构体 | `packet_s` |
| `_u` | 联合体 | `data_u` |
| `_e` | 枚举 | `op_mode_e` |
| `_if` | Interface实例 | `apb_if` |
| `_io` | Interface定义 | `apb_io` |

### 2.4 总线信号前缀

根据协议标准添加前缀：

- **APB**: `P_` 前缀 (e.g., `PADDR`, `PWDATA`, `PRDATA`)
- **AHB**: `H_` 前缀 (e.g., `HADDR`, `HWDATA`, `HRDATA`)
- **AXI**: `AW`, `W`, `B`, `AR`, `R` 通道前缀

---

## 3. 代码布局

### 3.1 缩进与空格

- **缩进**: 4空格 (禁止Tab)
- **最大行宽**: 100字符
- **逗号后空格**: `foo(arg1, arg2, arg3)`

```vim
" Vim 配置
set tabstop=4
set shiftwidth=4
set expandtab
```

```elisp
; Emacs 配置
(setq-default indent-tabs-mode nil)
(setq-default tab-width 4)
```

### 3.2 begin/end 风格

```systemverilog
// ✓ 正确: begin 在同一行
always_ff @(posedge clk) begin
    if (enable) begin
        data <= next_data;
    end
end

// ✗ 错误
always_ff @(posedge clk)
begin
    // ...
end
```

### 3.3 if/else 风格

```systemverilog
// ✓ 正确: else 单独一行，始终使用 begin/end
if (condition) begin
    do_something();
end
else begin
    do_other();
end

// ✗ 错误: 容易引入bug
if (condition)
    do_something();    // 未来可能添加代码但忘记加begin

// ✗ 错误: else 位置
if (condition) begin
    do_something();
end else begin
    do_other();
end
```

### 3.4 函数/任务调用

```systemverilog
// ✓ 正确: 函数名与括号间无空格
foo(x, y, z);
void_function bar(arg1, arg2);

// ✗ 错误
foo (x, y, z);
foo( x, y, z );
```

### 3.5 默认参数

```systemverilog
// ✓ 正确: 等号周围无空格
void function foo(name="foo", x=1, y=20)

// ✗ 错误
void function foo(name = "foo", x = 1, y = 20)
```

---

## 4. 注释规范

### 4.1 版权头部

```systemverilog
/***********************************************************************
 * Copyright 2026 Your Company Name
 * All Rights Reserved Worldwide
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 ***********************************************************************/
```

### 4.2 模块文档字符串

```systemverilog
/*
 * Module: fifo_controller
 *
 * FIFO控制器模块，提供同步读写功能
 * 支持可配置深度和阈值中断
 *
 * 参数:
 *   DEPTH - FIFO深度，必须为2的幂次
 *   WIDTH - 数据位宽
 *
 * 端口:
 *   clk     - 时钟输入
 *   rst_n   - 异步低电平复位
 *   wr_en   - 写使能
 *   rd_en   - 读使能
 */
```

### 4.3 行内注释

尽量避免行内注释，保持代码自文档化。

```systemverilog
// ✗ 避免
x = x + 1    // Increment counter

// ✓ 推荐: 代码自解释
x <= x + 1;
```

### 4.4 块注释

```systemverilog
// 这是块注释的第一行
// 这是块注释的第二行
//
// 新的段落

/* 这是另一种块注释风格
 * 可以用于注释代码块
 */
```

---

## 5. 模块设计

### 5.1 模块模板

```systemverilog
/***********************************************************************
 * Copyright 2026 Your Company
 ***********************************************************************/

/*
 * Module: module_name
 *
 * 功能描述...
 */

module module_name #(
    parameter int ADDR_WIDTH = 8,
    parameter int DATA_WIDTH = 32
)(
    input  logic                 clk,
    input  logic                 rst_n,
    
    // 主接口
    input  logic [ADDR_WIDTH-1:0] addr,
    input  logic [DATA_WIDTH-1:0] wdata,
    output logic [DATA_WIDTH-1:0] rdata,
    input  logic                 valid,
    output logic                 ready
);

    // ========== 信号定义 ==========
    logic [DATA_WIDTH-1:0]        data_reg;
    logic                        busy;

    // ========== 逻辑实现 ==========
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_reg <= '0;
            busy     <= 1'b0;
        end
        else begin
            if (valid && !busy) begin
                data_reg <= wdata;
                busy     <= 1'b1;
            end
            else if (busy) begin
                busy <= 1'b0;
            end
        end
    end

    assign rdata  = data_reg;
    assign ready  = !busy;

endmodule: module_name
```

### 2. 参数化设计

```systemverilog
module generic_fifo #(
    parameter int DEPTH = 16,           // FIFO深度
    parameter int WIDTH = 32,            // 数据位宽
    parameter bit ASYNC = 1              // 异步FIFO标志
)(
    // 接口定义
);
```

---

## 6. FSM 状态机

### 6.1 枚举类型定义

```systemverilog
typedef enum logic [2:0] {
    IDLE  = 3'b000,
    SETUP = 3'b001,
    ACCESS = 3'b010,
    PAUSE = 3'b011,
    ERROR = 3'b100
} state_e;
```

### 6.2 两段式FSM (推荐)

```systemverilog
state_e state, next_state;

// 状态寄存器
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        state <= IDLE;
    else
        state <= next_state;
end

// 组合逻辑
always_comb begin
    next_state = state;
    case (state)
        IDLE:  begin
            if (start)
                next_state = SETUP;
        end
        SETUP: begin
            if (setup_done)
                next_state = ACCESS;
            else
                next_state = ERROR;
        end
        // ...
        default: next_state = IDLE;
    endcase
end
```

---

## 7. 时钟域跨越 (CDC)

### 7.1 同步器

```systemverilog
// 2-3级同步器 - 用于单bit信号
logic [2:0] data_sync;
always_ff @(posedge dest_clk or negedge rst_n) begin
    if (!rst_n)
        data_sync <= '0;
    else
        data_sync <= {data_sync[1:0], async_data};
end
assign sync_data = data_sync[2];
```

### 7.2 握手协议

```systemverilog
// 请求-应答跨域
logic req_sync, ack_sync;
logic req_reg, ack_reg;

// 请求同步到目标时钟域
always_ff @(posedge dest_clk or negedge rst_n) begin
    if (!rst_n) begin
        req_sync <= 1'b0;
        req_reg  <= 1'b0;
    end
    else begin
        req_sync <= req;
        req_reg  <= req_sync;
    end
end

// 应答同步回源时钟域
always_ff @(posedge src_clk or negedge rst_n) begin
    if (!rst_n) begin
        ack_sync <= 1'b0;
        ack_reg  <= 1'b0;
    end
    else begin
        ack_sync <= ack;
        ack_reg  <= ack_sync;
    end
end
```

---

## 8. 接口定义

### 8.1 Interface模板

```systemverilog
interface axi4lite_io(input logic clk, input logic rst_n);
    logic [31:0] awaddr;
    logic        awvalid;
    logic        awready;
    logic [31:0] wdata;
    logic        wvalid;
    logic        wready;
    logic [1:0]  bresp;
    logic        bvalid;
    logic        bready;

    clocking master @(posedge clk);
        default input #1ns output #1ns;
        output awaddr, awvalid;
        input  awready;
        output wdata, wvalid;
        input  wready, bresp, bvalid;
        output bready;
    endclocking

    clocking slave @(posedge clk);
        default input #1ns output #1ns;
        input  awaddr, awvalid;
        output awready;
        input  wdata, wvalid;
        output wready, bresp, bvalid;
        input  bready;
    endclocking

    modport master_mp(clocking master);
    modport slave_mp(clocking slave);
endinterface: axi4lite_io
```

---

## 9. 可综合设计要点

### 9.1 组合逻辑

```systemverilog
// ✓ 推荐: always_comb用于next-state、条件组合和mux
always_comb begin
    next_state = state;
    case (state)
        // ...
    endcase
end

// ✓ 推荐: 纯字段提取、位选、拼接、简单布尔关系用assign
assign result = (a & b) | (c & d);
```

补充规则：

- `always_comb` 不要写成过大的“全功能块”，应按作用拆分
- 推荐拆分类别：
  - 输入sanitize
  - 控制位解码
  - request汇总
  - next-state逻辑
  - 输出mux
- 对纯组合的位选/切片/字段提取，优先使用 `assign`
- 对参数化切片或指针拼接，若工具在 `always_comb` 中报敏感表 warning，优先提取为中间 `assign`
- `always_comb` 更适合承载“条件关系”，不适合堆积大量简单切片语句

示例：

```systemverilog
// ✓ 推荐: 将参数化切片提成独立assign
assign fifo_full_cmp_gray = {
    ~rd_gray_sync2[PTR_WIDTH-1:PTR_WIDTH-2],
    rd_gray_sync2[PTR_WIDTH-3:0]
};

always_comb begin
    fifo_full = (wr_gray_next == fifo_full_cmp_gray);
    fifo_empty = (rd_gray == wr_gray_sync2);
end
```

### 9.2 时序逻辑

```systemverilog
// ✓ 推荐: always_ff + 复位
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        counter <= '0;
    end
    else begin
        counter <= counter + 1'b1;
    end
end
```

### 9.3 锁存器避免

```systemverilog
// ✗ 避免: 会生成锁存器
always_comb begin
    if (enable)
        data_out = data_in;
end

// ✓ 推荐: 完整分支
always_comb begin
    if (enable)
        data_out = data_in;
    else
        data_out = '0;
end
```

---

## 10. 工具兼容性

### 10.1 通用规则

- 避免在port中使用数组化interface
- 避免在interface中使用function/task
- 避免简单变量名如`length`, `size`, `out`, `in`
- 使用`always_comb`代替`assign`处理struct成员
- 将大型组合逻辑按功能拆成多个小 `always_comb`
- 对纯切片/拼接/字段提取优先使用 `assign`
- 对参数化位选尽量避免直接堆叠在大型 `always_comb` 中，以提升 Icarus/开源工具兼容性

### 10.2 常用工具

| 工具类型 | 软件 |
|---------|------|
| 仿真 | VCS, ModelSim/QuestaSim, Vivado Simulator, Verilator |
| 综合 | Design Compiler, Vivado Synthesis |
| 形式验证 | Formality, Conformal |
| STA | PrimeTime, Tempus |

---

## 11. 参考资源

### 11.1 在线规范

- [SystemVerilog Style Guide - systemverilog.io](https://www.systemverilog.io/verification/styleguide/)
- [RTL Naming Conventions - Chipress](https://chipress.online/2024/07/29/best-practice-for-rtl-naming-conventions/)
- [BSG SystemVerilog Coding Standards](https://docs.google.com/document/d/1xA5XUzBtz_D6aSyIBQUwFk_kSUdckrfxa2uzGjMgmCU/edit)
- [Open SoC Debug - SystemVerilog Guidelines](https://opensocdebug.readthedocs.io/en/latest/04_implementer/styleguides/systemverilog.html)
- [Verilog Coding Conventions - Private Island](https://privateisland.tech/dev/pi-verilog-conventions)

### 11.2 书籍推荐

- "Verilog and SystemVerilog Gotchas: 101 Common Coding Errors and How to Avoid Them"

---

## 12. 修订历史

| 版本 | 日期 | 修订人 | 描述 |
|------|------|--------|------|
| 1.0 | 2026-03-08 | - | 初始版本 |

---

*本文档基于行业最佳实践编写，适用于中小规模数字IC设计项目。*
