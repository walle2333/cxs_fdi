/***********************************************************************
 * Copyright 2026
 **********************************************************************/

/*
 * Module: tx_path_tb
 *
 * Skeleton testbench for tx_path.
 * Intended for later expansion with FIFO-oriented scoreboard checking.
 */

`timescale 1ns/1ps

module tx_path_tb;

    localparam time CXS_CLK_PERIOD = 10ns;

    typedef struct packed {
        logic [511:0] data;
        logic [127:0] user;
        logic [63:0]  cntl;
        logic         last;
        logic [7:0]   srcid;
        logic [7:0]   tgtid;
    } flit_t;

    logic         cxs_clk;
    logic         cxs_rst_n;
    logic         in_valid;
    logic         in_ready;
    logic [511:0] in_data;
    logic [127:0] in_user;
    logic [63:0]  in_cntl;
    logic         in_last;
    logic [7:0]   in_srcid;
    logic [7:0]   in_tgtid;
    logic         link_tx_ready;

    logic         out_valid;
    logic         out_ready;
    logic [511:0] out_data;
    logic [127:0] out_user;
    logic [63:0]  out_cntl;
    logic         out_last;
    logic [7:0]   out_srcid;
    logic [7:0]   out_tgtid;
    flit_t        exp_queue[$];
    int           error_count;

    initial begin
        cxs_clk = 1'b0;
        forever #(CXS_CLK_PERIOD / 2) cxs_clk = ~cxs_clk;
    end

    initial begin
        cxs_rst_n     = 1'b0;
        in_valid      = 1'b0;
        in_data       = '0;
        in_user       = '0;
        in_cntl       = '0;
        in_last       = 1'b0;
        in_srcid      = '0;
        in_tgtid      = '0;
        link_tx_ready = 1'b1;
        out_ready     = 1'b1;

        repeat (4) @(posedge cxs_clk);
        cxs_rst_n = 1'b1;
    end

    initial begin
        $dumpfile("tx_path_tb.fst");
        $dumpvars(0, tx_path_tb);
    end

    // DUT hookup template:
    // tx_path dut (
    //     .cxs_clk      (cxs_clk),
    //     .cxs_rst_n    (cxs_rst_n),
    //     .in_valid     (in_valid),
    //     .in_ready     (in_ready),
    //     .in_data      (in_data),
    //     .in_user      (in_user),
    //     .in_cntl      (in_cntl),
    //     .in_last      (in_last),
    //     .in_srcid     (in_srcid),
    //     .in_tgtid     (in_tgtid),
    //     .link_tx_ready(link_tx_ready),
    //     .out_valid    (out_valid),
    //     .out_ready    (out_ready),
    //     .out_data     (out_data),
    //     .out_user     (out_user),
    //     .out_cntl     (out_cntl),
    //     .out_last     (out_last),
    //     .out_srcid    (out_srcid),
    //     .out_tgtid    (out_tgtid)
    // );

    task automatic send_flit(
        input logic [511:0] data,
        input logic [127:0] user,
        input logic [63:0]  cntl,
        input logic         last,
        input logic [7:0]   srcid,
        input logic [7:0]   tgtid
    );
        begin
            @(posedge cxs_clk);
            in_valid <= 1'b1;
            in_data  <= data;
            in_user  <= user;
            in_cntl  <= cntl;
            in_last  <= last;
            in_srcid <= srcid;
            in_tgtid <= tgtid;
            exp_queue.push_back('{data, user, cntl, last, srcid, tgtid});
            wait (in_ready === 1'b1);
            @(posedge cxs_clk);
            in_valid <= 1'b0;
        end
    endtask

    task automatic compare_output(input string tag);
        flit_t exp_flit;
        begin
            if (exp_queue.size() == 0) begin
                error_count++;
                $display("ERROR[%0t] %s unexpected output flit", $time, tag);
            end
            else begin
                exp_flit = exp_queue.pop_front();

                if (out_data !== exp_flit.data) begin
                    error_count++;
                    $display("ERROR[%0t] %s data mismatch", $time, tag);
                end
                if (out_user !== exp_flit.user) begin
                    error_count++;
                    $display("ERROR[%0t] %s user mismatch", $time, tag);
                end
                if (out_cntl !== exp_flit.cntl) begin
                    error_count++;
                    $display("ERROR[%0t] %s cntl mismatch", $time, tag);
                end
                if (out_last !== exp_flit.last) begin
                    error_count++;
                    $display("ERROR[%0t] %s last mismatch", $time, tag);
                end
                if (out_srcid !== exp_flit.srcid) begin
                    error_count++;
                    $display("ERROR[%0t] %s srcid mismatch", $time, tag);
                end
                if (out_tgtid !== exp_flit.tgtid) begin
                    error_count++;
                    $display("ERROR[%0t] %s tgtid mismatch", $time, tag);
                end
            end
        end
    endtask

    task automatic scenario_single_flit;
        begin
            send_flit(512'hA5A5_0001, 128'h11, 64'h1, 1'b1, 8'h12, 8'h34);
            repeat (2) @(posedge cxs_clk);
            $display("[%0t] single_flit queued=%0d", $time, exp_queue.size());
        end
    endtask

    task automatic scenario_burst_flits;
        begin
            send_flit(512'hA5A5_0002, 128'h22, 64'h2, 1'b0, 8'h56, 8'h78);
            send_flit(512'hA5A5_0003, 128'h33, 64'h3, 1'b1, 8'h9A, 8'hBC);
            repeat (2) @(posedge cxs_clk);
            $display("[%0t] burst_flits queued=%0d", $time, exp_queue.size());
        end
    endtask

    task automatic scenario_link_gating;
        begin
            @(posedge cxs_clk);
            link_tx_ready <= 1'b0;
            repeat (3) @(posedge cxs_clk);
            link_tx_ready <= 1'b1;
            $display("[%0t] link gating exercised", $time);
        end
    endtask

    always @(posedge cxs_clk) begin
        if (out_valid && out_ready) begin
            compare_output("out_handshake");
        end
    end

    initial begin
        error_count = 0;
        @(posedge cxs_rst_n);

        // NOTE:
        // Queue-based scoreboard structure is ready.
        // Once the DUT is connected, out_valid/out_ready handshakes will
        // automatically trigger payload comparison.
        scenario_single_flit();
        scenario_burst_flits();
        scenario_link_gating();

        repeat (20) @(posedge cxs_clk);
        $display("tx_path_tb completed with error_count=%0d queue_depth=%0d",
                 error_count, exp_queue.size());
        $finish;
    end

endmodule: tx_path_tb
