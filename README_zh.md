# UCIe CXS-FDI 数字设计

[English](README.md) | **简体中文**

[![SystemVerilog](https://img.shields.io/badge/Language-SystemVerilog-blue.svg)](https://ieeexplore.ieee.org/document/8299595)
[![Icarus Verilog](https://img.shields.io/badge/Simulator-Icarus%20Verilog-green.svg)](http://iverilog.icarus.com/)
[![Yosys](https://img.shields.io/badge/Synthesis-Yosys-orange.svg)](http://www.clifford.at/yosys/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

一个 **UCIe（通用芯粒互连标准）CXS（芯粒到芯粒流式传输）FDI（前向数据接口）** RTL 设计项目，在顶层封装器中实现了演示计数器模块。

## 目录

- [✨ 特性](#-特性)
- [🚀 快速开始](#-快速开始)
  - [环境要求](#环境要求)
  - [构建和仿真](#构建和仿真)
  - [运行综合](#运行综合)
- [📁 项目结构](#-项目结构)
- [🛠️ 开发指南](#️-开发指南)
  - [编码规范](#编码规范)
  - [模块模板](#模块模板)
- [🧪 测试](#-测试)
- [📖 文档](#-文档)
- [🤝 贡献](#-贡献)
- [📄 许可证](#-许可证)
- [🙏 致谢](#-致谢)

## ✨ 特性

- 🏗️ **完整的 RTL 设计**：顶层封装器带可配置计数器子模块
- 🧪 **完整验证**：带综合测试用例的 SystemVerilog 测试平台
- 🔧 **开源工具链**：使用 Icarus Verilog、Yosys 和 Verilator
- 📊 **波形调试**：支持 FST 格式的高效波形查看
- 📚 **文档完善**：完整的编码标准和架构规范

## 🚀 快速开始

### 环境要求

安装 [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build)，它提供了所有必需的工具：

```bash
# 下载并安装 OSS CAD Suite
# 访问：https://github.com/YosysHQ/oss-cad-suite-build/releases

# 添加到 PATH
export PATH="$HOME/oss-cad-suite/bin:$PATH"
```

所需工具：
- **Icarus Verilog** (v14.0+) - 仿真
- **Yosys** (v0.62+) - 综合
- **Verilator** (v5.047+) - 高性能仿真
- **GTKWave** - 波形查看

### 构建和仿真

```bash
# 克隆仓库
git clone https://github.com/yourusername/ucie-cxs-fdi.git
cd ucie-cxs-fdi

# 运行仿真
make sim

# 查看波形（需要 GTKWave）
gtkwave sim/build/ucie_cxs_fdi_top_tb.fst
```

### 运行综合

```bash
# 运行 Yosys 综合
make synth

# 查看综合后的网表
cat frontend/synthesis/ucie_cxs_fdi_top.v
```

## 📁 项目结构

```
.
├── design/rtl/              # RTL 源文件
│   ├── ucie_cxs_fdi_top.sv  # 顶层模块
│   └── counter.sv           # 可配置计数器
├── sim/tb/                  # 测试平台
│   └── ucie_cxs_fdi_top_tb.sv
├── sim/                     # 仿真产物
│   ├── build/               # 构建输出
│   ├── logs/                # 仿真日志
│   └── waves/               # 波形转储
├── frontend/                # EDA 工作流
│   ├── synthesis/           # 综合输出
│   ├── constraints/         # 时序约束
│   ├── pnr/                 # 布局布线
│   ├── sta/                 # 静态时序分析
│   └── formal/              # 形式验证
├── lib/                     # 库文件
│   ├── standard_cells/      # 标准单元库
│   ├── lef/                 # LEF 格式文件
│   └── lib/                 # Liberty 时序文件
├── docs/                    # 文档
│   ├── coding_standards/    # SystemVerilog 风格指南
│   ├── specification/       # 接口规范
│   ├── flow/                # 自动化流程文档
│   └── templates/           # 文档模板
├── scripts/                 # 工具脚本
│   ├── build/
│   └── utility/
├── Makefile                 # 构建自动化
└── README.md               # 本文件
```

## 🛠️ 开发指南

### 编码规范

本项目遵循严格的 SystemVerilog 编码规范：

- **命名**：信号使用 lowercase_with_underscore，参数使用 UPPERCASE
- **缩进**：4 个空格（不用 Tab）
- **最大行宽**：100 个字符
- **复位约定**：低电平有效（`rst_n`）

完整规范见 [docs/coding_standards/coding_guide.md](docs/coding_standards/coding_guide.md)。

### 模块模板

```systemverilog
/***********************************************************************
 * Copyright 2026 Your Company
 **********************************************************************/

/*
 * Module: module_name
 *
 * 功能简要描述
 */

module module_name #(
    parameter int WIDTH = 8
)(
    input  logic        clk,
    input  logic        rst_n,
    // ... 端口
);

    // ========== 信号定义 ==========
    logic [WIDTH-1:0] data_reg;

    // ========== 逻辑实现 ==========
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_reg <= '0;
        end
        else begin
            // ...
        end
    end

endmodule: module_name
```

## 🧪 测试

测试平台包含以下综合测试：

1. **复位测试**：验证异步复位功能
2. **使能关闭测试**：禁用时计数器不应递增
3. **使能开启测试**：计数器正确递增
4. **溢出检查**：验证溢出标志行为
5. **异步复位**：操作中复位正常工作

运行测试：
```bash
make sim
# 检查控制台输出的 PASS/FAIL 消息
```

## 📖 文档

- **[编码规范](docs/coding_standards/coding_guide.md)** - SystemVerilog 风格指南
- **[自动化流程](docs/flow/automation_flow.md)** - 工具链和工作流文档
- **[架构规范](docs/specification/)** - 接口规范

## 🤝 贡献

1. Fork 本仓库
2. 创建功能分支（`git checkout -b feature/amazing-feature`）
3. 遵循 `docs/coding_standards/coding_guide.md` 中的编码规范
4. 运行 `make sim` 验证你的更改
5. 提交更改（`git commit -m 'Add amazing feature'`）
6. 推送到分支（`git push origin feature/amazing-feature`）
7. 创建 Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件。

## 🙏 致谢

- [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build) - 开源 EDA 工具链
- [Icarus Verilog](http://iverilog.icarus.com/) - 仿真
- [Yosys](http://www.clifford.at/yosys/) - 综合
- [UCIe Consortium](https://www.ucie.org/) - 芯粒互连规范

---

**注意**：这是一个用于教育目的的演示项目。对于生产设计，还需要额外的验证、时序分析和物理实现步骤。
