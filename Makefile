#============================================
# IC Design Flow Makefile (通用版)
#============================================

export PATH := $(HOME)/oss-cad-suite/bin:$(PATH)

#=================== 用户配置区域 ===================
# 项目名称 (用于输出文件命名)
PROJECT     = ucie_cxs_fdi_top

# Top 模块名称 (必须与RTL中的top module一致)
TOP_MODULE  = ucie_cxs_fdi_top

# 目录配置
SIM         = sim
RTL_DIR     = design/rtl
TB_DIR      = sim/tb
SIM_BUILD   = sim/build
SIM_LOGS    = sim/logs
SYN_DIR     = frontend/synthesis

# 工具配置
IVERILOG    = iverilog
VVP         = vvp
YOSYS       = yosys
GTKWAVE     = gtkwave
#===================================================

# File Lists (自动获取目录下所有.sv文件)
RTL_FILES   = $(wildcard $(RTL_DIR)/*.sv)
TB_FILES    = $(wildcard $(TB_DIR)/*.sv)

# 衍生变量
SIM_OBJ     = $(SIM_BUILD)/$(PROJECT).vvp
WAVE_FILE   = $(SIM_BUILD)/$(PROJECT).fst
SYN_NETLIST = $(SYN_DIR)/$(PROJECT).v

.PHONY: all sim synth clean clean-all help

all: sim

sim: $(SIM)/$(PROJECT).done

$(SIM)/$(PROJECT).done: $(RTL_FILES) $(TB_FILES)
	@mkdir -p $(SIM_BUILD) $(SIM_LOGS)
	@echo "=== Compiling $(PROJECT) with iverilog ==="
	$(IVERILOG) -g2012 -o $(SIM_OBJ) $(RTL_FILES) $(TB_FILES) 2>&1 | tee $(SIM_LOGS)/iverilog.log
	@echo "=== Running ==="
	$(VVP) $(SIM_OBJ) -fst -lurm
	@touch $(SIM)/$(PROJECT).done
	@echo "Done. Waveform: $(WAVE_FILE)"

synth: $(SYN_NETLIST)

$(SYN_NETLIST): $(RTL_FILES)
	@mkdir -p $(SYN_DIR)
	@echo "=== Synthesizing $(TOP_MODULE) with yosys ==="
	$(YOSYS) -p "read_verilog -sv $(RTL_FILES); hierarchy -check -top $(TOP_MODULE); proc; opt; synth; write_verilog $(SYN_NETLIST)" 2>&1 | tee $(SYN_DIR)/yosys.log
	@echo "Done. Netlist: $(SYN_NETLIST)"

clean:
	rm -rf $(SIM_BUILD) $(SIM_LOGS) $(SIM)/$(PROJECT).done $(SIM_BUILD)/*.fst

clean-all: clean
	rm -rf $(SYN_DIR) sim/obj_dir

help:
	@echo "=========================================="
	@echo "IC Design Flow - Makefile"
	@echo "=========================================="
	@echo ""
	@echo "【配置】修改 Makefile 前部的变量:"
	@echo "  PROJECT     = $(PROJECT)"
	@echo "  TOP_MODULE = $(TOP_MODULE)"
	@echo "  RTL_DIR    = $(RTL_DIR)"
	@echo "  TB_DIR     = $(TB_DIR)"
	@echo ""
	@echo "【使用】make [target]"
	@echo "  sim         - 运行仿真"
	@echo "  synth       - 运行综合"
	@echo "  clean       - 清理仿真文件"
	@echo "  clean-all   - 清理所有生成文件"
	@echo "  help        - 显示帮助"
	@echo ""
	@echo "【添加新设计】"
	@echo "  1. 修改 PROJECT 和 TOP_MODULE"
	@echo "  2. 将 RTL 文件放入 $(RTL_DIR)/"
	@echo "  3. 将 TB 文件放入 $(TB_DIR)/"
	@echo ""
