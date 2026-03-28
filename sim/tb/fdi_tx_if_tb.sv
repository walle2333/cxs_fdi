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
    logic         fdi_lp_irdy;
    logic         fdi_lp_valid;
    logic [511:0] fdi_lp_flit;
    logic [3:0]   fdi_lp_stream;
    logic         fdi_lp_dllp_valid;
    logic [31:0]  fdi_lp_dllp;
    logic         tx_valid_in;
    logic [511:0] tx_data_in;
    logic [7:0]   tx_cntl_in;
    logic [511:0] hold_data;
    logic         tx_data_ack;

    logic [523:0] exp_queue[$];
    int           error_count;

    initial begin
        fdi_lclk = 1'b0;
        forever #(FDI_CLK_PERIOD / 2) fdi_lclk = ~fdi_lclk;
    end

    initial begin
        fdi_rst_n          = 1'b0;
        fdi_pl_state_sts   = 4'b0000;
        fdi_lp_irdy        = 1'b1;
        tx_valid_in        = 1'b0;
        tx_data_in         = '0;
        tx_cntl_in         = '0;

        repeat (4) @(posedge fdi_lclk);
        fdi_rst_n = 1'b1;
    end

    initial begin
        $dumpfile("fdi_tx_if_tb.fst");
        $dumpvars(0, fdi_tx_if_tb);
    end

    fdi_tx_if #(
        .FDI_DATA_WIDTH   (512),
        .FDI_USER_WIDTH   (64),
        .FDI_STREAM_WIDTH (4),
        .FDI_DLLP_WIDTH   (32),
        .CXS_CNTL_WIDTH   (8)
    ) dut (
        .fdi_lclk         (fdi_lclk),
        .fdi_rst_n        (fdi_rst_n),
        .tx_valid_in      (tx_valid_in),
        .tx_data_in       (tx_data_in),
        .tx_user_in       ('0),
        .tx_cntl_in       (tx_cntl_in),
        .tx_last_in       (1'b0),
        .tx_data_ack      (tx_data_ack),
        .fdi_lp_valid     (fdi_lp_valid),
        .fdi_lp_flit      (fdi_lp_flit),
        .fdi_lp_stream    (fdi_lp_stream),
        .fdi_lp_irdy      (fdi_lp_irdy),
        .fdi_lp_dllp_valid(fdi_lp_dllp_valid),
        .fdi_lp_dllp      (fdi_lp_dllp),
        .fdi_pl_state_sts (fdi_pl_state_sts)
    );

    task automatic drive_payload(
        input logic [511:0] data,
        input logic [7:0]   cntl
    );
        begin
            @(posedge fdi_lclk);
            tx_valid_in <= 1'b1;
            tx_data_in  <= data;
            tx_cntl_in  <= cntl;
            hold_data   = data;
            @(posedge fdi_lclk);
            tx_valid_in <= 1'b0;
        end
    endtask

    task automatic clear_payload();
        begin
            @(posedge fdi_lclk);
            tx_valid_in <= 1'b0;
            tx_data_in  <= '0;
            tx_cntl_in  <= '0;
        end
    endtask

    task automatic check_irdy_backpressure(input string tag);
        begin
            if (fdi_lp_valid && (fdi_lp_flit !== hold_data)) begin
                error_count++;
                $display("ERROR[%0t] %s payload changed while irdy=0", $time, tag);
            end
        end
    endtask

    task automatic compare_output(input string tag);
        logic [523:0] exp_flit;
        begin
            if (exp_queue.size() == 0) begin
                error_count++;
                $display("ERROR[%0t] %s unexpected output flit", $time, tag);
            end
            else begin
                exp_flit = exp_queue.pop_front();
                if (fdi_lp_flit !== exp_flit[523:12]) begin
                    error_count++;
                    $display("ERROR[%0t] %s flit mismatch", $time, tag);
                end
                if (fdi_lp_stream !== exp_flit[3:0]) begin
                    error_count++;
                    $display("ERROR[%0t] %s stream mismatch", $time, tag);
                end
            end
        end
    endtask

    task automatic scenario_non_active_block;
        begin
            fdi_pl_state_sts <= FDI_RESET_STS;
            drive_payload(512'h3001, 8'h01);
            clear_payload();
            $display("[%0t] non_active_block exercised", $time);
        end
    endtask

    task automatic scenario_active_transfer;
        logic [523:0] exp_flit;
        begin
            fdi_pl_state_sts <= FDI_ACTIVE_STS;
            exp_flit = {512'h3002, 8'h02, 4'h2};
            exp_queue.push_back(exp_flit);
            drive_payload(512'h3002, 8'h02);
            clear_payload();
            $display("[%0t] active_transfer exercised", $time);
        end
    endtask

    task automatic scenario_irdy_backpressure;
        logic [523:0] exp_flit;
        begin
            fdi_pl_state_sts <= FDI_ACTIVE_STS;
            fdi_lp_irdy      <= 1'b0;
            exp_flit = {512'h3003, 8'h03, 4'h3};
            exp_queue.push_back(exp_flit);
            drive_payload(512'h3003, 8'h03);
            repeat (3) begin
                @(posedge fdi_lclk);
                check_irdy_backpressure("fdi_tx_irdy_backpressure");
            end
            fdi_lp_irdy <= 1'b1;
            clear_payload();
            $display("[%0t] irdy_backpressure exercised", $time);
        end
    endtask

    task automatic scenario_retrain_pause;
        logic [523:0] exp_flit;
        begin
            fdi_pl_state_sts <= FDI_ACTIVE_STS;
            fdi_lp_irdy      <= 1'b0;
            exp_flit = {512'h3004, 8'h04, 4'h4};
            exp_queue.push_back(exp_flit);
            drive_payload(512'h3004, 8'h04);
            repeat (3) begin
                @(posedge fdi_lclk);
                check_irdy_backpressure("fdi_tx_irdy_backpressure");
            end
            fdi_pl_state_sts <= FDI_RETRAIN_STS;
            repeat (2) @(posedge fdi_lclk);
            fdi_pl_state_sts <= FDI_ACTIVE_STS;
            fdi_lp_irdy      <= 1'b1;
            clear_payload();
            $display("[%0t] retrain_pause exercised", $time);
        end
    endtask

    always @(posedge fdi_lclk) begin
        if (fdi_lp_valid && fdi_lp_irdy) begin
            compare_output("fdi_output_handshake");
        end
    end

    initial begin
        error_count = 0;
        @(posedge fdi_rst_n);

        scenario_non_active_block();
        scenario_active_transfer();
        scenario_irdy_backpressure();
        scenario_retrain_pause();

        repeat (10) @(posedge fdi_lclk);
        $display("fdi_tx_if_tb completed with error_count=%0d", error_count);
        $finish;
    end

endmodule: fdi_tx_if_tb
