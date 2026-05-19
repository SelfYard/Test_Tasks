//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/12/2026 08:00:53 PM
// Design Name: Synchronous FIFO
// Module Name: fifo
// Project Name: yadro_test_dsp
// Target Devices: RAMB36E2 compatible
// Tool Versions: 
// Description: Synchronous FIFO based on RAMB36E2
// Dependencies:
// Additional Comments:
// 
// Alternative FIFO implementations:
// 1 Memory:
// 1.1 register-file
// 1.2 SRAM
// 1.3 DRAM
// 2 Microarhitecture
// 2.1 Parity-bit pointers
// 2.2 VALID-READY
// 2.3 Show-ahead
// 2.4 Others
//  
//////////////////////////////////////////////////////////////////////////////////

module fifo #(
    parameter int DATA_WIDTH = 32,
    parameter int DEPTH = 512,
    parameter int ALMOST_EMPTY_N = 4,
    parameter int ALMOST_FULL_N  = 4
) (
    input logic clk,
    input logic rst_n,
    input logic wr_en,
    input logic rd_en,
    input [DATA_WIDTH-1:0] din,
    output [DATA_WIDTH-1:0] dout,
    output logic full,
    output logic almost_full,
    output logic empty,
    output logic almost_empty
);
    localparam ADDR_WIDTH = $clog2(DEPTH);
    localparam CNT_WIDTH  = $clog2(DEPTH+1);
    
    (*ram_style = "block"*)    
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    
    reg [DATA_WIDTH-1:0] dout_reg;
    
    logic [ADDR_WIDTH-1:0] wr_ptr, rd_ptr;
    logic [CNT_WIDTH-1:0]  cnt;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            cnt <= 0;
        end else begin
            case ({wr_en, rd_en})
                2'b10: begin
                    if (!full) begin
                        wr_ptr <= wr_ptr + 1'b1;
                        cnt <= cnt + 1'b1;
                    end
                end
                2'b01: begin
                    if (!empty) begin
                        rd_ptr <= rd_ptr + 1'b1;
                        cnt <= cnt - 1'b1;
                    end
                end
                2'b11: begin
                    if (!full & !empty) begin
                        wr_ptr <= wr_ptr + 1'b1;
                        rd_ptr <= rd_ptr + 1'b1;
                    end
                end
                default;
            endcase
        end
    end
    
    always_ff @(posedge clk) begin
        if (wr_en && !full)
            mem[wr_ptr] <= din;
    end
    
    always_ff @(posedge clk) begin
        if (rd_en && !empty)
            dout_reg <= mem[rd_ptr];
    end
    
    assign dout = dout_reg;
    assign full = (cnt == DEPTH);
    assign empty = (cnt == 0);
    assign almost_full = (cnt >= DEPTH - ALMOST_FULL_N);
    assign almost_empty = (cnt <= ALMOST_EMPTY_N);
endmodule
