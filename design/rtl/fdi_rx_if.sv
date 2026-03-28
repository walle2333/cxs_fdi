/***********************************************************************
 * Copyright 2026
 **********************************************************************/

/*
 * Module: fdi_rx_if
 *
 * FDI receive interface for the UCIe CXS-FDI bridge.
 *
 * This module accepts FDI flits from the adapter, provides ready/valid
 * handshake back to the adapter, and presents a registered internal
 * payload interface to the RX path.
 */

module fdi_rx_if #(
    parameter int FDI_DATA_WIDTH   = 512,
    parameter int FDI_USER_WIDTH   = 64,
    parameter int FDI_STREAM_WIDTH = 4,
    parameter int FDI_DLLP_WIDTH   = 32,
    parameter int CXS_CNTL_WIDTH   = 8,
    parameter int CXS_SRCID_WIDTH  = 8,
    parameter int CXS_TGTID_WIDTH  = 8
) (
    input  logic                     fdi_lclk,
    input  logic                     fdi_rst_n,

    input  logic                     fdi_pl_valid,
    input  logic [FDI_DATA_WIDTH-1:0] fdi_pl_flit,
    input  logic [FDI_STREAM_WIDTH-1:0] fdi_pl_stream,
    output logic                     fdi_pl_trdy,
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic                     fdi_pl_dllp_valid,
    input  logic [FDI_DLLP_WIDTH-1:0] fdi_pl_dllp,
    input  logic                     fdi_pl_flit_cancel,
    input  logic [3:0]               fdi_pl_state_sts,
    input  logic                     fdi_pl_idle,
    /* verilator lint_on UNUSEDSIGNAL */
    input  logic                     fdi_pl_error,

    output logic                     rx_valid_out,
    output logic [FDI_DATA_WIDTH-1:0] rx_data_out,
    output logic [FDI_USER_WIDTH-1:0] rx_user_out,
    output logic [CXS_CNTL_WIDTH-1:0] rx_cntl_out,
    output logic                     rx_last_out,
    output logic [CXS_SRCID_WIDTH-1:0] rx_srcid_out,
    output logic [CXS_TGTID_WIDTH-1:0] rx_tgtid_out,
    input  logic                     rx_ready
);

    localparam logic [3:0] FDI_ACTIVE_STS = 4'b0010;

    logic                     receive_enable_q;
    logic                     flit_cancel_pending_q;
    logic                     rx_valid_q;
    logic [FDI_DATA_WIDTH-1:0] rx_data_q;
    logic [FDI_USER_WIDTH-1:0] rx_user_q;
    logic [CXS_CNTL_WIDTH-1:0] rx_cntl_q;
    logic                     rx_last_q;
    logic [CXS_SRCID_WIDTH-1:0] rx_srcid_q;
    logic [CXS_TGTID_WIDTH-1:0] rx_tgtid_q;

    logic                     capture_flit;
    logic                     consume_flit;
    logic                     link_active;
    logic                     link_error;

    function automatic logic [FDI_USER_WIDTH-1:0] build_user_field(
        input logic [FDI_STREAM_WIDTH-1:0] stream_value
    );
        int bit_idx;
        begin
            build_user_field = '0;
            for (bit_idx = 0; bit_idx < FDI_USER_WIDTH; bit_idx++) begin
                if (bit_idx < FDI_STREAM_WIDTH) begin
                    build_user_field[bit_idx] = stream_value[bit_idx];
                end
            end
        end
    endfunction

    always_comb begin
        link_active = (fdi_pl_state_sts == FDI_ACTIVE_STS);
        link_error = fdi_pl_error;
        capture_flit = fdi_pl_valid &&
                       fdi_pl_trdy &&
                       !fdi_pl_flit_cancel &&
                       !link_error;
        consume_flit = rx_valid_q && rx_ready;
    end

    always_comb begin
        fdi_pl_trdy = rx_ready && receive_enable_q && !flit_cancel_pending_q;
    end

    always_ff @(posedge fdi_lclk or negedge fdi_rst_n) begin
        if (!fdi_rst_n) begin
            receive_enable_q <= 1'b0;
            flit_cancel_pending_q <= 1'b0;
            rx_valid_q <= 1'b0;
            rx_data_q <= '0;
            rx_user_q <= '0;
            rx_cntl_q <= '0;
            rx_last_q <= 1'b0;
            rx_srcid_q <= '0;
            rx_tgtid_q <= '0;
        end
        else begin
            receive_enable_q <= link_active && !link_error;
            flit_cancel_pending_q <= fdi_pl_valid && fdi_pl_flit_cancel;

            if (link_error || (fdi_pl_state_sts != FDI_ACTIVE_STS)) begin
                rx_valid_q <= 1'b0;
                rx_last_q <= 1'b0;
            end
            else if (capture_flit && consume_flit) begin
                rx_valid_q <= 1'b1;
                rx_data_q <= fdi_pl_flit;
                rx_user_q <= build_user_field(fdi_pl_stream);
                rx_cntl_q <= '0;
                rx_last_q <= 1'b1;
                rx_srcid_q <= '0;
                rx_tgtid_q <= '0;
            end
            else if (consume_flit) begin
                rx_valid_q <= 1'b0;
                rx_last_q <= 1'b0;
            end
            else if (capture_flit) begin
                rx_valid_q <= 1'b1;
                rx_data_q <= fdi_pl_flit;
                rx_user_q <= build_user_field(fdi_pl_stream);
                rx_cntl_q <= '0;
                rx_last_q <= 1'b1;
                rx_srcid_q <= '0;
                rx_tgtid_q <= '0;
            end

            if (fdi_pl_valid && (fdi_pl_error || fdi_pl_flit_cancel)) begin
                if (CXS_CNTL_WIDTH > 0) begin
                    rx_cntl_q[0] <= 1'b1;
                end
            end
        end
    end

    always_comb begin
        rx_valid_out = rx_valid_q;
        rx_data_out = rx_data_q;
        rx_user_out = rx_user_q;
        rx_cntl_out = rx_cntl_q;
        rx_last_out = rx_last_q;
        rx_srcid_out = rx_srcid_q;
        rx_tgtid_out = rx_tgtid_q;
    end

endmodule: fdi_rx_if
