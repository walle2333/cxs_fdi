/***********************************************************************
 * Copyright 2026
 **********************************************************************/

/*
 * Module: fdi_tx_if
 *
 * FDI TX interface for the UCIe CXS-FDI bridge.
 *
 * This implementation matches the current top-level port wiring:
 * - accepts data from the TX path in the fdi_lclk domain
 * - drives fdi_lp_valid / fdi_lp_flit / fdi_lp_stream
 * - stalls upstream when the internal buffer is full or the link is
 *   not in Active state
 * - pauses output during Retrain
 *
 * Note:
 * - The current top-level wrapper does not expose an explicit
 *   credit_ready input to this module, so the practical handoff is
 *   implemented with a one-entry elastic buffer plus fdi_lp_irdy
 *   cooperation.
 */

module fdi_tx_if #(
    parameter int FDI_DATA_WIDTH   = 512,
    parameter int FDI_USER_WIDTH   = 64,
    parameter int FDI_STREAM_WIDTH = 4,
    parameter int FDI_DLLP_WIDTH   = 32,
    parameter int CXS_CNTL_WIDTH    = 8
) (
    input  logic                        fdi_lclk,
    input  logic                        fdi_rst_n,

    input  logic                        tx_valid_in,
    input  logic [FDI_DATA_WIDTH-1:0]   tx_data_in,
    input  logic [FDI_USER_WIDTH-1:0]   tx_user_in,
    input  logic [CXS_CNTL_WIDTH-1:0]   tx_cntl_in,
    input  logic                        tx_last_in,
    output logic                        tx_data_ack,

    output logic                        fdi_lp_valid,
    output logic [FDI_DATA_WIDTH-1:0]   fdi_lp_flit,
    output logic [FDI_STREAM_WIDTH-1:0]  fdi_lp_stream,
    input  logic                        fdi_lp_irdy,
    output logic                        fdi_lp_dllp_valid,
    output logic [FDI_DLLP_WIDTH-1:0]   fdi_lp_dllp,

    input  logic [3:0]                  fdi_pl_state_sts
);

    localparam logic [3:0] FDI_ACTIVE_STS = 4'b0010;
    localparam logic [3:0] FDI_RETRAIN_STS = 4'b0011;

    logic                        link_active;
    logic                        link_retrain;
    logic                        buffer_valid_q;
    logic                        buffer_valid_d;
    logic [FDI_DATA_WIDTH-1:0]   flit_reg_q;
    logic [FDI_DATA_WIDTH-1:0]   flit_reg_d;
    logic [FDI_USER_WIDTH-1:0]   user_reg_q;
    logic [FDI_USER_WIDTH-1:0]   user_reg_d;
    logic [CXS_CNTL_WIDTH-1:0]   cntl_reg_q;
    logic [CXS_CNTL_WIDTH-1:0]   cntl_reg_d;
    logic                        last_reg_q;
    logic                        last_reg_d;
    logic [FDI_STREAM_WIDTH-1:0] stream_reg_q;
    logic [FDI_STREAM_WIDTH-1:0] stream_reg_d;
    logic [FDI_STREAM_WIDTH-1:0] tx_stream_field;

    assign tx_stream_field = tx_cntl_in[FDI_STREAM_WIDTH-1:0];

    assign link_active = (fdi_pl_state_sts == FDI_ACTIVE_STS);
    assign link_retrain = (fdi_pl_state_sts == FDI_RETRAIN_STS);

    always_comb begin
        buffer_valid_d = buffer_valid_q;
        flit_reg_d     = flit_reg_q;
        user_reg_d     = user_reg_q;
        cntl_reg_d     = cntl_reg_q;
        last_reg_d     = last_reg_q;
        stream_reg_d   = stream_reg_q;

        if (!fdi_rst_n) begin
            buffer_valid_d = 1'b0;
            flit_reg_d     = '0;
            user_reg_d     = '0;
            cntl_reg_d     = '0;
            last_reg_d     = 1'b0;
            stream_reg_d   = '0;
        end
        else if (!link_active && !link_retrain) begin
            buffer_valid_d = 1'b0;
        end
        else begin
            if (buffer_valid_q && fdi_lp_irdy && !tx_valid_in) begin
                buffer_valid_d = 1'b0;
            end

            if (tx_valid_in && tx_data_ack) begin
                flit_reg_d   = tx_data_in;
                user_reg_d   = tx_user_in;
                cntl_reg_d   = tx_cntl_in;
                last_reg_d    = tx_last_in;
                stream_reg_d = tx_stream_field;
                buffer_valid_d = 1'b1;
            end
        end
    end

    always_ff @(posedge fdi_lclk or negedge fdi_rst_n) begin
        if (!fdi_rst_n) begin
            buffer_valid_q <= 1'b0;
            flit_reg_q     <= '0;
            user_reg_q     <= '0;
            cntl_reg_q     <= '0;
            last_reg_q     <= 1'b0;
            stream_reg_q   <= '0;
        end
        else begin
            buffer_valid_q <= buffer_valid_d;
            flit_reg_q     <= flit_reg_d;
            user_reg_q     <= user_reg_d;
            cntl_reg_q     <= cntl_reg_d;
            last_reg_q     <= last_reg_d;
            stream_reg_q   <= stream_reg_d;
        end
    end

    assign tx_data_ack = link_active &&
                         (buffer_valid_q ? fdi_lp_irdy : 1'b1);
    assign fdi_lp_valid = buffer_valid_q && link_active && !link_retrain;
    assign fdi_lp_flit = flit_reg_q;
    assign fdi_lp_stream = stream_reg_q;
    assign fdi_lp_dllp_valid = 1'b0;
    assign fdi_lp_dllp = '0;

endmodule: fdi_tx_if
