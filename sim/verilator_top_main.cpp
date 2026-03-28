/***********************************************************************
 * Verilator smoke runner for ucie_cxs_fdi_top
 **********************************************************************/

#include <cstdint>
#include <filesystem>
#include <iostream>
#include <memory>

#include "Vucie_cxs_fdi_top.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

namespace {

constexpr vluint64_t kMaxTime = 4000;
constexpr int kCxsHalfPeriod = 5;
constexpr int kFdiHalfPeriod = 6;
constexpr int kApbHalfPeriod = 10;

void set_flit_word(WData* bus, std::uint64_t value) {
    for (int idx = 0; idx < 16; ++idx) {
        bus[idx] = 0;
    }
    bus[0] = static_cast<IData>(value & 0xffffffffULL);
    bus[1] = static_cast<IData>((value >> 32) & 0xffffffffULL);
}

}  // namespace

int main(int argc, char** argv) {
    std::filesystem::create_directories("sim/waves");

    auto contextp = std::make_unique<VerilatedContext>();
    contextp->commandArgs(argc, argv);
    contextp->traceEverOn(true);

    auto top = std::make_unique<Vucie_cxs_fdi_top>(contextp.get(), "TOP");
    auto tfp = std::make_unique<VerilatedVcdC>();
    top->trace(tfp.get(), 99);
    tfp->open("sim/waves/verilator_top.vcd");

    top->cxs_clk = 0;
    top->fdi_lclk = 0;
    top->apb_clk = 0;
    top->cxs_rst_n = 0;
    top->fdi_rst_n = 0;
    top->apb_rst_n = 0;
    top->rst_sw = 0;

    top->cxs_tx_valid = 0;
    set_flit_word(top->cxs_tx_data, 0);
    top->cxs_tx_user = 0;
    top->cxs_tx_cntl = 0;
    top->cxs_tx_last = 0;
    top->cxs_tx_srcid = 0;
    top->cxs_tx_tgtid = 0;
    top->cxs_tx_crdret = 0;
    top->cxs_tx_active_req = 0;
    top->cxs_tx_deact_hint = 0;

    top->cxs_rx_crdret = 0;
    top->cxs_rx_active_req = 0;
    top->cxs_rx_deact_hint = 0;

    top->fdi_tx_ready = 1;
    top->fdi_rx_valid = 0;
    set_flit_word(top->fdi_rx_data, 0);
    top->fdi_rx_stream = 0;
    top->fdi_rx_dllp_valid = 0;
    top->fdi_rx_dllp = 0;

    top->fdi_pl_state_sts = 0;
    top->fdi_pl_inband_pres = 0;
    top->fdi_pl_error = 0;
    top->fdi_pl_flit_cancel = 0;
    top->fdi_pl_idle = 1;

    top->cxs_sb_rx_valid = 0;
    top->cxs_sb_rx_data = 0;
    top->cxs_sb_tx_ready = 1;
    top->fdi_sb_rx_valid = 0;
    top->fdi_sb_rx_data = 0;
    top->fdi_sb_tx_ready = 1;

    top->apb_paddr = 0;
    top->apb_pwdata = 0;
    top->apb_penable = 0;
    top->apb_psel = 0;
    top->apb_pwrite = 0;

    std::cout << "=========================================\n";
    std::cout << "UCIe CXS-FDI Verilator Smoke Started\n";
    std::cout << "=========================================\n";

    bool saw_link_active = false;
    bool saw_tx_flit = false;

    for (vluint64_t sim_time = 0; sim_time < kMaxTime && !contextp->gotFinish(); ++sim_time) {
        contextp->timeInc(1);

        if ((sim_time % kCxsHalfPeriod) == 0) {
            top->cxs_clk = !top->cxs_clk;
        }
        if ((sim_time % kFdiHalfPeriod) == 0) {
            top->fdi_lclk = !top->fdi_lclk;
        }
        if ((sim_time % kApbHalfPeriod) == 0) {
            top->apb_clk = !top->apb_clk;
        }

        if (sim_time == 40) {
            top->cxs_rst_n = 1;
        }
        if (sim_time == 48) {
            top->fdi_rst_n = 1;
        }
        if (sim_time == 60) {
            top->apb_rst_n = 1;
        }

        if (sim_time == 120) {
            top->cxs_tx_active_req = 1;
            top->cxs_rx_active_req = 1;
            top->fdi_pl_state_sts = 0x2;
            top->fdi_pl_idle = 0;
            top->fdi_pl_inband_pres = 1;
        }

        if (sim_time == 220) {
            top->cxs_tx_valid = 1;
            set_flit_word(top->cxs_tx_data, 0x12345678ULL);
            top->cxs_tx_user = 0x55aaULL;
            top->cxs_tx_cntl = 0x5;
            top->cxs_tx_last = 1;
            top->cxs_tx_srcid = 0x12;
            top->cxs_tx_tgtid = 0x34;
        }
        if (sim_time == 232) {
            top->cxs_tx_valid = 0;
            set_flit_word(top->cxs_tx_data, 0);
            top->cxs_tx_user = 0;
            top->cxs_tx_cntl = 0;
            top->cxs_tx_last = 0;
            top->cxs_tx_srcid = 0;
            top->cxs_tx_tgtid = 0;
        }

        top->eval();
        tfp->dump(contextp->time());

        if (top->cxs_tx_active && top->cxs_rx_active) {
            saw_link_active = true;
        }
        if (top->fdi_tx_valid) {
            saw_tx_flit = true;
        }
    }

    top->final();
    tfp->close();

    if (!saw_link_active) {
        std::cerr << "ERROR: Verilator smoke did not observe active link\n";
        return 1;
    }
    if (!saw_tx_flit) {
        std::cerr << "ERROR: Verilator smoke did not observe FDI TX flit\n";
        return 1;
    }

    std::cout << "=========================================\n";
    std::cout << "Verilator Smoke Completed PASS\n";
    std::cout << "Waveform: sim/waves/verilator_top.vcd\n";
    std::cout << "=========================================\n";
    return 0;
}
