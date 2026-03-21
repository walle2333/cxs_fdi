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
    logic [31:0] exp_prdata;
    logic        exp_irq;
    logic [31:0] exp_link_ctrl_reg;
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

    // DUT hookup template:
    // regs dut (
    //     .pclk               (pclk),
    //     .preset_n           (preset_n),
    //     .psel               (psel),
    //     .penable            (penable),
    //     .pwrite             (pwrite),
    //     .paddr              (paddr),
    //     .pwdata             (pwdata),
    //     .prdata             (prdata),
    //     .pready             (pready),
    //     .pslverr            (pslverr),
    //     .status_link_state  (status_link_state),
    //     .status_busy        (status_busy),
    //     .status_tx_ready    (status_tx_ready),
    //     .status_rx_ready    (status_rx_ready),
    //     .status_init_done   (status_init_done),
    //     .err_status_in      (err_status_in),
    //     .evt_link_up        (evt_link_up),
    //     .evt_link_down      (evt_link_down),
    //     .evt_fifo_almost_full(evt_fifo_almost_full),
    //     .stat_tx_flit_pulse (stat_tx_flit_pulse),
    //     .stat_rx_flit_pulse (stat_rx_flit_pulse),
    //     .irq                (irq)
    // );

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

    task automatic apb_read(input logic [15:0] addr);
        begin
            @(posedge pclk);
            psel   <= 1'b1;
            pwrite <= 1'b0;
            paddr  <= addr;
            @(posedge pclk);
            penable <= 1'b1;
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
            exp_cfg_enable          = 1'b0;
            exp_cfg_mode            = 8'h00;
            exp_cfg_flit_width_sel  = 4'h1;
        end
    endtask

    task automatic check_basic_outputs(input string tag);
        begin
            // These checks become active once the DUT is connected.
            if (irq !== exp_irq) begin
                error_count++;
                $display("ERROR[%0t] %s irq mismatch exp=%0b got=%0b",
                         $time, tag, exp_irq, irq);
            end
        end
    endtask

    task automatic scenario_reset_defaults;
        begin
            model_reset();
            repeat (2) @(posedge pclk);
            $display("[%0t] reset_defaults exp_enable=%0b exp_flit_width=%0h",
                     $time, exp_cfg_enable, exp_cfg_flit_width_sel);
            check_basic_outputs("reset_defaults");
        end
    endtask

    task automatic scenario_ctrl_write;
        logic [31:0] ctrl_data;
        begin
            ctrl_data = 32'h0002_0011;
            exp_cfg_mode           = ctrl_data[23:16];
            exp_cfg_flit_width_sel = ctrl_data[7:4];
            exp_cfg_enable         = ctrl_data[0];

            apb_write(REG_CTRL, ctrl_data);
            apb_read(REG_CTRL);
            repeat (2) @(posedge pclk);
            $display("[%0t] ctrl_write exp_enable=%0b exp_mode=0x%0h exp_flit_width=%0h",
                     $time, exp_cfg_enable, exp_cfg_mode, exp_cfg_flit_width_sel);
            check_basic_outputs("ctrl_write");
        end
    endtask

    task automatic scenario_link_ctrl_write;
        logic [31:0] link_ctrl_data;
        begin
            link_ctrl_data   = 32'h0000_0707;
            exp_link_ctrl_reg = link_ctrl_data;

            apb_write(REG_LINK_CTRL, link_ctrl_data);
            apb_read(REG_LINK_CTRL);
            repeat (2) @(posedge pclk);
            $display("[%0t] link_ctrl_write exp_link_ctrl=0x%08h",
                     $time, exp_link_ctrl_reg);
            check_basic_outputs("link_ctrl_write");
        end
    endtask

    task automatic scenario_event_irq;
        begin
            apb_write(REG_INT_EN, 32'h0000_0007);

            @(posedge pclk);
            evt_link_up <= 1'b1;
            @(posedge pclk);
            evt_link_up <= 1'b0;

            exp_irq = 1'b1;
            repeat (2) @(posedge pclk);
            $display("[%0t] event_irq expected irq asserted", $time);
            check_basic_outputs("event_irq");
        end
    endtask

    task automatic scenario_err_w1c;
        begin
            @(posedge pclk);
            err_status_in[0] <= 1'b1;
            @(posedge pclk);
            err_status_in[0] <= 1'b0;

            exp_irq = 1'b1;
            repeat (2) @(posedge pclk);
            apb_write(REG_ERR_STATUS, 32'h0000_0001);
            repeat (2) @(posedge pclk);
            $display("[%0t] err_w1c exercised", $time);
            check_basic_outputs("err_w1c");
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
        scenario_event_irq();
        scenario_err_w1c();

        repeat (10) @(posedge pclk);
        $display("regs_tb completed with error_count=%0d", error_count);
        $finish;
    end

endmodule: regs_tb
