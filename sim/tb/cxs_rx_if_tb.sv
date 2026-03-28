/***********************************************************************
 * Copyright 2026
 **********************************************************************/

/*
 * Module: cxs_rx_if_tb
 *
 * Directed smoke test for cxs_rx_if.
 */

`timescale 1ns/1ps

module cxs_rx_if_tb;

    localparam time CXS_CLK_PERIOD = 10ns;

    logic         cxs_clk;
    logic         cxs_rst_n;
    logic         rx_valid_in;
    logic [511:0] rx_data_in;
    logic [63:0]  rx_user_in;
    logic [7:0]   rx_cntl_in;
    logic         rx_last_in;
    logic [7:0]   rx_srcid_in;
    logic [7:0]   rx_tgtid_in;
    logic         rx_data_ack;
    logic         cxs_rx_valid;
    logic [511:0] cxs_rx_data;
    logic [63:0]  cxs_rx_user;
    logic [7:0]   cxs_rx_cntl;
    logic         cxs_rx_last;
    logic [7:0]   cxs_rx_srcid;
    logic [7:0]   cxs_rx_tgtid;
    logic         cxs_rx_active_req;
    logic         cxs_rx_active;
    logic         cxs_rx_deact_hint;
    logic [511:0] exp_data;
    logic [63:0]  exp_user;
    logic [7:0]   exp_cntl;
    logic         exp_last;
    logic [7:0]   exp_srcid;
    logic [7:0]   exp_tgtid;
    int           error_count;

    cxs_rx_if #(
        .CXS_DATA_WIDTH (512),
        .CXS_USER_WIDTH (64),
        .CXS_CNTL_WIDTH (8),
        .CXS_SRCID_WIDTH (8),
        .CXS_TGTID_WIDTH (8),
        .CXS_HAS_LAST   (1'b1)
    ) dut (
        .cxs_clk          (cxs_clk),
        .cxs_rst_n        (cxs_rst_n),
        .rx_valid_in      (rx_valid_in),
        .rx_data_in       (rx_data_in),
        .rx_user_in       (rx_user_in),
        .rx_cntl_in       (rx_cntl_in),
        .rx_last_in       (rx_last_in),
        .rx_srcid_in      (rx_srcid_in),
        .rx_tgtid_in      (rx_tgtid_in),
        .rx_data_ack      (rx_data_ack),
        .cxs_rx_valid     (cxs_rx_valid),
        .cxs_rx_data      (cxs_rx_data),
        .cxs_rx_user      (cxs_rx_user),
        .cxs_rx_cntl      (cxs_rx_cntl),
        .cxs_rx_last      (cxs_rx_last),
        .cxs_rx_srcid     (cxs_rx_srcid),
        .cxs_rx_tgtid     (cxs_rx_tgtid),
        .cxs_rx_active_req(cxs_rx_active_req),
        .cxs_rx_active    (cxs_rx_active),
        .cxs_rx_deact_hint(cxs_rx_deact_hint)
    );

    initial begin
        cxs_clk = 1'b0;
        forever #(CXS_CLK_PERIOD / 2) cxs_clk = ~cxs_clk;
    end

    initial begin
        cxs_rst_n         = 1'b0;
        rx_valid_in       = 1'b0;
        rx_data_in        = '0;
        rx_user_in        = '0;
        rx_cntl_in        = '0;
        rx_last_in        = 1'b0;
        rx_srcid_in       = '0;
        rx_tgtid_in       = '0;
        cxs_rx_active_req = 1'b0;
        cxs_rx_deact_hint = 1'b0;

        repeat (4) @(posedge cxs_clk);
        cxs_rst_n = 1'b1;
    end

    initial begin
        $dumpfile("cxs_rx_if_tb.fst");
        $dumpvars(0, cxs_rx_if_tb);
    end

    task automatic drive_active_req;
        begin
            @(negedge cxs_clk);
            cxs_rx_active_req <= 1'b1;
            cxs_rx_deact_hint <= 1'b0;
            @(posedge cxs_clk);
            #1;
            if (cxs_rx_active !== 1'b1) begin
                error_count++;
                $display("ERROR[%0t] active_req did not raise cxs_rx_active", $time);
            end
            @(negedge cxs_clk);
            cxs_rx_active_req <= 1'b0;
        end
    endtask

    task automatic drive_deact_hint;
        begin
            @(negedge cxs_clk);
            cxs_rx_deact_hint <= 1'b1;
            @(posedge cxs_clk);
            #1;
            if (cxs_rx_active !== 1'b0) begin
                error_count++;
                $display("ERROR[%0t] deact_hint did not clear cxs_rx_active", $time);
            end
            @(negedge cxs_clk);
            cxs_rx_deact_hint <= 1'b0;
        end
    endtask

    task automatic drive_flit(
        input logic [511:0] data,
        input logic [63:0]  user,
        input logic [7:0]   cntl,
        input logic         last,
        input logic [7:0]   srcid,
        input logic [7:0]   tgtid
    );
        begin
            @(negedge cxs_clk);
            rx_valid_in <= 1'b1;
            rx_data_in  <= data;
            rx_user_in  <= user;
            rx_cntl_in  <= cntl;
            rx_last_in  <= last;
            rx_srcid_in <= srcid;
            rx_tgtid_in <= tgtid;
            exp_data  = data;
            exp_user  = user;
            exp_cntl  = cntl;
            exp_last  = last;
            exp_srcid = srcid;
            exp_tgtid = tgtid;
            @(posedge cxs_clk);
            #1;
            check_output("rx_flit");
            @(negedge cxs_clk);
            rx_valid_in <= 1'b0;
            rx_data_in  <= '0;
            rx_user_in  <= '0;
            rx_cntl_in  <= '0;
            rx_last_in  <= 1'b0;
            rx_srcid_in <= '0;
            rx_tgtid_in <= '0;
        end
    endtask

    task automatic check_output(input string tag);
        begin
            if (cxs_rx_data !== exp_data) begin
                error_count++;
                $display("ERROR[%0t] %s data mismatch", $time, tag);
            end
            if (cxs_rx_user !== exp_user) begin
                error_count++;
                $display("ERROR[%0t] %s user mismatch", $time, tag);
            end
            if (cxs_rx_cntl !== exp_cntl) begin
                error_count++;
                $display("ERROR[%0t] %s cntl mismatch", $time, tag);
            end
            if (cxs_rx_last !== exp_last) begin
                error_count++;
                $display("ERROR[%0t] %s last mismatch", $time, tag);
            end
            if (cxs_rx_srcid !== exp_srcid) begin
                error_count++;
                $display("ERROR[%0t] %s srcid mismatch", $time, tag);
            end
            if (cxs_rx_tgtid !== exp_tgtid) begin
                error_count++;
                $display("ERROR[%0t] %s tgtid mismatch", $time, tag);
            end
        end
    endtask

    task automatic scenario_active_gate;
        begin
            drive_active_req();
            drive_flit(512'h2001, 64'h3, 8'h3, 1'b1, 8'h03, 8'h30);
        end
    endtask

    task automatic scenario_burst;
        begin
            drive_active_req();
            drive_flit(512'h2002, 64'h4, 8'h4, 1'b0, 8'h04, 8'h40);
            drive_flit(512'h2003, 64'h5, 8'h5, 1'b1, 8'h05, 8'h50);
        end
    endtask

    task automatic scenario_deact_hint;
        begin
            drive_deact_hint();
        end
    endtask

    initial begin
        error_count = 0;
        @(posedge cxs_rst_n);

        scenario_active_gate();
        scenario_burst();
        scenario_deact_hint();

        repeat (10) @(posedge cxs_clk);
        $display("cxs_rx_if_tb completed with error_count=%0d queue_depth=%0d",
                 error_count, 0);
        $finish;
    end

endmodule: cxs_rx_if_tb
