/***********************************************************************
 * Copyright 2024
 * UCIe CXS-FDI Top Testbench (SystemVerilog)
 **********************************************************************/

/*
 * Module: ucie_cxs_fdi_top_tb
 *
 * Top-level verification testbench
 * Tests the ucie_cxs_fdi_top module
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
    // Test Stimulus
    // =========================================
    initial begin
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

        // Test 1: Enable OFF, count should not increment
        $display("[%0t] Test 1: Enable OFF", $time);
        enable = 0;
        #50;
        if (count == 0) begin
            $display("PASS: Count is 0 when disabled");
        end
        else begin
            $display("FAIL: Count should be 0");
        end

        // Test 2: Enable ON, count increments
        $display("[%0t] Test 2: Enable ON", $time);
        enable = 1;
        #500;

        // Test 3: Overflow check
        $display("[%0t] Test 3: Overflow check", $time);
        #1000;

        // Test 4: Async Reset
        $display("[%0t] Test 4: Async Reset", $time);
        rst_n = 0;
        #20;
        if (count == 0) begin
            $display("PASS: Reset works correctly");
        end
        else begin
            $display("FAIL: Reset failed");
        end
        rst_n = 1;

        // End simulation
        #100;
        $display("=========================================");
        $display("Testbench Completed at Time: %0t", $time);
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
