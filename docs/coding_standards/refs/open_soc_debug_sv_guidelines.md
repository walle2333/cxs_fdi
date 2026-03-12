# Open SoC Debug - SystemVerilog Coding Guidelines

> 来源: https://opensocdebug.readthedocs.io/en/latest/04_implementer/styleguides/systemverilog.html

## 概述

本文档提供在Open SoC Debug项目中使用的SystemVerilog编码指南，旨在提高代码在多种EDA工具间的兼容性。

**兼容工具**: Verilator, VCS, ISim (Vivado Simulator), Vivado Synthesis

---

## 兼容性准则

为提高代码兼容性，请遵循以下准则：

### 1. 避免使用数组化Interface

```systemverilog
// ✗ 避免
interface bus_io[7:0](input bit clk);

// ✓ 推荐
interface bus_io(input bit clk);
```

**问题工具**: ISim, Vivado

### 2. 避免在Interface中使用Functions/Tasks

```systemverilog
// ✗ 避免
interface bus_io(input bit clk);
    function void drive(logic [7:0] data);
endinterface

// ✓ 推荐: 使用clocking block
```

**问题工具**: VCS

### 3. 避免使用简单名称

```systemverilog
// ✗ 避免 - 这些名称可能被误认为是函数
logic length;
logic size;
logic out;
logic in;

// ✓ 推荐
logic data_length;
logic packet_size;
logic data_out;
logic data_in;
```

**问题工具**: ISim

### 4. 使用always_comb而非assign处理struct成员

```systemverilog
// ✗ 避免
struct packed { logic [7:0] a; logic [7:0] b; } data;
assign data.a = 8'h55;

// ✓ 推荐
always_comb begin
    data.a = 8'h55;
end
```

**问题工具**: ISim

### 5. 避免使用Interface作为数据缓冲

```systemverilog
// ✗ 避免
module test;
    bus_io buffer_inst();
endmodule

// Interface不是为此目的设计的
```

**问题工具**: 所有工具

### 6. 避免Interface连接多层层次端口

```systemverilog
// ✗ 避免
// A.data -> B.data -> C.data
// B是A的子模块，C是B的子模块

// ✓ 推荐: 显式端口连接
```

**问题工具**: ISim

### 7. 避免在顶层端口使用Interface

```systemverilog
// ✗ 避免
// Interface在综合后会被展平，导致行为仿真DUT和综合后DUT端口不匹配

// ✓ 推荐: 避免使用interface modport
// 某些工具无法正确检查modport的input/output定义
```

**问题工具**: ISim, Verilator

### 8. 使用always_comb而非always_comb @(*)

```systemverilog
// ✗ 避免
always_comb @(*) begin
    // ...
end

// ✓ 推荐
always_comb begin
    // ...
end
```

**问题工具**: VCS (wild-cased sensitive list是错误)

---

## 总结

在编写SystemVerilog代码时，应优先考虑工具兼容性：
1. 避免使用复杂的语言特性
2. 使用标准的always_ff/always_comb块
3. 避免在接口中使用高级特性
4. 显式连接端口信号
