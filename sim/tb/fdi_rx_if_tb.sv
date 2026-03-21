/***********************************************************************
 * Copyright 2026
 **********************************************************************/

/*
 * Module: fdi_rx_if_tb
 *
 * Skeleton testbench for fdi_rx_if.
 */

`timescale 1ns/1ps

module fdi_rx_if_tb;

    localparam time FDI_CLK_PERIOD = 10ns;
    localparam logic [3:0] FDI_RESET_STS   = 4'b0000;
    localparam logic [3:0] FDI_ACTIVE_STS  = 4'b0010;

    logic         fdi_lclk;
    logic         fdi_rst_n;
    logic [3:0]   fdi_pl_state_sts;
    logic         fdi_pl_valid;
    logic         fdi_pl_trdy;
    logic [511:0] fdi_pl_data;
    logic         fdi_pl_flit_cancel;
    logic         rx_ready;
    logic         rx_valid;
    logic [511:0] rx_data;
    logic [511:0] hold_data;
    int           error_count;

    initial begin
        fdi_lclk = 1'b0;
        forever #(FDI_CLK_PERIOD / 2) fdi_lclk = ~fdi_lclk;
    end

    initial begin
        fdi_rst_n          = 1'b0;
        fdi_pl_state_sts   = 4'b0000;
        fdi_pl_valid       = 1'b0;
        fdi_pl_trdy        = 1'b0;
        fdi_pl_data        = '0;
        fdi_pl_flit_cancel = 1'b0;
        rx_ready           = 1'b1;

        repeat (4) @(posedge fdi_lclk);
        fdi_rst_n = 1'b1;
    end

    initial begin
        $dumpfile("fdi_rx_if_tb.fst");
        $dumpvars(0, fdi_rx_if_tb);
    end

    // DUT hookup template:
    // fdi_rx_if dut (
    //     .fdi_lclk         (fdi_lclk),
    //     .fdi_rst_n        (fdi_rst_n),
    //     .fdi_pl_state_sts (fdi_pl_state_sts),
    //     .fdi_pl_valid     (fdi_pl_valid),
    //     .fdi_pl_trdy      (fdi_pl_trdy),
    //     .fdi_pl_data      (fdi_pl_data),
    //     .fdi_pl_flit_cancel(fdi_pl_flit_cancel),
    //     .rx_ready         (rx_ready),
    //     .rx_valid         (rx_valid),
    //     .rx_data          (rx_data)
    // );

    task automatic drive_input_flit(input logic [511:0] data);
        begin
            @(posedge fdi_lclk);
            fdi_pl_valid <= 1'b1;
            fdi_pl_data  <= data;
            hold_data    <= data;
        end
    endtask

    task automatic clear_input_flit;
        begin
            @(posedge fdi_lclk);
            fdi_pl_valid <= 1'b0;
            fdi_pl_data  <= '0;
        end
    endtask

    task automatic scenario_non_active_block;
        begin
            fdi_pl_state_sts <= FDI_RESET_STS;
            fdi_pl_trdy      <= 1'b0;
            drive_input_flit(512'h4001);
            repeat (2) @(posedge fdi_lclk);
            clear_input_flit();
            $display("[%0t] rx non_active_block exercised", $time);
        end
    endtask

    task automatic scenario_rx_backpressure;
        begin
            fdi_pl_state_sts <= FDI_ACTIVE_STS;
            rx_ready         <= 1'b0;
            fdi_pl_trdy      <= 1'b0;
            drive_input_flit(512'h4002);
            repeat (3) @(posedge fdi_lclk);
            rx_ready    <= 1'b1;
            fdi_pl_trdy <= 1'b1;
            @(posedge fdi_lclk);
            clear_input_flit();
            $display("[%0t] rx backpressure exercised", $time);
        end
    endtask

    task automatic scenario_flit_cancel;
        begin
            fdi_pl_state_sts   <= FDI_ACTIVE_STS;
            rx_ready           <= 1'b1;
            fdi_pl_trdy        <= 1'b1;
            drive_input_flit(512'h4003);
            @(posedge fdi_lclk);
            fdi_pl_flit_cancel <= 1'b1;
            @(posedge fdi_lclk);
            fdi_pl_flit_cancel <= 1'b0;
            clear_input_flit();
            $display("[%0t] flit_cancel exercised", $time);
        end
    endtask

    initial begin
        error_count = 0;
        @(posedge fdi_rst_n);

        scenario_non_active_block();
        scenario_rx_backpressure();
        scenario_flit_cancel();

        repeat (10) @(posedge fdi_lclk);
        $display("fdi_rx_if_tb completed with error_count=%0d", error_count);
        $finish;
    end

endmodule: fdi_rx_if_tb
