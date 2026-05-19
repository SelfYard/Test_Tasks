//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/13/2026 06:17:26 PM
// Design Name: 
// Module Name: axi_stream_mux
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// Dependencies: 
// Additional Comments:
//////////////////////////////////////////////////////////////////////////////////

module axi_stream_mux_n_1 #(
    parameter DATA_WIDTH = 8,
    parameter N_IN = 2
) (
    input logic clk,
    input logic rst_n,

    input logic [($clog2(N_IN))-1:0]   sel_i,

    input logic [N_IN-1:0] [DATA_WIDTH-1:0] sig_tdata,
    input logic [N_IN-1:0] sig_tvalid,
    output logic [N_IN-1:0] sig_tready,
    input logic [N_IN-1:0] sig_tlast,

    output logic [DATA_WIDTH-1:0] mux_tdata,
    output logic mux_tvalid,
    input logic mux_tready,
    output logic mux_tlast
);
/*
    // switch from sel_i to sel_reg to avoid async logic glitches
    logic [$clog2(N_IN)-1:0] sel_reg;

    always_ff @(posedge clk or negedge rst_n)
        if (!rst_n)
            sel_reg <= '0;
        else
            sel_reg <= sel_i;
*/
    assign mux_tdata = sig_tdata[sel_i];
    assign mux_tvalid = sig_tvalid[sel_i];
    assign mux_tlast = sig_tlast[sel_i];

    always_comb begin
        for (int i = 0; i < N_IN; i++) begin
            if (i == sel_i)
                sig_tready[i] = mux_tready;
            else
                sig_tready[i] = 1'b0;
        end
    end

endmodule