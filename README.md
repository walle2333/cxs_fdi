# UCIe CXS-FDI Digital Design

**English** | [简体中文](README_zh.md)

[![SystemVerilog](https://img.shields.io/badge/Language-SystemVerilog-blue.svg)](https://ieeexplore.ieee.org/document/8299595)
[![Icarus Verilog](https://img.shields.io/badge/Simulator-Icarus%20Verilog-green.svg)](http://iverilog.icarus.com/)
[![Yosys](https://img.shields.io/badge/Synthesis-Yosys-orange.svg)](http://www.clifford.at/yosys/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A **UCIe (Universal Chiplet Interconnect Express) CXS (Chiplet-to-Chiplet Streaming) FDI (Forward Data Interface)** RTL design project implementing a demonstration counter module within a top-level wrapper.

## ✨ Features

- 🏗️ **Complete RTL Design**: Top-level wrapper with configurable counter submodule
- 🧪 **Full Verification**: SystemVerilog testbench with comprehensive test cases
- 🔧 **Open Source Toolchain**: Uses Icarus Verilog, Yosys, and Verilator
- 📊 **Waveform Debug**: FST format support for efficient waveform viewing
- 📚 **Well Documented**: Complete coding standards and architecture specifications

## 🚀 Quick Start

### Prerequisites

Install [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build) which provides all required tools:

```bash
# Download and install OSS CAD Suite
# Visit: https://github.com/YosysHQ/oss-cad-suite-build/releases

# Add to your PATH
export PATH="$HOME/oss-cad-suite/bin:$PATH"
```

Required tools:
- **Icarus Verilog** (v14.0+) - Simulation
- **Yosys** (v0.62+) - Synthesis
- **Verilator** (v5.047+) - High-performance simulation
- **GTKWave** - Waveform viewing

### Build and Simulate

```bash
# Clone the repository
git clone https://github.com/yourusername/ucie-cxs-fdi.git
cd ucie-cxs-fdi

# Run simulation
make sim

# View waveforms (requires GTKWave)
gtkwave sim/build/ucie_cxs_fdi_top_tb.fst
```

### Run Synthesis

```bash
# Run Yosys synthesis
make synth

# View synthesized netlist
cat frontend/synthesis/ucie_cxs_fdi_top.v
```

## 📁 Project Structure

```
.
├── design/rtl/              # RTL source files
│   ├── ucie_cxs_fdi_top.sv  # Top-level module
│   └── counter.sv           # Configurable counter
├── sim/tb/                  # Testbenches
│   └── ucie_cxs_fdi_top_tb.sv
├── sim/                     # Simulation artifacts
│   ├── build/               # Build outputs
│   ├── logs/                # Simulation logs
│   └── waves/               # Waveform dumps
├── frontend/                # EDA workflows
│   ├── synthesis/           # Synthesis outputs
│   ├── constraints/         # Timing constraints
│   ├── pnr/                 # Place & Route
│   ├── sta/                 # Static Timing Analysis
│   └── formal/              # Formal verification
├── lib/                     # Library files
│   ├── standard_cells/      # Standard cell libraries
│   ├── lef/                 # LEF format files
│   └── lib/                 # Liberty timing files
├── docs/                    # Documentation
│   ├── coding_standards/    # SystemVerilog style guide
│   ├── specification/       # Interface specifications
│   ├── flow/                # Automation flow docs
│   └── templates/           # Documentation templates
├── scripts/                 # Utility scripts
│   ├── build/
│   └── utility/
├── Makefile                 # Build automation
└── README.md               # This file
```

## 🛠️ Development

### Coding Standards

This project follows strict SystemVerilog coding standards:

- **Naming**: lowercase_with_underscore for signals, UPPERCASE for parameters
- **Indentation**: 4 spaces (no tabs)
- **Max line width**: 100 characters
- **Reset convention**: Active-low (`rst_n`)

See [docs/coding_standards/coding_guide.md](docs/coding_standards/coding_guide.md) for complete guidelines.

### Module Template

```systemverilog
/***********************************************************************
 * Copyright 2026 Your Company
 **********************************************************************/

/*
 * Module: module_name
 *
 * Brief functional description
 */

module module_name #(
    parameter int WIDTH = 8
)(
    input  logic        clk,
    input  logic        rst_n,
    // ... ports
);

    // ========== Signal Definitions ==========
    logic [WIDTH-1:0] data_reg;

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

## 🧪 Testing

The testbench includes comprehensive tests:

1. **Reset Test**: Verify async reset functionality
2. **Enable OFF Test**: Count should not increment when disabled
3. **Enable ON Test**: Count increments correctly
4. **Overflow Check**: Verify overflow flag behavior
5. **Async Reset**: Reset works correctly during operation

Run tests:
```bash
make sim
# Check console output for PASS/FAIL messages
```

## 📖 Documentation

- **[Coding Standards](docs/coding_standards/coding_guide.md)** - SystemVerilog style guide
- **[Automation Flow](docs/flow/automation_flow.md)** - Toolchain and workflow documentation
- **[Architecture Spec](docs/specification/)** - Interface specifications

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Follow the coding standards in `docs/coding_standards/coding_guide.md`
4. Run `make sim` to verify your changes
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build) for the open-source EDA toolchain
- [Icarus Verilog](http://iverilog.icarus.com/) for simulation
- [Yosys](http://www.clifford.at/yosys/) for synthesis
- [UCIe Consortium](https://www.ucie.org/) for the chiplet interconnect specification

---

**Note**: This is a demonstration project for educational purposes. For production designs, additional verification, timing analysis, and physical implementation steps would be required.
