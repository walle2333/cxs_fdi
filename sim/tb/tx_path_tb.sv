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
    localparam time FDI_CLK_PERIOD = 12ns;
    localparam int  CXS_DATA_WIDTH  = 512;
    localparam int  CXS_USER_WIDTH  = 64;
    localparam int  CXS_CNTL_WIDTH  = 8;
    localparam int  CXS_SRCID_WIDTH = 8;
    localparam int  CXS_TGTID_WIDTH = 8;
    localparam int  FDI_DATA_WIDTH  = 512;
    localparam int  FDI_USER_WIDTH  = 64;
    localparam int  FLIT_WIDTH = CXS_DATA_WIDTH + CXS_USER_WIDTH +
                                 CXS_CNTL_WIDTH + 1 +
                                 CXS_SRCID_WIDTH + CXS_TGTID_WIDTH;
    localparam int  FLIT_TGTID_LSB = 0;
    localparam int  FLIT_SRCID_LSB = FLIT_TGTID_LSB + CXS_TGTID_WIDTH;
    localparam int  FLIT_LAST_LSB   = FLIT_SRCID_LSB + CXS_SRCID_WIDTH;
    localparam int  FLIT_CNTL_LSB   = FLIT_LAST_LSB + 1;
    localparam int  FLIT_USER_LSB   = FLIT_CNTL_LSB + CXS_CNTL_WIDTH;
    localparam int  FLIT_DATA_LSB   = FLIT_USER_LSB + CXS_USER_WIDTH;

    logic         cxs_clk;
    logic         cxs_rst_n;
    logic         fdi_lclk;
    logic         fdi_rst_n;
    logic         tx_valid_in;
    logic         tx_ready;
    logic [511:0] tx_data_in;
    logic [63:0]  tx_user_in;
    logic [7:0]   tx_cntl_in;
    logic         tx_last_in;
    logic [7:0]   tx_srcid_in;
    logic [7:0]   tx_tgtid_in;
    logic         tx_valid_out;
    logic         tx_ready_in;
    logic [511:0] tx_data_out;
    logic [63:0]  tx_user_out;
    logic [7:0]   tx_cntl_out;
    logic         tx_last_out;
    logic [7:0]   tx_srcid_out;
    logic [7:0]   tx_tgtid_out;
    logic [FLIT_WIDTH-1:0] exp_queue[$];
    int           error_count;

    initial begin
        cxs_clk = 1'b0;
        forever #(CXS_CLK_PERIOD / 2) cxs_clk = ~cxs_clk;
    end

    initial begin
        fdi_lclk = 1'b0;
        forever #(FDI_CLK_PERIOD / 2) fdi_lclk = ~fdi_lclk;
    end

    initial begin
        cxs_rst_n     = 1'b0;
        fdi_rst_n     = 1'b0;
        tx_valid_in   = 1'b0;
        tx_data_in    = '0;
        tx_user_in    = '0;
        tx_cntl_in    = '0;
        tx_last_in    = 1'b0;
        tx_srcid_in   = '0;
        tx_tgtid_in   = '0;
        tx_ready_in   = 1'b1;

        repeat (4) @(posedge cxs_clk);
        cxs_rst_n = 1'b1;
        repeat (2) @(posedge fdi_lclk);
        fdi_rst_n = 1'b1;
    end

    initial begin
        $dumpfile("tx_path_tb.fst");
        $dumpvars(0, tx_path_tb);
    end

    tx_path #(
        .CXS_DATA_WIDTH  (CXS_DATA_WIDTH),
        .CXS_USER_WIDTH  (CXS_USER_WIDTH),
        .CXS_CNTL_WIDTH  (CXS_CNTL_WIDTH),
        .CXS_SRCID_WIDTH (CXS_SRCID_WIDTH),
        .CXS_TGTID_WIDTH (CXS_TGTID_WIDTH),
        .FDI_DATA_WIDTH  (FDI_DATA_WIDTH),
        .FDI_USER_WIDTH  (FDI_USER_WIDTH),
        .FIFO_DEPTH      (64),
        .ERR_WIDTH       (8)
    ) dut (
        .cxs_clk      (cxs_clk),
        .cxs_rst_n    (cxs_rst_n),
        .fdi_lclk     (fdi_lclk),
        .fdi_rst_n    (fdi_rst_n),
        .tx_valid_in  (tx_valid_in),
        .tx_data_in   (tx_data_in),
        .tx_user_in   (tx_user_in),
        .tx_cntl_in   (tx_cntl_in),
        .tx_last_in   (tx_last_in),
        .tx_srcid_in  (tx_srcid_in),
        .tx_tgtid_in  (tx_tgtid_in),
        .tx_ready     (tx_ready),
        .tx_valid_out (tx_valid_out),
        .tx_data_out  (tx_data_out),
        .tx_user_out  (tx_user_out),
        .tx_cntl_out  (tx_cntl_out),
        .tx_last_out  (tx_last_out),
        .tx_srcid_out (tx_srcid_out),
        .tx_tgtid_out (tx_tgtid_out),
        .tx_ready_in  (tx_ready_in),
        .tx_error     ()
    );

    task automatic send_flit(
        input logic [511:0] data,
        input logic [63:0]  user,
        input logic [7:0]   cntl,
        input logic         last,
        input logic [7:0]   srcid,
        input logic [7:0]   tgtid
    );
        begin
            @(posedge cxs_clk);
            tx_valid_in <= 1'b1;
            tx_data_in  <= data;
            tx_user_in  <= user;
            tx_cntl_in  <= cntl;
            tx_last_in  <= last;
            tx_srcid_in <= srcid;
            tx_tgtid_in <= tgtid;
            wait (tx_ready === 1'b1);
            exp_queue.push_back({data, user, cntl, last, srcid, tgtid});
            @(posedge cxs_clk);
            tx_valid_in <= 1'b0;
        end
    endtask

    task automatic compare_output(input string tag);
        logic [FLIT_WIDTH-1:0] exp_flit;
        begin
            if (exp_queue.size() == 0) begin
                error_count++;
                $display("ERROR[%0t] %s unexpected output flit", $time, tag);
            end
            else begin
                exp_flit = exp_queue.pop_front();

                if (tx_data_out !== exp_flit[FLIT_DATA_LSB +: CXS_DATA_WIDTH]) begin
                    error_count++;
                    $display("ERROR[%0t] %s data mismatch", $time, tag);
                end
                if (tx_user_out !== exp_flit[FLIT_USER_LSB +: CXS_USER_WIDTH]) begin
                    error_count++;
                    $display("ERROR[%0t] %s user mismatch", $time, tag);
                end
                if (tx_cntl_out !== exp_flit[FLIT_CNTL_LSB +: CXS_CNTL_WIDTH]) begin
                    error_count++;
                    $display("ERROR[%0t] %s cntl mismatch", $time, tag);
                end
                if (tx_last_out !== exp_flit[FLIT_LAST_LSB]) begin
                    error_count++;
                    $display("ERROR[%0t] %s last mismatch", $time, tag);
                end
                if (tx_srcid_out !== exp_flit[FLIT_SRCID_LSB +: CXS_SRCID_WIDTH]) begin
                    error_count++;
                    $display("ERROR[%0t] %s srcid mismatch", $time, tag);
                end
                if (tx_tgtid_out !== exp_flit[FLIT_TGTID_LSB +: CXS_TGTID_WIDTH]) begin
                    error_count++;
                    $display("ERROR[%0t] %s tgtid mismatch", $time, tag);
                end
            end
        end
    endtask

    task automatic scenario_single_flit;
        begin
            send_flit(512'hA5A5_0001, 64'h11, 8'h1, 1'b1, 8'h12, 8'h34);
            repeat (2) @(posedge cxs_clk);
            $display("[%0t] single_flit queued=%0d", $time, exp_queue.size());
        end
    endtask

    task automatic scenario_burst_flits;
        begin
            send_flit(512'hA5A5_0002, 64'h22, 8'h2, 1'b0, 8'h56, 8'h78);
            send_flit(512'hA5A5_0003, 64'h33, 8'h3, 1'b1, 8'h9A, 8'hBC);
            repeat (2) @(posedge cxs_clk);
            $display("[%0t] burst_flits queued=%0d", $time, exp_queue.size());
        end
    endtask

    task automatic scenario_link_gating;
        begin
            @(posedge cxs_clk);
            tx_ready_in <= 1'b0;
            repeat (3) @(posedge cxs_clk);
            tx_ready_in <= 1'b1;
            $display("[%0t] link gating exercised", $time);
        end
    endtask

    always @(posedge fdi_lclk) begin
        if (tx_valid_out && tx_ready_in) begin
            compare_output("out_handshake");
        end
    end

    initial begin
        error_count = 0;
        @(posedge cxs_rst_n);

        // NOTE:
        // Queue-based scoreboard structure is ready.
        // Once the DUT is connected, tx_valid_out/tx_ready_in handshakes will
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
