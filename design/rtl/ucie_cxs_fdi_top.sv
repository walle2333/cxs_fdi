/***********************************************************************
 * UCIe CXS-FDI Top Module
 * Spec: docs/specification/ucie_cxs_fdi_arch_spec.md (v0.1, 2026-03-15)
 **********************************************************************/

// Top-level wrapper for UCIe CXS-FDI Bridge
// This file provides the overall integration skeleton only.
// Submodules are expected to be implemented in their own RTL files.

module ucie_cxs_fdi_top #(
    // Core widths
    parameter int CXS_DATA_WIDTH   = 512,
    parameter int CXS_USER_WIDTH   = 64,
    parameter int CXS_SRCID_WIDTH  = 8,
    parameter int CXS_TGTID_WIDTH  = 8,
    parameter int CXS_CNTL_WIDTH   = 8,
    parameter int FDI_DATA_WIDTH   = 512,
    parameter int FDI_USER_WIDTH   = 64,
    parameter int FDI_STREAM_WIDTH = 4,
    parameter int FDI_DLLP_WIDTH   = 32,

    // Flow control / buffering
    parameter int FIFO_DEPTH       = 64,
    parameter int MAX_CREDIT       = 32,

    // Optional features
    parameter bit CXS_HAS_LAST     = 1'b1,
    parameter bit CXS_HAS_LINK_CTRL = 1'b1,

    // Error/status
    parameter int ERR_WIDTH        = 8
) (
    // ----------------------------------------------------------------
    // Clocks and resets
    // ----------------------------------------------------------------
    input  logic                     cxs_clk,
    input  logic                     cxs_rst_n,
    input  logic                     fdi_lclk,
    input  logic                     fdi_rst_n,
    input  logic                     apb_clk,
    input  logic                     apb_rst_n,
    input  logic                     rst_sw,

    // ----------------------------------------------------------------
    // CXS TX Interface (Protocol Layer -> Bridge)
    // ----------------------------------------------------------------
    input  logic                     cxs_tx_valid,
    input  logic [CXS_DATA_WIDTH-1:0] cxs_tx_data,
    input  logic [CXS_USER_WIDTH-1:0] cxs_tx_user,
    input  logic [CXS_CNTL_WIDTH-1:0] cxs_tx_cntl,
    input  logic                     cxs_tx_last,
    input  logic [CXS_SRCID_WIDTH-1:0] cxs_tx_srcid,
    input  logic [CXS_TGTID_WIDTH-1:0] cxs_tx_tgtid,
    output logic                     cxs_tx_crdgnt,
    input  logic                     cxs_tx_crdret,
    input  logic                     cxs_tx_active_req,
    output logic                     cxs_tx_active,
    input  logic                     cxs_tx_deact_hint,

    // ----------------------------------------------------------------
    // CXS RX Interface (Bridge -> Protocol Layer)
    // ----------------------------------------------------------------
    output logic                     cxs_rx_valid,
    output logic [CXS_DATA_WIDTH-1:0] cxs_rx_data,
    output logic [CXS_USER_WIDTH-1:0] cxs_rx_user,
    output logic [CXS_CNTL_WIDTH-1:0] cxs_rx_cntl,
    output logic                     cxs_rx_last,
    output logic [CXS_SRCID_WIDTH-1:0] cxs_rx_srcid,
    output logic [CXS_TGTID_WIDTH-1:0] cxs_rx_tgtid,
    output logic                     cxs_rx_crdgnt,
    input  logic                     cxs_rx_crdret,
    output logic                     cxs_rx_active,
    input  logic                     cxs_rx_active_req,
    input  logic                     cxs_rx_deact_hint,

    // ----------------------------------------------------------------
    // FDI TX Interface (Bridge -> UCIe Adapter)
    // ----------------------------------------------------------------
    output logic                     fdi_tx_valid,      // fdi_lp_valid
    output logic [FDI_DATA_WIDTH-1:0] fdi_tx_data,       // fdi_lp_flit
    output logic [FDI_STREAM_WIDTH-1:0] fdi_tx_stream,   // fdi_lp_stream
    input  logic                     fdi_tx_ready,      // fdi_lp_irdy
    output logic                     fdi_tx_dllp_valid, // fdi_lp_dllp_valid
    output logic [FDI_DLLP_WIDTH-1:0] fdi_tx_dllp,       // fdi_lp_dllp

    // ----------------------------------------------------------------
    // FDI RX Interface (UCIe Adapter -> Bridge)
    // ----------------------------------------------------------------
    input  logic                     fdi_rx_valid,      // fdi_pl_valid
    input  logic [FDI_DATA_WIDTH-1:0] fdi_rx_data,       // fdi_pl_flit
    input  logic [FDI_STREAM_WIDTH-1:0] fdi_rx_stream,   // fdi_pl_stream
    output logic                     fdi_rx_ready,      // fdi_pl_trdy
    input  logic                     fdi_rx_dllp_valid, // fdi_pl_dllp_valid
    input  logic [FDI_DLLP_WIDTH-1:0] fdi_rx_dllp,       // fdi_pl_dllp

    // ----------------------------------------------------------------
    // Physical Layer Status (UCIe Adapter -> Bridge)
    // ----------------------------------------------------------------
    input  logic [3:0]               fdi_pl_state_sts,
    input  logic                     fdi_pl_inband_pres,
    input  logic                     fdi_pl_error,
    input  logic                     fdi_pl_flit_cancel,
    input  logic                     fdi_pl_idle,

    // ----------------------------------------------------------------
    // APB Interface (Configuration/Debug)
    // ----------------------------------------------------------------
    input  logic [31:0]              apb_paddr,
    input  logic [31:0]              apb_pwdata,
    input  logic                     apb_penable,
    input  logic                     apb_psel,
    input  logic                     apb_pwrite,
    output logic [31:0]              apb_prdata,
    output logic                     apb_pready,
    output logic                     apb_pslverr
);

    // ----------------------------------------------------------------
    // Reset handling (placeholder)
    // ----------------------------------------------------------------
    logic cxs_rst_n_int;
    logic fdi_rst_n_int;
    logic apb_rst_n_int;

    assign cxs_rst_n_int = cxs_rst_n & ~rst_sw;
    assign fdi_rst_n_int = fdi_rst_n & ~rst_sw;
    assign apb_rst_n_int = apb_rst_n & ~rst_sw;

    // ----------------------------------------------------------------
    // Internal interconnects
    // ----------------------------------------------------------------
    // CXS TX IF -> TX Path (cxs_clk domain)
    logic                      txp_valid_in;
    logic [CXS_DATA_WIDTH-1:0] txp_data_in;
    logic [CXS_USER_WIDTH-1:0] txp_user_in;
    logic [CXS_CNTL_WIDTH-1:0] txp_cntl_in;
    logic                      txp_last_in;
    logic [CXS_SRCID_WIDTH-1:0] txp_srcid_in;
    logic [CXS_TGTID_WIDTH-1:0] txp_tgtid_in;
    logic                      txp_ready_out;

    // TX Path -> FDI TX IF (fdi_lclk domain)
    logic                      fdi_txp_valid;
    logic [FDI_DATA_WIDTH-1:0] fdi_txp_data;
    logic [FDI_USER_WIDTH-1:0] fdi_txp_user;
    logic [CXS_CNTL_WIDTH-1:0] fdi_txp_cntl;
    logic                      fdi_txp_last;
    logic                      fdi_txp_ready;

    // FDI RX IF -> RX Path (fdi_lclk domain)
    logic                      fdi_rxp_valid;
    logic [FDI_DATA_WIDTH-1:0] fdi_rxp_data;
    logic [FDI_USER_WIDTH-1:0] fdi_rxp_user;
    logic [CXS_CNTL_WIDTH-1:0] fdi_rxp_cntl;
    logic                      fdi_rxp_last;
    logic [CXS_SRCID_WIDTH-1:0] fdi_rxp_srcid;
    logic [CXS_TGTID_WIDTH-1:0] fdi_rxp_tgtid;
    logic                      fdi_rxp_ready;

    // RX Path -> CXS RX IF (cxs_clk domain)
    logic                      rxp_valid_out;
    logic [CXS_DATA_WIDTH-1:0] rxp_data_out;
    logic [CXS_USER_WIDTH-1:0] rxp_user_out;
    logic [CXS_CNTL_WIDTH-1:0] rxp_cntl_out;
    logic                      rxp_last_out;
    logic [CXS_SRCID_WIDTH-1:0] rxp_srcid_out;
    logic [CXS_TGTID_WIDTH-1:0] rxp_tgtid_out;
    logic                      rxp_ready_in;

    // Credit manager signals (cxs_clk domain)
    logic                      tx_credit_consume;
    logic                      rx_credit_consume;
    logic                      tx_credit_gnt;
    logic                      rx_credit_gnt;
    logic                      credit_ready;
    logic [5:0]                cfg_credit_max;
    logic [5:0]                cfg_credit_init;
    logic [5:0]                status_tx_credit_cnt;
    logic [5:0]                status_rx_credit_cnt;

    // Link control signals (cxs_clk domain)
    logic                      link_active;
    logic                      link_tx_ready;
    logic                      link_rx_ready;
    logic                      link_error;
    logic [2:0]                link_status;
    logic                      link_cxs_tx_active;
    logic                      link_cxs_rx_active;

    // CXS TX IF <-> Link Ctrl handshake placeholders
    logic                      tx_link_active_req;
    logic                      tx_link_active_ack;
    logic                      tx_link_deact_req;
    logic                      tx_link_deact_ack;

    // Derived retrain indicator from state (placeholder mapping)
    logic                      fdi_pl_retrain;
    assign fdi_pl_retrain = (fdi_pl_state_sts == 4'b0011);

    // Placeholder link handshake mapping (to be refined in submodule integration)
    assign tx_link_active_ack = link_cxs_tx_active;
    assign tx_link_deact_ack  = 1'b0;

    // ----------------------------------------------------------------
    // CXS TX Interface
    // ----------------------------------------------------------------
    cxs_tx_if #(
        .CXS_DATA_WIDTH   (CXS_DATA_WIDTH),
        .CXS_USER_WIDTH   (CXS_USER_WIDTH),
        .CXS_CNTL_WIDTH   (CXS_CNTL_WIDTH),
        .CXS_SRCID_WIDTH  (CXS_SRCID_WIDTH),
        .CXS_TGTID_WIDTH  (CXS_TGTID_WIDTH),
        .CXS_HAS_LAST     (CXS_HAS_LAST)
    ) u_cxs_tx_if (
        .cxs_clk              (cxs_clk),
        .cxs_rst_n            (cxs_rst_n_int),
        .cxs_tx_valid         (cxs_tx_valid),
        .cxs_tx_data          (cxs_tx_data),
        .cxs_tx_user          (cxs_tx_user),
        .cxs_tx_cntl          (cxs_tx_cntl),
        .cxs_tx_last          (cxs_tx_last),
        .cxs_tx_srcid         (cxs_tx_srcid),
        .cxs_tx_tgtid         (cxs_tx_tgtid),
        .cxs_tx_active_req    (cxs_tx_active_req),
        .cxs_tx_active        (link_cxs_tx_active),
        .cxs_tx_deact_hint    (cxs_tx_deact_hint),
        .tx_valid_out         (txp_valid_in),
        .tx_data_out          (txp_data_in),
        .tx_user_out          (txp_user_in),
        .tx_cntl_out          (txp_cntl_in),
        .tx_last_out          (txp_last_in),
        .tx_srcid_out         (txp_srcid_in),
        .tx_tgtid_out         (txp_tgtid_in),
        .tx_ready             (txp_ready_out),
        .link_ctrl_active_req (tx_link_active_req),
        .link_ctrl_active_ack (tx_link_active_ack),
        .link_ctrl_deact_req  (tx_link_deact_req),
        .link_ctrl_deact_ack  (tx_link_deact_ack)
    );

    // Credit consumption hint from TX path input acceptance
    assign tx_credit_consume = txp_valid_in & txp_ready_out;

    // ----------------------------------------------------------------
    // TX Path (CDC: cxs_clk -> fdi_lclk)
    // ----------------------------------------------------------------
    tx_path #(
        .CXS_DATA_WIDTH (CXS_DATA_WIDTH),
        .CXS_USER_WIDTH (CXS_USER_WIDTH),
        .CXS_CNTL_WIDTH (CXS_CNTL_WIDTH),
        .CXS_SRCID_WIDTH (CXS_SRCID_WIDTH),
        .CXS_TGTID_WIDTH (CXS_TGTID_WIDTH),
        .FDI_DATA_WIDTH (FDI_DATA_WIDTH),
        .FDI_USER_WIDTH (FDI_USER_WIDTH),
        .FIFO_DEPTH     (FIFO_DEPTH),
        .ERR_WIDTH      (ERR_WIDTH)
    ) u_tx_path (
        .cxs_clk        (cxs_clk),
        .cxs_rst_n      (cxs_rst_n_int),
        .fdi_lclk       (fdi_lclk),
        .fdi_rst_n      (fdi_rst_n_int),
        .tx_valid_in    (txp_valid_in),
        .tx_data_in     (txp_data_in),
        .tx_user_in     (txp_user_in),
        .tx_cntl_in     (txp_cntl_in),
        .tx_last_in     (txp_last_in),
        .tx_srcid_in    (txp_srcid_in),
        .tx_tgtid_in    (txp_tgtid_in),
        .tx_ready       (txp_ready_out),
        .tx_valid_out   (fdi_txp_valid),
        .tx_data_out    (fdi_txp_data),
        .tx_user_out    (fdi_txp_user),
        .tx_cntl_out    (fdi_txp_cntl),
        .tx_last_out    (fdi_txp_last),
        .tx_ready_in    (fdi_txp_ready),
        .link_active    (link_active),
        .tx_error       (/* TODO: error status to regs */)
    );

    // ----------------------------------------------------------------
    // FDI TX Interface (fdi_lclk domain)
    // ----------------------------------------------------------------
    fdi_tx_if #(
        .FDI_DATA_WIDTH   (FDI_DATA_WIDTH),
        .FDI_USER_WIDTH   (FDI_USER_WIDTH),
        .FDI_STREAM_WIDTH (FDI_STREAM_WIDTH),
        .FDI_DLLP_WIDTH   (FDI_DLLP_WIDTH),
        .CXS_CNTL_WIDTH   (CXS_CNTL_WIDTH)
    ) u_fdi_tx_if (
        .fdi_lclk         (fdi_lclk),
        .fdi_rst_n        (fdi_rst_n_int),
        .tx_valid_in      (fdi_txp_valid),
        .tx_data_in       (fdi_txp_data),
        .tx_user_in       (fdi_txp_user),
        .tx_cntl_in       (fdi_txp_cntl),
        .tx_last_in       (fdi_txp_last),
        .tx_data_ack      (fdi_txp_ready),
        .fdi_lp_valid     (fdi_tx_valid),
        .fdi_lp_flit      (fdi_tx_data),
        .fdi_lp_stream    (fdi_tx_stream),
        .fdi_lp_irdy      (fdi_tx_ready),
        .fdi_lp_dllp_valid(fdi_tx_dllp_valid),
        .fdi_lp_dllp      (fdi_tx_dllp),
        .fdi_pl_state_sts (fdi_pl_state_sts)
    );

    // ----------------------------------------------------------------
    // FDI RX Interface (fdi_lclk domain)
    // ----------------------------------------------------------------
    fdi_rx_if #(
        .FDI_DATA_WIDTH   (FDI_DATA_WIDTH),
        .FDI_USER_WIDTH   (FDI_USER_WIDTH),
        .FDI_STREAM_WIDTH (FDI_STREAM_WIDTH),
        .FDI_DLLP_WIDTH   (FDI_DLLP_WIDTH),
        .CXS_CNTL_WIDTH   (CXS_CNTL_WIDTH),
        .CXS_SRCID_WIDTH  (CXS_SRCID_WIDTH),
        .CXS_TGTID_WIDTH  (CXS_TGTID_WIDTH)
    ) u_fdi_rx_if (
        .fdi_lclk          (fdi_lclk),
        .fdi_rst_n         (fdi_rst_n_int),
        .fdi_pl_valid      (fdi_rx_valid),
        .fdi_pl_flit       (fdi_rx_data),
        .fdi_pl_stream     (fdi_rx_stream),
        .fdi_pl_trdy       (fdi_rx_ready),
        .fdi_pl_dllp_valid (fdi_rx_dllp_valid),
        .fdi_pl_dllp       (fdi_rx_dllp),
        .fdi_pl_flit_cancel(fdi_pl_flit_cancel),
        .fdi_pl_state_sts  (fdi_pl_state_sts),
        .fdi_pl_idle       (fdi_pl_idle),
        .fdi_pl_error      (fdi_pl_error),
        .rx_valid_out      (fdi_rxp_valid),
        .rx_data_out       (fdi_rxp_data),
        .rx_user_out       (fdi_rxp_user),
        .rx_cntl_out       (fdi_rxp_cntl),
        .rx_last_out       (fdi_rxp_last),
        .rx_srcid_out      (fdi_rxp_srcid),
        .rx_tgtid_out      (fdi_rxp_tgtid),
        .rx_ready          (fdi_rxp_ready)
    );

    // ----------------------------------------------------------------
    // RX Path (CDC: fdi_lclk -> cxs_clk)
    // ----------------------------------------------------------------
    rx_path #(
        .CXS_DATA_WIDTH (CXS_DATA_WIDTH),
        .CXS_USER_WIDTH (CXS_USER_WIDTH),
        .CXS_CNTL_WIDTH (CXS_CNTL_WIDTH),
        .CXS_SRCID_WIDTH (CXS_SRCID_WIDTH),
        .CXS_TGTID_WIDTH (CXS_TGTID_WIDTH),
        .FDI_DATA_WIDTH (FDI_DATA_WIDTH),
        .FDI_USER_WIDTH (FDI_USER_WIDTH),
        .FIFO_DEPTH     (FIFO_DEPTH),
        .ERR_WIDTH      (ERR_WIDTH)
    ) u_rx_path (
        .cxs_clk        (cxs_clk),
        .cxs_rst_n      (cxs_rst_n_int),
        .fdi_lclk       (fdi_lclk),
        .fdi_rst_n      (fdi_rst_n_int),
        .rx_valid_in    (fdi_rxp_valid),
        .rx_data_in     (fdi_rxp_data),
        .rx_user_in     (fdi_rxp_user),
        .rx_cntl_in     (fdi_rxp_cntl),
        .rx_last_in     (fdi_rxp_last),
        .rx_srcid_in    (fdi_rxp_srcid),
        .rx_tgtid_in    (fdi_rxp_tgtid),
        .rx_data_ack    (fdi_rxp_ready),
        .rx_valid_out   (rxp_valid_out),
        .rx_data_out    (rxp_data_out),
        .rx_user_out    (rxp_user_out),
        .rx_cntl_out    (rxp_cntl_out),
        .rx_last_out    (rxp_last_out),
        .rx_srcid_out   (rxp_srcid_out),
        .rx_tgtid_out   (rxp_tgtid_out),
        .rx_ready       (rxp_ready_in),
        .rx_error       (/* TODO: error status to regs */)
    );

    // ----------------------------------------------------------------
    // CXS RX Interface
    // ----------------------------------------------------------------
    cxs_rx_if #(
        .CXS_DATA_WIDTH   (CXS_DATA_WIDTH),
        .CXS_USER_WIDTH   (CXS_USER_WIDTH),
        .CXS_CNTL_WIDTH   (CXS_CNTL_WIDTH),
        .CXS_SRCID_WIDTH  (CXS_SRCID_WIDTH),
        .CXS_TGTID_WIDTH  (CXS_TGTID_WIDTH),
        .CXS_HAS_LAST     (CXS_HAS_LAST)
    ) u_cxs_rx_if (
        .cxs_clk          (cxs_clk),
        .cxs_rst_n        (cxs_rst_n_int),
        .rx_valid_in      (rxp_valid_out),
        .rx_data_in       (rxp_data_out),
        .rx_user_in       (rxp_user_out),
        .rx_cntl_in       (rxp_cntl_out),
        .rx_last_in       (rxp_last_out),
        .rx_srcid_in      (rxp_srcid_out),
        .rx_tgtid_in      (rxp_tgtid_out),
        .rx_data_ack      (rxp_ready_in),
        .cxs_rx_valid     (cxs_rx_valid),
        .cxs_rx_data      (cxs_rx_data),
        .cxs_rx_user      (cxs_rx_user),
        .cxs_rx_cntl      (cxs_rx_cntl),
        .cxs_rx_last      (cxs_rx_last),
        .cxs_rx_srcid     (cxs_rx_srcid),
        .cxs_rx_tgtid     (cxs_rx_tgtid),
        .cxs_rx_active_req(cxs_rx_active_req),
        .cxs_rx_active    (link_cxs_rx_active),
        .cxs_rx_deact_hint(cxs_rx_deact_hint)
    );

    // Credit consumption hint from RX output
    assign rx_credit_consume = cxs_rx_valid & rxp_ready_in;

    // ----------------------------------------------------------------
    // Credit Manager (cxs_clk domain)
    // ----------------------------------------------------------------
    credit_mgr #(
        .MAX_CREDIT (MAX_CREDIT)
    ) u_credit_mgr (
        .cxs_clk             (cxs_clk),
        .cxs_rst_n           (cxs_rst_n_int),
        .tx_data_valid       (tx_credit_consume),
        .cxs_tx_crdret       (cxs_tx_crdret),
        .cxs_tx_crdgnt       (tx_credit_gnt),
        .rx_data_valid       (rx_credit_consume),
        .cxs_rx_crdret       (cxs_rx_crdret),
        .cxs_rx_crdgnt       (rx_credit_gnt),
        .cfg_credit_max      (cfg_credit_max),
        .cfg_credit_init     (cfg_credit_init),
        .status_tx_credit_cnt(status_tx_credit_cnt),
        .status_rx_credit_cnt(status_rx_credit_cnt)
    );

    // Credit manager directly interfaces with protocol layer
    assign cxs_tx_crdgnt = tx_credit_gnt;
    assign cxs_rx_crdgnt = rx_credit_gnt;
    assign credit_ready  = tx_credit_gnt & rx_credit_gnt;
    assign cxs_tx_active = link_cxs_tx_active;
    assign cxs_rx_active = link_cxs_rx_active;

    // ----------------------------------------------------------------
    // Link Control (cxs_clk domain)
    // ----------------------------------------------------------------
    cxs_fdi_link_ctrl u_link_ctrl (
        .cxs_clk          (cxs_clk),
        .cxs_rst_n        (cxs_rst_n_int),
        .cxs_tx_active_req(cxs_tx_active_req),
        .cxs_tx_deact_hint(cxs_tx_deact_hint),
        .cxs_tx_active    (link_cxs_tx_active),
        .cxs_rx_active_req(cxs_rx_active_req),
        .cxs_rx_active    (link_cxs_rx_active),
        .fdi_pl_state_sts (fdi_pl_state_sts),
        .fdi_pl_retrain   (fdi_pl_retrain),
        .credit_ready    (credit_ready),
        .link_active      (link_active),
        .link_tx_ready    (link_tx_ready),
        .link_rx_ready    (link_rx_ready),
        .link_error       (link_error),
        .link_status      (link_status)
    );

    // ----------------------------------------------------------------
    // Register block (APB) - placeholder
    // ----------------------------------------------------------------
    ucie_cxs_fdi_regs u_regs (
        .apb_clk             (apb_clk),
        .apb_rst_n           (apb_rst_n_int),
        .apb_paddr           (apb_paddr),
        .apb_pwdata          (apb_pwdata),
        .apb_penable         (apb_penable),
        .apb_psel            (apb_psel),
        .apb_pwrite          (apb_pwrite),
        .apb_prdata          (apb_prdata),
        .apb_pready          (apb_pready),
        .apb_pslverr         (apb_pslverr),
        .cfg_credit_max      (cfg_credit_max),
        .cfg_credit_init     (cfg_credit_init),
        .status_tx_credit_cnt(status_tx_credit_cnt),
        .status_rx_credit_cnt(status_rx_credit_cnt),
        .link_status         (link_status),
        .link_error          (link_error)
    );

endmodule : ucie_cxs_fdi_top
