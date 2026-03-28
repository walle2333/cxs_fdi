/***********************************************************************
 * Copyright 2026
 **********************************************************************/

/*
 * Module: cxs_fdi_link_ctrl
 *
 * Global link control state machine for the UCIe CXS-FDI bridge.
 *
 * The module arbitrates CXS activation/deactivation requests, watches
 * FDI physical-layer state, and generates link status outputs that are
 * consumed by the path and register blocks.
 */

module cxs_fdi_link_ctrl (
    input  logic        cxs_clk,
    input  logic        cxs_rst_n,

    input  logic        cxs_tx_active_req,
    input  logic        cxs_tx_deact_hint,
    output logic        cxs_tx_active,

    input  logic        cxs_rx_active_req,
    input  logic        cxs_rx_deact_hint,
    output logic        cxs_rx_active,

    input  logic [3:0]  fdi_pl_state_sts,
    input  logic        fdi_pl_retrain,
    input  logic        fdi_pl_rx_active_req,
    output logic        fdi_lp_rx_active_sts,

    input  logic        credit_ready,
    input  logic [7:0]  cfg_timeout,
    input  logic [6:0]  cfg_retry_cnt,
    input  logic [31:0] link_ctrl_reg,

    output logic        link_active,
    output logic        link_tx_ready,
    output logic        link_rx_ready,
    output logic        link_error,
    output logic [2:0]  link_status
);

    localparam logic [2:0] ST_STOP      = 3'b000;
    localparam logic [2:0] ST_ACTIV_REQ = 3'b001;
    localparam logic [2:0] ST_ACTIV_ACK = 3'b010;
    localparam logic [2:0] ST_RUN       = 3'b011;
    localparam logic [2:0] ST_DEACT     = 3'b100;
    localparam logic [2:0] ST_RETRAIN   = 3'b101;
    localparam logic [2:0] ST_ERROR     = 3'b110;

    localparam logic [3:0] FDI_RESET_STS   = 4'b0000;
    /* verilator lint_off UNUSEDPARAM */
    localparam logic [3:0] FDI_LINKUP_STS  = 4'b0001;
    /* verilator lint_on UNUSEDPARAM */
    localparam logic [3:0] FDI_ACTIVE_STS  = 4'b0010;
    localparam logic [3:0] FDI_RETRAIN_STS = 4'b0011;

    localparam logic [31:0] LINK_CTRL_DFLT = 32'h0000_0700;

    typedef enum logic [2:0] {
        ST_STOP_E      = ST_STOP,
        ST_ACTIV_REQ_E = ST_ACTIV_REQ,
        ST_ACTIV_ACK_E = ST_ACTIV_ACK,
        ST_RUN_E       = ST_RUN,
        ST_DEACT_E     = ST_DEACT,
        ST_RETRAIN_E   = ST_RETRAIN,
        ST_ERROR_E     = ST_ERROR
    } link_state_t;

    link_state_t curr_state;
    link_state_t next_state;

    logic [7:0]  timeout_cnt_q;
    logic [7:0]  timeout_cnt_d;
    logic [6:0]  retry_rem_q;
    logic [6:0]  retry_rem_d;
    logic        retry_arm_q;
    logic        retry_arm_d;
    logic        cxs_tx_active_req_s;
    logic        cxs_tx_deact_hint_s;
    logic        cxs_rx_active_req_s;
    logic        cxs_rx_deact_hint_s;
    logic        fdi_pl_retrain_s;
    logic        fdi_pl_rx_active_req_s;
    logic        credit_ready_s;
    logic [7:0]  cfg_timeout_s;
    logic [6:0]  cfg_retry_cnt_s;
    /* verilator lint_off UNUSEDSIGNAL */
    logic [31:0] link_ctrl_reg_s;
    /* verilator lint_on UNUSEDSIGNAL */
    logic        link_ctrl_activate_bit_s;
    logic        link_ctrl_deact_bit_s;
    logic        link_ctrl_retrain_bit_s;
    logic        auto_retry_en_bit_s;
    logic        fdi_rx_active_follow_en_bit_s;
    logic        error_stop_en_bit_s;

    logic        link_ctrl_activate_s;
    logic        link_ctrl_deact_s;
    logic        link_ctrl_retrain_s;
    logic        link_ctrl_activate_prev_q;
    logic        link_ctrl_deact_prev_q;
    logic        link_ctrl_retrain_prev_q;
    logic        sw_activate_req;
    logic        sw_deact_req;
    logic        sw_retrain_req;
    logic        auto_retry_en;
    logic        fdi_rx_active_follow_en;
    logic        error_stop_en;

    logic        activation_req;
    logic        deactivation_req;
    logic        retrain_req;
    logic        link_ctrl_ack;
    logic        timeout_hit;
    logic        deact_complete;
    logic        link_down;

    function automatic logic sanitize_bit(
        input logic sig,
        input logic dflt
    );
        begin
            if (sig === 1'b1) begin
                sanitize_bit = 1'b1;
            end
            else if (sig === 1'b0) begin
                sanitize_bit = 1'b0;
            end
            else begin
                sanitize_bit = dflt;
            end
        end
    endfunction

    function automatic logic [7:0] sanitize_u8(
        input logic [7:0] sig,
        input logic [7:0] dflt
    );
        begin
            sanitize_u8 = (^sig === 1'bx) ? dflt : sig;
        end
    endfunction

    function automatic logic [6:0] sanitize_u7(
        input logic [6:0] sig,
        input logic [6:0] dflt
    );
        begin
            sanitize_u7 = (^sig === 1'bx) ? dflt : sig;
        end
    endfunction

    function automatic logic [31:0] sanitize_u32(
        input logic [31:0] sig,
        input logic [31:0] dflt
    );
        begin
            sanitize_u32 = (^sig === 1'bx) ? dflt : sig;
        end
    endfunction

    // Sanitize direct inputs first so the rest of the FSM uses only local clean signals.
    always_comb begin
        cxs_tx_active_req_s    = sanitize_bit(cxs_tx_active_req, 1'b0);
        cxs_tx_deact_hint_s    = sanitize_bit(cxs_tx_deact_hint, 1'b0);
        cxs_rx_active_req_s    = sanitize_bit(cxs_rx_active_req, 1'b0);
        cxs_rx_deact_hint_s    = sanitize_bit(cxs_rx_deact_hint, 1'b0);
        fdi_pl_retrain_s       = sanitize_bit(fdi_pl_retrain, 1'b0);
        fdi_pl_rx_active_req_s = sanitize_bit(fdi_pl_rx_active_req, 1'b0);
        credit_ready_s         = sanitize_bit(credit_ready, 1'b0);
        cfg_timeout_s          = sanitize_u8(cfg_timeout, 8'hff);
        cfg_retry_cnt_s        = sanitize_u7(cfg_retry_cnt, 7'd3);
        link_ctrl_reg_s        = sanitize_u32(link_ctrl_reg, LINK_CTRL_DFLT);
    end

    // Keep pure bit extraction as continuous assigns so Icarus does not need
    // to infer an always_comb sensitivity list for parameterized selects.
    assign link_ctrl_activate_bit_s      = link_ctrl_reg_s[0];
    assign link_ctrl_deact_bit_s         = link_ctrl_reg_s[1];
    assign link_ctrl_retrain_bit_s       = link_ctrl_reg_s[2];
    assign auto_retry_en_bit_s           = link_ctrl_reg_s[8];
    assign fdi_rx_active_follow_en_bit_s = link_ctrl_reg_s[9];
    assign error_stop_en_bit_s           = link_ctrl_reg_s[10];

    // Sanitize the individual software control bits separately from the rest
    // of the request generation logic.
    always_comb begin
        link_ctrl_activate_s    = sanitize_bit(link_ctrl_activate_bit_s, 1'b0);
        link_ctrl_deact_s       = sanitize_bit(link_ctrl_deact_bit_s, 1'b0);
        link_ctrl_retrain_s     = sanitize_bit(link_ctrl_retrain_bit_s, 1'b0);
        auto_retry_en           = sanitize_bit(auto_retry_en_bit_s, 1'b1);
        fdi_rx_active_follow_en = sanitize_bit(fdi_rx_active_follow_en_bit_s, 1'b1);
        error_stop_en           = sanitize_bit(error_stop_en_bit_s, 1'b1);
    end

    // Derive software edge-triggered requests after the control bits are stable.
    always_comb begin
        sw_activate_req        = link_ctrl_activate_s & ~link_ctrl_activate_prev_q;
        sw_deact_req           = link_ctrl_deact_s & ~link_ctrl_deact_prev_q;
        sw_retrain_req         = link_ctrl_retrain_s & ~link_ctrl_retrain_prev_q;
    end

    // Collect protocol- and software-driven requests for the state machine.
    always_comb begin
        activation_req = cxs_tx_active_req_s ||
                         cxs_rx_active_req_s ||
                         sw_activate_req ||
                         (fdi_pl_rx_active_req_s && fdi_rx_active_follow_en);
        deactivation_req = cxs_tx_deact_hint_s ||
                           cxs_rx_deact_hint_s ||
                           sw_deact_req;
        retrain_req = fdi_pl_retrain_s ||
                      (fdi_pl_state_sts == FDI_RETRAIN_STS) ||
                      sw_retrain_req;
        link_ctrl_ack = (fdi_pl_state_sts == FDI_ACTIVE_STS) && credit_ready_s;
        timeout_hit = (timeout_cnt_q >= cfg_timeout_s);
        deact_complete = !activation_req && !deactivation_req;
        link_down = (fdi_pl_state_sts == FDI_RESET_STS);
    end

    // Next-state and retry/timeout bookkeeping.
    always_comb begin
        next_state = curr_state;
        timeout_cnt_d = timeout_cnt_q;
        retry_rem_d = retry_rem_q;
        retry_arm_d = retry_arm_q;

        case (curr_state)
            ST_STOP_E: begin
                timeout_cnt_d = '0;
                if (!activation_req) begin
                    retry_arm_d = 1'b0;
                    retry_rem_d = cfg_retry_cnt_s;
                end
                else if (!retry_arm_q || (retry_rem_q != '0)) begin
                    next_state = ST_ACTIV_REQ_E;
                    timeout_cnt_d = '0;
                end
            end

            ST_ACTIV_REQ_E: begin
                timeout_cnt_d = timeout_cnt_q + 1'b1;
                if (deactivation_req) begin
                    next_state = ST_STOP_E;
                    timeout_cnt_d = '0;
                end
                else if (link_ctrl_ack) begin
                    next_state = ST_ACTIV_ACK_E;
                    timeout_cnt_d = '0;
                    retry_arm_d = 1'b0;
                    retry_rem_d = cfg_retry_cnt_s;
                end
                else if (timeout_hit) begin
                    timeout_cnt_d = '0;
                    if (auto_retry_en && (retry_rem_q != '0)) begin
                        next_state = ST_STOP_E;
                        retry_rem_d = retry_rem_q - 1'b1;
                        retry_arm_d = 1'b1;
                    end
                    else if (error_stop_en) begin
                        next_state = ST_ERROR_E;
                        retry_arm_d = 1'b0;
                    end
                    else begin
                        next_state = ST_STOP_E;
                        retry_arm_d = 1'b0;
                    end
                end
            end

            ST_ACTIV_ACK_E: begin
                timeout_cnt_d = '0;
                if (deactivation_req) begin
                    next_state = ST_STOP_E;
                end
                else if (credit_ready_s) begin
                    next_state = ST_RUN_E;
                end
                else if (link_down) begin
                    if (error_stop_en) begin
                        next_state = ST_ERROR_E;
                    end
                    else begin
                        next_state = ST_STOP_E;
                    end
                end
            end

            ST_RUN_E: begin
                timeout_cnt_d = '0;
                if (deactivation_req) begin
                    next_state = ST_DEACT_E;
                end
                else if (retrain_req) begin
                    next_state = ST_RETRAIN_E;
                end
                else if (link_down) begin
                    if (error_stop_en) begin
                        next_state = ST_ERROR_E;
                    end
                    else begin
                        next_state = ST_STOP_E;
                    end
                end
            end

            ST_DEACT_E: begin
                timeout_cnt_d = '0;
                if (deact_complete) begin
                    next_state = ST_STOP_E;
                    retry_arm_d = 1'b0;
                    retry_rem_d = cfg_retry_cnt_s;
                end
            end

            ST_RETRAIN_E: begin
                timeout_cnt_d = '0;
                if (deactivation_req) begin
                    next_state = ST_DEACT_E;
                end
                else if (!retrain_req) begin
                    next_state = ST_RUN_E;
                end
            end

            ST_ERROR_E: begin
                timeout_cnt_d = '0;
                retry_arm_d = 1'b0;
                if (!cxs_rst_n) begin
                    next_state = ST_STOP_E;
                end
            end

            default: begin
                next_state = ST_STOP_E;
                timeout_cnt_d = '0;
                retry_arm_d = 1'b0;
                retry_rem_d = cfg_retry_cnt_s;
            end
        endcase
    end

    always_ff @(posedge cxs_clk or negedge cxs_rst_n) begin
        if (!cxs_rst_n) begin
            curr_state <= ST_STOP_E;
            timeout_cnt_q <= '0;
            retry_rem_q <= 7'd3;
            retry_arm_q <= 1'b0;
            link_ctrl_activate_prev_q <= 1'b0;
            link_ctrl_deact_prev_q <= 1'b0;
            link_ctrl_retrain_prev_q <= 1'b0;
        end
        else begin
            curr_state <= next_state;
            timeout_cnt_q <= timeout_cnt_d;
            retry_rem_q <= retry_rem_d;
            retry_arm_q <= retry_arm_d;
            link_ctrl_activate_prev_q <= link_ctrl_activate_s;
            link_ctrl_deact_prev_q <= link_ctrl_deact_s;
            link_ctrl_retrain_prev_q <= link_ctrl_retrain_s;
        end
    end

    always_comb begin
        link_status = curr_state;
        link_active = (curr_state == ST_RUN_E);
        link_tx_ready = (curr_state == ST_RUN_E);
        link_rx_ready = (curr_state == ST_RUN_E);
        link_error = (curr_state == ST_ERROR_E);
        cxs_tx_active = (curr_state == ST_ACTIV_ACK_E) ||
                        (curr_state == ST_RUN_E);
        cxs_rx_active = (curr_state == ST_ACTIV_ACK_E) ||
                        (curr_state == ST_RUN_E);
        fdi_lp_rx_active_sts = (curr_state == ST_ACTIV_ACK_E) ||
                               (curr_state == ST_RUN_E);
    end

endmodule: cxs_fdi_link_ctrl
