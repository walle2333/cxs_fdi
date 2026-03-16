# IC Design Project Knowledge Base

**Project**: UCIe CXS-FDI Digital Design  
**Type**: ASIC/FPGA RTL Design (SystemVerilog)  
**Stack**: Icarus Verilog / Yosys / Verilator  

---

## OVERVIEW

This is a **UCIe (Universal Chiplet Interconnect Express) CXS (Chiplet-to-Chiplet Streaming) FDI (Forward Data Interface)** RTL design project. It implements a demonstration counter module within a top-level wrapper to showcase the UCIe CXS interface architecture.

**Current State**: Early-stage proof-of-concept (~585 lines SystemVerilog)

---

## STRUCTURE

```
.
├── design/rtl/              # RTL source files (SystemVerilog)
│   ├── ucie_cxs_fdi_top.sv  # Top-level module (entry point)
│   └── counter.sv           # Configurable counter submodule
├── sim/tb/                  # Testbenches
│   └── ucie_cxs_fdi_top_tb.sv
├── sim/                     # Simulation artifacts (build/, logs/, waves/)
├── frontend/                # EDA tool workflows
│   ├── synthesis/           # Yosys synthesis output
│   ├── constraints/         # SDC timing constraints
│   ├── pnr/                 # Place & Route (floorplan/place/route)
│   ├── sta/                 # Static Timing Analysis
│   └── formal/              # Formal verification
├── lib/                     # Library files
│   ├── standard_cells/      # Standard cell libraries
│   ├── lef/                 # LEF (Library Exchange Format)
│   └── lib/                 # Liberty timing files
├── docs/                    # Documentation (see docs/AGENTS.md)
│   ├── coding_standards/    # SystemVerilog coding guide
│   ├── specification/       # Interface specs
│   ├── flow/                # Automation flow docs
│   └── templates/           # Doc templates
├── scripts/                 # Utility scripts
│   ├── build/
│   └── utility/
└── Makefile                 # Build automation (iverilog/yosys)
```

---

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| **Start here** | `design/rtl/ucie_cxs_fdi_top.sv` | Top-level RTL entry point |
| **Add new RTL** | `design/rtl/*.sv` | Follow naming: lowercase_with_underscore.sv |
| **Add testbench** | `sim/tb/*_tb.sv` | Follow naming: <module>_tb.sv |
| **Build simulation** | `make sim` | Uses iverilog + vvp |
| **Build synthesis** | `make synth` | Uses Yosys |
| **View waveforms** | `gtkwave sim/build/*.fst` | FST format (compressed) |
| **Coding standards** | `docs/coding_standards/coding_guide.md` | Complete SV style guide |
| **Flow documentation** | `docs/flow/automation_flow.md` | Toolchain + workflow docs |

---

## CONVENTIONS

### Naming (MUST follow)

| Element | Convention | Example |
|---------|------------|---------|
| Files | lowercase_with_underscore | `fifo_controller.sv` |
| Modules | lowercase_with_underscore | `packet_parser_engine` |
| Signals/vars | lowercase_with_underscore | `data_valid`, `wr_data` |
| Parameters | UPPERCASE_WITH_UNDERSCORE | `ADDR_WIDTH`, `MAX_VAL` |
| Typedef | camelCase + suffix | `state_t`, `config_s` |
| Interface def | lowercase + `_io` | `axi4lite_io` |
| Interface inst | `_if` suffix | `apb_if` |

### Code Layout (MUST follow)

- **Indent**: 4 spaces (NO tabs)
- **Max line**: 100 characters
- **begin/end**: Same line as control statement
  ```systemverilog
  // CORRECT
  always_ff @(posedge clk) begin
      if (enable) begin
  
  // WRONG
  always_ff @(posedge clk)
  begin
  ```
- **else**: On its own line
  ```systemverilog
  if (condition) begin
      // ...
  end
  else begin
      // ...
  end
  ```
- **Function calls**: No space between name and parenthesis: `foo(arg1, arg2)`

### Module Structure Template

```systemverilog
/***********************************************************************
 * Copyright YYYY Company
 **********************************************************************/

/*
 * Module: module_name
 *
 * Brief functional description
 *
 * Parameters:
 *   PARAM1 - Description
 *
 * Ports:
 *   clk   - Clock input
 *   rst_n - Async active-low reset
 */

module module_name #(
    parameter int PARAM1 = 8
)(
    input  logic        clk,
    input  logic        rst_n,
    // ... other ports
);

    // ========== Signal Definitions ==========
    logic [PARAM1-1:0] data_reg;

    // ========== Logic Implementation ==========
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

---

## ANTI-PATTERNS (FORBIDDEN)

### NEVER DO

| Anti-Pattern | Why | Correct Approach |
|--------------|-----|------------------|
| **Incomplete if/else in combinational logic** | Creates latches | Always provide complete branches or use default assignment |
| **Using `assign` for complex combinational logic** | Poor readability | Use `always_comb` with proper structure |
| **Arrayed interfaces in ports** | Tool compatibility issues | Use simple ports or flatten arrays |
| **Function/task inside interfaces** | Synthesis issues | Keep interfaces simple |
| **Simple variable names** (`length`, `size`, `out`, `in`) | Conflicts, poor readability | Use descriptive names with context |
| **Combinational paths from credit grant to data valid** | Protocol violation, timing issues | Register all credit-related outputs |
| **CDC without synchronizers** | Metastability, data corruption | Always use 2-3 stage synchronizers or async FIFO |

### ALWAYS DO

| Pattern | Implementation |
|---------|----------------|
| **Use `always_comb` for combinational logic** | `always_comb begin ... end` |
| **Use `always_ff` for sequential logic** | `always_ff @(posedge clk or negedge rst_n)` |
| **Use `logic` type for all signals** | `logic [7:0] data;` not `reg` or `wire` |
| **Active-low reset with `_n` suffix** | `input logic rst_n` |
| **Complete if/else in combinational blocks** | Provide else branch or default assignment |
| **Parameterized designs** | `parameter int WIDTH = 8` |
| **FIFO depth as power of 2** | `parameter int DEPTH = 16` (2^n) |
| **Two-process FSM** | Separate `always_ff` for state register, `always_comb` for next state logic |
| **Async FIFO for CDC** | Use verified async FIFO for cross-clock data transfers |

---

## COMMANDS

### Quick Start

```bash
# 1. Build and run simulation
make sim

# 2. View waveforms (requires GTKWave)
gtkwave sim/build/*.fst

# 3. Run synthesis
make synth

# 4. Clean build artifacts
make clean
```

### Makefile Targets

| Target | Command | Description |
|--------|---------|-------------|
| `sim` | `make sim` | Compile RTL + TB with iverilog, run with vvp |
| `synth` | `make synth` | Synthesize with Yosys, output netlist |
| `clean` | `make clean` | Remove sim/build/, sim/logs/, .done files |
| `clean-all` | `make clean-all` | Clean + remove frontend/synthesis/ |

### Manual Simulation (Icarus Verilog)

```bash
# Compile
cd /home/walle/project/cxs_fdi
iverilog -g2012 -o sim/build/ucie_cxs_fdi_top.vvp \
    design/rtl/*.sv sim/tb/*.sv

# Run
vvp sim/build/ucie_cxs_fdi_top.vvp -fst

# View waves
gtkwave sim/build/ucie_cxs_fdi_top_tb.fst
```

### Manual Synthesis (Yosys)

```bash
cd /home/walle/project/cxs_fdi
yosys -p "
    read_verilog -sv design/rtl/*.sv;
    hierarchy -check -top ucie_cxs_fdi_top;
    proc;
    opt;
    synth -top ucie_cxs_fdi_top;
    write_verilog frontend/synthesis/ucie_cxs_fdi_top.v
"
```

---

## NOTES

### Project Context

This is a **UCIe CXS-FDI demonstration project** for chiplet interconnect. The current implementation is a minimal viable example with:
- 1 top-level wrapper (`ucie_cxs_fdi_top`)
- 1 internal counter module (`counter`)
- 1 testbench (`ucie_cxs_fdi_top_tb`)

The architecture documentation exists in `/docs/specification/` but the RTL implementation is intentionally simple for demonstration purposes.

### Toolchain Dependencies

This project uses **OSS CAD Suite** (open-source EDA tools):
- **Icarus Verilog** (v14.0): Simulation
- **Yosys** (v0.62+): Synthesis
- **Verilator** (v5.047): High-performance simulation
- **GTKWave**: Waveform viewing

**No commercial EDA tools required** for basic simulation and synthesis.

### Files That Must Never Be Committed

See `.gitignore` for complete list. Key items:
- Simulation outputs: `*.vvp`, `*.fst`, `*.vcd`, `sim/build/`, `sim/logs/`
- Synthesis outputs: `frontend/synthesis/`, `*.ddc`, `*.svf`
- FPGA bitstreams: `*.bit`, `*.bin`
- Tool artifacts: `work/`, `transcript`, `*.wlf`

### Common Gotchas

1. **Top module name mismatch**: `TOP_MODULE` in Makefile must match actual top-level module name in RTL
2. **Clock/reset polarity**: Project uses `rst_n` (active-low reset) convention
3. **Timescale**: Testbenches use `timescale 1ns/1ps`
4. **Waveform format**: FST format preferred (compressed) over VCD
5. **OSS CAD Suite PATH**: Makefile prepends `$(HOME)/oss-cad-suite/bin` to PATH

### Next Steps for Contributors

1. Read `docs/coding_standards/coding_guide.md` (517 lines of SV conventions)
2. Read `docs/flow/automation_flow.md` for toolchain details
3. Examine existing RTL: `design/rtl/ucie_cxs_fdi_top.sv`, `design/rtl/counter.sv`
4. Run `make sim` to verify setup works
5. Follow module template in coding_guide.md Section 5.1
