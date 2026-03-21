/***********************************************************************
 * Copyright 2026
 **********************************************************************/

/*
 * Module: lme_handler_tb
 *
 * Skeleton testbench for lme_handler.
 * This testbench is intended to validate normalized sideband message
 * exchange, negotiation flow, and CDC-aware message ordering.
 */

`timescale 1ns/1ps

module lme_handler_tb;

    localparam time CXS_CLK_PERIOD = 10ns;
    localparam time FDI_CLK_PERIOD = 12ns;
    localparam int  SB_MSG_WIDTH   = 32;
    localparam logic [3:0] OP_PARAM_REQ    = 4'h1;
    localparam logic [3:0] OP_PARAM_RSP    = 4'h2;
    localparam logic [3:0] OP_PARAM_ACCEPT = 4'h3;
    localparam logic [3:0] OP_PARAM_REJECT = 4'h4;
    localparam logic [3:0] OP_ACTIVE_REQ   = 4'h5;
    localparam logic [3:0] OP_ACTIVE_ACK   = 4'h6;
    localparam logic [3:0] OP_DEACT_HINT   = 4'h7;
    localparam logic [3:0] OP_ERROR_MSG    = 4'h8;

    typedef struct packed {
        logic [3:0] opcode;
        logic [3:0] tag;
        logic [7:0] arg0;
        logic [7:0] arg1;
        logic [7:0] arg2;
    } sb_msg_t;

    logic                    cxs_clk;
    logic                    cxs_rst_n;
    logic                    fdi_lclk;
    logic                    fdi_rst_n;

    logic                    cxs_sb_rx_valid;
    logic [SB_MSG_WIDTH-1:0] cxs_sb_rx_data;
    logic                    cxs_sb_rx_ready;
    logic                    cxs_sb_tx_valid;
    logic [SB_MSG_WIDTH-1:0] cxs_sb_tx_data;
    logic                    cxs_sb_tx_ready;

    logic                    fdi_sb_rx_valid;
    logic [SB_MSG_WIDTH-1:0] fdi_sb_rx_data;
    logic                    fdi_sb_rx_ready;
    logic                    fdi_sb_tx_valid;
    logic [SB_MSG_WIDTH-1:0] fdi_sb_tx_data;
    logic                    fdi_sb_tx_ready;

    logic                    lme_enable;
    logic [3:0]              local_flit_width_sel;
    logic [7:0]              local_max_credit;
    logic [7:0]              local_fifo_depth;
    logic [7:0]              local_timeout;

    logic [3:0]              neg_flit_width_sel;
    logic [7:0]              neg_max_credit;
    logic [7:0]              neg_fifo_depth;
    logic                    lme_init_done;
    logic                    lme_active;
    logic                    lme_error;
    logic                    lme_timeout;
    logic                    lme_intr;
    sb_msg_t                 exp_cxs_tx_queue[$];
    sb_msg_t                 exp_fdi_tx_queue[$];
    int                      error_count;

    initial begin
        cxs_clk = 1'b0;
        forever #(CXS_CLK_PERIOD / 2) cxs_clk = ~cxs_clk;
    end

    initial begin
        fdi_lclk = 1'b0;
        forever #(FDI_CLK_PERIOD / 2) fdi_lclk = ~fdi_lclk;
    end

    initial begin
        cxs_rst_n             = 1'b0;
        fdi_rst_n             = 1'b0;
        cxs_sb_rx_valid       = 1'b0;
        cxs_sb_rx_data        = '0;
        cxs_sb_tx_ready       = 1'b1;
        fdi_sb_rx_valid       = 1'b0;
        fdi_sb_rx_data        = '0;
        fdi_sb_tx_ready       = 1'b1;
        lme_enable            = 1'b0;
        local_flit_width_sel  = 4'd2;
        local_max_credit      = 8'd16;
        local_fifo_depth      = 8'd32;
        local_timeout         = 8'd20;

        repeat (4) @(posedge cxs_clk);
        cxs_rst_n = 1'b1;
        repeat (2) @(posedge fdi_lclk);
        fdi_rst_n = 1'b1;
    end

    initial begin
        $dumpfile("lme_handler_tb.fst");
        $dumpvars(0, lme_handler_tb);
    end

    // DUT hookup template:
    // lme_handler dut (
    //     .cxs_clk            (cxs_clk),
    //     .cxs_rst_n          (cxs_rst_n),
    //     .fdi_lclk           (fdi_lclk),
    //     .fdi_rst_n          (fdi_rst_n),
    //     .cxs_sb_rx_valid    (cxs_sb_rx_valid),
    //     .cxs_sb_rx_data     (cxs_sb_rx_data),
    //     .cxs_sb_rx_ready    (cxs_sb_rx_ready),
    //     .cxs_sb_tx_valid    (cxs_sb_tx_valid),
    //     .cxs_sb_tx_data     (cxs_sb_tx_data),
    //     .cxs_sb_tx_ready    (cxs_sb_tx_ready),
    //     .fdi_sb_rx_valid    (fdi_sb_rx_valid),
    //     .fdi_sb_rx_data     (fdi_sb_rx_data),
    //     .fdi_sb_rx_ready    (fdi_sb_rx_ready),
    //     .fdi_sb_tx_valid    (fdi_sb_tx_valid),
    //     .fdi_sb_tx_data     (fdi_sb_tx_data),
    //     .fdi_sb_tx_ready    (fdi_sb_tx_ready),
    //     .lme_enable         (lme_enable),
    //     .local_flit_width_sel(local_flit_width_sel),
    //     .local_max_credit   (local_max_credit),
    //     .local_fifo_depth   (local_fifo_depth),
    //     .local_timeout      (local_timeout),
    //     .neg_flit_width_sel (neg_flit_width_sel),
    //     .neg_max_credit     (neg_max_credit),
    //     .neg_fifo_depth     (neg_fifo_depth),
    //     .lme_init_done      (lme_init_done),
    //     .lme_active         (lme_active),
    //     .lme_error          (lme_error),
    //     .lme_timeout        (lme_timeout),
    //     .lme_intr           (lme_intr)
    // );

    task automatic send_cxs_msg(input logic [SB_MSG_WIDTH-1:0] msg);
        begin
            @(posedge cxs_clk);
            cxs_sb_rx_valid <= 1'b1;
            cxs_sb_rx_data  <= msg;
            wait (cxs_sb_rx_ready === 1'b1);
            @(posedge cxs_clk);
            cxs_sb_rx_valid <= 1'b0;
            cxs_sb_rx_data  <= '0;
        end
    endtask

    task automatic send_fdi_msg(input logic [SB_MSG_WIDTH-1:0] msg);
        begin
            @(posedge fdi_lclk);
            fdi_sb_rx_valid <= 1'b1;
            fdi_sb_rx_data  <= msg;
            wait (fdi_sb_rx_ready === 1'b1);
            @(posedge fdi_lclk);
            fdi_sb_rx_valid <= 1'b0;
            fdi_sb_rx_data  <= '0;
        end
    endtask

    function automatic logic [SB_MSG_WIDTH-1:0] make_msg(
        input logic [3:0] opcode,
        input logic [3:0] tag,
        input logic [7:0] arg0,
        input logic [7:0] arg1,
        input logic [7:0] arg2
    );
        begin
            make_msg = {opcode, tag, arg0, arg1, arg2};
        end
    endfunction

    function automatic sb_msg_t unpack_msg(input logic [SB_MSG_WIDTH-1:0] msg);
        begin
            unpack_msg.opcode = msg[31:28];
            unpack_msg.tag    = msg[27:24];
            unpack_msg.arg0   = msg[23:16];
            unpack_msg.arg1   = msg[15:8];
            unpack_msg.arg2   = msg[7:0];
        end
    endfunction

    task automatic compare_cxs_tx_msg(input string tag);
        sb_msg_t exp_msg;
        sb_msg_t got_msg;
        begin
            if (exp_cxs_tx_queue.size() == 0) begin
                error_count++;
                $display("ERROR[%0t] %s unexpected CXS TX msg 0x%08h",
                         $time, tag, cxs_sb_tx_data);
            end
            else begin
                exp_msg = exp_cxs_tx_queue.pop_front();
                got_msg = unpack_msg(cxs_sb_tx_data);
                if (got_msg !== exp_msg) begin
                    error_count++;
                    $display("ERROR[%0t] %s CXS TX msg mismatch exp=0x%08h got=0x%08h",
                             $time, tag,
                             make_msg(exp_msg.opcode, exp_msg.tag, exp_msg.arg0, exp_msg.arg1, exp_msg.arg2),
                             cxs_sb_tx_data);
                end
            end
        end
    endtask

    task automatic compare_fdi_tx_msg(input string tag);
        sb_msg_t exp_msg;
        sb_msg_t got_msg;
        begin
            if (exp_fdi_tx_queue.size() == 0) begin
                error_count++;
                $display("ERROR[%0t] %s unexpected FDI TX msg 0x%08h",
                         $time, tag, fdi_sb_tx_data);
            end
            else begin
                exp_msg = exp_fdi_tx_queue.pop_front();
                got_msg = unpack_msg(fdi_sb_tx_data);
                if (got_msg !== exp_msg) begin
                    error_count++;
                    $display("ERROR[%0t] %s FDI TX msg mismatch exp=0x%08h got=0x%08h",
                             $time, tag,
                             make_msg(exp_msg.opcode, exp_msg.tag, exp_msg.arg0, exp_msg.arg1, exp_msg.arg2),
                             fdi_sb_tx_data);
                end
            end
        end
    endtask

    task automatic scenario_param_negotiation;
        sb_msg_t exp_msg;
        begin
            send_cxs_msg(make_msg(OP_PARAM_REQ, 4'h0, 8'd2, 8'd16, 8'd32));
            send_fdi_msg(make_msg(OP_PARAM_RSP, 4'h0, 8'd2, 8'd16, 8'd32));

            exp_msg = '{opcode: OP_PARAM_ACCEPT, tag: 4'h0, arg0: 8'd2, arg1: 8'd16, arg2: 8'd32};
            exp_cxs_tx_queue.push_back(exp_msg);

            repeat (4) @(posedge cxs_clk);
            $display("[%0t] scenario_param_negotiation queued_cxs_tx=%0d",
                     $time, exp_cxs_tx_queue.size());
        end
    endtask

    task automatic scenario_param_reject;
        sb_msg_t exp_msg;
        begin
            send_fdi_msg(make_msg(OP_PARAM_REJECT, 4'h0, 8'hFF, 8'h00, 8'h00));
            exp_msg = '{opcode: OP_ERROR_MSG, tag: 4'h0, arg0: 8'h00, arg1: 8'h00, arg2: 8'h00};
            exp_cxs_tx_queue.push_back(exp_msg);

            repeat (4) @(posedge cxs_clk);
            $display("[%0t] scenario_param_reject queued_cxs_tx=%0d",
                     $time, exp_cxs_tx_queue.size());
        end
    endtask

    task automatic scenario_active_handshake;
        sb_msg_t exp_msg;
        begin
            exp_msg = '{opcode: OP_ACTIVE_REQ, tag: 4'h0, arg0: 8'h00, arg1: 8'h00, arg2: 8'h00};
            exp_fdi_tx_queue.push_back(exp_msg);

            send_fdi_msg(make_msg(OP_ACTIVE_ACK, 4'h0, 8'h00, 8'h00, 8'h00));

            repeat (4) @(posedge cxs_clk);
            $display("[%0t] scenario_active_handshake queued_fdi_tx=%0d",
                     $time, exp_fdi_tx_queue.size());
        end
    endtask

    task automatic scenario_unknown_opcode;
        begin
            send_fdi_msg(make_msg(4'hF, 4'h0, 8'h00, 8'h00, 8'h00));
            repeat (4) @(posedge cxs_clk);
            $display("[%0t] scenario_unknown_opcode exercised", $time);
        end
    endtask

    task automatic scenario_backpressure;
        begin
            cxs_sb_tx_ready <= 1'b0;
            fdi_sb_tx_ready <= 1'b0;
            repeat (4) @(posedge cxs_clk);
            cxs_sb_tx_ready <= 1'b1;
            fdi_sb_tx_ready <= 1'b1;
            $display("[%0t] scenario_backpressure exercised", $time);
        end
    endtask

    always @(posedge cxs_clk) begin
        if (cxs_sb_tx_valid && cxs_sb_tx_ready) begin
            compare_cxs_tx_msg("cxs_tx_handshake");
        end
    end

    always @(posedge fdi_lclk) begin
        if (fdi_sb_tx_valid && fdi_sb_tx_ready) begin
            compare_fdi_tx_msg("fdi_tx_handshake");
        end
    end

    initial begin
        error_count = 0;
        @(posedge cxs_rst_n);
        @(posedge fdi_rst_n);

        @(posedge cxs_clk);
        lme_enable <= 1'b1;

        // NOTE:
        // Message queue based scoreboarding is ready.
        // Once the DUT is connected, outgoing sideband messages will be
        // compared automatically on valid/ready handshakes.
        scenario_param_negotiation();
        scenario_param_reject();
        scenario_active_handshake();
        scenario_unknown_opcode();
        scenario_backpressure();

        repeat (40) @(posedge cxs_clk);
        $display("lme_handler_tb completed with error_count=%0d cxs_q=%0d fdi_q=%0d",
                 error_count, exp_cxs_tx_queue.size(), exp_fdi_tx_queue.size());
        $finish;
    end

endmodule: lme_handler_tb
