/***********************************************************************
 * Copyright 2026
 **********************************************************************/

/*
 * Module: lme_handler
 *
 * Project-internal normalized sideband LME handler.
 *
 * This implementation is intentionally compact and verification-friendly:
 * - CXS-side control/state is managed in cxs_clk domain
 * - FDI incoming messages are edge-synchronized into cxs_clk domain
 * - FDI outgoing messages are launched from cxs_clk and consumed in
 *   fdi_lclk domain through a toggle-based event handoff
 */

module lme_handler #(
    parameter int SB_MSG_WIDTH = 32
) (
    input  logic                    cxs_clk,
    input  logic                    cxs_rst_n,
    input  logic                    fdi_lclk,
    input  logic                    fdi_rst_n,
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic                    cxs_sb_rx_valid,
    input  logic [SB_MSG_WIDTH-1:0] cxs_sb_rx_data,
    output logic                    cxs_sb_rx_ready,
    output logic                    cxs_sb_tx_valid,
    output logic [SB_MSG_WIDTH-1:0] cxs_sb_tx_data,
    input  logic                    cxs_sb_tx_ready,
    input  logic                    fdi_sb_rx_valid,
    input  logic [SB_MSG_WIDTH-1:0] fdi_sb_rx_data,
    output logic                    fdi_sb_rx_ready,
    output logic                    fdi_sb_tx_valid,
    output logic [SB_MSG_WIDTH-1:0] fdi_sb_tx_data,
    input  logic                    fdi_sb_tx_ready,
    input  logic                    lme_enable,
    input  logic [3:0]              local_flit_width_sel,
    input  logic [7:0]              local_max_credit,
    input  logic [7:0]              local_fifo_depth,
    /* verilator lint_on UNUSEDSIGNAL */
    input  logic [7:0]              local_timeout,
    output logic [3:0]              neg_flit_width_sel,
    output logic [7:0]              neg_max_credit,
    output logic [7:0]              neg_fifo_depth,
    output logic                    lme_init_done,
    output logic                    lme_active,
    output logic                    lme_error,
    output logic                    lme_timeout,
    output logic                    lme_intr
);

    /* verilator lint_off UNUSEDPARAM */
    localparam logic [3:0] OP_PARAM_REQ    = 4'h1;
    /* verilator lint_on UNUSEDPARAM */
    localparam logic [3:0] OP_PARAM_RSP    = 4'h2;
    localparam logic [3:0] OP_PARAM_ACCEPT = 4'h3;
    localparam logic [3:0] OP_PARAM_REJECT = 4'h4;
    localparam logic [3:0] OP_ACTIVE_REQ   = 4'h5;
    localparam logic [3:0] OP_ACTIVE_ACK   = 4'h6;
    localparam logic [3:0] OP_ERROR_MSG    = 4'h8;

    localparam logic [2:0] ST_IDLE      = 3'b000;
    localparam logic [2:0] ST_INIT      = 3'b001;
    localparam logic [2:0] ST_NEGOTIATE = 3'b010;
    localparam logic [2:0] ST_ACTIVE    = 3'b011;
    localparam logic [2:0] ST_MONITOR   = 3'b100;
    localparam logic [2:0] ST_ERROR     = 3'b101;

    logic [2:0]                state_q;
    logic [7:0]                timeout_cnt_q;

    logic                      cxs_tx_pending_q;
    logic [SB_MSG_WIDTH-1:0]   cxs_tx_msg_q;

    logic [SB_MSG_WIDTH-1:0]   fdi_rx_msg_async_q;
    logic                      fdi_rx_toggle_q;
    logic                      fdi_rx_toggle_sync1_q;
    logic                      fdi_rx_toggle_sync2_q;
    logic                      fdi_rx_toggle_seen_q;

    logic [SB_MSG_WIDTH-1:0]   fdi_tx_msg_buf_q;
    logic                      fdi_tx_launch_toggle_q;
    logic                      fdi_tx_launch_sync1_q;
    logic                      fdi_tx_launch_sync2_q;
    logic                      fdi_tx_launch_seen_q;
    logic                      fdi_tx_pending_q;
    logic [SB_MSG_WIDTH-1:0]   fdi_tx_msg_q;

    /* verilator lint_off UNUSEDSIGNAL */
    function automatic logic [3:0] msg_opcode(input logic [SB_MSG_WIDTH-1:0] msg);
        begin
            msg_opcode = msg[31:28];
        end
    endfunction

    function automatic logic [3:0] msg_tag(input logic [SB_MSG_WIDTH-1:0] msg);
        begin
            msg_tag = msg[27:24];
        end
    endfunction

    function automatic logic [7:0] msg_arg0(input logic [SB_MSG_WIDTH-1:0] msg);
        begin
            msg_arg0 = msg[23:16];
        end
    endfunction

    function automatic logic [7:0] msg_arg1(input logic [SB_MSG_WIDTH-1:0] msg);
        begin
            msg_arg1 = msg[15:8];
        end
    endfunction

    function automatic logic [7:0] msg_arg2(input logic [SB_MSG_WIDTH-1:0] msg);
        begin
            msg_arg2 = msg[7:0];
        end
    endfunction
    /* verilator lint_on UNUSEDSIGNAL */

    function automatic logic [SB_MSG_WIDTH-1:0] build_msg(
        input logic [3:0] opcode,
        input logic [3:0] tag,
        input logic [7:0] arg0,
        input logic [7:0] arg1,
        input logic [7:0] arg2
    );
        begin
            build_msg = {opcode, tag, arg0, arg1, arg2};
        end
    endfunction

    assign cxs_sb_rx_ready = 1'b1;
    assign fdi_sb_rx_ready = 1'b1;

    // CXS TX side is held until handshake.
    assign cxs_sb_tx_valid = cxs_tx_pending_q;
    assign cxs_sb_tx_data  = cxs_tx_msg_q;

    // FDI TX side is held in fdi_lclk domain until handshake.
    assign fdi_sb_tx_valid = fdi_tx_pending_q;
    assign fdi_sb_tx_data  = fdi_tx_msg_q;

    assign lme_intr = lme_error || lme_timeout;

    // Capture FDI inbound messages in FDI clock domain and signal cxs domain.
    always_ff @(posedge fdi_lclk or negedge fdi_rst_n) begin
        if (!fdi_rst_n) begin
            fdi_rx_msg_async_q <= '0;
            fdi_rx_toggle_q    <= 1'b0;
        end
        else if (fdi_sb_rx_valid && fdi_sb_rx_ready) begin
            fdi_rx_msg_async_q <= fdi_sb_rx_data;
            fdi_rx_toggle_q    <= ~fdi_rx_toggle_q;
        end
    end

    // Receive launch event in FDI TX domain.
    always_ff @(posedge fdi_lclk or negedge fdi_rst_n) begin
        if (!fdi_rst_n) begin
            fdi_tx_launch_sync1_q <= 1'b0;
            fdi_tx_launch_sync2_q <= 1'b0;
            fdi_tx_launch_seen_q  <= 1'b0;
            fdi_tx_pending_q      <= 1'b0;
            fdi_tx_msg_q          <= '0;
        end
        else begin
            fdi_tx_launch_sync1_q <= fdi_tx_launch_toggle_q;
            fdi_tx_launch_sync2_q <= fdi_tx_launch_sync1_q;

            if (fdi_tx_launch_sync2_q != fdi_tx_launch_seen_q) begin
                fdi_tx_launch_seen_q <= fdi_tx_launch_sync2_q;
                fdi_tx_pending_q     <= 1'b1;
                fdi_tx_msg_q         <= fdi_tx_msg_buf_q;
            end
            else if (fdi_tx_pending_q && fdi_sb_tx_ready) begin
                fdi_tx_pending_q <= 1'b0;
            end
        end
    end

    // Main LME control in cxs_clk domain.
    always_ff @(posedge cxs_clk or negedge cxs_rst_n) begin
        if (!cxs_rst_n) begin
            state_q              <= ST_IDLE;
            timeout_cnt_q        <= '0;
            cxs_tx_pending_q     <= 1'b0;
            cxs_tx_msg_q         <= '0;
            fdi_rx_toggle_sync1_q <= 1'b0;
            fdi_rx_toggle_sync2_q <= 1'b0;
            fdi_rx_toggle_seen_q  <= 1'b0;
            fdi_tx_msg_buf_q     <= '0;
            fdi_tx_launch_toggle_q <= 1'b0;
            neg_flit_width_sel   <= '0;
            neg_max_credit       <= '0;
            neg_fifo_depth       <= '0;
            lme_init_done        <= 1'b0;
            lme_active           <= 1'b0;
            lme_error            <= 1'b0;
            lme_timeout          <= 1'b0;
        end
        else begin
            fdi_rx_toggle_sync1_q <= fdi_rx_toggle_q;
            fdi_rx_toggle_sync2_q <= fdi_rx_toggle_sync1_q;

            if (cxs_tx_pending_q && cxs_sb_tx_ready) begin
                cxs_tx_pending_q <= 1'b0;
            end

            if (!lme_enable) begin
                state_q        <= ST_IDLE;
                timeout_cnt_q  <= '0;
                lme_init_done  <= 1'b0;
                lme_active     <= 1'b0;
                lme_error      <= 1'b0;
                lme_timeout    <= 1'b0;
            end
            else begin
                if (state_q != ST_MONITOR && state_q != ST_ERROR) begin
                    timeout_cnt_q <= timeout_cnt_q + 1'b1;
                end

                if ((state_q == ST_NEGOTIATE || state_q == ST_ACTIVE) &&
                    (timeout_cnt_q >= local_timeout)) begin
                    state_q       <= ST_ERROR;
                    lme_timeout   <= 1'b1;
                    lme_error     <= 1'b1;
                    lme_active    <= 1'b0;
                    cxs_tx_pending_q <= 1'b1;
                    cxs_tx_msg_q     <= build_msg(OP_ERROR_MSG, 4'h0, 8'h00, 8'h00, 8'h00);
                end

                case (state_q)
                    ST_IDLE: begin
                        state_q     <= ST_INIT;
                        timeout_cnt_q <= '0;
                    end

                    ST_INIT: begin
                        state_q     <= ST_NEGOTIATE;
                        timeout_cnt_q <= '0;
                    end

                    default: begin
                        // State transitions are primarily driven by received messages below.
                    end
                endcase

                if (fdi_rx_toggle_sync2_q != fdi_rx_toggle_seen_q) begin
                    fdi_rx_toggle_seen_q <= fdi_rx_toggle_sync2_q;

                    case (msg_opcode(fdi_rx_msg_async_q))
                        OP_PARAM_RSP: begin
                            if (msg_tag(fdi_rx_msg_async_q) != 4'h0) begin
                                state_q         <= ST_ERROR;
                                lme_error       <= 1'b1;
                                cxs_tx_pending_q <= 1'b1;
                                cxs_tx_msg_q     <= build_msg(OP_ERROR_MSG, 4'h0, 8'h00, 8'h00, 8'h00);
                            end
                            else begin
                                neg_flit_width_sel <= fdi_rx_msg_async_q[19:16];
                                neg_max_credit     <= msg_arg1(fdi_rx_msg_async_q);
                                neg_fifo_depth     <= msg_arg2(fdi_rx_msg_async_q);
                                cxs_tx_pending_q   <= 1'b1;
                                cxs_tx_msg_q       <= build_msg(OP_PARAM_ACCEPT, 4'h0,
                                                                msg_arg0(fdi_rx_msg_async_q),
                                                                msg_arg1(fdi_rx_msg_async_q),
                                                                msg_arg2(fdi_rx_msg_async_q));
                                fdi_tx_msg_buf_q     <= build_msg(OP_ACTIVE_REQ, 4'h0,
                                                                  8'h00, 8'h00, 8'h00);
                                fdi_tx_launch_toggle_q <= ~fdi_tx_launch_toggle_q;
                                state_q             <= ST_ACTIVE;
                                timeout_cnt_q       <= '0;
                                lme_init_done       <= 1'b1;
                            end
                        end

                        OP_PARAM_REJECT: begin
                            state_q          <= ST_ERROR;
                            lme_error        <= 1'b1;
                            lme_active       <= 1'b0;
                            cxs_tx_pending_q <= 1'b1;
                            cxs_tx_msg_q     <= build_msg(OP_ERROR_MSG, 4'h0, 8'h00, 8'h00, 8'h00);
                        end

                        OP_ACTIVE_ACK: begin
                            if (state_q == ST_ACTIVE) begin
                                state_q      <= ST_MONITOR;
                                lme_active   <= 1'b1;
                                lme_error    <= 1'b0;
                                lme_timeout  <= 1'b0;
                                timeout_cnt_q <= '0;
                            end
                            else begin
                                state_q          <= ST_ERROR;
                                lme_error        <= 1'b1;
                                lme_active       <= 1'b0;
                                cxs_tx_pending_q <= 1'b1;
                                cxs_tx_msg_q     <= build_msg(OP_ERROR_MSG, 4'h0, 8'h00, 8'h00, 8'h00);
                            end
                        end

                        OP_ERROR_MSG: begin
                            state_q    <= ST_ERROR;
                            lme_error  <= 1'b1;
                            lme_active <= 1'b0;
                        end

                        default: begin
                            state_q          <= ST_ERROR;
                            lme_error        <= 1'b1;
                            lme_active       <= 1'b0;
                            cxs_tx_pending_q <= 1'b1;
                            cxs_tx_msg_q     <= build_msg(OP_ERROR_MSG, 4'h0, 8'h00, 8'h00, 8'h00);
                        end
                    endcase
                end
            end
        end
    end

endmodule: lme_handler
