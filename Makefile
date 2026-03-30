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
VERILATOR   = verilator
#===================================================

# File Lists (自动获取目录下所有.sv文件)
RTL_FILES   = $(wildcard $(RTL_DIR)/*.sv)
TB_FILES    = $(wildcard $(TB_DIR)/*.sv)
TOP_TB      = $(TB_DIR)/$(TOP_MODULE)_tb.sv
SIM_TB_FILES = $(TOP_TB)
TB_BASENAMES = $(patsubst $(TB_DIR)/%.sv,%,$(TB_FILES))

# 衍生变量
SIM_OBJ     = $(SIM_BUILD)/$(PROJECT).vvp
WAVE_FILE   = $(SIM_BUILD)/$(PROJECT).fst
SYN_NETLIST = $(SYN_DIR)/$(PROJECT).v
REGRESS_SUMMARY = $(SIM_LOGS)/regress.summary
REGRESS_STATUS  = $(SIM_LOGS)/regress_status.csv
REGRESS_JSON    = $(SIM_LOGS)/regress_status.json
REGRESS_JUNIT   = $(SIM_LOGS)/regress_junit.xml
MATRIX_SUMMARY  = $(SIM_LOGS)/regress_matrix.summary
MATRIX_STATUS   = $(SIM_LOGS)/regress_matrix.csv
MATRIX_CASES    = default fifo64_last0 fifo128_last1 fifo256_last1 opt_fields_off single_pkt_mode credit8_fifo64 user128 srcids_off user32
VL_DIR          = sim/obj_dir
VL_MAIN         = sim/verilator_top_main.cpp
VL_EXE          = $(VL_DIR)/V$(TOP_MODULE)

.PHONY: all sim regress regress-matrix verilate synth clean clean-all help

all: sim

sim: $(SIM)/$(PROJECT).done

$(SIM)/$(PROJECT).done: $(RTL_FILES) $(SIM_TB_FILES)
	@mkdir -p $(SIM_BUILD) $(SIM_LOGS)
	@echo "=== Compiling $(PROJECT) with iverilog ==="
	$(IVERILOG) -g2012 -o $(SIM_OBJ) $(RTL_FILES) $(SIM_TB_FILES) 2>&1 | tee $(SIM_LOGS)/iverilog.log
	@echo "=== Running ==="
	$(VVP) $(SIM_OBJ) -fst -lurm
	@touch $(SIM)/$(PROJECT).done
	@echo "Done. Waveform: $(WAVE_FILE)"

regress:
	@mkdir -p $(SIM_BUILD) $(SIM_LOGS)
	@echo "=== Running module regression ==="
	@rm -f $(REGRESS_SUMMARY) $(REGRESS_STATUS) $(REGRESS_JSON) $(REGRESS_JUNIT)
	@printf "tb,result,compile_warnings,run_error_markers,elapsed_ms\n" > $(REGRESS_STATUS)
	@set -e; \
	total=0; \
	pass=0; \
	fail=0; \
	first_json=1; \
	printf '{\n  "total": %d,\n  "results": [\n' $(words $(TB_BASENAMES)) > $(REGRESS_JSON); \
	printf '<testsuite name="cxs_fdi_regression" tests="%d" failures="0">\n' $(words $(TB_BASENAMES)) > $(REGRESS_JUNIT); \
	for tb in $(TB_BASENAMES); do \
		total=$$((total + 1)); \
		compile_log="$(SIM_LOGS)/$$tb.iverilog.log"; \
		run_log="$(SIM_LOGS)/$$tb.vvp.log"; \
		start_ts=$$(date +%s%3N); \
		printf "[%02d/%02d] %-24s " $$total $(words $(TB_BASENAMES)) "$$tb"; \
		if $(IVERILOG) -g2012 -s $$tb -o $(SIM_BUILD)/$$tb.vvp $(RTL_FILES) $(TB_DIR)/$$tb.sv \
			> $$compile_log 2>&1; then \
			if $(VVP) $(SIM_BUILD)/$$tb.vvp -fst > $$run_log 2>&1; then \
				result="PASS"; \
				pass=$$((pass + 1)); \
				printf "PASS\n"; \
			else \
				result="RUN_FAIL"; \
				fail=$$((fail + 1)); \
				printf "RUN_FAIL\n"; \
				tail -n 20 $$run_log; \
			fi; \
		else \
			result="COMPILE_FAIL"; \
			fail=$$((fail + 1)); \
			printf "COMPILE_FAIL\n"; \
			tail -n 20 $$compile_log; \
		fi; \
		end_ts=$$(date +%s%3N); \
		elapsed_ms=$$((end_ts - start_ts)); \
		compile_warnings=$$(grep -E -c "warning:|sorry:" $$compile_log || true); \
		run_errors=$$(grep -E -c "ERROR\\[|error_count=[1-9]" $$run_log || true); \
		printf "%s,%s,%s,%s,%s\n" "$$tb" "$$result" "$$compile_warnings" "$$run_errors" "$$elapsed_ms" >> $(REGRESS_STATUS); \
		if [ $$first_json -eq 0 ]; then \
			printf ',\n' >> $(REGRESS_JSON); \
		fi; \
		first_json=0; \
		printf '    {"tb":"%s","result":"%s","compile_warnings":%s,"run_error_markers":%s,"elapsed_ms":%s}' \
			"$$tb" "$$result" "$$compile_warnings" "$$run_errors" "$$elapsed_ms" >> $(REGRESS_JSON); \
		printf '  <testcase classname="regress" name="%s" time="0.%03d">' "$$tb" "$$elapsed_ms" >> $(REGRESS_JUNIT); \
		if [ "$$result" = "COMPILE_FAIL" ]; then \
			printf '<failure message="compile failed">' >> $(REGRESS_JUNIT); \
			sed -e 's/&/\\&amp;/g' -e 's/</\\&lt;/g' -e 's/>/\\&gt;/g' $$compile_log >> $(REGRESS_JUNIT); \
			printf '</failure>' >> $(REGRESS_JUNIT); \
		elif [ "$$result" = "RUN_FAIL" ]; then \
			printf '<failure message="run failed">' >> $(REGRESS_JUNIT); \
			sed -e 's/&/\\&amp;/g' -e 's/</\\&lt;/g' -e 's/>/\\&gt;/g' $$run_log >> $(REGRESS_JUNIT); \
			printf '</failure>' >> $(REGRESS_JUNIT); \
		fi; \
		printf '</testcase>\n' >> $(REGRESS_JUNIT); \
	done; \
	printf '\n  ],\n  "passed": %d,\n  "failed": %d\n}\n' $$pass $$fail >> $(REGRESS_JSON); \
	sed -i 's/failures="0"/failures="'$$fail'"/' $(REGRESS_JUNIT); \
	printf '</testsuite>\n' >> $(REGRESS_JUNIT); \
	{ \
		echo "Regression Summary"; \
		echo "=================="; \
		echo "Total TBs : $$total"; \
		echo "Passed    : $$pass"; \
		echo "Failed    : $$fail"; \
		echo "Status CSV: $(REGRESS_STATUS)"; \
		echo "Status JSON: $(REGRESS_JSON)"; \
		echo "JUnit XML : $(REGRESS_JUNIT)"; \
		echo "Log Dir   : $(SIM_LOGS)"; \
	} | tee $(REGRESS_SUMMARY); \
	test $$fail -eq 0

regress-matrix:
	@mkdir -p $(SIM_BUILD) $(SIM_LOGS)
	@echo "=== Running top-level parameter matrix ==="
	@rm -f $(MATRIX_SUMMARY) $(MATRIX_STATUS)
	@printf "case,result,override_args\n" > $(MATRIX_STATUS)
	@set -e; \
	total=0; \
	pass=0; \
	fail=0; \
	for case_name in $(MATRIX_CASES); do \
		total=$$((total + 1)); \
		override_args=""; \
		case "$$case_name" in \
			default) \
				override_args="" ;; \
			fifo64_last0) \
				override_args="-P$(TOP_MODULE).FIFO_DEPTH=64 -P$(TOP_MODULE).CXS_HAS_LAST=0" ;; \
			fifo128_last1) \
				override_args="-P$(TOP_MODULE).FIFO_DEPTH=128 -P$(TOP_MODULE).CXS_HAS_LAST=1" ;; \
			fifo256_last1) \
				override_args="-P$(TOP_MODULE).FIFO_DEPTH=256 -P$(TOP_MODULE).CXS_HAS_LAST=1" ;; \
			opt_fields_off) \
				override_args="-P$(TOP_MODULE).CXS_USER_WIDTH=0 -P$(TOP_MODULE).CXS_SRCID_WIDTH=0 -P$(TOP_MODULE).CXS_TGTID_WIDTH=0" ;; \
			single_pkt_mode) \
				override_args="-P$(TOP_MODULE).CXS_CNTL_WIDTH=0 -P$(TOP_MODULE).CXS_HAS_LAST=0" ;; \
			credit8_fifo64) \
				override_args="-P$(TOP_MODULE).MAX_CREDIT=8 -P$(TOP_MODULE).FIFO_DEPTH=64" ;; \
			user128) \
				override_args="-P$(TOP_MODULE).CXS_USER_WIDTH=128 -P$(TOP_MODULE).FDI_USER_WIDTH=128" ;; \
			srcids_off) \
				override_args="-P$(TOP_MODULE).CXS_SRCID_WIDTH=0 -P$(TOP_MODULE).CXS_TGTID_WIDTH=0" ;; \
			user32) \
				override_args="-P$(TOP_MODULE).CXS_USER_WIDTH=32 -P$(TOP_MODULE).FDI_USER_WIDTH=32" ;; \
			*) \
				echo "Unknown matrix case: $$case_name"; \
				exit 1 ;; \
		esac; \
		compile_log="$(SIM_LOGS)/$$case_name.matrix.iverilog.log"; \
		run_log="$(SIM_LOGS)/$$case_name.matrix.vvp.log"; \
		printf "[%02d/%02d] %-16s " $$total $(words $(MATRIX_CASES)) "$$case_name"; \
		if $(IVERILOG) -g2012 $$override_args -s $(TOP_MODULE)_tb -o $(SIM_BUILD)/$$case_name.matrix.vvp $(RTL_FILES) $(TOP_TB) \
			> $$compile_log 2>&1; then \
			if $(VVP) $(SIM_BUILD)/$$case_name.matrix.vvp -fst > $$run_log 2>&1; then \
				result="PASS"; \
				pass=$$((pass + 1)); \
				printf "PASS\n"; \
			else \
				result="RUN_FAIL"; \
				fail=$$((fail + 1)); \
				printf "RUN_FAIL\n"; \
				tail -n 20 $$run_log; \
			fi; \
		else \
			result="COMPILE_FAIL"; \
			fail=$$((fail + 1)); \
			printf "COMPILE_FAIL\n"; \
			tail -n 20 $$compile_log; \
		fi; \
		printf "%s,%s,\"%s\"\n" "$$case_name" "$$result" "$$override_args" >> $(MATRIX_STATUS); \
	done; \
	{ \
		echo "Parameter Matrix Summary"; \
		echo "========================"; \
		echo "Total Cases : $$total"; \
		echo "Passed      : $$pass"; \
		echo "Failed      : $$fail"; \
		echo "Status CSV  : $(MATRIX_STATUS)"; \
		echo "Log Dir     : $(SIM_LOGS)"; \
	} | tee $(MATRIX_SUMMARY); \
	test $$fail -eq 0

verilate: $(VL_EXE)
	@echo "=== Running Verilator smoke ==="
	@$(VL_EXE)

$(VL_EXE): $(RTL_FILES) $(VL_MAIN)
	@mkdir -p $(SIM_LOGS) $(VL_DIR)
	@echo "=== Building Verilator model for $(TOP_MODULE) ==="
	$(VERILATOR) --cc --exe --build --trace -Wall -Wno-fatal \
		--top-module $(TOP_MODULE) \
		-Mdir $(VL_DIR) \
		$(RTL_FILES) $(VL_MAIN) > $(SIM_LOGS)/verilator.log 2>&1

synth: $(SYN_NETLIST)

$(SYN_NETLIST): $(RTL_FILES)
	@mkdir -p $(SYN_DIR)
	@echo "=== Synthesizing $(TOP_MODULE) with yosys ==="
	$(YOSYS) -p "read_verilog -sv $(RTL_FILES); hierarchy -check -top $(TOP_MODULE); proc; opt; synth -top $(TOP_MODULE); write_verilog $(SYN_NETLIST)" 2>&1 | tee $(SYN_DIR)/yosys.log
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
	@echo "  regress     - 逐个运行所有 testbench 回归"
	@echo "  regress-matrix - 运行顶层参数矩阵回归"
	@echo "  verilate    - 构建并运行 Verilator 顶层 smoke"
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
