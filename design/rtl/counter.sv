/***********************************************************************
 * Copyright 2024
 * Simple Counter Module
 **********************************************************************/

/*
 * Module: counter
 *
 * 可配置的递增计数器模块
 * 支持同步复位和使能控制
 */

module counter #(
    parameter int WIDTH = 8,
    parameter int MAX_VAL = 255
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic             enable,
    output logic [WIDTH-1:0] count,
    output logic             overflow
);

    // =========================================
    // 信号定义
    // =========================================
    logic [WIDTH-1:0]       count_next;

    // =========================================
    // 组合逻辑: 计算下一个计数值
    // =========================================
    always_comb begin
        if (!rst_n) begin
            count_next = '0;
        end
        else if (enable) begin
            if (count >= MAX_VAL[WIDTH-1:0]) begin
                count_next = '0;
            end
            else begin
                count_next = count + 1'b1;
            end
        end
        else begin
            count_next = count;
        end
    end

    // =========================================
    // 时序逻辑: 更新计数值
    // =========================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= '0;
        end
        else begin
            count <= count_next;
        end
    end

    // =========================================
    // 输出: 溢出标志
    // =========================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            overflow <= 1'b0;
        end
        else begin
            overflow <= (count >= MAX_VAL[WIDTH-1:0]) && enable;
        end
    end

endmodule: counter
