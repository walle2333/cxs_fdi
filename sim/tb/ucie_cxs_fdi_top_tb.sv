/***********************************************************************
 * Copyright 2024
 * UCIe CXS-FDI Top Testbench (SystemVerilog)
 **********************************************************************/

/*
 * Module: ucie_cxs_fdi_top_tb
 *
 * Top-level verification testbench.
 *
 * Current role:
 * - Validates the existing demo top (`ucie_cxs_fdi_top`) counter behavior
 *
 * Future role:
 * - Serves as the integration-TB scaffold for the full CXS-FDI bridge
 * - Hosts init / negotiation / run / deact / retrain / error scenarios
 */

`timescale 1ns/1ps

module ucie_cxs_fdi_top_tb;

    // =========================================
    // Clock and Reset
    // =========================================
    logic       clk;
    logic       rst_n;
    logic       enable;

    // =========================================
    // Outputs
    // =========================================
    logic [7:0] count;
    logic       overflow;
    int         error_count;

    // =========================================
    // Clock Generation: 10ns period
    // =========================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // =========================================
    // Waveform dump
    // =========================================
    initial begin
        $dumpfile("ucie_cxs_fdi_top_tb.fst");
        $dumpvars(0, ucie_cxs_fdi_top_tb);
    end

    // =========================================
    // DUT Instance
    // =========================================
    ucie_cxs_fdi_top dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .enable   (enable),
        .count    (count),
        .overflow (overflow)
    );

    // =========================================
    // Future Bridge Integration Hookup Template
    // =========================================
    // Once `ucie_cxs_fdi_top` evolves into the full bridge top, this TB
    // should be extended with:
    // 1. CXS-side flit drivers/monitors
    // 2. FDI-side flit drivers/monitors
    // 3. Sideband/LME drivers and message scoreboards
    // 4. APB/CSR access tasks
    // 5. End-to-end state and traffic checkers

    // =========================================
    // Current Demo Test Tasks
    // =========================================
    task automatic check_count_is_zero(input string tag);
        begin
            if (count == 0) begin
                $display("PASS[%0t] %s count is 0", $time, tag);
            end
            else begin
                error_count++;
                $display("FAIL[%0t] %s count expected 0 got %0d", $time, tag, count);
            end
        end
    endtask

    task automatic scenario_demo_enable_off;
        begin
            $display("[%0t] Demo Test: Enable OFF", $time);
            enable = 0;
            #50;
            check_count_is_zero("demo_enable_off");
        end
    endtask

    task automatic scenario_demo_enable_on;
        begin
            $display("[%0t] Demo Test: Enable ON", $time);
            enable = 1;
            #500;
        end
    endtask

    task automatic scenario_demo_async_reset;
        begin
            $display("[%0t] Demo Test: Async Reset", $time);
            rst_n = 0;
            #20;
            check_count_is_zero("demo_async_reset");
            rst_n = 1;
        end
    endtask

    // =========================================
    // Future Bridge Integration Scenarios
    // =========================================
    task automatic scenario_bridge_init;
        begin
            $display("[%0t] Future TB TODO: bridge init sequence", $time);
            // TODO:
            // - release resets for all bridge domains
            // - program CTRL/CONFIG/LINK_CTRL through APB
            // - wait for init_done / negotiated parameters
        end
    endtask

    task automatic scenario_bridge_run;
        begin
            $display("[%0t] Future TB TODO: bridge run sequence", $time);
            // TODO:
            // - drive CXS ingress flits
            // - monitor FDI egress flits
            // - check credit/link-active gating
        end
    endtask

    task automatic scenario_bridge_deact_retrain_error;
        begin
            $display("[%0t] Future TB TODO: deact / retrain / error sequence", $time);
            // TODO:
            // - exercise DEACT_HINT
            // - exercise Retrain entry/exit
            // - inject timeout / protocol error path
        end
    endtask

    // =========================================
    // Main Stimulus
    // =========================================
    initial begin
        error_count = 0;
        $display("=========================================");
        $display("UCIe CXS-FDI Top Testbench Started");
        $display("Time: %0t", $time);
        $display("=========================================");

        // Initialize
        rst_n   = 0;
        enable  = 0;

        // Reset test
        #20;
        rst_n = 1;
        #10;

        // Current demo regression
        scenario_demo_enable_off();
        scenario_demo_enable_on();

        // Demo overflow observation window
        $display("[%0t] Demo Test: Overflow observation", $time);
        #1000;

        scenario_demo_async_reset();

        // Future bridge integration placeholders
        scenario_bridge_init();
        scenario_bridge_run();
        scenario_bridge_deact_retrain_error();

        // End simulation
        #100;
        $display("=========================================");
        $display("Testbench Completed at Time: %0t, error_count=%0d", $time, error_count);
        $display("=========================================");
        $finish;
    end

    // =========================================
    // Monitor
    // =========================================
    always @(posedge clk) begin
        if (enable && rst_n) begin
            $display("[%0t] count=%d overflow=%b", $time, count, overflow);
        end
    end

endmodule: ucie_cxs_fdi_top_tb
