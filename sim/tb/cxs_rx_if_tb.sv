/***********************************************************************
 * Copyright 2026
 **********************************************************************/

/*
 * Module: cxs_rx_if_tb
 *
 * Skeleton testbench for cxs_rx_if.
 */

`timescale 1ns/1ps

module cxs_rx_if_tb;

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
    logic         cxs_rx_active;
    logic         rx_valid;
    logic         rx_ready;
    logic [511:0] rx_data;
    logic [127:0] rx_user;
    logic [63:0]  rx_cntl;
    logic         rx_last;
    logic [7:0]   rx_srcid;
    logic [7:0]   rx_tgtid;
    cxs_flit_t    hold_flit;
    int           error_count;

    initial begin
        cxs_clk = 1'b0;
        forever #(CXS_CLK_PERIOD / 2) cxs_clk = ~cxs_clk;
    end

    initial begin
        cxs_rst_n     = 1'b0;
        cxs_rx_active = 1'b0;
        rx_valid      = 1'b0;
        rx_ready      = 1'b1;
        rx_data       = '0;
        rx_user       = '0;
        rx_cntl       = '0;
        rx_last       = 1'b0;
        rx_srcid      = '0;
        rx_tgtid      = '0;

        repeat (4) @(posedge cxs_clk);
        cxs_rst_n = 1'b1;
    end

    initial begin
        $dumpfile("cxs_rx_if_tb.fst");
        $dumpvars(0, cxs_rx_if_tb);
    end

    // DUT hookup template:
    // cxs_rx_if dut (
    //     .cxs_clk      (cxs_clk),
    //     .cxs_rst_n    (cxs_rst_n),
    //     .cxs_rx_active(cxs_rx_active),
    //     .rx_valid     (rx_valid),
    //     .rx_ready     (rx_ready),
    //     .rx_data      (rx_data),
    //     .rx_user      (rx_user),
    //     .rx_cntl      (rx_cntl),
    //     .rx_last      (rx_last),
    //     .rx_srcid     (rx_srcid),
    //     .rx_tgtid     (rx_tgtid)
    // );

    task automatic drive_rx_flit(
        input logic [511:0] data,
        input logic [127:0] user,
        input logic [63:0]  cntl,
        input logic         last,
        input logic [7:0]   srcid,
        input logic [7:0]   tgtid
    );
        begin
            @(posedge cxs_clk);
            rx_valid <= 1'b1;
            rx_data  <= data;
            rx_user  <= user;
            rx_cntl  <= cntl;
            rx_last  <= last;
            rx_srcid <= srcid;
            rx_tgtid <= tgtid;
            hold_flit = '{data, user, cntl, last, srcid, tgtid};
        end
    endtask

    task automatic clear_rx_flit;
        begin
            @(posedge cxs_clk);
            rx_valid <= 1'b0;
            rx_data  <= '0;
            rx_user  <= '0;
            rx_cntl  <= '0;
            rx_last  <= 1'b0;
            rx_srcid <= '0;
            rx_tgtid <= '0;
        end
    endtask

    task automatic check_backpressure_stability(input string tag);
        begin
            if (rx_data !== hold_flit.data) begin
                error_count++;
                $display("ERROR[%0t] %s data changed under backpressure", $time, tag);
            end
            if (rx_user !== hold_flit.user) begin
                error_count++;
                $display("ERROR[%0t] %s user changed under backpressure", $time, tag);
            end
            if (rx_cntl !== hold_flit.cntl) begin
                error_count++;
                $display("ERROR[%0t] %s cntl changed under backpressure", $time, tag);
            end
            if (rx_last !== hold_flit.last) begin
                error_count++;
                $display("ERROR[%0t] %s last changed under backpressure", $time, tag);
            end
        end
    endtask

    task automatic scenario_active_gating;
        begin
            cxs_rx_active <= 1'b0;
            drive_rx_flit(512'h2001, 128'h3, 64'h3, 1'b1, 8'h03, 8'h30);
            repeat (2) @(posedge cxs_clk);
            $display("[%0t] rx active_gating exercised", $time);
            clear_rx_flit();
        end
    endtask

    task automatic scenario_backpressure;
        begin
            cxs_rx_active <= 1'b1;
            drive_rx_flit(512'h2002, 128'h4, 64'h4, 1'b0, 8'h04, 8'h40);
            @(posedge cxs_clk);
            rx_ready <= 1'b0;
            repeat (3) begin
                @(posedge cxs_clk);
                check_backpressure_stability("rx_backpressure");
            end
            rx_ready <= 1'b1;
            @(posedge cxs_clk);
            clear_rx_flit();
        end
    endtask

    initial begin
        error_count = 0;
        @(posedge cxs_rst_n);

        scenario_active_gating();
        scenario_backpressure();

        repeat (10) @(posedge cxs_clk);
        $display("cxs_rx_if_tb completed with error_count=%0d", error_count);
        $finish;
    end

endmodule: cxs_rx_if_tb
