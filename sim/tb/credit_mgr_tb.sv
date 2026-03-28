/***********************************************************************
 * Copyright 2026
 **********************************************************************/

/*
 * Module: credit_mgr_tb
 *
 * Skeleton testbench for credit_mgr.
 * This file provides the initial verification scaffold and can be
 * connected to the RTL module once the implementation is available.
 */

`timescale 1ns/1ps

module credit_mgr_tb;

    localparam time CLK_PERIOD = 10ns;

    logic       cxs_clk;
    logic       cxs_rst_n;

    logic       tx_data_valid;
    logic       cxs_tx_crdret;
    logic       cxs_tx_crdgnt;
    logic       rx_data_valid;
    logic       cxs_rx_crdret;
    logic       cxs_rx_crdgnt;
    logic       credit_ready;
    logic [5:0] cfg_credit_max;
    logic [5:0] cfg_credit_init;
    logic [5:0] status_tx_credit_cnt;
    logic [5:0] status_rx_credit_cnt;
    logic [5:0] exp_tx_credit_cnt;
    logic [5:0] exp_rx_credit_cnt;
    logic       exp_credit_ready;

    int         error_count;

    initial begin
        cxs_clk = 1'b0;
        forever #(CLK_PERIOD / 2) cxs_clk = ~cxs_clk;
    end

    initial begin
        cxs_rst_n           = 1'b0;
        tx_data_valid       = 1'b0;
        cxs_tx_crdret       = 1'b0;
        rx_data_valid       = 1'b0;
        cxs_rx_crdret       = 1'b0;
        cfg_credit_max      = 6'd8;
        cfg_credit_init     = 6'd4;

        repeat (4) @(posedge cxs_clk);
        cxs_rst_n = 1'b1;
    end

    initial begin
        $dumpfile("credit_mgr_tb.fst");
        $dumpvars(0, credit_mgr_tb);
    end

    credit_mgr #(
        .CREDIT_WIDTH (6)
    ) dut (
        .cxs_clk              (cxs_clk),
        .cxs_rst_n            (cxs_rst_n),
        .tx_data_valid        (tx_data_valid),
        .cxs_tx_crdret        (cxs_tx_crdret),
        .cxs_tx_crdgnt        (cxs_tx_crdgnt),
        .rx_data_valid        (rx_data_valid),
        .cxs_rx_crdret        (cxs_rx_crdret),
        .cxs_rx_crdgnt        (cxs_rx_crdgnt),
        .credit_ready         (credit_ready),
        .cfg_credit_max       (cfg_credit_max),
        .cfg_credit_init      (cfg_credit_init),
        .status_tx_credit_cnt (status_tx_credit_cnt),
        .status_rx_credit_cnt (status_rx_credit_cnt)
    );

    task automatic send_tx_flit;
        begin
            @(posedge cxs_clk);
            tx_data_valid <= 1'b1;
            @(posedge cxs_clk);
            tx_data_valid <= 1'b0;
        end
    endtask

    task automatic return_tx_credit;
        begin
            @(posedge cxs_clk);
            cxs_tx_crdret <= 1'b1;
            @(posedge cxs_clk);
            cxs_tx_crdret <= 1'b0;
        end
    endtask

    task automatic send_rx_flit;
        begin
            @(posedge cxs_clk);
            rx_data_valid <= 1'b1;
            @(posedge cxs_clk);
            rx_data_valid <= 1'b0;
        end
    endtask

    task automatic return_rx_credit;
        begin
            @(posedge cxs_clk);
            cxs_rx_crdret <= 1'b1;
            @(posedge cxs_clk);
            cxs_rx_crdret <= 1'b0;
        end
    endtask

    task automatic model_reset;
        begin
            exp_tx_credit_cnt = cfg_credit_init;
            exp_rx_credit_cnt = cfg_credit_init;
            exp_credit_ready  = (cfg_credit_init > 0);
        end
    endtask

    task automatic model_tx_consume;
        begin
            if (exp_tx_credit_cnt > 0) begin
                exp_tx_credit_cnt = exp_tx_credit_cnt - 1'b1;
            end
            exp_credit_ready = (exp_tx_credit_cnt > 0) && (exp_rx_credit_cnt > 0);
        end
    endtask

    task automatic model_tx_return;
        begin
            if (exp_tx_credit_cnt < cfg_credit_max) begin
                exp_tx_credit_cnt = exp_tx_credit_cnt + 1'b1;
            end
            exp_credit_ready = (exp_tx_credit_cnt > 0) && (exp_rx_credit_cnt > 0);
        end
    endtask

    task automatic model_rx_consume;
        begin
            if (exp_rx_credit_cnt > 0) begin
                exp_rx_credit_cnt = exp_rx_credit_cnt - 1'b1;
            end
            exp_credit_ready = (exp_tx_credit_cnt > 0) && (exp_rx_credit_cnt > 0);
        end
    endtask

    task automatic model_rx_return;
        begin
            if (exp_rx_credit_cnt < cfg_credit_max) begin
                exp_rx_credit_cnt = exp_rx_credit_cnt + 1'b1;
            end
            exp_credit_ready = (exp_tx_credit_cnt > 0) && (exp_rx_credit_cnt > 0);
        end
    endtask

    task automatic print_expected_state(input string tag);
        begin
            $display("[%0t] %s exp_tx=%0d exp_rx=%0d exp_ready=%0b",
                     $time, tag, exp_tx_credit_cnt, exp_rx_credit_cnt, exp_credit_ready);
        end
    endtask

    task automatic check_observed_state(input string tag);
        begin
            // This task becomes active after the DUT is connected.
            if (status_tx_credit_cnt !== exp_tx_credit_cnt) begin
                error_count++;
                $display("ERROR[%0t] %s tx count mismatch exp=%0d got=%0d",
                         $time, tag, exp_tx_credit_cnt, status_tx_credit_cnt);
            end

            if (status_rx_credit_cnt !== exp_rx_credit_cnt) begin
                error_count++;
                $display("ERROR[%0t] %s rx count mismatch exp=%0d got=%0d",
                         $time, tag, exp_rx_credit_cnt, status_rx_credit_cnt);
            end

            if (credit_ready !== exp_credit_ready) begin
                error_count++;
                $display("ERROR[%0t] %s credit_ready mismatch exp=%0b got=%0b",
                         $time, tag, exp_credit_ready, credit_ready);
            end
        end
    endtask

    task automatic scenario_reset_init;
        begin
            model_reset();
            repeat (2) @(posedge cxs_clk);
            print_expected_state("reset_init");
            check_observed_state("reset_init");
        end
    endtask

    task automatic scenario_consume_to_zero;
        begin
            while (exp_tx_credit_cnt > 0) begin
                send_tx_flit();
                model_tx_consume();
            end

            while (exp_rx_credit_cnt > 0) begin
                send_rx_flit();
                model_rx_consume();
            end

            repeat (2) @(posedge cxs_clk);
            print_expected_state("consume_to_zero");
            check_observed_state("consume_to_zero");
        end
    endtask

    task automatic scenario_return_to_max;
        begin
            while (exp_tx_credit_cnt < cfg_credit_max) begin
                return_tx_credit();
                model_tx_return();
            end

            while (exp_rx_credit_cnt < cfg_credit_max) begin
                return_rx_credit();
                model_rx_return();
            end

            repeat (2) @(posedge cxs_clk);
            print_expected_state("return_to_max");
            check_observed_state("return_to_max");
        end
    endtask

    task automatic scenario_same_cycle_consume_return;
        begin
            @(posedge cxs_clk);
            tx_data_valid <= 1'b1;
            cxs_tx_crdret <= 1'b1;
            rx_data_valid <= 1'b1;
            cxs_rx_crdret <= 1'b1;
            @(posedge cxs_clk);
            tx_data_valid <= 1'b0;
            cxs_tx_crdret <= 1'b0;
            rx_data_valid <= 1'b0;
            cxs_rx_crdret <= 1'b0;

            // Net change is zero on both sides.
            repeat (2) @(posedge cxs_clk);
            print_expected_state("same_cycle_consume_return");
            check_observed_state("same_cycle_consume_return");
        end
    endtask

    initial begin
        error_count = 0;
        @(posedge cxs_rst_n);

        model_reset();

        // NOTE:
        // The directed sequence and checking model are ready.
        // Once the DUT is connected, the check_observed_state() task
        // will report mismatches automatically.
        scenario_reset_init();
        scenario_consume_to_zero();
        scenario_return_to_max();
        scenario_same_cycle_consume_return();

        repeat (10) @(posedge cxs_clk);
        $display("credit_mgr_tb completed with error_count=%0d", error_count);
        $finish;
    end

endmodule: credit_mgr_tb
