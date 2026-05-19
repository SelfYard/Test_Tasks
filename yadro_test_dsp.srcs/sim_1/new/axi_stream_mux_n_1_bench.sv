//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/15/2026 05:28:34 AM
// Design Name: 
// Module Name: axi_stream_mux_n_1_bench
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
module axi_stream_mux_n_1_bench;

    // ----------------------------------
    // Testbench parameters
    // ----------------------------------
    localparam DATA_WIDTH = 8;
    localparam N_IN       = 4;          // число входов (N_IN >= 2)
    localparam SEL_WIDTH  = $clog2(N_IN);

    // ----------------------------------
    // DUT signals
    // ----------------------------------
    logic                              clk;
    logic                              rst_n;
    logic [SEL_WIDTH-1:0]              sel_i;
    logic [N_IN-1:0][DATA_WIDTH-1:0]   sig_tdata;
    logic [N_IN-1:0]                   sig_tvalid;
    logic [N_IN-1:0]                   sig_tready;
    logic [N_IN-1:0]                   sig_tlast;
    logic [DATA_WIDTH-1:0]             mux_tdata;
    logic                              mux_tvalid;
    logic                              mux_tready;
    logic                              mux_tlast;

    axi_stream_mux_n_1 #(
        .DATA_WIDTH(DATA_WIDTH),
        .N_IN      (N_IN)
    ) dut (.*);

    initial clk = 0;
    always #5 clk = ~clk;

    int error_count = 0;

    always_ff @(posedge clk) begin
        if (rst_n) begin
            // проверка выходных данных
            if (mux_tdata !== sig_tdata[sel_i]) begin
                $error("[%0t] tdata mismatch: mux=0x%0h, expected=0x%0h (sel=%0d)",
                       $time, mux_tdata, sig_tdata[sel_i], sel_i);
                error_count <= error_count + 1;
            end

            // проверка валидности
            if (mux_tvalid !== sig_tvalid[sel_i]) begin
                $error("[%0t] tvalid mismatch: mux=%b, expected=%b (sel=%0d)",
                       $time, mux_tvalid, sig_tvalid[sel_i], sel_i);
                error_count <= error_count + 1;
            end

            // проверка tlast
            if (mux_tlast !== sig_tlast[sel_i]) begin
                $error("[%0t] tlast mismatch: mux=%b, expected=%b (sel=%0d)",
                       $time, mux_tlast, sig_tlast[sel_i], sel_i);
                error_count <= error_count + 1;
            end

            // проверка сигналов готовности tready
            for (int i = 0; i < N_IN; i++) begin
                if (i == sel_i) begin
                    if (sig_tready[i] !== mux_tready) begin
                        $error("[%0t] tready mismatch for selected input %0d: got %b, expected %b",
                               $time, i, sig_tready[i], mux_tready);
                        error_count <= error_count + 1;
                    end
                end else begin
                    if (sig_tready[i] !== 1'b0) begin
                        $error("[%0t] tready mismatch for unselected input %0d: got %b, expected 0",
                               $time, i, sig_tready[i]);
                        error_count <= error_count + 1;
                    end
                end
            end
        end
    end

    initial begin
        clk        = 0;
        rst_n      = 0;
        sel_i      = 0;
        sig_tdata  = '0;
        sig_tvalid = '0;
        sig_tlast  = '0;
        mux_tready = 0;

        repeat (5) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // --------------------------------------------------
        // Test 1: Basic connectivity
        // --------------------------------------------------
        $display("========== Test 1: Basic connectivity (sel=0) ==========");
        sel_i = 0;
        // устанавливаем данные на входах
        sig_tdata[0]  = 8'hA5;
        sig_tvalid[0] = 1;
        sig_tlast[0]  = 0;
        for (int i = 1; i < N_IN; i++) begin
            sig_tdata[i]  = 8'h11 * i;
            sig_tvalid[i] = 1;
            sig_tlast[i]  = 1;
        end
        mux_tready = 1;
        @(posedge clk);
        // снимаем валидность с выбранного входа
        sig_tvalid[0] = 0;
        @(posedge clk);

        // --------------------------------------------------
        // Test 2: Backpressure (mux_tready)
        // --------------------------------------------------
        $display("========== Test 2: Backpressure (sel=1) ==========");
        sel_i = 1;
        sig_tdata[1]  = 8'hC3;
        sig_tvalid[1] = 1;
        sig_tlast[1]  = 0;
        mux_tready = 0;   // выход не готов
        @(posedge clk);
        // tready выбранного входа должно быть 0
        mux_tready = 1;   // теперь готов
        @(posedge clk);
        // tready выбранного входа должно стать 1

        // --------------------------------------------------
        // Test 3: Dynamic selection change
        // --------------------------------------------------
        $display("========== Test 3: Dynamic selection change ==========");
        sel_i = 2;
        sig_tdata[2]  = 8'h5A;
        sig_tvalid[2] = 1;
        sig_tlast[2]  = 0;
        mux_tready = 1;
        @(posedge clk);
        sel_i = 3;
        sig_tdata[3]  = 8'h77;
        sig_tvalid[3] = 1;
        @(posedge clk);

        // --------------------------------------------------
        // Test 4: Random stimulus (200 cycles)
        // --------------------------------------------------
        $display("========== Test 4: Random test (200 cycles) ==========");
        repeat (200) begin
            sel_i = $urandom_range(N_IN-1, 0);
            for (int i = 0; i < N_IN; i++) begin
                sig_tdata[i]  = $urandom_range(0, 255);
                sig_tvalid[i] = $urandom_range(0, 1);
                sig_tlast[i]  = $urandom_range(0, 1);
            end
            mux_tready = $urandom_range(0, 1);
            @(posedge clk);
        end

        // --------------------------------------------------
        // Test 5: TLAST propagation
        // --------------------------------------------------
        $display("========== Test 5: TLAST propagation ==========");
        sel_i = 0;
        sig_tvalid[0] = 1;
        sig_tlast[0]  = 1;
        sig_tdata[0]  = 8'hFF;
        mux_tready = 1;
        @(posedge clk);

        // --------------------------------------------------
        // Завершение
        // --------------------------------------------------
        repeat (5) @(posedge clk);
        if (error_count == 0) begin
            $display("========== ALL TESTS PASSED ==========");
        end else begin
            $display("========== TEST FAILED with %0d errors ==========", error_count);
        end
        $finish;
    end

endmodule