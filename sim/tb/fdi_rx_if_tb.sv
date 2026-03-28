/***********************************************************************
 * Copyright 2026
 **********************************************************************/

/*
 * Module: fdi_rx_if_tb
 *
 * Directed smoke testbench for fdi_rx_if.
 */

`timescale 1ns/1ps

module fdi_rx_if_tb;

    localparam time FDI_CLK_PERIOD = 10ns;
    localparam logic [3:0] FDI_RESET_STS  = 4'b0000;
    localparam logic [3:0] FDI_ACTIVE_STS = 4'b0010;

    localparam int EXP_W = 605;
    localparam int EXP_DATA_LSB = 0;
    localparam int EXP_STREAM_LSB = 512;
    localparam int EXP_USER_LSB = 516;
    localparam int EXP_CNTL_LSB = 580;
    localparam int EXP_LAST_LSB = 588;
    localparam int EXP_SRCID_LSB = 589;
    localparam int EXP_TGTID_LSB = 597;

    logic         fdi_lclk;
    logic         fdi_rst_n;
    logic [3:0]   fdi_pl_state_sts;
    logic         fdi_pl_valid;
    logic [511:0] fdi_pl_flit;
    logic [3:0]   fdi_pl_stream;
    logic         fdi_pl_trdy;
    logic         fdi_pl_dllp_valid;
    logic [31:0]  fdi_pl_dllp;
    logic         fdi_pl_flit_cancel;
    logic         fdi_pl_idle;
    logic         fdi_pl_error;
    logic         rx_ready;
    logic         rx_valid;
    logic [511:0] rx_data;
    logic [63:0]  rx_user;
    logic [7:0]   rx_cntl;
    logic         rx_last;
    logic [7:0]   rx_srcid;
    logic [7:0]   rx_tgtid;
    logic [EXP_W-1:0] exp_queue[$];
    int           error_count;
    logic         rx_handshake_seen;

    initial begin
        fdi_lclk = 1'b0;
        forever #(FDI_CLK_PERIOD / 2) fdi_lclk = ~fdi_lclk;
    end

    initial begin
        fdi_rst_n          = 1'b0;
        fdi_pl_state_sts   = FDI_RESET_STS;
        fdi_pl_valid       = 1'b0;
        fdi_pl_flit        = '0;
        fdi_pl_stream      = '0;
        fdi_pl_dllp_valid  = 1'b0;
        fdi_pl_dllp        = '0;
        fdi_pl_flit_cancel = 1'b0;
        fdi_pl_idle        = 1'b1;
        fdi_pl_error       = 1'b0;
        rx_ready           = 1'b1;
        rx_handshake_seen  = 1'b0;

        repeat (4) @(posedge fdi_lclk);
        fdi_rst_n = 1'b1;
    end

    initial begin
        $dumpfile("fdi_rx_if_tb.fst");
        $dumpvars(0, fdi_rx_if_tb);
    end

    fdi_rx_if #(
        .FDI_DATA_WIDTH   (512),
        .FDI_USER_WIDTH   (64),
        .FDI_STREAM_WIDTH (4),
        .FDI_DLLP_WIDTH   (32),
        .CXS_CNTL_WIDTH   (8),
        .CXS_SRCID_WIDTH  (8),
        .CXS_TGTID_WIDTH  (8)
    ) dut (
        .fdi_lclk          (fdi_lclk),
        .fdi_rst_n         (fdi_rst_n),
        .fdi_pl_valid      (fdi_pl_valid),
        .fdi_pl_flit       (fdi_pl_flit),
        .fdi_pl_stream     (fdi_pl_stream),
        .fdi_pl_trdy       (fdi_pl_trdy),
        .fdi_pl_dllp_valid (fdi_pl_dllp_valid),
        .fdi_pl_dllp       (fdi_pl_dllp),
        .fdi_pl_flit_cancel(fdi_pl_flit_cancel),
        .fdi_pl_state_sts  (fdi_pl_state_sts),
        .fdi_pl_idle       (fdi_pl_idle),
        .fdi_pl_error      (fdi_pl_error),
        .rx_valid_out      (rx_valid),
        .rx_data_out       (rx_data),
        .rx_user_out       (rx_user),
        .rx_cntl_out       (rx_cntl),
        .rx_last_out       (rx_last),
        .rx_srcid_out      (rx_srcid),
        .rx_tgtid_out      (rx_tgtid),
        .rx_ready          (rx_ready)
    );

    function automatic logic [63:0] expected_user(input logic [3:0] stream_value);
        begin
            expected_user = {60'h0, stream_value};
        end
    endfunction

    function automatic logic [EXP_W-1:0] pack_expected(
        input logic [511:0] data,
        input logic [3:0]   stream_value,
        input logic [63:0]  user_value,
        input logic [7:0]   cntl_value,
        input logic         last_value,
        input logic [7:0]   srcid_value,
        input logic [7:0]   tgtid_value
    );
        begin
            pack_expected = {tgtid_value, srcid_value, last_value, cntl_value,
                             user_value, stream_value, data};
        end
    endfunction

    task automatic push_expected(
        input logic [511:0] data,
        input logic [3:0]   stream_value
    );
        logic [EXP_W-1:0] item;
        begin
            item = pack_expected(data, stream_value, expected_user(stream_value),
                                 8'h00, 1'b1, 8'h00, 8'h00);
            exp_queue.push_back(item);
        end
    endtask

    task automatic compare_output(input string tag);
        logic [EXP_W-1:0] exp_item;
        begin
            if (exp_queue.size() == 0) begin
                error_count++;
                $display("ERROR[%0t] %s unexpected output", $time, tag);
            end
            else begin
                exp_item = exp_queue.pop_front();
                if (rx_data !== exp_item[511:0]) begin
                    error_count++;
                    $display("ERROR[%0t] %s data mismatch", $time, tag);
                end
                if (rx_user !== exp_item[EXP_USER_LSB +: 64]) begin
                    error_count++;
                    $display("ERROR[%0t] %s user mismatch", $time, tag);
                end
                if (rx_cntl !== exp_item[EXP_CNTL_LSB +: 8]) begin
                    error_count++;
                    $display("ERROR[%0t] %s cntl mismatch", $time, tag);
                end
                if (rx_last !== exp_item[EXP_LAST_LSB]) begin
                    error_count++;
                    $display("ERROR[%0t] %s last mismatch", $time, tag);
                end
                if (rx_srcid !== exp_item[EXP_SRCID_LSB +: 8]) begin
                    error_count++;
                    $display("ERROR[%0t] %s srcid mismatch", $time, tag);
                end
                if (rx_tgtid !== exp_item[EXP_TGTID_LSB +: 8]) begin
                    error_count++;
                    $display("ERROR[%0t] %s tgtid mismatch", $time, tag);
                end
            end
        end
    endtask

    task automatic drive_flit(
        input logic [511:0] data,
        input logic [3:0]   stream_value,
        input logic         cancel
    );
        begin
            @(posedge fdi_lclk);
            fdi_pl_valid       <= 1'b1;
            fdi_pl_flit        <= data;
            fdi_pl_stream      <= stream_value;
            fdi_pl_flit_cancel <= cancel;
        end
    endtask

    task automatic clear_flit;
        begin
            @(posedge fdi_lclk);
            fdi_pl_valid       <= 1'b0;
            fdi_pl_flit        <= '0;
            fdi_pl_stream      <= '0;
            fdi_pl_flit_cancel <= 1'b0;
        end
    endtask

    task automatic scenario_active_receive;
        begin
            fdi_pl_state_sts = FDI_ACTIVE_STS;
            fdi_pl_idle      = 1'b0;
            fdi_pl_error     = 1'b0;
            rx_ready         = 1'b1;
            push_expected(512'h4000_0001, 4'h1);
            drive_flit(512'h4000_0001, 4'h1, 1'b0);
            @(posedge fdi_lclk);
            clear_flit();
            repeat (2) @(posedge fdi_lclk);
            $display("[%0t] active_receive exercised", $time);
        end
    endtask

    task automatic scenario_rx_backpressure;
        begin
            fdi_pl_state_sts = FDI_ACTIVE_STS;
            fdi_pl_idle      = 1'b0;
            fdi_pl_error     = 1'b0;
            rx_ready         = 1'b0;
            drive_flit(512'h4000_0002, 4'h2, 1'b0);
            repeat (2) @(posedge fdi_lclk);
            if (fdi_pl_trdy !== 1'b0) begin
                error_count++;
                $display("ERROR[%0t] backpressure expected fdi_pl_trdy=0", $time);
            end
            rx_ready = 1'b1;
            push_expected(512'h4000_0002, 4'h2);
            @(posedge fdi_lclk);
            clear_flit();
            repeat (2) @(posedge fdi_lclk);
            $display("[%0t] rx_backpressure exercised", $time);
        end
    endtask

    task automatic scenario_flit_cancel;
        begin
            fdi_pl_state_sts = FDI_ACTIVE_STS;
            fdi_pl_idle      = 1'b0;
            fdi_pl_error     = 1'b0;
            rx_ready         = 1'b1;
            drive_flit(512'h4000_0003, 4'h3, 1'b1);
            repeat (2) @(posedge fdi_lclk);
            if (fdi_pl_trdy !== 1'b0) begin
                error_count++;
                $display("ERROR[%0t] cancel expected fdi_pl_trdy=0", $time);
            end
            clear_flit();
            repeat (2) @(posedge fdi_lclk);
            $display("[%0t] flit_cancel exercised", $time);
        end
    endtask

    task automatic scenario_error_gate;
        begin
            fdi_pl_state_sts = FDI_ACTIVE_STS;
            fdi_pl_idle      = 1'b0;
            fdi_pl_error     = 1'b1;
            rx_ready         = 1'b1;
            drive_flit(512'h4000_0004, 4'h4, 1'b0);
            repeat (2) @(posedge fdi_lclk);
            if (fdi_pl_trdy !== 1'b0) begin
                error_count++;
                $display("ERROR[%0t] error gate expected fdi_pl_trdy=0", $time);
            end
            clear_flit();
            fdi_pl_error = 1'b0;
            repeat (2) @(posedge fdi_lclk);
            $display("[%0t] error_gate exercised", $time);
        end
    endtask

    always @(posedge fdi_lclk or negedge fdi_rst_n) begin
        if (!fdi_rst_n) begin
            rx_handshake_seen <= 1'b0;
        end
        else if (rx_valid && rx_ready) begin
            if (!rx_handshake_seen) begin
                compare_output("rx_handshake");
                rx_handshake_seen <= 1'b1;
            end
        end
        else if (!rx_valid) begin
            rx_handshake_seen <= 1'b0;
        end
    end

    initial begin
        error_count = 0;
        @(posedge fdi_rst_n);

        scenario_active_receive();
        scenario_rx_backpressure();
        scenario_flit_cancel();
        scenario_error_gate();

        repeat (10) @(posedge fdi_lclk);
        $display("fdi_rx_if_tb completed with error_count=%0d queue_depth=%0d",
                 error_count, exp_queue.size());
        $finish;
    end

endmodule: fdi_rx_if_tb
