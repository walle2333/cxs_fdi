/***********************************************************************
 * Copyright 2026
 **********************************************************************/

/*
 * Module: rx_path
 *
 * RX path CDC bridge from fdi_lclk to cxs_clk.
 * A small dual-clock FIFO is used to preserve flit ordering.
 */

module rx_path #(
    parameter int CXS_DATA_WIDTH  = 512,
    parameter int CXS_USER_WIDTH  = 64,
    parameter int CXS_CNTL_WIDTH  = 8,
    parameter int CXS_SRCID_WIDTH = 8,
    parameter int CXS_TGTID_WIDTH = 8,
    parameter int FDI_DATA_WIDTH  = 512,
    parameter int FDI_USER_WIDTH  = 64,
    parameter int FIFO_DEPTH      = 64,
    parameter int ERR_WIDTH       = 8
) (
    input  logic                       cxs_clk,
    input  logic                       cxs_rst_n,
    input  logic                       fdi_lclk,
    input  logic                       fdi_rst_n,
    input  logic                       rx_valid_in,
    input  logic [FDI_DATA_WIDTH-1:0]  rx_data_in,
    input  logic [FDI_USER_WIDTH-1:0]  rx_user_in,
    input  logic [CXS_CNTL_WIDTH-1:0]  rx_cntl_in,
    input  logic                       rx_last_in,
    input  logic [CXS_SRCID_WIDTH-1:0] rx_srcid_in,
    input  logic [CXS_TGTID_WIDTH-1:0] rx_tgtid_in,
    output logic                       rx_data_ack,
    output logic                       rx_valid_out,
    output logic [CXS_DATA_WIDTH-1:0]  rx_data_out,
    output logic [CXS_USER_WIDTH-1:0]  rx_user_out,
    output logic [CXS_CNTL_WIDTH-1:0]  rx_cntl_out,
    output logic                       rx_last_out,
    output logic [CXS_SRCID_WIDTH-1:0] rx_srcid_out,
    output logic [CXS_TGTID_WIDTH-1:0] rx_tgtid_out,
    input  logic                       rx_ready,
    output logic [ERR_WIDTH-1:0]       rx_error
);

    localparam int ADDR_WIDTH   = (FIFO_DEPTH <= 1) ? 1 : $clog2(FIFO_DEPTH);
    localparam int PTR_WIDTH    = ADDR_WIDTH + 1;
    localparam int PAYLOAD_WIDTH = FDI_DATA_WIDTH + FDI_USER_WIDTH +
                                   CXS_CNTL_WIDTH + 1 +
                                   CXS_SRCID_WIDTH + CXS_TGTID_WIDTH;

    localparam int RX_TGTID_LSB = 0;
    localparam int RX_SRCID_LSB = RX_TGTID_LSB + CXS_TGTID_WIDTH;
    localparam int RX_LAST_LSB   = RX_SRCID_LSB + CXS_SRCID_WIDTH;
    localparam int RX_CNTL_LSB   = RX_LAST_LSB + 1;
    localparam int RX_USER_LSB   = RX_CNTL_LSB + CXS_CNTL_WIDTH;
    localparam int RX_DATA_LSB   = RX_USER_LSB + FDI_USER_WIDTH;

    logic [PAYLOAD_WIDTH-1:0] fifo_mem [0:FIFO_DEPTH-1];
    logic [PTR_WIDTH-1:0]      wr_bin;
    logic [PTR_WIDTH-1:0]      wr_gray;
    logic [PTR_WIDTH-1:0]      rd_bin;
    logic [PTR_WIDTH-1:0]      rd_gray;
    logic [PTR_WIDTH-1:0]      wr_gray_sync1;
    logic [PTR_WIDTH-1:0]      wr_gray_sync2;
    logic [PTR_WIDTH-1:0]      rd_gray_sync1;
    logic [PTR_WIDTH-1:0]      rd_gray_sync2;
    logic [PTR_WIDTH-1:0]      wr_bin_next;
    logic [PTR_WIDTH-1:0]      wr_gray_next;
    logic [PTR_WIDTH-1:0]      rd_bin_next;
    logic [PTR_WIDTH-1:0]      rd_gray_next;
    logic [PTR_WIDTH-1:0]      fifo_full_cmp_gray;
    logic [PAYLOAD_WIDTH-1:0]  rd_word;
    logic                      fifo_full;
    logic                      fifo_empty;
    logic                      wr_fire;
    logic                      rd_fire;

    function automatic logic [PTR_WIDTH-1:0] bin2gray(
        input logic [PTR_WIDTH-1:0] value
    );
        begin
            bin2gray = (value >> 1) ^ value;
        end
    endfunction

    // Keep the parameterized pointer slice outside always_comb so Icarus
    // doesn't warn about constant-select sensitivity handling.
    assign fifo_full_cmp_gray = {
        ~rd_gray_sync2[PTR_WIDTH-1:PTR_WIDTH-2],
        rd_gray_sync2[PTR_WIDTH-3:0]
    };

    always_comb begin
        wr_bin_next  = wr_bin + 1'b1;
        wr_gray_next = bin2gray(wr_bin_next);
        rd_bin_next  = rd_bin + 1'b1;
        rd_gray_next = bin2gray(rd_bin_next);
        fifo_full = (wr_gray_next == fifo_full_cmp_gray);
        fifo_empty = (rd_gray == wr_gray_sync2);
    end

    assign rx_data_ack = !fifo_full;
    assign rx_valid_out = !fifo_empty;
    assign rd_word      = fifo_mem[rd_bin[ADDR_WIDTH-1:0]];
    assign rx_data_out  = fifo_empty ? '0 : rd_word[RX_DATA_LSB +: FDI_DATA_WIDTH];
    assign rx_user_out  = fifo_empty ? '0 : rd_word[RX_USER_LSB +: FDI_USER_WIDTH];
    assign rx_cntl_out  = fifo_empty ? '0 : rd_word[RX_CNTL_LSB +: CXS_CNTL_WIDTH];
    assign rx_last_out  = fifo_empty ? 1'b0 : rd_word[RX_LAST_LSB];
    assign rx_srcid_out = fifo_empty ? '0 : rd_word[RX_SRCID_LSB +: CXS_SRCID_WIDTH];
    assign rx_tgtid_out = fifo_empty ? '0 : rd_word[RX_TGTID_LSB +: CXS_TGTID_WIDTH];

    assign wr_fire = rx_valid_in && rx_data_ack;
    assign rd_fire = rx_valid_out && rx_ready;

    always_ff @(posedge fdi_lclk or negedge fdi_rst_n) begin
        if (!fdi_rst_n) begin
            wr_bin        <= '0;
            wr_gray       <= '0;
            rd_gray_sync1 <= '0;
            rd_gray_sync2 <= '0;
            rx_error      <= '0;
        end
        else begin
            rd_gray_sync1 <= rd_gray;
            rd_gray_sync2 <= rd_gray_sync1;

            if (wr_fire) begin
                fifo_mem[wr_bin[ADDR_WIDTH-1:0]] <= {
                    rx_data_in,
                    rx_user_in,
                    rx_cntl_in,
                    rx_last_in,
                    rx_srcid_in,
                    rx_tgtid_in
                };
                wr_bin  <= wr_bin_next;
                wr_gray <= wr_gray_next;
            end
            else if (rx_valid_in && !rx_data_ack) begin
                rx_error[0] <= 1'b1;
            end
        end
    end

    always_ff @(posedge cxs_clk or negedge cxs_rst_n) begin
        if (!cxs_rst_n) begin
            rd_bin        <= '0;
            rd_gray       <= '0;
            wr_gray_sync1 <= '0;
            wr_gray_sync2 <= '0;
        end
        else begin
            wr_gray_sync1 <= wr_gray;
            wr_gray_sync2 <= wr_gray_sync1;

            if (rd_fire) begin
                rd_bin  <= rd_bin_next;
                rd_gray <= rd_gray_next;
            end
        end
    end

endmodule: rx_path
