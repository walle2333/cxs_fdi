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

# 逐个testbench回归
make regress

# 仅打开波形
make wave

# 仅综合
make synth

# 清理
make clean
```

### 6.3 回归产物

执行 `make regress` 后，会在 `sim/logs` 下生成以下文件：

| 文件 | 用途 |
|------|------|
| `regress.summary` | 人类可读的回归摘要 |
| `regress_status.csv` | 适合脚本处理的表格结果 |
| `regress_status.json` | 适合CI/自动化工具消费的结构化结果 |
| `regress_junit.xml` | 适合 GitLab CI / Jenkins / GitHub Actions 等平台展示测试结果 |
| `<tb>.iverilog.log` | 单个 testbench 的编译日志 |
| `<tb>.vvp.log` | 单个 testbench 的运行日志 |

`regress_status.csv/json` 当前包含以下字段：

- `tb`
- `result`
- `compile_warnings`
- `run_error_markers`
- `elapsed_ms`

推荐用法：

1. 本地开发时先运行 `make sim`
2. 提交前运行 `make regress`
3. 需要综合检查时运行 `make synth`
4. 在CI中优先收集 `regress_junit.xml` 和 `regress_status.json`

### 6.4 GitHub Actions 最小配置

仓库当前提供了一个最小 CI 样板：

- `.github/workflows/ci.yml`

该工作流会在 `push`、`pull_request` 和手工触发时执行以下步骤：

1. checkout 仓库
2. 安装 `iverilog` 与 `yosys`
3. 运行 `make regress`
4. 运行 `make regress-matrix`
5. 运行 `make sim`
6. 运行 `make synth`
7. 上传 regression 与 synthesis 产物

### 6.5 顶层参数矩阵回归

当前 `Makefile` 还提供了一个轻量级的顶层参数矩阵入口：

```bash
make regress-matrix
```

该目标用于对 `ucie_cxs_fdi_top_tb` 做少量 compile-time 参数扫描，当前内置 case 包括：

- `default`
- `fifo64_last0`
- `fifo128_last1`
- `fifo256_last1`
- `opt_fields_off`
- `single_pkt_mode`
- `credit8_fifo64`
- `user128`
- `srcids_off`
- `user32`

当前主要扫描的参数为：

- `FIFO_DEPTH`
- `CXS_HAS_LAST`
- `CXS_USER_WIDTH`
- `CXS_SRCID_WIDTH`
- `CXS_TGTID_WIDTH`
- `CXS_CNTL_WIDTH`

产物包括：

- `sim/logs/regress_matrix.summary`
- `sim/logs/regress_matrix.csv`
- `sim/logs/<case>.matrix.iverilog.log`
- `sim/logs/<case>.matrix.vvp.log`

### 6.6 Verilator 顶层 Smoke

当前 `Makefile` 还提供了一个 Verilator 顶层 smoke 入口：

```bash
make verilate
```

该目标会：

1. 使用 `verilator` 构建 `ucie_cxs_fdi_top`
2. 编译 `sim/verilator_top_main.cpp`
3. 运行一个最小顶层 smoke 场景
4. 生成波形与构建日志

当前主要产物包括：

- `sim/logs/verilator.log`
- `sim/obj_dir/Vucie_cxs_fdi_top`
- `sim/waves/verilator_top.vcd`
- `docs/release/README.md`
- `docs/release/milestone_2026_03_bridge_bringup.md`
- `docs/release/release_prep_v0_1.md`

当前 `sim/logs/verilator.log` 已收敛到 `0` 个 warning/error marker。

当前上传的核心产物包括：

- `sim/logs/regress.summary`
- `sim/logs/regress_status.csv`
- `sim/logs/regress_status.json`
- `sim/logs/regress_junit.xml`
- `frontend/synthesis/yosys.log`
- `frontend/synthesis/ucie_cxs_fdi_top.v`

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

## 8. 当前项目状态

当前项目自动化流程已经具备以下入口：

- `make sim`
  - 运行顶层 `ucie_cxs_fdi_top_tb`
- `make regress`
  - 逐个编译并运行全部模块级与顶层 testbench
- `make regress-matrix`
  - 运行顶层参数矩阵回归
- `make verilate`
  - 构建并运行 Verilator 顶层 smoke
- `make synth`
  - 对 `ucie_cxs_fdi_top` 进行 Yosys 综合

当前执行结果：

- `make sim`：PASS
- `make regress`：11/11 PASS
- `make regress-matrix`：10/10 PASS
- `make verilate`：PASS
- `make synth`：PASS
- regression 编译 warning：0
- Verilator 日志 warning：0
- 顶层 TB 已额外覆盖 `ERROR_STOP_EN=0` timeout 行为和 `FDI_RX_ACTIVE_FOLLOW_EN` 激活行为
- `FDI_RX_ACTIVE_FOLLOW_EN` 场景现已通过顶层真实端口 `fdi_pl_rx_active_req` 驱动，不再依赖 TB `force/release`

当前回归产物路径：

- `sim/logs/regress.summary`
- `sim/logs/regress_status.csv`
- `sim/logs/regress_status.json`
- `sim/logs/regress_junit.xml`
- `sim/logs/regress_matrix.summary`
- `sim/logs/regress_matrix.csv`
- `sim/logs/verilator.log`
- `frontend/synthesis/yosys.log`
- `frontend/synthesis/ucie_cxs_fdi_top.v`
- `sim/waves/verilator_top.vcd`
- `docs/release/README.md`
- `docs/release/milestone_2026_03_bridge_bringup.md`
- `docs/release/release_prep_v0_1.md`

顶层 `ucie_cxs_fdi_top_tb` 当前已覆盖：

- APB 基础访问
- 硬件触发与软件触发的 link activation / deactivation / retrain / error
- TX/RX 单 flit 通路
- TX/RX burst 通路
- credit 边界耗尽与恢复
- RX `flit_cancel` 丢弃路径
- LME 正常 negotiation
- LME `PARAM_REJECT`
- unknown opcode
- timeout
- remote `ERROR_MSG`
- 非法 `ACTIVE_ACK`
- sideband backpressure
- 顶层长期协议检查

相关文档建议一起阅读：

- 项目根目录说明：`README.md`
- 中文说明：`README_zh.md`
- 验证总检查表：`docs/checklist/rtl_tb_verification_checklist.md`
- Testbench执行计划：`docs/checklist/tb_execution_plan.md`

---

## 9. 参考资源

- [Verilator官方文档](https://veripool.org/guide/latest/)
- [Icarus Verilog文档](https://steveicarus.github.io/iverilog/)
- [Yosys官方文档](https://yosyshq.readthedocs.io/projects/yosys/)
- [GTKWave GitHub](https://github.com/gtkwave/gtkwave)

---

## 10. 修订记录

| 版本 | 日期 | 描述 |
|------|------|------|
| 1.0 | 2026-03-08 | 初始版本 |
| 1.1 | 2026-03-25 | 补充当前项目自动化状态、回归产物与顶层覆盖摘要 |
