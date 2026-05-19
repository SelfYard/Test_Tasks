`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/15/2026 10:51:55 AM
// Design Name: 
// Module Name: bus_sync
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module bus_sync #(
    parameter DATA_WIDTH = 32
) (
    input  logic                     src_clk,
    input  logic                     dst_clk,
    input  logic                     rst_n,
    input  logic [DATA_WIDTH-1:0]    src_data,
    input  logic                     src_valid,
    output logic [DATA_WIDTH-1:0]    dst_data,
    output logic                     dst_valid
);
    logic src_flag;
    logic [DATA_WIDTH-1:0] src_data_latched;

    always_ff @(posedge src_clk or negedge rst_n) begin
        if (!rst_n) begin
            src_flag <= 1'b0;
            src_data_latched <= '0;
        end else if (src_valid) begin
            src_flag <= ~src_flag;          // flag switch
            src_data_latched <= src_data;   // grab data
        end
    end

    logic [2:0] dst_flag_sync;
    always_ff @(posedge dst_clk or negedge rst_n) begin
        if (!rst_n) dst_flag_sync <= '0;
        else dst_flag_sync <= {dst_flag_sync[1:0], src_flag};
    end

    logic dst_flag_prev;
    always_ff @(posedge dst_clk or negedge rst_n) begin
        if (!rst_n) dst_flag_prev <= 1'b0;
        else dst_flag_prev <= dst_flag_sync[2];
    end
    wire flag_toggle = dst_flag_sync[2] ^ dst_flag_prev;

    // ---- Out data reg, puls ready ----
    always_ff @(posedge dst_clk or negedge rst_n) begin
        if (!rst_n) begin
            dst_data <= '0;
            dst_valid <= 1'b0;
        end else begin
            dst_valid <= flag_toggle;
            if (flag_toggle) begin
                dst_data <= src_data_latched;
            end
        end
    end
endmodule
