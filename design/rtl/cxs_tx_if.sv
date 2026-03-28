/***********************************************************************
 * Copyright 2026
 **********************************************************************/

/*
 * Module: cxs_tx_if
 *
 * CXS transmit interface front-end.
 *
 * Behavior:
 * - Accepts CXS protocol-layer flits
 * - Gates traffic by link-active request/deactivate hint
 * - Presents a small 1-entry elastic buffer toward tx_path
 * - Keeps sideband fields aligned with data
 */

module cxs_tx_if #(
    parameter int CXS_DATA_WIDTH = 512,
    parameter int CXS_USER_WIDTH = 64,
    parameter int CXS_CNTL_WIDTH = 8,
    parameter int CXS_SRCID_WIDTH = 8,
    parameter int CXS_TGTID_WIDTH = 8,
    parameter bit CXS_HAS_LAST = 1'b1,
    parameter int CXS_USER_PORT_WIDTH = (CXS_USER_WIDTH > 0) ? CXS_USER_WIDTH : 1,
    parameter int CXS_CNTL_PORT_WIDTH = (CXS_CNTL_WIDTH > 0) ? CXS_CNTL_WIDTH : 1,
    parameter int CXS_SRCID_PORT_WIDTH = (CXS_SRCID_WIDTH > 0) ? CXS_SRCID_WIDTH : 1,
    parameter int CXS_TGTID_PORT_WIDTH = (CXS_TGTID_WIDTH > 0) ? CXS_TGTID_WIDTH : 1
) (
    input  logic                               cxs_clk,
    input  logic                               cxs_rst_n,

    input  logic                               cxs_tx_valid,
    input  logic [CXS_DATA_WIDTH-1:0]          cxs_tx_data,
    input  logic [CXS_USER_PORT_WIDTH-1:0]      cxs_tx_user,
    input  logic [CXS_CNTL_PORT_WIDTH-1:0]      cxs_tx_cntl,
    input  logic                               cxs_tx_last,
    input  logic [CXS_SRCID_PORT_WIDTH-1:0]     cxs_tx_srcid,
    input  logic [CXS_TGTID_PORT_WIDTH-1:0]     cxs_tx_tgtid,
    input  logic                               cxs_tx_active_req,
    output logic                               cxs_tx_active,
    input  logic                               cxs_tx_deact_hint,

    output logic                               tx_valid_out,
    output logic [CXS_DATA_WIDTH-1:0]          tx_data_out,
    output logic [CXS_USER_PORT_WIDTH-1:0]      tx_user_out,
    output logic [CXS_CNTL_PORT_WIDTH-1:0]      tx_cntl_out,
    output logic                               tx_last_out,
    output logic [CXS_SRCID_PORT_WIDTH-1:0]     tx_srcid_out,
    output logic [CXS_TGTID_PORT_WIDTH-1:0]     tx_tgtid_out,
    input  logic                               tx_ready,

    output logic                               link_ctrl_active_req,
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic                               link_ctrl_active_ack,
    output logic                               link_ctrl_deact_req,
    /* verilator lint_on UNUSEDSIGNAL */
    input  logic                               link_ctrl_deact_ack
);

    logic                                        buf_valid_q;
    logic                                        buf_valid_d;
    logic [CXS_DATA_WIDTH-1:0]                   buf_data_q;
    logic [CXS_DATA_WIDTH-1:0]                   buf_data_d;
    logic [CXS_USER_PORT_WIDTH-1:0]              buf_user_q;
    logic [CXS_USER_PORT_WIDTH-1:0]              buf_user_d;
    logic [CXS_CNTL_PORT_WIDTH-1:0]              buf_cntl_q;
    logic [CXS_CNTL_PORT_WIDTH-1:0]              buf_cntl_d;
    logic                                        buf_last_q;
    logic                                        buf_last_d;
    logic [CXS_SRCID_PORT_WIDTH-1:0]             buf_srcid_q;
    logic [CXS_SRCID_PORT_WIDTH-1:0]             buf_srcid_d;
    logic [CXS_TGTID_PORT_WIDTH-1:0]             buf_tgtid_q;
    logic [CXS_TGTID_PORT_WIDTH-1:0]             buf_tgtid_d;

    logic                                        accept_in;
    logic                                        cxs_tx_valid_prev_q;
    logic                                        cxs_tx_valid_edge;
    logic                                        active_gate;
    logic                                        can_capture;
    logic                                        capture_now;
    logic                                        consume_now;

    always_comb begin
        active_gate = cxs_tx_active_req && !cxs_tx_deact_hint && !link_ctrl_deact_ack;
        cxs_tx_active = active_gate;

        link_ctrl_active_req = cxs_tx_active_req || cxs_tx_valid;
        link_ctrl_deact_req  = cxs_tx_deact_hint;

        cxs_tx_valid_edge = cxs_tx_valid && !cxs_tx_valid_prev_q;
        accept_in = cxs_tx_valid_edge && active_gate;
        consume_now = buf_valid_q && tx_ready;
        can_capture = !buf_valid_q;
        capture_now = accept_in && can_capture;

        buf_valid_d = buf_valid_q;
        buf_data_d   = buf_data_q;
        buf_user_d   = buf_user_q;
        buf_cntl_d   = buf_cntl_q;
        buf_last_d   = buf_last_q;
        buf_srcid_d  = buf_srcid_q;
        buf_tgtid_d  = buf_tgtid_q;

        if (!cxs_rst_n) begin
            buf_valid_d = 1'b0;
            buf_data_d  = '0;
            buf_user_d   = '0;
            buf_cntl_d   = '0;
            buf_last_d   = 1'b0;
            buf_srcid_d  = '0;
            buf_tgtid_d  = '0;
        end
        else begin
            if (consume_now && !capture_now) begin
                buf_valid_d = 1'b0;
            end
            if (capture_now) begin
                buf_valid_d = 1'b1;
                buf_data_d  = cxs_tx_data;
                buf_user_d   = cxs_tx_user;
                buf_cntl_d   = cxs_tx_cntl;
                buf_last_d   = CXS_HAS_LAST ? cxs_tx_last : 1'b1;
                buf_srcid_d  = cxs_tx_srcid;
                buf_tgtid_d  = cxs_tx_tgtid;
            end
        end

        tx_valid_out = buf_valid_q;
        tx_data_out  = buf_data_q;
        tx_user_out  = buf_user_q;
        tx_cntl_out  = buf_cntl_q;
        tx_last_out  = buf_last_q;
        tx_srcid_out = buf_srcid_q;
        tx_tgtid_out = buf_tgtid_q;
    end

    always_ff @(posedge cxs_clk or negedge cxs_rst_n) begin
        if (!cxs_rst_n) begin
            buf_valid_q <= 1'b0;
            buf_data_q  <= '0;
            buf_user_q  <= '0;
            buf_cntl_q  <= '0;
            buf_last_q  <= 1'b1;
            buf_srcid_q <= '0;
            buf_tgtid_q <= '0;
            cxs_tx_valid_prev_q <= 1'b0;
        end
        else begin
            buf_valid_q <= buf_valid_d;
            buf_data_q  <= buf_data_d;
            buf_user_q  <= buf_user_d;
            buf_cntl_q  <= buf_cntl_d;
            buf_last_q  <= buf_last_d;
            buf_srcid_q <= buf_srcid_d;
            buf_tgtid_q <= buf_tgtid_d;
            cxs_tx_valid_prev_q <= cxs_tx_valid;
        end
    end

endmodule: cxs_tx_if
