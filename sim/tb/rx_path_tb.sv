/***********************************************************************
 * Copyright 2026
 **********************************************************************/

/*
 * Module: rx_path_tb
 *
 * Skeleton testbench for rx_path.
 * Intended for later expansion with FIFO-oriented scoreboard checking.
 */

`timescale 1ns/1ps

module rx_path_tb;

    localparam time CXS_CLK_PERIOD = 10ns;
    localparam time FDI_CLK_PERIOD = 12ns;
    localparam int  CXS_DATA_WIDTH  = 512;
    localparam int  CXS_USER_WIDTH  = 64;
    localparam int  CXS_CNTL_WIDTH  = 8;
    localparam int  CXS_SRCID_WIDTH = 8;
    localparam int  CXS_TGTID_WIDTH = 8;
    localparam int  FDI_DATA_WIDTH  = 512;
    localparam int  FDI_USER_WIDTH  = 64;
    localparam int  FLIT_WIDTH = FDI_DATA_WIDTH + FDI_USER_WIDTH +
                                 CXS_CNTL_WIDTH + 1 +
                                 CXS_SRCID_WIDTH + CXS_TGTID_WIDTH;
    localparam int  FLIT_TGTID_LSB = 0;
    localparam int  FLIT_SRCID_LSB = FLIT_TGTID_LSB + CXS_TGTID_WIDTH;
    localparam int  FLIT_LAST_LSB   = FLIT_SRCID_LSB + CXS_SRCID_WIDTH;
    localparam int  FLIT_CNTL_LSB   = FLIT_LAST_LSB + 1;
    localparam int  FLIT_USER_LSB   = FLIT_CNTL_LSB + CXS_CNTL_WIDTH;
    localparam int  FLIT_DATA_LSB   = FLIT_USER_LSB + FDI_USER_WIDTH;

    logic         cxs_clk;
    logic         cxs_rst_n;
    logic         fdi_lclk;
    logic         fdi_rst_n;
    logic         rx_valid_in;
    logic         rx_data_ack;
    logic [511:0] rx_data_in;
    logic [63:0]  rx_user_in;
    logic [7:0]   rx_cntl_in;
    logic         rx_last_in;
    logic [7:0]   rx_srcid_in;
    logic [7:0]   rx_tgtid_in;
    logic         rx_valid_out;
    logic         rx_ready;
    logic [511:0] rx_data_out;
    logic [63:0]  rx_user_out;
    logic [7:0]   rx_cntl_out;
    logic         rx_last_out;
    logic [7:0]   rx_srcid_out;
    logic [7:0]   rx_tgtid_out;
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
        rx_valid_in   = 1'b0;
        rx_data_in    = '0;
        rx_user_in    = '0;
        rx_cntl_in    = '0;
        rx_last_in    = 1'b0;
        rx_srcid_in   = '0;
        rx_tgtid_in   = '0;
        rx_ready      = 1'b1;

        repeat (4) @(posedge fdi_lclk);
        fdi_rst_n = 1'b1;
        repeat (2) @(posedge cxs_clk);
        cxs_rst_n = 1'b1;
    end

    initial begin
        $dumpfile("rx_path_tb.fst");
        $dumpvars(0, rx_path_tb);
    end

    rx_path #(
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
        .rx_valid_in  (rx_valid_in),
        .rx_data_in   (rx_data_in),
        .rx_user_in   (rx_user_in),
        .rx_cntl_in   (rx_cntl_in),
        .rx_last_in   (rx_last_in),
        .rx_srcid_in  (rx_srcid_in),
        .rx_tgtid_in  (rx_tgtid_in),
        .rx_data_ack  (rx_data_ack),
        .rx_valid_out (rx_valid_out),
        .rx_data_out  (rx_data_out),
        .rx_user_out  (rx_user_out),
        .rx_cntl_out  (rx_cntl_out),
        .rx_last_out  (rx_last_out),
        .rx_srcid_out (rx_srcid_out),
        .rx_tgtid_out (rx_tgtid_out),
        .rx_ready     (rx_ready),
        .rx_error     ()
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
            @(posedge fdi_lclk);
            rx_valid_in <= 1'b1;
            rx_data_in  <= data;
            rx_user_in  <= user;
            rx_cntl_in  <= cntl;
            rx_last_in  <= last;
            rx_srcid_in <= srcid;
            rx_tgtid_in <= tgtid;
            wait (rx_data_ack === 1'b1);
            exp_queue.push_back({data, user, cntl, last, srcid, tgtid});
            @(posedge fdi_lclk);
            rx_valid_in <= 1'b0;
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

                if (rx_data_out !== exp_flit[FLIT_DATA_LSB +: FDI_DATA_WIDTH]) begin
                    error_count++;
                    $display("ERROR[%0t] %s data mismatch", $time, tag);
                end
                if (rx_user_out !== exp_flit[FLIT_USER_LSB +: FDI_USER_WIDTH]) begin
                    error_count++;
                    $display("ERROR[%0t] %s user mismatch", $time, tag);
                end
                if (rx_cntl_out !== exp_flit[FLIT_CNTL_LSB +: CXS_CNTL_WIDTH]) begin
                    error_count++;
                    $display("ERROR[%0t] %s cntl mismatch", $time, tag);
                end
                if (rx_last_out !== exp_flit[FLIT_LAST_LSB]) begin
                    error_count++;
                    $display("ERROR[%0t] %s last mismatch", $time, tag);
                end
                if (rx_srcid_out !== exp_flit[FLIT_SRCID_LSB +: CXS_SRCID_WIDTH]) begin
                    error_count++;
                    $display("ERROR[%0t] %s srcid mismatch", $time, tag);
                end
                if (rx_tgtid_out !== exp_flit[FLIT_TGTID_LSB +: CXS_TGTID_WIDTH]) begin
                    error_count++;
                    $display("ERROR[%0t] %s tgtid mismatch", $time, tag);
                end
            end
        end
    endtask

    task automatic scenario_single_flit;
        begin
            send_flit(512'h5A5A_0001, 64'h44, 8'h4, 1'b1, 8'h21, 8'h43);
            repeat (2) @(posedge cxs_clk);
            $display("[%0t] single_flit queued=%0d", $time, exp_queue.size());
        end
    endtask

    task automatic scenario_burst_flits;
        begin
            send_flit(512'h5A5A_0002, 64'h55, 8'h5, 1'b0, 8'h65, 8'h87);
            send_flit(512'h5A5A_0003, 64'h66, 8'h6, 1'b1, 8'hA9, 8'hCB);
            repeat (2) @(posedge cxs_clk);
            $display("[%0t] burst_flits queued=%0d", $time, exp_queue.size());
        end
    endtask

    task automatic scenario_link_gating;
        begin
            @(posedge cxs_clk);
            rx_ready <= 1'b0;
            repeat (3) @(posedge cxs_clk);
            rx_ready <= 1'b1;
            $display("[%0t] link gating exercised", $time);
        end
    endtask

    always @(posedge cxs_clk) begin
        if (rx_valid_out && rx_ready) begin
            compare_output("out_handshake");
        end
    end

    initial begin
        error_count = 0;
        @(posedge cxs_rst_n);

        // NOTE:
        // Queue-based scoreboard structure is ready.
        // Once the DUT is connected, rx_valid_out/rx_ready handshakes will
        // automatically trigger payload comparison.
        scenario_single_flit();
        scenario_burst_flits();
        scenario_link_gating();

        repeat (20) @(posedge cxs_clk);
        $display("rx_path_tb completed with error_count=%0d queue_depth=%0d",
                 error_count, exp_queue.size());
        $finish;
    end

endmodule: rx_path_tb
