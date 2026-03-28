/***********************************************************************
 * Copyright 2026
 **********************************************************************/

/*
 * Module: cxs_rx_if
 *
 * CXS RX interface for the bridge.
 *
 * This implementation keeps the protocol-facing output registered,
 * mirrors the active request/deactivate hint into the local active
 * acknowledgement, and forwards payload fields from the internal RX
 * path to the CXS protocol layer.
 */

module cxs_rx_if #(
    parameter int CXS_DATA_WIDTH = 512,
    parameter int CXS_USER_WIDTH = 64,
    parameter int CXS_USER_W = (CXS_USER_WIDTH > 0) ? CXS_USER_WIDTH : 1,
    parameter int CXS_CNTL_WIDTH = 8,
    parameter int CXS_CNTL_W = (CXS_CNTL_WIDTH > 0) ? CXS_CNTL_WIDTH : 1,
    parameter int CXS_SRCID_WIDTH = 8,
    parameter int CXS_SRCID_W = (CXS_SRCID_WIDTH > 0) ? CXS_SRCID_WIDTH : 1,
    parameter int CXS_TGTID_WIDTH = 8,
    parameter int CXS_TGTID_W = (CXS_TGTID_WIDTH > 0) ? CXS_TGTID_WIDTH : 1,
    parameter bit CXS_HAS_LAST = 1'b1
) (
    input  logic                     cxs_clk,
    input  logic                     cxs_rst_n,

    input  logic                     rx_valid_in,
    input  logic [CXS_DATA_WIDTH-1:0] rx_data_in,
    input  logic [CXS_USER_W-1:0] rx_user_in,
    input  logic [CXS_CNTL_W-1:0] rx_cntl_in,
    input  logic                     rx_last_in,
    input  logic [CXS_SRCID_W-1:0] rx_srcid_in,
    input  logic [CXS_TGTID_W-1:0] rx_tgtid_in,
    output logic                     rx_data_ack,

    output logic                     cxs_rx_valid,
    output logic [CXS_DATA_WIDTH-1:0] cxs_rx_data,
    output logic [CXS_USER_W-1:0] cxs_rx_user,
    output logic [CXS_CNTL_W-1:0] cxs_rx_cntl,
    output logic                     cxs_rx_last,
    output logic [CXS_SRCID_W-1:0] cxs_rx_srcid,
    output logic [CXS_TGTID_W-1:0] cxs_rx_tgtid,
    input  logic                     cxs_rx_active_req,
    output logic                     cxs_rx_active,
    input  logic                     cxs_rx_deact_hint
);

    logic cxs_rx_active_q;
    logic rx_accept_d;
    logic cxs_rx_last_d;

    always_comb begin
        rx_accept_d = rx_valid_in && cxs_rx_active_q && !cxs_rx_deact_hint;
        cxs_rx_last_d = CXS_HAS_LAST ? rx_last_in : 1'b0;
    end

    always_ff @(posedge cxs_clk or negedge cxs_rst_n) begin
        if (!cxs_rst_n) begin
            cxs_rx_active_q <= 1'b0;
            cxs_rx_valid <= 1'b0;
            cxs_rx_data <= '0;
            cxs_rx_user <= '0;
            cxs_rx_cntl <= '0;
            cxs_rx_last <= 1'b0;
            cxs_rx_srcid <= '0;
            cxs_rx_tgtid <= '0;
        end
        else begin
            if (cxs_rx_deact_hint) begin
                cxs_rx_active_q <= 1'b0;
            end
            else if (cxs_rx_active_req) begin
                cxs_rx_active_q <= 1'b1;
            end

            cxs_rx_valid <= rx_accept_d;

            if (rx_accept_d) begin
                cxs_rx_data <= rx_data_in;
                cxs_rx_user <= rx_user_in;
                cxs_rx_cntl <= rx_cntl_in;
                cxs_rx_last <= cxs_rx_last_d;
                cxs_rx_srcid <= rx_srcid_in;
                cxs_rx_tgtid <= rx_tgtid_in;
            end
        end
    end

    assign rx_data_ack = 1'b1;
    assign cxs_rx_active = cxs_rx_active_q;

endmodule: cxs_rx_if
