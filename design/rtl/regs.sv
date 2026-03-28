/***********************************************************************
 * Copyright 2026
 **********************************************************************/

/*
 * Module: regs
 *
 * APB CSR register block for the UCIe CXS-FDI bridge.
 *
 * Features:
 * - APB read/write access
 * - CTRL/STATUS/CONFIG/INT_EN/INT_STATUS/ERR_STATUS/LINK_CTRL/VERSION
 * - TX/RX flit counters
 * - interrupt request generation
 * - status and configuration output mirrors
 */

module regs (
    input  logic        pclk,
    input  logic        preset_n,
    input  logic        psel,
    input  logic        penable,
    input  logic        pwrite,
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [15:0] paddr,
    /* verilator lint_on UNUSEDSIGNAL */
    input  logic [31:0] pwdata,
    output logic [31:0] prdata,
    output logic        pready,
    output logic        pslverr,

    input  logic [2:0]  status_link_state,
    input  logic        status_busy,
    input  logic        status_tx_ready,
    input  logic        status_rx_ready,
    input  logic        status_init_done,
    input  logic [6:0]  err_status_in,
    input  logic        evt_link_up,
    input  logic        evt_link_down,
    input  logic        evt_fifo_almost_full,
    input  logic        stat_tx_flit_pulse,
    input  logic        stat_rx_flit_pulse,
    output logic        irq,

    output logic        cfg_enable,
    output logic [7:0]  cfg_mode,
    output logic [3:0]  cfg_flit_width_sel,
    output logic        sw_reset_pulse,
    output logic [7:0]  cfg_max_credit,
    output logic [7:0]  cfg_fifo_depth,
    output logic [7:0]  cfg_timeout,
    output logic [6:0]  cfg_retry_cnt,
    output logic [31:0] link_ctrl_reg
);

    localparam logic [5:0] REG_CTRL       = 6'h00;
    localparam logic [5:0] REG_STATUS     = 6'h01;
    localparam logic [5:0] REG_CONFIG     = 6'h02;
    localparam logic [5:0] REG_INT_EN     = 6'h03;
    localparam logic [5:0] REG_INT_STATUS = 6'h04;
    localparam logic [5:0] REG_ERR_STATUS = 6'h05;
    localparam logic [5:0] REG_LINK_CTRL  = 6'h06;
    localparam logic [5:0] REG_TX_CNT_L   = 6'h08;
    localparam logic [5:0] REG_TX_CNT_H   = 6'h09;
    localparam logic [5:0] REG_RX_CNT_L   = 6'h0A;
    localparam logic [5:0] REG_RX_CNT_H   = 6'h0B;
    localparam logic [5:0] REG_VERSION    = 6'h0C;

    localparam logic [31:0] VERSION_VALUE = 32'h0001_0000;

    logic [31:0] ctrl_reg;
    logic [31:0] config_reg;
    logic [31:0] int_en_reg;
    logic [31:0] int_status_reg;
    logic [31:0] err_status_reg;
    logic [31:0] link_ctrl_reg_q;
    logic [63:0] tx_flit_cnt;
    logic [63:0] rx_flit_cnt;

    logic [31:0] status_reg;
    logic [31:0] read_data;
    logic [31:0] tx_flit_cnt_lo;
    logic [31:0] tx_flit_cnt_hi;
    logic [31:0] rx_flit_cnt_lo;
    logic [31:0] rx_flit_cnt_hi;

    logic        ctrl_write;
    logic        config_write;
    logic        int_en_write;
    logic        int_status_write;
    logic        err_status_write;
    logic        link_ctrl_write;
    logic        apb_access;
    logic [5:0]  word_addr;

    assign apb_access = psel && penable;
    assign pready = apb_access;
    assign word_addr = paddr[7:2];

    assign ctrl_write       = apb_access && pwrite && (word_addr == REG_CTRL);
    assign config_write     = apb_access && pwrite && (word_addr == REG_CONFIG);
    assign int_en_write     = apb_access && pwrite && (word_addr == REG_INT_EN);
    assign int_status_write = apb_access && pwrite && (word_addr == REG_INT_STATUS);
    assign err_status_write = apb_access && pwrite && (word_addr == REG_ERR_STATUS);
    assign link_ctrl_write  = apb_access && pwrite && (word_addr == REG_LINK_CTRL);

    // ----------------------------------------------------------------
    // Control, config and status mirrors
    // ----------------------------------------------------------------
    always_ff @(posedge pclk or negedge preset_n) begin
        if (!preset_n) begin
            ctrl_reg           <= 32'h0000_0010;
            config_reg         <= 32'h2040_FF07;
            int_en_reg         <= 32'h0000_0000;
            int_status_reg     <= 32'h0000_0000;
            err_status_reg     <= 32'h0000_0000;
            link_ctrl_reg_q    <= 32'h0000_0700;
            tx_flit_cnt        <= 64'h0000_0000_0000_0000;
            rx_flit_cnt        <= 64'h0000_0000_0000_0000;
            sw_reset_pulse     <= 1'b0;
        end
        else begin
            sw_reset_pulse <= 1'b0;

            if (ctrl_write) begin
                ctrl_reg[31]    <= pwdata[31];
                ctrl_reg[23:16] <= pwdata[23:16];
                ctrl_reg[7:4]   <= pwdata[7:4];
                ctrl_reg[30:24] <= 7'h00;
                ctrl_reg[15:8]  <= 8'h00;
                ctrl_reg[3:1]   <= 3'h0;
                ctrl_reg[0]     <= 1'b0;

                if (pwdata[0]) begin
                    sw_reset_pulse <= 1'b1;
                end
            end

            if (config_write) begin
                config_reg[31:24] <= pwdata[31:24];
                config_reg[23:16] <= pwdata[23:16];
                config_reg[15:8]  <= pwdata[15:8];
                config_reg[7:1]   <= pwdata[7:1];
                config_reg[0]     <= 1'b1;
            end

            if (int_en_write) begin
                int_en_reg[7:4] <= pwdata[7:4];
                int_en_reg[31:8] <= 24'h0;
                int_en_reg[3:0] <= 4'h0;
            end

            int_status_reg <= (int_status_reg & ~(int_status_write ? pwdata : 32'h0)) |
                              int_status_set_mask();

            err_status_reg <= (err_status_reg & ~(err_status_write ? pwdata : 32'h0)) |
                              err_status_set_mask();

            if (link_ctrl_write) begin
                link_ctrl_reg_q[10:8] <= pwdata[10:8];
                link_ctrl_reg_q[2:0]  <= pwdata[2:0];
                link_ctrl_reg_q[7:3]  <= 5'h00;
                link_ctrl_reg_q[31:11] <= 21'h0;
            end

            if (stat_tx_flit_pulse) begin
                tx_flit_cnt <= tx_flit_cnt + 64'd1;
            end
            if (stat_rx_flit_pulse) begin
                rx_flit_cnt <= rx_flit_cnt + 64'd1;
            end
        end
    end

    function automatic logic [31:0] int_status_set_mask;
        logic [31:0] set_mask;
        begin
            set_mask = 32'h0;
            if (|err_status_in) begin
                set_mask[7] = 1'b1;
            end
            if (evt_link_up) begin
                set_mask[6] = 1'b1;
            end
            if (evt_link_down) begin
                set_mask[5] = 1'b1;
            end
            if (evt_fifo_almost_full) begin
                set_mask[4] = 1'b1;
            end
            int_status_set_mask = set_mask;
        end
    endfunction

    function automatic logic [31:0] err_status_set_mask;
        logic [31:0] set_mask;
        begin
            set_mask = 32'h0;
            set_mask[6:0] = err_status_in;
            err_status_set_mask = set_mask;
        end
    endfunction

    function automatic logic [31:0] int_status_next(
        input logic [31:0] current,
        input logic [31:0] w1c_data,
        input logic        unused
    );
        logic [31:0] set_mask;
        begin
            set_mask = int_status_set_mask();
            int_status_next = (current & ~w1c_data) | set_mask;
        end
    endfunction

    // ----------------------------------------------------------------
    // Read data decode
    // ----------------------------------------------------------------
    always_comb begin
        status_reg = 32'h0;
        status_reg[15:8] = {5'b0, status_link_state};
        status_reg[3] = status_busy;
        status_reg[2] = status_tx_ready;
        status_reg[1] = status_rx_ready;
        status_reg[0] = status_init_done;
    end

    // Keep simple counter slices as continuous assigns so the read mux remains
    // compact and Icarus does not warn on constant-select sensitivity.
    assign tx_flit_cnt_lo = tx_flit_cnt[31:0];
    assign tx_flit_cnt_hi = tx_flit_cnt[63:32];
    assign rx_flit_cnt_lo = rx_flit_cnt[31:0];
    assign rx_flit_cnt_hi = rx_flit_cnt[63:32];

    always_comb begin
        read_data = 32'h0;
        pslverr = 1'b0;

        case (word_addr)
            REG_CTRL: begin
                read_data = ctrl_reg;
            end
            REG_STATUS: begin
                read_data = status_reg;
            end
            REG_CONFIG: begin
                read_data = config_reg;
            end
            REG_INT_EN: begin
                read_data = int_en_reg;
            end
            REG_INT_STATUS: begin
                read_data = int_status_reg;
            end
            REG_ERR_STATUS: begin
                read_data = err_status_reg;
            end
            REG_LINK_CTRL: begin
                read_data = link_ctrl_reg_q;
            end
            REG_TX_CNT_L: begin
                read_data = tx_flit_cnt_lo;
            end
            REG_TX_CNT_H: begin
                read_data = tx_flit_cnt_hi;
            end
            REG_RX_CNT_L: begin
                read_data = rx_flit_cnt_lo;
            end
            REG_RX_CNT_H: begin
                read_data = rx_flit_cnt_hi;
            end
            REG_VERSION: begin
                read_data = VERSION_VALUE;
            end
            default: begin
                read_data = 32'h0;
                if (apb_access) begin
                    pslverr = 1'b1;
                end
            end
        endcase
    end

    assign prdata = read_data;

    // ----------------------------------------------------------------
    // Output mirrors
    // ----------------------------------------------------------------
    assign cfg_enable          = ctrl_reg[31];
    assign cfg_mode            = ctrl_reg[23:16];
    assign cfg_flit_width_sel  = ctrl_reg[7:4];
    assign cfg_max_credit      = config_reg[31:24];
    assign cfg_fifo_depth      = config_reg[23:16];
    assign cfg_timeout         = config_reg[15:8];
    assign cfg_retry_cnt       = config_reg[7:1];
    assign link_ctrl_reg       = link_ctrl_reg_q;
    assign irq                 = |(int_status_reg & int_en_reg);

endmodule: regs
