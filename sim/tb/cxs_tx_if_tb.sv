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

    typedef struct packed {
        logic [511:0] data;
        logic [127:0] user;
        logic [63:0]  cntl;
        logic         last;
        logic [7:0]   srcid;
        logic [7:0]   tgtid;
    } cxs_flit_t;

    logic         cxs_clk;
    logic         cxs_rst_n;
    logic         cxs_tx_active;
    logic         tx_valid;
    logic         tx_ready;
    logic [511:0] tx_data;
    logic [127:0] tx_user;
    logic [63:0]  tx_cntl;
    logic         tx_last;
    logic [7:0]   tx_srcid;
    logic [7:0]   tx_tgtid;
    cxs_flit_t    hold_flit;
    int           error_count;

    initial begin
        cxs_clk = 1'b0;
        forever #(CXS_CLK_PERIOD / 2) cxs_clk = ~cxs_clk;
    end

    initial begin
        cxs_rst_n     = 1'b0;
        cxs_tx_active = 1'b0;
        tx_valid      = 1'b0;
        tx_data       = '0;
        tx_user       = '0;
        tx_cntl       = '0;
        tx_last       = 1'b0;
        tx_srcid      = '0;
        tx_tgtid      = '0;
        tx_ready      = 1'b1;

        repeat (4) @(posedge cxs_clk);
        cxs_rst_n = 1'b1;
    end

    initial begin
        $dumpfile("cxs_tx_if_tb.fst");
        $dumpvars(0, cxs_tx_if_tb);
    end

    // DUT hookup template:
    // cxs_tx_if dut (
    //     .cxs_clk      (cxs_clk),
    //     .cxs_rst_n    (cxs_rst_n),
    //     .cxs_tx_active(cxs_tx_active),
    //     .tx_valid     (tx_valid),
    //     .tx_ready     (tx_ready),
    //     .tx_data      (tx_data),
    //     .tx_user      (tx_user),
    //     .tx_cntl      (tx_cntl),
    //     .tx_last      (tx_last),
    //     .tx_srcid     (tx_srcid),
    //     .tx_tgtid     (tx_tgtid)
    // );

    task automatic drive_tx_flit(
        input logic [511:0] data,
        input logic [127:0] user,
        input logic [63:0]  cntl,
        input logic         last,
        input logic [7:0]   srcid,
        input logic [7:0]   tgtid
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
            hold_flit = '{data, user, cntl, last, srcid, tgtid};
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
            if (tx_data !== hold_flit.data) begin
                error_count++;
                $display("ERROR[%0t] %s data changed under backpressure", $time, tag);
            end
            if (tx_user !== hold_flit.user) begin
                error_count++;
                $display("ERROR[%0t] %s user changed under backpressure", $time, tag);
            end
            if (tx_cntl !== hold_flit.cntl) begin
                error_count++;
                $display("ERROR[%0t] %s cntl changed under backpressure", $time, tag);
            end
            if (tx_last !== hold_flit.last) begin
                error_count++;
                $display("ERROR[%0t] %s last changed under backpressure", $time, tag);
            end
        end
    endtask

    task automatic scenario_active_gating;
        begin
            cxs_tx_active <= 1'b0;
            drive_tx_flit(512'h1001, 128'h1, 64'h1, 1'b1, 8'h01, 8'h10);
            repeat (2) @(posedge cxs_clk);
            $display("[%0t] active_gating exercised", $time);
            clear_tx_flit();
        end
    endtask

    task automatic scenario_backpressure;
        begin
            cxs_tx_active <= 1'b1;
            drive_tx_flit(512'h1002, 128'h2, 64'h2, 1'b0, 8'h02, 8'h20);
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

    initial begin
        error_count = 0;
        @(posedge cxs_rst_n);

        scenario_active_gating();
        scenario_backpressure();

        repeat (10) @(posedge cxs_clk);
        $display("cxs_tx_if_tb completed with error_count=%0d", error_count);
        $finish;
    end

endmodule: cxs_tx_if_tb
