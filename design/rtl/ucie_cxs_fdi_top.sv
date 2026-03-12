/***********************************************************************
 * Copyright 2024
 * UCIe CXS-FDI Top Module
 **********************************************************************/

/*
 * Module: ucie_cxs_fdi_top
 *
 * UCIe CXS-FDI Top-level wrapper
 * Contains internal counter for demonstration
 */

module ucie_cxs_fdi_top (
    input  logic             clk,
    input  logic             rst_n,
    input  logic             enable,
    output logic [7:0]       count,
    output logic             overflow
);

    // =========================================
    // Internal signals
    // =========================================
    logic [7:0]              internal_count;
    logic                    internal_overflow;

    // =========================================
    // Internal counter instance
    // =========================================
    counter #(
        .WIDTH  (8),
        .MAX_VAL(255)
    ) u_counter (
        .clk      (clk),
        .rst_n    (rst_n),
        .enable   (enable),
        .count    (internal_count),
        .overflow (internal_overflow)
    );

    // =========================================
    // Output assignment
    // =========================================
    assign count     = internal_count;
    assign overflow  = internal_overflow;

endmodule: ucie_cxs_fdi_top
