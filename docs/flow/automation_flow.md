# IC设计自动化流程指南

本文档描述基于开源工具的RTL到综合的完整自动化流程。

---

## 1. 工具链概览

你已安装 **OSS CAD Suite**，包含以下可用工具：

| 阶段 | 工具 | 路径 | 版本 |
|------|------|------|------|
| 仿真 | Icarus Verilog | `~/oss-cad-suite/bin/iverilog` | 14.0 |
| 仿真 | Verilator | `~/oss-cad-suite/bin/verilator` | 5.047 |
| 综合 | Yosys | `~/oss-cad-suite/bin/yosys` | 0.62+117 |
| 波形查看 | GTKWave | `/usr/bin/gtkwave` | - *(有依赖问题)* |
| 形式验证 | SymbiYosys | `~/oss-cad-suite/bin/sby` | - |

---

## 2. 仿真工具对比

### 2.1 Icarus Verilog vs Verilator

| 特性 | Icarus Verilog (iverilog) | Verilator |
|------|---------------------------|-----------|
| **原理** | 解释型仿真器 | 编译型(Verilog→C++) |
| **性能** | 慢 (~1x) | 快 (~10-100x) |
| **SystemVerilog** | 部分支持 (`-g2012`) | 良好支持 |
| **波形格式** | VCD, FST, LXT | VCD, FST |
| **调试能力** | 基础 | 强 (linting, coverage) |
| **测试平台** | Verilog | C++/SystemC |

### 2.2 推荐选择

| 场景 | 推荐工具 | 原因 |
|------|---------|------|
| 快速原型/简单验证 | Icarus Verilog | 使用简单，无需编写C++ |
| 高性能仿真/大规模设计 | Verilator | 速度快，支持coverage |
| Linting检查 | Verilator | 强大的静态检查 |
| CI/CD自动化 | Verilator | 可预测的性能 |

### 2.3 波形Debug方案

**推荐流程**：
```
仿真产生波形 → GTKWave查看 → 定位问题 → 修改RTL
```

**支持的波形格式**：
- **VCD**: 通用格式，所有工具兼容，但文件大
- **FST**: 压缩格式，加载快10x，GTKWave推荐

---

## 3. 完整流程设计

### 3.1 流程图

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   RTL设计    │────▶│    仿真     │────▶│    综合     │
│  (SystemVerilog)  │     │ 验证+Debug │     │   Yosys    │
└─────────────┘     └─────────────┘     └─────────────┘
                          │                     │
                          ▼                     ▼
                   ┌─────────────┐     ┌─────────────┐
                   │  GTKWave   │     │   网表输出   │
                   │  波形调试   │     │  (.v/.json) │
                   └─────────────┘     └─────────────┘
```

### 3.2 推荐的仿真+Debug流程 (Verilator)

```bash
# Step 1: 编译 + 生成波形
verilator -cc --exe --trace-vcd --trace-fst \
    -Wall --assert \
    -j 4 \
    -o sim_v design.sv sim_main.cpp

# Step 2: 运行仿真
./obj_dir/Vdesign +trace

# Step 3: 查看波形
gtkwave waveform.fst &
```

### 3.3 备选流程 (Icarus Verilog)

```bash
# Step 1: 编译
iverilog -g2012 -o sim.vvp design.sv tb.v

# Step 2: 运行仿真 (生成FST波形)
vvp sim.vvp -fst

# Step 3: 查看波形
gtkwave dump.fst &
```

---

## 4. 综合流程 (Yosys)

### 4.1 基本综合命令

```bash
# 读取设计
read_verilog -sv design.sv

# 层级处理
hierarchy -check -top top_module
proc
opt

# 高层综合
synth -top top_module

# 输出网表
write_verilog synth_netlist.v
write_json synth.json
```

### 4.2 FPGA综合 (以iCE40为例)

```bash
synth_ice40 -top top_module -json top.json
```

### 4.3 ASIC综合 (通用)

```bash
# 使用标准单元库
read_verilog -sv design.sv
hierarchy -top top_module
synth -top top_module
opt
abc -liberty standard_cells.lib
write_verilog netlist.v
```

---

## 5. 工具使用详解

### 5.1 Verilator 仿真

**命令选项**：

| 选项 | 说明 |
|------|------|
| `-cc` | 生成C++代码 |
| `--exe` | 生成可执行文件 |
| `--trace-vcd` | 启用VCD波形 |
| `--trace-fst` | 启用FST波形(推荐) |
| `--assert` | 启用断言 |
| `--coverage` | 代码覆盖率 |
| `-Wall` | 启用所有警告 |
| `-j N` | 并行编译 |

**C++测试平台示例** (`sim_main.cpp`)：

```cpp
#include "Vdesign.h"
#include "verilated.h"
#include "verilated_fst_c.h"

int main(int argc, char** argv) {
    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);
    
    Vdesign* top = new Vdesign{contextp, "TOP"};
    
    // 波形追踪
    Verilated::traceEverOn(true);
    VerilatedFstC* tfp = new VerilatedFstC;
    top->trace(tfp, 99);
    tfp->open("waveform.fst");
    
    // 时钟生成
    top->clk = 0;
    
    while (!contextp->gotFinish()) {
        contextp->timeInc(5);  // 10ns周期
        top->clk = !top->clk;
        top->eval();
        tfp->dump(contextp->time());
    }
    
    tfp->close();
    top->final();
    delete top;
    delete contextp;
    return 0;
}
```

### 5.2 GTKWave 波形查看

```bash
# 查看FST波形 (推荐)
gtkwave waveform.fst

# 查看VCD波形
gtkwave waveform.vcd

# 使用保存的信号配置
gtkwave -o waveform.fst save.gtkw
```

**信号搜索技巧**：
- 支持正则表达式搜索信号名
- 可分组显示 (按模块层次)
- 可添加标记 (marker) 测量时序

---

## 6. 自动化脚本模板

### 6.1 Makefile 模板

```makefile
# ============================================
# IC设计自动化流程 Makefile
# ============================================

# 工具路径
VERILATOR = verilator
IVERILOG = iverilog
VVP = vvp
YOSYS = yosys
GTKWAVE = gtkwave

# 设计文件
RTL_DIR = design/rtl
TB_DIR = sim/tb
RTL_FILES = $(wildcard $(RTL_DIR)/*.sv)
TB_FILE = $(wildcard $(TB_DIR)/*.sv)

# 输出目录
BUILD_DIR = build
LOGS_DIR = logs
WAVES_DIR = waves

# Verilator设置
VL_FLAGS = -cc --trace-fst -Wall --assert -j 4
VL_TOP = Vtop

.PHONY: all sim wave synth clean

# 默认目标: 完整流程
all: sim wave

# ============================================
# 仿真目标
# ============================================
sim: $(BUILD_DIR)/sim_done

$(BUILD_DIR)/sim_done: $(RTL_FILES) $(TB_FILE)
	@mkdir -p $(BUILD_DIR) $(LOGS_DIR) $(WAVES_DIR)
	@echo "=== Compiling with Verilator ==="
	$(VERILATOR) $(VL_FLAGS) \
		--exe -o $(BUILD_DIR)/$(VL_TOP) \
		$(RTL_FILES) $(TB_FILE) sim_main.cpp \
		2>&1 | tee $(LOGS_DIR)/verilator.log
	@echo "=== Running Simulation ==="
	cd $(BUILD_DIR) && ./$(VL_TOP) +trace=1
	@touch $(BUILD_DIR)/sim_done

# ============================================
# 波形查看
# ============================================
wave: $(BUILD_DIR)/sim_done
	@echo "=== Opening GTKWave ==="
	$(GTKWAVE) $(WAVES_DIR)/waveform.fst &

# ============================================
# 综合目标
# ============================================
synth: $(BUILD_DIR)/synth.v

$(BUILD_DIR)/synth.v: $(RTL_FILES)
	@mkdir -p $(BUILD_DIR)
	@echo "=== Running Yosys Synthesis ==="
	$(YOSYS) -p " \
		read_verilog -sv $(RTL_FILES); \
		hierarchy -check -top top; \
		proc; \
		opt; \
		synth; \
		write_verilog $(BUILD_DIR)/synth.v \
		" 2>&1 | tee $(LOGS_DIR)/yosys.log

# ============================================
# 清理
# ============================================
clean:
	rm -rf $(BUILD_DIR) $(LOGS_DIR) $(WAVES_DIR)
```

### 6.2 运行命令

```bash
# 完整流程 (仿真 + 打开波形)
make all

# 仅仿真
make sim

# 仅打开波形
make wave

# 仅综合
make synth

# 清理
make clean
```

---

## 7. 局限性与注意事项

### 7.1 工具限制

| 限制项 | 说明 |
|--------|------|
| **无开源STA** | 时序分析需商业工具 (PrimeTime) 或 OpenSTA |
| **GTKWave依赖** | 系统GTK库可能有兼容问题 |
| **Verilator限制** | 不支持 SDF timing, specify blocks |
| **Yosys SDC** | 需配合 OpenROAD 才能完整支持 |

### 7.2 建议的工作流程

1. **RTL开发阶段**: 使用 Verilator 快速仿真 + GTKWave 调试
2. **功能验证**: 启用 `--assert` 捕获断言失败
3. **综合**: 使用 Yosys 生成网表
4. **形式验证** (可选): 使用 sby 进行属性检查

---

## 8. 参考资源

- [Verilator官方文档](https://veripool.org/guide/latest/)
- [Icarus Verilog文档](https://steveicarus.github.io/iverilog/)
- [Yosys官方文档](https://yosyshq.readthedocs.io/projects/yosys/)
- [GTKWave GitHub](https://github.com/gtkwave/gtkwave)

---

## 9. 修订记录

| 版本 | 日期 | 描述 |
|------|------|------|
| 1.0 | 2026-03-08 | 初始版本 |
