//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/13/2026 06:18:12 PM
// Design Name: 
// Module Name: pulse_sync
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


module pulse_sync (
    input  logic src_clk,
    input  logic dst_clk,
    input  logic rst_n,
    input  logic pulse_in,
    output logic pulse_out
);
    logic src_flag;
    always_ff @(posedge src_clk or negedge rst_n) begin
        if (!rst_n) src_flag <= 1'b0;
        else if (pulse_in) src_flag <= ~src_flag;
    end

    logic [2:0] dst_sync;
    always_ff @(posedge dst_clk or negedge rst_n) begin
        if (!rst_n) dst_sync <= '0;
        else dst_sync <= {dst_sync[1:0], src_flag};
    end

    logic dst_flag_prev;
    always_ff @(posedge dst_clk or negedge rst_n) begin
        if (!rst_n) dst_flag_prev <= 1'b0;
        else dst_flag_prev <= dst_sync[2];
    end

    assign pulse_out = dst_sync[2] ^ dst_flag_prev;
endmodule