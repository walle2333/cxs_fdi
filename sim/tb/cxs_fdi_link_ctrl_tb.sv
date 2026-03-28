/***********************************************************************
 * Copyright 2026
 **********************************************************************/

/*
 * Module: cxs_fdi_link_ctrl_tb
 *
 * Skeleton testbench for cxs_fdi_link_ctrl.
 * This file establishes the control-domain stimulus framework and can
 * be connected to the DUT after RTL implementation is added.
 */

`timescale 1ns/1ps

module cxs_fdi_link_ctrl_tb;

    localparam time CXS_CLK_PERIOD = 10ns;
    localparam logic [2:0] ST_STOP      = 3'b000;
    localparam logic [2:0] ST_ACTIV_REQ = 3'b001;
    localparam logic [2:0] ST_ACTIV_ACK = 3'b010;
    localparam logic [2:0] ST_RUN       = 3'b011;
    localparam logic [2:0] ST_DEACT     = 3'b100;
    localparam logic [2:0] ST_RETRAIN   = 3'b101;
    localparam logic [2:0] ST_ERROR     = 3'b110;
    localparam logic [3:0] FDI_RESET_STS   = 4'b0000;
    localparam logic [3:0] FDI_LINKUP_STS  = 4'b0001;
    localparam logic [3:0] FDI_ACTIVE_STS  = 4'b0010;
    localparam logic [3:0] FDI_RETRAIN_STS = 4'b0011;

    logic       cxs_clk;
    logic       cxs_rst_n;
    logic       cxs_tx_active_req;
    logic       cxs_tx_deact_hint;
    logic       cxs_tx_active;
    logic       cxs_rx_active_req;
    logic       cxs_rx_deact_hint;
    logic       cxs_rx_active;
    logic [3:0] fdi_pl_state_sts;
    logic       fdi_pl_retrain;
    logic       fdi_pl_rx_active_req;
    logic       fdi_lp_rx_active_sts;
    logic       credit_ready;
    logic [7:0] cfg_timeout;
    logic [6:0] cfg_retry_cnt;
    logic [31:0] link_ctrl_reg;
    logic       link_active;
    logic       link_tx_ready;
    logic       link_rx_ready;
    logic       link_error;
    logic [2:0] link_status;
    logic [2:0] exp_link_status;
    logic       exp_link_active;
    logic       exp_link_tx_ready;
    logic       exp_link_rx_ready;
    logic       exp_link_error;
    logic       exp_cxs_tx_active;
    logic       exp_cxs_rx_active;
    logic       exp_fdi_lp_rx_active_sts;
    int         error_count;

    initial begin
        cxs_clk = 1'b0;
        forever #(CXS_CLK_PERIOD / 2) cxs_clk = ~cxs_clk;
    end

    initial begin
        cxs_rst_n             = 1'b0;
        cxs_tx_active_req     = 1'b0;
        cxs_tx_deact_hint     = 1'b0;
        cxs_rx_active_req     = 1'b0;
        cxs_rx_deact_hint     = 1'b0;
        fdi_pl_state_sts      = 4'b0000;
        fdi_pl_retrain        = 1'b0;
        fdi_pl_rx_active_req  = 1'b0;
        credit_ready          = 1'b0;
        cfg_timeout           = 8'd16;
        cfg_retry_cnt         = 7'd2;
        link_ctrl_reg         = 32'h0000_0700;

        repeat (4) @(posedge cxs_clk);
        cxs_rst_n = 1'b1;
    end

    initial begin
        $dumpfile("cxs_fdi_link_ctrl_tb.fst");
        $dumpvars(0, cxs_fdi_link_ctrl_tb);
    end

    cxs_fdi_link_ctrl dut (
        .cxs_clk              (cxs_clk),
        .cxs_rst_n            (cxs_rst_n),
        .cxs_tx_active_req    (cxs_tx_active_req),
        .cxs_tx_deact_hint    (cxs_tx_deact_hint),
        .cxs_tx_active        (cxs_tx_active),
        .cxs_rx_active_req    (cxs_rx_active_req),
        .cxs_rx_deact_hint    (cxs_rx_deact_hint),
        .cxs_rx_active        (cxs_rx_active),
        .fdi_pl_state_sts     (fdi_pl_state_sts),
        .fdi_pl_retrain       (fdi_pl_retrain),
        .fdi_pl_rx_active_req (fdi_pl_rx_active_req),
        .fdi_lp_rx_active_sts (fdi_lp_rx_active_sts),
        .credit_ready         (credit_ready),
        .cfg_timeout          (cfg_timeout),
        .cfg_retry_cnt        (cfg_retry_cnt),
        .link_ctrl_reg        (link_ctrl_reg),
        .link_active          (link_active),
        .link_tx_ready        (link_tx_ready),
        .link_rx_ready        (link_rx_ready),
        .link_error           (link_error),
        .link_status          (link_status)
    );

    task automatic issue_sw_activate;
        begin
            @(posedge cxs_clk);
            link_ctrl_reg[0] <= 1'b1;
            @(posedge cxs_clk);
            link_ctrl_reg[0] <= 1'b0;
        end
    endtask

    task automatic issue_sw_deact;
        begin
            @(posedge cxs_clk);
            link_ctrl_reg[1] <= 1'b1;
            @(posedge cxs_clk);
            link_ctrl_reg[1] <= 1'b0;
        end
    endtask

    task automatic issue_sw_retrain;
        begin
            @(posedge cxs_clk);
            link_ctrl_reg[2] <= 1'b1;
            @(posedge cxs_clk);
            link_ctrl_reg[2] <= 1'b0;
        end
    endtask

    task automatic model_set_state(input logic [2:0] state);
        begin
            exp_link_status            = state;
            exp_link_active            = (state == ST_RUN);
            exp_link_tx_ready          = (state == ST_RUN);
            exp_link_rx_ready          = (state == ST_RUN);
            exp_link_error             = (state == ST_ERROR);
            exp_cxs_tx_active          = (state == ST_ACTIV_ACK) || (state == ST_RUN);
            exp_cxs_rx_active          = (state == ST_ACTIV_ACK) || (state == ST_RUN);
            exp_fdi_lp_rx_active_sts   = (state == ST_ACTIV_ACK) || (state == ST_RUN);
        end
    endtask

    task automatic print_expected_state(input string tag);
        begin
            $display("[%0t] %s exp_state=%03b exp_active=%0b exp_error=%0b",
                     $time, tag, exp_link_status, exp_link_active, exp_link_error);
        end
    endtask

    task automatic check_observed_state(input string tag);
        begin
            if (link_status !== exp_link_status) begin
                error_count++;
                $display("ERROR[%0t] %s link_status mismatch exp=%03b got=%03b",
                         $time, tag, exp_link_status, link_status);
            end

            if (link_active !== exp_link_active) begin
                error_count++;
                $display("ERROR[%0t] %s link_active mismatch exp=%0b got=%0b",
                         $time, tag, exp_link_active, link_active);
            end

            if (link_tx_ready !== exp_link_tx_ready) begin
                error_count++;
                $display("ERROR[%0t] %s link_tx_ready mismatch exp=%0b got=%0b",
                         $time, tag, exp_link_tx_ready, link_tx_ready);
            end

            if (link_rx_ready !== exp_link_rx_ready) begin
                error_count++;
                $display("ERROR[%0t] %s link_rx_ready mismatch exp=%0b got=%0b",
                         $time, tag, exp_link_rx_ready, link_rx_ready);
            end

            if (link_error !== exp_link_error) begin
                error_count++;
                $display("ERROR[%0t] %s link_error mismatch exp=%0b got=%0b",
                         $time, tag, exp_link_error, link_error);
            end

            if (cxs_tx_active !== exp_cxs_tx_active) begin
                error_count++;
                $display("ERROR[%0t] %s cxs_tx_active mismatch exp=%0b got=%0b",
                         $time, tag, exp_cxs_tx_active, cxs_tx_active);
            end

            if (cxs_rx_active !== exp_cxs_rx_active) begin
                error_count++;
                $display("ERROR[%0t] %s cxs_rx_active mismatch exp=%0b got=%0b",
                         $time, tag, exp_cxs_rx_active, cxs_rx_active);
            end

            if (fdi_lp_rx_active_sts !== exp_fdi_lp_rx_active_sts) begin
                error_count++;
                $display("ERROR[%0t] %s fdi_lp_rx_active_sts mismatch exp=%0b got=%0b",
                         $time, tag, exp_fdi_lp_rx_active_sts, fdi_lp_rx_active_sts);
            end
        end
    endtask

    task automatic scenario_reset_state;
        begin
            model_set_state(ST_STOP);
            repeat (2) @(posedge cxs_clk);
            print_expected_state("reset_state");
            check_observed_state("reset_state");
        end
    endtask

    task automatic scenario_activate_to_run;
        begin
            @(posedge cxs_clk);
            fdi_pl_state_sts  <= FDI_ACTIVE_STS;
            fdi_pl_retrain    <= 1'b0;
            credit_ready      <= 1'b0;
            cxs_tx_active_req <= 1'b1;
            cxs_rx_active_req <= 1'b1;
            link_ctrl_reg[0]  <= 1'b1;
            model_set_state(ST_ACTIV_REQ);
            @(posedge cxs_clk);
            cxs_tx_active_req <= 1'b0;
            cxs_rx_active_req <= 1'b0;
            link_ctrl_reg[0]  <= 1'b0;
            repeat (1) @(posedge cxs_clk);
            print_expected_state("activate_req");
            check_observed_state("activate_req");

            credit_ready <= 1'b1;
            model_set_state(ST_ACTIV_ACK);
            repeat (2) @(posedge cxs_clk);
            print_expected_state("activate_ack");
            check_observed_state("activate_ack");

            model_set_state(ST_RUN);
            repeat (2) @(posedge cxs_clk);
            print_expected_state("run_state");
            check_observed_state("run_state");
        end
    endtask

    task automatic scenario_deact_to_stop;
        begin
            @(posedge cxs_clk);
            cxs_tx_deact_hint <= 1'b1;
            cxs_rx_deact_hint <= 1'b1;
            link_ctrl_reg[1]  <= 1'b1;
            model_set_state(ST_DEACT);
            @(posedge cxs_clk);
            cxs_tx_deact_hint <= 1'b0;
            cxs_rx_deact_hint <= 1'b0;
            link_ctrl_reg[1]  <= 1'b0;
            repeat (1) @(posedge cxs_clk);
            print_expected_state("deact_state");
            check_observed_state("deact_state");

            credit_ready <= 1'b0;
            model_set_state(ST_STOP);
            repeat (1) @(posedge cxs_clk);
            print_expected_state("stop_after_deact");
            check_observed_state("stop_after_deact");
        end
    endtask

    task automatic scenario_retrain_return;
        begin
            // Re-enter RUN first.
            credit_ready      <= 1'b0;
            fdi_pl_state_sts  <= FDI_ACTIVE_STS;
            fdi_pl_retrain    <= 1'b0;
            cxs_tx_active_req <= 1'b1;
            cxs_rx_active_req <= 1'b1;
            link_ctrl_reg[0]  <= 1'b1;
            model_set_state(ST_ACTIV_REQ);
            @(posedge cxs_clk);
            cxs_tx_active_req <= 1'b0;
            cxs_rx_active_req <= 1'b0;
            link_ctrl_reg[0]  <= 1'b0;
            repeat (1) @(posedge cxs_clk);
            credit_ready <= 1'b1;
            model_set_state(ST_ACTIV_ACK);
            repeat (1) @(posedge cxs_clk);
            model_set_state(ST_RUN);
            repeat (1) @(posedge cxs_clk);

            fdi_pl_state_sts  <= FDI_RETRAIN_STS;
            fdi_pl_retrain    <= 1'b1;
            model_set_state(ST_RETRAIN);
            repeat (2) @(posedge cxs_clk);
            print_expected_state("retrain_state");
            check_observed_state("retrain_state");

            fdi_pl_state_sts  <= FDI_ACTIVE_STS;
            fdi_pl_retrain    <= 1'b0;
            model_set_state(ST_RUN);
            repeat (2) @(posedge cxs_clk);
            print_expected_state("run_after_retrain");
            check_observed_state("run_after_retrain");
        end
    endtask

    task automatic scenario_error_stop_mode;
        begin
            // ERROR_STOP_EN = 0
            @(posedge cxs_clk);
            link_ctrl_reg = 32'h0000_0300;
            repeat (4) @(posedge cxs_clk);
            fdi_pl_state_sts  = FDI_RESET_STS;
            credit_ready      = 1'b1;
            model_set_state(ST_STOP);
            repeat (2) @(posedge cxs_clk);
            print_expected_state("error_stop_disabled");
            check_observed_state("error_stop_disabled");
        end
    endtask

    initial begin
        error_count = 0;
        @(posedge cxs_rst_n);

        fdi_pl_state_sts <= FDI_LINKUP_STS;
        model_set_state(ST_STOP);

        // NOTE:
        // The expected-state model and directed scenarios are ready.
        // Once the DUT is connected, check_observed_state() will report
        // mismatches automatically.
        scenario_reset_state();
        scenario_activate_to_run();
        scenario_deact_to_stop();
        scenario_retrain_return();
        scenario_error_stop_mode();

        repeat (10) @(posedge cxs_clk);
        $display("cxs_fdi_link_ctrl_tb completed with error_count=%0d", error_count);
        $finish;
    end

endmodule: cxs_fdi_link_ctrl_tb
