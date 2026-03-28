/***********************************************************************
 * Copyright 2026
 **********************************************************************/

/*
 * Module: cxs_tx_if_tb
 *
 * Skeleton testbench for cxs_tx_if.
 */

`timescale 1ns/1ps

module cxs_tx_if_tb;

    localparam time CXS_CLK_PERIOD = 10ns;

    localparam int FLIT_WORD_W = 512 + 128 + 64 + 1 + 8 + 8;
    typedef logic [FLIT_WORD_W-1:0] cxs_flit_word_t;

    logic         cxs_clk;
    logic         cxs_rst_n;
    logic         cxs_tx_active_req;
    logic         cxs_tx_active;
    logic         cxs_tx_deact_hint;
    logic         tx_valid;
    logic         tx_ready;
    logic [511:0] tx_data;
    logic [127:0] tx_user;
    logic [63:0]  tx_cntl;
    logic         tx_last;
    logic [7:0]   tx_srcid;
    logic [7:0]   tx_tgtid;
    logic         tx_valid_out;
    logic [511:0] tx_data_out;
    logic [127:0] tx_user_out;
    logic [63:0]  tx_cntl_out;
    logic         tx_last_out;
    logic [7:0]   tx_srcid_out;
    logic [7:0]   tx_tgtid_out;
    logic         link_ctrl_active_req;
    logic         link_ctrl_active_ack;
    logic         link_ctrl_deact_req;
    logic         link_ctrl_deact_ack;
    cxs_flit_word_t hold_word;
    cxs_flit_word_t exp_queue[$];
    int           error_count;

    initial begin
        cxs_clk = 1'b0;
        forever #(CXS_CLK_PERIOD / 2) cxs_clk = ~cxs_clk;
    end

    initial begin
        cxs_rst_n     = 1'b0;
        cxs_tx_active_req = 1'b0;
        cxs_tx_deact_hint = 1'b0;
        tx_valid      = 1'b0;
        tx_data       = '0;
        tx_user       = '0;
        tx_cntl       = '0;
        tx_last       = 1'b0;
        tx_srcid      = '0;
        tx_tgtid      = '0;
        tx_ready      = 1'b1;
        link_ctrl_active_ack = 1'b1;
        link_ctrl_deact_ack  = 1'b0;
        hold_word = '0;

        repeat (4) @(posedge cxs_clk);
        cxs_rst_n = 1'b1;
    end

    initial begin
        $dumpfile("cxs_tx_if_tb.fst");
        $dumpvars(0, cxs_tx_if_tb);
    end

    cxs_tx_if #(
        .CXS_DATA_WIDTH       (512),
        .CXS_USER_WIDTH       (128),
        .CXS_CNTL_WIDTH       (64),
        .CXS_SRCID_WIDTH      (8),
        .CXS_TGTID_WIDTH      (8),
        .CXS_HAS_LAST         (1'b1)
    ) dut (
        .cxs_clk              (cxs_clk),
        .cxs_rst_n            (cxs_rst_n),
        .cxs_tx_valid         (tx_valid),
        .cxs_tx_data          (tx_data),
        .cxs_tx_user          (tx_user),
        .cxs_tx_cntl          (tx_cntl),
        .cxs_tx_last          (tx_last),
        .cxs_tx_srcid         (tx_srcid),
        .cxs_tx_tgtid         (tx_tgtid),
        .cxs_tx_active_req    (cxs_tx_active_req),
        .cxs_tx_active        (cxs_tx_active),
        .cxs_tx_deact_hint    (cxs_tx_deact_hint),
        .tx_valid_out         (tx_valid_out),
        .tx_data_out          (tx_data_out),
        .tx_user_out          (tx_user_out),
        .tx_cntl_out          (tx_cntl_out),
        .tx_last_out          (tx_last_out),
        .tx_srcid_out         (tx_srcid_out),
        .tx_tgtid_out         (tx_tgtid_out),
        .tx_ready             (tx_ready),
        .link_ctrl_active_req (link_ctrl_active_req),
        .link_ctrl_active_ack (link_ctrl_active_ack),
        .link_ctrl_deact_req  (link_ctrl_deact_req),
        .link_ctrl_deact_ack  (link_ctrl_deact_ack)
    );

    task automatic drive_tx_flit(
        input logic [511:0] data,
        input logic [127:0] user,
        input logic [63:0]  cntl,
        input logic         last,
        input logic [7:0]   srcid,
        input logic [7:0]   tgtid,
        input bit           expect_output = 1'b1
    );
        begin
            @(posedge cxs_clk);
            tx_valid <= 1'b1;
            tx_data  <= data;
            tx_user  <= user;
            tx_cntl  <= cntl;
            tx_last  <= last;
            tx_srcid <= srcid;
            tx_tgtid <= tgtid;
            hold_word = {data, user, cntl, last, srcid, tgtid};
            if (expect_output) begin
                exp_queue.push_back(hold_word);
            end
        end
    endtask

    task automatic clear_tx_flit;
        begin
            @(posedge cxs_clk);
            tx_valid <= 1'b0;
            tx_data  <= '0;
            tx_user  <= '0;
            tx_cntl  <= '0;
            tx_last  <= 1'b0;
            tx_srcid <= '0;
            tx_tgtid <= '0;
        end
    endtask

    task automatic check_backpressure_stability(input string tag);
        begin
            if (tx_data !== hold_word[FLIT_WORD_W-1 -: 512]) begin
                error_count++;
                $display("ERROR[%0t] %s data changed under backpressure", $time, tag);
            end
            if (tx_user !== hold_word[FLIT_WORD_W-513 -: 128]) begin
                error_count++;
                $display("ERROR[%0t] %s user changed under backpressure", $time, tag);
            end
            if (tx_cntl !== hold_word[FLIT_WORD_W-641 -: 64]) begin
                error_count++;
                $display("ERROR[%0t] %s cntl changed under backpressure", $time, tag);
            end
            if (tx_last !== hold_word[FLIT_WORD_W-705]) begin
                error_count++;
                $display("ERROR[%0t] %s last changed under backpressure", $time, tag);
            end
        end
    endtask

    task automatic scenario_active_gating;
        begin
            cxs_tx_active_req <= 1'b0;
            drive_tx_flit(512'h1001, 128'h1, 64'h1, 1'b1, 8'h01, 8'h10, 1'b0);
            repeat (2) @(posedge cxs_clk);
            if (cxs_tx_active !== 1'b0) begin
                error_count++;
                $display("ERROR[%0t] active gating failed: active should be low", $time);
            end
            $display("[%0t] active_gating exercised", $time);
            clear_tx_flit();
        end
    endtask

    task automatic scenario_backpressure;
        begin
            cxs_tx_active_req <= 1'b1;
            drive_tx_flit(512'h1002, 128'h2, 64'h2, 1'b0, 8'h02, 8'h20, 1'b1);
            @(posedge cxs_clk);
            tx_ready <= 1'b0;
            repeat (3) begin
                @(posedge cxs_clk);
                check_backpressure_stability("tx_backpressure");
            end
            tx_ready <= 1'b1;
            @(posedge cxs_clk);
            clear_tx_flit();
        end
    endtask

    always @(posedge cxs_clk) begin
        if (tx_valid_out && tx_ready) begin
            if (exp_queue.size() == 0) begin
                error_count++;
                $display("ERROR[%0t] unexpected tx_valid_out handshake", $time);
            end
            else begin
                hold_word = exp_queue.pop_front();
                if (tx_data_out !== hold_word[FLIT_WORD_W-1 -: 512]) begin
                    error_count++;
                    $display("ERROR[%0t] data mismatch", $time);
                end
                if (tx_user_out !== hold_word[FLIT_WORD_W-513 -: 128]) begin
                    error_count++;
                    $display("ERROR[%0t] user mismatch", $time);
                end
                if (tx_cntl_out !== hold_word[FLIT_WORD_W-641 -: 64]) begin
                    error_count++;
                    $display("ERROR[%0t] cntl mismatch", $time);
                end
                if (tx_last_out !== hold_word[FLIT_WORD_W-705]) begin
                    error_count++;
                    $display("ERROR[%0t] last mismatch", $time);
                end
                if (tx_srcid_out !== hold_word[FLIT_WORD_W-706 -: 8]) begin
                    error_count++;
                    $display("ERROR[%0t] srcid mismatch", $time);
                end
                if (tx_tgtid_out !== hold_word[7:0]) begin
                    error_count++;
                    $display("ERROR[%0t] tgtid mismatch", $time);
                end
            end
        end
    end

    initial begin
        error_count = 0;
        @(posedge cxs_rst_n);

        scenario_active_gating();
        cxs_tx_active_req = 1'b1;
        scenario_backpressure();

        repeat (10) @(posedge cxs_clk);
        $display("cxs_tx_if_tb completed with error_count=%0d", error_count);
        $finish;
    end

endmodule: cxs_tx_if_tb
