/***********************************************************************
 * Copyright 2026
 **********************************************************************/

/*
 * Module: credit_mgr
 *
 * Centralized TX/RX credit manager for the UCIe CXS-FDI bridge.
 *
 * Key behavior:
 * - TX and RX credits are tracked independently
 * - consume + return in the same cycle results in zero net change
 * - counters saturate at cfg_credit_max and never underflow below zero
 * - grant outputs are registered
 * - credit_ready is asserted only when both TX and RX counters are non-zero
 */

module credit_mgr #(
    parameter int CREDIT_WIDTH = 6
) (
    input  logic                    cxs_clk,
    input  logic                    cxs_rst_n,
    input  logic                    tx_data_valid,
    input  logic                    cxs_tx_crdret,
    output logic                    cxs_tx_crdgnt,
    input  logic                    rx_data_valid,
    input  logic                    cxs_rx_crdret,
    output logic                    cxs_rx_crdgnt,
    output logic                    credit_ready,
    input  logic [CREDIT_WIDTH-1:0] cfg_credit_max,
    input  logic [CREDIT_WIDTH-1:0] cfg_credit_init,
    output logic [CREDIT_WIDTH-1:0] status_tx_credit_cnt,
    output logic [CREDIT_WIDTH-1:0] status_rx_credit_cnt
);

    // =========================================
    // Internal signals
    // =========================================
    logic [CREDIT_WIDTH-1:0] tx_credit_cnt_next;
    logic [CREDIT_WIDTH-1:0] rx_credit_cnt_next;

    // =========================================
    // TX credit next-state logic
    // =========================================
    always_comb begin
        tx_credit_cnt_next = status_tx_credit_cnt;

        case ({tx_data_valid, cxs_tx_crdret})
            2'b10: begin
                if (status_tx_credit_cnt > '0) begin
                    tx_credit_cnt_next = status_tx_credit_cnt - 1'b1;
                end
            end
            2'b01: begin
                if (status_tx_credit_cnt < cfg_credit_max) begin
                    tx_credit_cnt_next = status_tx_credit_cnt + 1'b1;
                end
            end
            2'b11: begin
                tx_credit_cnt_next = status_tx_credit_cnt;
            end
            default: begin
                tx_credit_cnt_next = status_tx_credit_cnt;
            end
        endcase
    end

    // =========================================
    // RX credit next-state logic
    // =========================================
    always_comb begin
        rx_credit_cnt_next = status_rx_credit_cnt;

        case ({rx_data_valid, cxs_rx_crdret})
            2'b10: begin
                if (status_rx_credit_cnt > '0) begin
                    rx_credit_cnt_next = status_rx_credit_cnt - 1'b1;
                end
            end
            2'b01: begin
                if (status_rx_credit_cnt < cfg_credit_max) begin
                    rx_credit_cnt_next = status_rx_credit_cnt + 1'b1;
                end
            end
            2'b11: begin
                rx_credit_cnt_next = status_rx_credit_cnt;
            end
            default: begin
                rx_credit_cnt_next = status_rx_credit_cnt;
            end
        endcase
    end

    // =========================================
    // Credit counters
    // =========================================
    always_ff @(posedge cxs_clk or negedge cxs_rst_n) begin
        if (!cxs_rst_n) begin
            status_tx_credit_cnt <= cfg_credit_init;
            status_rx_credit_cnt <= cfg_credit_init;
        end
        else begin
            status_tx_credit_cnt <= tx_credit_cnt_next;
            status_rx_credit_cnt <= rx_credit_cnt_next;
        end
    end

    // =========================================
    // Registered grant outputs
    // =========================================
    always_ff @(posedge cxs_clk or negedge cxs_rst_n) begin
        if (!cxs_rst_n) begin
            cxs_tx_crdgnt <= 1'b0;
            cxs_rx_crdgnt <= 1'b0;
        end
        else begin
            cxs_tx_crdgnt <= (tx_credit_cnt_next > '0);
            cxs_rx_crdgnt <= (rx_credit_cnt_next > '0);
        end
    end

    // =========================================
    // Combined credit-ready indication
    // =========================================
    always_ff @(posedge cxs_clk or negedge cxs_rst_n) begin
        if (!cxs_rst_n) begin
            credit_ready <= 1'b0;
        end
        else begin
            credit_ready <= (tx_credit_cnt_next > '0) && (rx_credit_cnt_next > '0);
        end
    end

endmodule: credit_mgr
