/***********************************************************************
 * Copyright 2026
 **********************************************************************/

/*
 * Module: fdi_tx_if_tb
 *
 * Skeleton testbench for fdi_tx_if.
 */

`timescale 1ns/1ps

module fdi_tx_if_tb;

    localparam time FDI_CLK_PERIOD = 10ns;
    localparam logic [3:0] FDI_RESET_STS   = 4'b0000;
    localparam logic [3:0] FDI_ACTIVE_STS  = 4'b0010;
    localparam logic [3:0] FDI_RETRAIN_STS = 4'b0011;

    logic         fdi_lclk;
    logic         fdi_rst_n;
    logic [3:0]   fdi_pl_state_sts;
    logic         credit_ready;
    logic         fdi_lp_irdy;
    logic         fdi_lp_valid;
    logic [511:0] fdi_lp_data;
    logic         fdi_pl_error;
    logic         fdi_pl_flit_cancel;
    logic [511:0] hold_data;
    int           error_count;

    initial begin
        fdi_lclk = 1'b0;
        forever #(FDI_CLK_PERIOD / 2) fdi_lclk = ~fdi_lclk;
    end

    initial begin
        fdi_rst_n          = 1'b0;
        fdi_pl_state_sts   = 4'b0000;
        credit_ready       = 1'b0;
        fdi_lp_irdy        = 1'b1;
        fdi_pl_error       = 1'b0;
        fdi_pl_flit_cancel = 1'b0;

        repeat (4) @(posedge fdi_lclk);
        fdi_rst_n = 1'b1;
    end

    initial begin
        $dumpfile("fdi_tx_if_tb.fst");
        $dumpvars(0, fdi_tx_if_tb);
    end

    // DUT hookup template:
    // fdi_tx_if dut (
    //     .fdi_lclk         (fdi_lclk),
    //     .fdi_rst_n        (fdi_rst_n),
    //     .fdi_pl_state_sts (fdi_pl_state_sts),
    //     .credit_ready     (credit_ready),
    //     .fdi_lp_irdy      (fdi_lp_irdy),
    //     .fdi_lp_valid     (fdi_lp_valid),
    //     .fdi_lp_data      (fdi_lp_data),
    //     .fdi_pl_error     (fdi_pl_error),
    //     .fdi_pl_flit_cancel(fdi_pl_flit_cancel)
    // );

    task automatic drive_payload(input logic [511:0] data);
        begin
            @(posedge fdi_lclk);
            hold_data = data;
        end
    endtask

    task automatic check_irdy_backpressure(input string tag);
        begin
            if (fdi_lp_data !== hold_data) begin
                error_count++;
                $display("ERROR[%0t] %s payload changed while irdy=0", $time, tag);
            end
        end
    endtask

    task automatic scenario_non_active_block;
        begin
            fdi_pl_state_sts <= FDI_RESET_STS;
            credit_ready     <= 1'b1;
            drive_payload(512'h3001);
            repeat (2) @(posedge fdi_lclk);
            $display("[%0t] non_active_block exercised", $time);
        end
    endtask

    task automatic scenario_credit_gating;
        begin
            fdi_pl_state_sts <= FDI_ACTIVE_STS;
            credit_ready     <= 1'b0;
            drive_payload(512'h3002);
            repeat (2) @(posedge fdi_lclk);
            $display("[%0t] credit_gating exercised", $time);
        end
    endtask

    task automatic scenario_retrain_pause;
        begin
            fdi_pl_state_sts <= FDI_ACTIVE_STS;
            credit_ready     <= 1'b1;
            fdi_lp_irdy      <= 1'b0;
            drive_payload(512'h3003);
            repeat (3) begin
                @(posedge fdi_lclk);
                check_irdy_backpressure("fdi_tx_irdy_backpressure");
            end
            fdi_pl_state_sts <= FDI_RETRAIN_STS;
            repeat (2) @(posedge fdi_lclk);
            fdi_pl_state_sts <= FDI_ACTIVE_STS;
            fdi_lp_irdy      <= 1'b1;
            $display("[%0t] retrain_pause exercised", $time);
        end
    endtask

    initial begin
        error_count = 0;
        @(posedge fdi_rst_n);

        scenario_non_active_block();
        scenario_credit_gating();
        scenario_retrain_pause();

        repeat (10) @(posedge fdi_lclk);
        $display("fdi_tx_if_tb completed with error_count=%0d", error_count);
        $finish;
    end

endmodule: fdi_tx_if_tb
