`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/15/2026 11:02:01 AM
// Design Name: 
// Module Name: cdc_bench
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

module cdc_bench;

    parameter DATA_WIDTH = 16;
    parameter CLK_A_PERIOD = 10;
    parameter CLK_B_PERIOD = 17.5;

    logic clk_a, clk_b;
    logic rst_n;

    logic pulse_in, pulse_out;
    logic [7:0] pulse_count_in, pulse_count_out;

    logic [DATA_WIDTH-1:0] src_data;
    logic src_valid;
    logic [DATA_WIDTH-1:0] dst_data;
    logic dst_valid;
    logic [DATA_WIDTH-1:0] expected_data [$];
    int error_cnt = 0;
    int test_done = 0;
    
    pulse_sync u_pulse_sync (
        .src_clk   (clk_a),
        .dst_clk   (clk_b),
        .rst_n     (rst_n),
        .pulse_in  (pulse_in),
        .pulse_out (pulse_out)
    );

    bus_sync #(.DATA_WIDTH(DATA_WIDTH)) u_bus_sync (
        .src_clk   (clk_a),
        .dst_clk   (clk_b),
        .rst_n     (rst_n),
        .src_data  (src_data),
        .src_valid (src_valid),
        .dst_data  (dst_data),
        .dst_valid (dst_valid)
    );

    initial clk_a = 0;
    always #(CLK_A_PERIOD/2) clk_a = ~clk_a;

    initial clk_b = 0;
    always #(CLK_B_PERIOD/2) clk_b = ~clk_b;

    initial begin
        rst_n = 0;
        #100 rst_n = 1;
    end

    task automatic test_pulse_sync;
        $display("[%0t] Starting pulse_sync test...", $time);
        pulse_count_in = 0;
        pulse_count_out = 0;
        pulse_in = 0;

        repeat (20) begin
            @(posedge clk_a);
            pulse_in <= 1'b1;
            pulse_count_in++;
            @(posedge clk_a);
            pulse_in <= 1'b0;
            repeat ($urandom_range(5,25)) @(posedge clk_a);
        end

        repeat (50) @(posedge clk_b);

        if (pulse_count_out == pulse_count_in)
            $display("[%0t] pulse_sync PASSED: in=%0d, out=%0d", $time, pulse_count_in, pulse_count_out);
        else begin
            $display("[%0t] pulse_sync FAILED: in=%0d, out=%0d", $time, pulse_count_in, pulse_count_out);
            error_cnt++;
        end
    endtask

    always_ff @(posedge clk_b or negedge rst_n) begin
        if (!rst_n) pulse_count_out <= 0;
        else if (pulse_out) pulse_count_out <= pulse_count_out + 1;
    end

    task automatic test_bus_sync;
        $display("[%0t] Starting bus_sync test...", $time);
        src_valid = 0;
        expected_data.delete();

        repeat (50) begin
            src_data = $urandom();
            src_valid <= 1'b1;
            expected_data.push_back(src_data);
            @(posedge clk_a);
            src_valid <= 1'b0;
            repeat ($urandom_range(10,50)) @(posedge clk_a);
        end

        repeat (200) @(posedge clk_b);

        if (expected_data.size() == 0)
            $display("[%0t] bus_sync PASSED", $time);
        else begin
            $display("[%0t] bus_sync FAILED: %0d words not received", $time, expected_data.size());
            error_cnt++;
        end
    endtask

    always_ff @(posedge clk_b) begin
        if (dst_valid) begin
            if (expected_data.size() > 0) begin
                automatic logic [DATA_WIDTH-1:0] exp = expected_data.pop_front();
                if (dst_data !== exp) begin
                    $display("[%0t] bus_sync DATA ERROR: expected 0x%0h, got 0x%0h",
                             $time, exp, dst_data);
                    error_cnt++;
                end
            end else begin
                $display("[%0t] bus_sync UNEXPECTED VALID", $time);
                error_cnt++;
            end
        end
    end

    initial begin
        @(posedge rst_n);
        #100;

        test_pulse_sync();

        test_bus_sync();

        #1000;
        if (error_cnt == 0)
            $display("\n========== ALL TESTS PASSED ==========");
        else
            $display("\n========== %0d TEST(S) FAILED ==========", error_cnt);

        test_done = 1;
        $finish;
    end
endmodule