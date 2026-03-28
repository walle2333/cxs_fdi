/***********************************************************************
 * Copyright 2026
 **********************************************************************/

/*
 * Module: regs_tb
 *
 * Skeleton testbench for regs.
 * This file provides an APB-oriented verification scaffold to be
 * completed after the CSR RTL is implemented.
 */

`timescale 1ns/1ps

module regs_tb;

    localparam time PCLK_PERIOD = 10ns;
    localparam logic [15:0] REG_CTRL       = 16'h0000;
    localparam logic [15:0] REG_STATUS     = 16'h0004;
    localparam logic [15:0] REG_CONFIG     = 16'h0008;
    localparam logic [15:0] REG_INT_EN     = 16'h000C;
    localparam logic [15:0] REG_INT_STATUS = 16'h0010;
    localparam logic [15:0] REG_ERR_STATUS = 16'h0014;
    localparam logic [15:0] REG_LINK_CTRL  = 16'h0018;
    localparam logic [15:0] REG_VERSION    = 16'h0030;

    logic        pclk;
    logic        preset_n;
    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [15:0] paddr;
    logic [31:0] pwdata;
    logic [31:0] prdata;
    logic        pready;
    logic        pslverr;

    logic [2:0]  status_link_state;
    logic        status_busy;
    logic        status_tx_ready;
    logic        status_rx_ready;
    logic        status_init_done;
    logic [6:0]  err_status_in;
    logic        evt_link_up;
    logic        evt_link_down;
    logic        evt_fifo_almost_full;
    logic        stat_tx_flit_pulse;
    logic        stat_rx_flit_pulse;
    logic        irq;
    logic        cfg_enable;
    logic [7:0]  cfg_mode;
    logic [3:0]  cfg_flit_width_sel;
    logic        sw_reset_pulse;
    logic [7:0]  cfg_max_credit;
    logic [7:0]  cfg_fifo_depth;
    logic [7:0]  cfg_timeout;
    logic [6:0]  cfg_retry_cnt;
    logic [31:0] link_ctrl_reg;
    logic [31:0] exp_prdata;
    logic        exp_irq;
    logic [31:0] exp_link_ctrl_reg;
    logic [31:0] exp_ctrl_reg;
    logic [31:0] exp_config_reg;
    logic [31:0] exp_int_status_reg;
    logic [31:0] exp_err_status_reg;
    logic [7:0]  exp_cfg_mode;
    logic [3:0]  exp_cfg_flit_width_sel;
    logic        exp_cfg_enable;
    int          error_count;

    initial begin
        pclk = 1'b0;
        forever #(PCLK_PERIOD / 2) pclk = ~pclk;
    end

    initial begin
        preset_n              = 1'b0;
        psel                  = 1'b0;
        penable               = 1'b0;
        pwrite                = 1'b0;
        paddr                 = '0;
        pwdata                = '0;
        status_link_state     = '0;
        status_busy           = 1'b0;
        status_tx_ready       = 1'b0;
        status_rx_ready       = 1'b0;
        status_init_done      = 1'b0;
        err_status_in         = '0;
        evt_link_up           = 1'b0;
        evt_link_down         = 1'b0;
        evt_fifo_almost_full  = 1'b0;
        stat_tx_flit_pulse    = 1'b0;
        stat_rx_flit_pulse    = 1'b0;

        repeat (4) @(posedge pclk);
        preset_n = 1'b1;
    end

    initial begin
        $dumpfile("regs_tb.fst");
        $dumpvars(0, regs_tb);
    end

    regs dut (
        .pclk                (pclk),
        .preset_n            (preset_n),
        .psel                (psel),
        .penable             (penable),
        .pwrite              (pwrite),
        .paddr               (paddr),
        .pwdata              (pwdata),
        .prdata              (prdata),
        .pready              (pready),
        .pslverr             (pslverr),
        .status_link_state   (status_link_state),
        .status_busy         (status_busy),
        .status_tx_ready     (status_tx_ready),
        .status_rx_ready     (status_rx_ready),
        .status_init_done    (status_init_done),
        .err_status_in       (err_status_in),
        .evt_link_up         (evt_link_up),
        .evt_link_down       (evt_link_down),
        .evt_fifo_almost_full(evt_fifo_almost_full),
        .stat_tx_flit_pulse  (stat_tx_flit_pulse),
        .stat_rx_flit_pulse  (stat_rx_flit_pulse),
        .irq                 (irq),
        .cfg_enable          (cfg_enable),
        .cfg_mode            (cfg_mode),
        .cfg_flit_width_sel  (cfg_flit_width_sel),
        .sw_reset_pulse      (sw_reset_pulse),
        .cfg_max_credit      (cfg_max_credit),
        .cfg_fifo_depth      (cfg_fifo_depth),
        .cfg_timeout         (cfg_timeout),
        .cfg_retry_cnt       (cfg_retry_cnt),
        .link_ctrl_reg       (link_ctrl_reg)
    );

    task automatic apb_write(input logic [15:0] addr, input logic [31:0] data);
        begin
            @(posedge pclk);
            psel   <= 1'b1;
            pwrite <= 1'b1;
            paddr  <= addr;
            pwdata <= data;
            @(posedge pclk);
            penable <= 1'b1;
            @(posedge pclk);
            psel    <= 1'b0;
            penable <= 1'b0;
            pwrite  <= 1'b0;
            paddr   <= '0;
            pwdata  <= '0;
        end
    endtask

    task automatic apb_read(input logic [15:0] addr, output logic [31:0] data);
        begin
            @(posedge pclk);
            psel   <= 1'b1;
            pwrite <= 1'b0;
            paddr  <= addr;
            @(posedge pclk);
            penable <= 1'b1;
            #1 data = prdata;
            @(posedge pclk);
            psel    <= 1'b0;
            penable <= 1'b0;
            paddr   <= '0;
        end
    endtask

    task automatic model_reset;
        begin
            exp_prdata              = '0;
            exp_irq                 = 1'b0;
            exp_link_ctrl_reg       = '0;
            exp_ctrl_reg            = 32'h0000_0010;
            exp_config_reg          = 32'h2040_FF07;
            exp_int_status_reg      = 32'h0000_0000;
            exp_err_status_reg      = 32'h0000_0000;
            exp_cfg_enable          = 1'b0;
            exp_cfg_mode            = 8'h00;
            exp_cfg_flit_width_sel  = 4'h1;
        end
    endtask

    task automatic check_eq32(
        input string tag,
        input logic [31:0] got,
        input logic [31:0] exp
    );
        begin
            if (got !== exp) begin
                error_count++;
                $display("ERROR[%0t] %s mismatch exp=0x%08h got=0x%08h",
                         $time, tag, exp, got);
            end
        end
    endtask

    task automatic check_eq1(
        input string tag,
        input logic got,
        input logic exp
    );
        begin
            if (got !== exp) begin
                error_count++;
                $display("ERROR[%0t] %s mismatch exp=%0b got=%0b",
                         $time, tag, exp, got);
            end
        end
    endtask

    task automatic scenario_reset_defaults;
        logic [31:0] rdata;
        begin
            model_reset();
            repeat (2) @(posedge pclk);
            apb_read(REG_VERSION, rdata);
            check_eq32("version", rdata, 32'h0001_0000);
            apb_read(REG_CTRL, rdata);
            check_eq32("ctrl_default", rdata, 32'h0000_0010);
            apb_read(REG_CONFIG, rdata);
            check_eq32("config_default", rdata, 32'h2040_FF07);
            apb_read(REG_LINK_CTRL, rdata);
            check_eq32("link_ctrl_default", rdata, 32'h0000_0700);
            check_eq1("cfg_enable_reset", cfg_enable, 1'b0);
            check_eq32("cfg_mode_reset", {24'h0, cfg_mode}, 32'h0000_0000);
            check_eq32("cfg_flit_width_reset", {28'h0, cfg_flit_width_sel},
                       32'h0000_0001);
            check_eq32("cfg_max_credit_reset", {24'h0, cfg_max_credit},
                       32'h0000_0020);
            check_eq32("cfg_fifo_depth_reset", {24'h0, cfg_fifo_depth},
                       32'h0000_0040);
            check_eq32("cfg_timeout_reset", {24'h0, cfg_timeout},
                       32'h0000_00FF);
            check_eq32("cfg_retry_cnt_reset", {25'h0, cfg_retry_cnt},
                       32'h0000_0003);
            check_eq1("sw_reset_pulse_reset", sw_reset_pulse, 1'b0);
        end
    endtask

    task automatic scenario_ctrl_write;
        logic [31:0] rdata;
        logic [31:0] ctrl_data;
        begin
            ctrl_data = 32'h8002_0011;
            exp_cfg_mode           = ctrl_data[23:16];
            exp_cfg_flit_width_sel = ctrl_data[7:4];
            exp_cfg_enable         = ctrl_data[31];

            apb_write(REG_CTRL, ctrl_data);
            apb_read(REG_CTRL, rdata);
            check_eq32("ctrl_write_readback", rdata, 32'h8002_0010);
            repeat (2) @(posedge pclk);
            check_eq1("cfg_enable_write", cfg_enable, 1'b1);
            check_eq32("cfg_mode_write", {24'h0, cfg_mode}, 32'h0000_0002);
            check_eq32("cfg_flit_width_write",
                       {28'h0, cfg_flit_width_sel}, 32'h0000_0001);
        end
    endtask

    task automatic scenario_link_ctrl_write;
        logic [31:0] rdata;
        logic [31:0] link_ctrl_data;
        begin
            link_ctrl_data   = 32'h0000_0707;
            exp_link_ctrl_reg = link_ctrl_data;

            apb_write(REG_LINK_CTRL, link_ctrl_data);
            apb_read(REG_LINK_CTRL, rdata);
            check_eq32("link_ctrl_write_readback", rdata, link_ctrl_data);
            repeat (2) @(posedge pclk);
            check_eq32("link_ctrl_mirror", link_ctrl_reg, link_ctrl_data);
        end
    endtask

    task automatic scenario_status_and_irq;
        logic [31:0] rdata;
        begin
            status_link_state = 3'd3;
            status_busy = 1'b1;
            status_tx_ready = 1'b1;
            status_rx_ready = 1'b0;
            status_init_done = 1'b1;

            apb_read(REG_STATUS, rdata);
            check_eq32("status_readback", rdata, 32'h0000_030D);

            apb_write(REG_INT_EN, 32'h0000_0070);

            @(posedge pclk);
            evt_link_up <= 1'b1;
            @(posedge pclk);
            evt_link_up <= 1'b0;

            repeat (2) @(posedge pclk);
            apb_read(REG_INT_STATUS, rdata);
            check_eq32("int_status_link_up", rdata, 32'h0000_0040);
            check_eq1("irq_link_up", irq, 1'b1);

            apb_write(REG_INT_STATUS, 32'h0000_0040);
            repeat (2) @(posedge pclk);
            check_eq1("irq_link_up_cleared", irq, 1'b0);
        end
    endtask

    task automatic scenario_err_w1c;
        logic [31:0] rdata;
        begin
            apb_write(REG_INT_EN, 32'h0000_0080);

            @(posedge pclk);
            err_status_in[0] <= 1'b1;
            @(posedge pclk);
            err_status_in[0] <= 1'b0;

            repeat (2) @(posedge pclk);
            apb_read(REG_ERR_STATUS, rdata);
            check_eq32("err_status_latched", rdata, 32'h0000_0001);
            check_eq1("irq_error", irq, 1'b1);

            apb_write(REG_INT_STATUS, 32'h0000_0080);
            apb_write(REG_ERR_STATUS, 32'h0000_0001);
            repeat (2) @(posedge pclk);
            apb_read(REG_ERR_STATUS, rdata);
            check_eq32("err_status_cleared", rdata, 32'h0000_0000);
            check_eq1("irq_error_cleared", irq, 1'b0);
        end
    endtask

    initial begin
        error_count = 0;
        @(posedge preset_n);

        model_reset();

        // NOTE:
        // The directed scenarios and reference expectations are ready.
        // Once the DUT is connected, these scenarios can be used as the
        // first runnable APB/CSR smoke tests.
        scenario_reset_defaults();
        scenario_ctrl_write();
        scenario_link_ctrl_write();
        scenario_status_and_irq();
        scenario_err_w1c();

        repeat (10) @(posedge pclk);
        $display("regs_tb completed with error_count=%0d", error_count);
        $finish;
    end

endmodule: regs_tb
