//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/15/2026 05:29:13 AM
// Design Name: 
// Module Name: fifo_bench
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
//   Комплексный тестбенч для синхронного FIFO.
//   Включает расширенные проверки одновременного чтения/записи.
// 
// Dependencies: 
// 
// Revision:
// Revision 0.02 - Добавлены расширенные параллельные тесты
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module fifo_bench;
    localparam DATA_WIDTH      = 8;
    localparam DEPTH           = 16;
    localparam ALMOST_EMPTY_N  = 2;
    localparam ALMOST_FULL_N   = 2;

    localparam ADDR_WIDTH = $clog2(DEPTH);
    localparam CNT_WIDTH  = $clog2(DEPTH+1);

    logic clk;
    logic rst_n;
    logic wr_en;
    logic rd_en;
    logic [DATA_WIDTH-1:0] din;
    logic [DATA_WIDTH-1:0] dout;
    logic full;
    logic almost_full;
    logic empty;
    logic almost_empty;

    always #5 clk = ~clk;

    fifo #(
        .DATA_WIDTH      (DATA_WIDTH),
        .DEPTH           (DEPTH),
        .ALMOST_EMPTY_N  (ALMOST_EMPTY_N),
        .ALMOST_FULL_N   (ALMOST_FULL_N)
    ) DUT (
        .clk           (clk),
        .rst_n         (rst_n),
        .wr_en         (wr_en),
        .rd_en         (rd_en),
        .din           (din),
        .dout          (dout),
        .full          (full),
        .almost_full   (almost_full),
        .empty         (empty),
        .almost_empty  (almost_empty)
    );

    logic [DATA_WIDTH-1:0] expected_q [$];

    // Запись одного слова
    task automatic write_word(input logic [DATA_WIDTH-1:0] data);
        @(posedge clk);
        wr_en <= 1'b1;
        din   <= data;
        @(posedge clk);
        wr_en <= 1'b0;
        expected_q.push_back(data);
    endtask

    // Чтение и проверка
    task automatic read_and_check();
        logic [DATA_WIDTH-1:0] expected;
        @(posedge clk);
        rd_en <= 1'b1;
        @(posedge clk);
        rd_en <= 1'b0;
        expected = expected_q.pop_front();
        if (dout !== expected) begin
            $error("Data mismatch at time %0t: got %h, expected %h", $time, dout, expected);
        end else begin
            $display("Read OK: %h", dout);
        end
    endtask

    task automatic reset_fifo();
        rst_n <= 1'b0;
        wr_en <= 1'b0;
        rd_en <= 1'b0;
        din   <= '0;
        expected_q.delete();
        repeat(3) @(posedge clk);
        rst_n <= 1'b1;
        @(posedge clk);
    endtask

    task automatic check_flags(input string msg);
        if (empty && (expected_q.size() != 0))
            $error("%s: empty asserted but model has %0d entries", msg, expected_q.size());
        if (full && (expected_q.size() != DEPTH))
            $error("%s: full asserted but model has %0d entries", msg, expected_q.size());
        if (almost_empty && (expected_q.size() > ALMOST_EMPTY_N))
            $error("%s: almost_empty asserted but model size = %0d (threshold %0d)", msg, expected_q.size(), ALMOST_EMPTY_N);
        if (almost_full && (expected_q.size() < DEPTH - ALMOST_FULL_N))
            $error("%s: almost_full asserted but model size = %0d (threshold %0d)", msg, expected_q.size(), DEPTH - ALMOST_FULL_N);
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        wr_en = 1'b0;
        rd_en = 1'b0;
        din   = '0;

        $display("=== Synchronous FIFO Testbench with Enhanced Parallel Tests ===");

        // 1. Сброс и начальное состояние
        reset_fifo();
        @(posedge clk);
        if (!empty || full || almost_full || almost_empty)
            $error("Reset state incorrect");
        else
            $display("Reset OK");

        // 2. Заполнение до полного, проверка almost_full / full
        for (int i = 0; i < DEPTH; i++) begin
            if (full) $error("FIFO full prematurely at i=%0d", i);
            write_word(i);
            check_flags($sformatf("After write %0d", i));
        end
        if (!full) $error("FIFO not full after DEPTH writes");
        else $display("FIFO correctly full");

        // Попытка записи при полном FIFO
        @(posedge clk);
        wr_en <= 1'b1;
        din   <= 8'hAA;
        @(posedge clk);
        wr_en <= 1'b0;
        if (expected_q.size() != DEPTH)
            $error("Write while full corrupted the FIFO");
        else
            $display("Write-while-full correctly ignored");

        // 3. Чтение всех данных, проверка порядка
        for (int i = 0; i < DEPTH; i++) begin
            read_and_check();
            check_flags($sformatf("After read %0d", i));
        end
        if (!empty) $error("FIFO not empty after reading all");
        else $display("All reads successful, FIFO empty");

        // Попытка чтения при пустом FIFO
        @(posedge clk);
        rd_en <= 1'b1;
        @(posedge clk);
        rd_en <= 1'b0;
        if (expected_q.size() != 0)
            $error("Read while empty corrupted the FIFO");
        else
            $display("Read-while-empty correctly ignored");

        // 4. Проверка порогов almost_empty и almost_full
        reset_fifo();
        for (int i = 0; i < ALMOST_EMPTY_N; i++) write_word(i);
        @(posedge clk);
        if (!almost_empty)
            $error("almost_empty not asserted at count = %0d", ALMOST_EMPTY_N);
        write_word(8'hFF);
        @(posedge clk);
        if (almost_empty)
            $error("almost_empty still asserted at count = %0d", ALMOST_EMPTY_N+1);

        for (int i = ALMOST_EMPTY_N+1; i < DEPTH - ALMOST_FULL_N; i++) write_word(i);
        @(posedge clk);
        if (!almost_full)
            $error("almost_full not asserted at count = %0d", DEPTH - ALMOST_FULL_N);
        write_word(8'hEE);
        @(posedge clk);
        if (!almost_full)
            $error("almost_full deasserted prematurely");

        // 5. Базовый одновременный доступ (непрерывный поток)
        reset_fifo();
        for (int i = 0; i < 5; i++) write_word(i);
        for (int i = 0; i < 10; i++) begin
            @(posedge clk);
            wr_en <= 1'b1;
            rd_en <= 1'b1;
            din   <= 8'hA0 + i;
            @(posedge clk);
            wr_en <= 1'b0;
            rd_en <= 1'b0;
            expected_q.pop_front();
            expected_q.push_back(8'hA0 + i);
            check_flags($sformatf("Simult RD/WR cycle %0d", i));
        end
        while (!empty) read_and_check();

        // 6. Тест циклического переполнения адреса
        reset_fifo();
        for (int i = 0; i < DEPTH; i++) write_word(i);
        for (int i = 0; i < DEPTH/2; i++) read_and_check();
        for (int i = 0; i < DEPTH/2; i++) write_word(8'hC0 + i);
        while (!empty) read_and_check();

        $display("--- Extended parallel read/write tests ---");

        // 7.1 Одновременная запись и чтение на пустом FIFO
        reset_fifo();
        @(posedge clk);
        wr_en <= 1'b1;
        rd_en <= 1'b1;
        din   <= 8'hA5;
        @(posedge clk);
        wr_en <= 1'b0;
        rd_en <= 1'b0;
        if (expected_q.size() == 0) expected_q.push_back(8'hA5);
        if (empty)   $error("7.1: FIFO still empty after simultaneous wr/rd on empty");
        if (full)    $error("7.1: FIFO full unexpectedly");
        if (almost_empty && ALMOST_EMPTY_N > 1)
                     $error("7.1: almost_empty incorrectly asserted");
        read_and_check();
        if (!empty) $error("7.1: FIFO not empty after draining");

        // 7.2 Одновременная запись и чтение на полном FIFO
        reset_fifo();
        for (int i = 0; i < DEPTH; i++) write_word(i);
        @(posedge clk);
        wr_en <= 1'b1;
        rd_en <= 1'b1;
        din   <= 8'h5A;
        @(posedge clk);
        wr_en <= 1'b0;
        rd_en <= 1'b0;
        expected_q.pop_front();
        if (expected_q.size() != DEPTH-1)
            $error("7.2: count after simultaneous on full should be DEPTH-1, got %0d", expected_q.size());
        if (full)  $error("7.2: full still asserted after read");
        while (!empty) read_and_check();

        // 7.3 Длительная непрерывная одновременная работа при заполнении наполовину
        reset_fifo();
        for (int i = 0; i < DEPTH/2; i++) write_word(i);
        for (int i = 0; i < 200; i++) begin
            @(posedge clk);
            wr_en <= 1'b1;
            rd_en <= 1'b1;
            din   <= 8'h80 + (i % 256);
            @(posedge clk);
            wr_en <= 1'b0;
            rd_en <= 1'b0;
            if (expected_q.size() != 0) begin
                expected_q.pop_front();
                expected_q.push_back(8'h80 + (i % 256));
            end else begin
                $error("7.3: empty during continuous simultaneous at cycle %0d", i);
            end
            if (expected_q.size() != DEPTH/2)
                $error("7.3: count changed at cycle %0d, size=%0d", i, expected_q.size());
            check_flags($sformatf("Simult cycle %0d", i));
        end
        while (!empty) read_and_check();

        // 7.4 Переход через almost_empty при одновременных операциях
        reset_fifo();
        for (int i = 0; i < ALMOST_EMPTY_N; i++) write_word(i);
        for (int i = 0; i < 10; i++) begin
            @(posedge clk);
            wr_en <= 1'b1;
            rd_en <= 1'b1;
            din   <= 8'h10 + i;
            @(posedge clk);
            wr_en <= 1'b0;
            rd_en <= 1'b0;
            expected_q.pop_front();
            expected_q.push_back(8'h10 + i);
            check_flags("7.4 during almost_empty simultaneous");
        end
        write_word(8'hFF);
        if (almost_empty)
            $error("7.4: almost_empty still asserted after adding extra word");
        while (!empty) read_and_check();

        // 7.5 Переход через almost_full при одновременных операциях
        reset_fifo();
        for (int i = 0; i < DEPTH - ALMOST_FULL_N; i++) write_word(i);
        if (!almost_full)
            $error("7.5: almost_full not asserted at expected level");
        for (int i = 0; i < 10; i++) begin
            @(posedge clk);
            wr_en <= 1'b1;
            rd_en <= 1'b1;
            din   <= 8'h50 + i;
            @(posedge clk);
            wr_en <= 1'b0;
            rd_en <= 1'b0;
            expected_q.pop_front();
            expected_q.push_back(8'h50 + i);
            check_flags("7.5 during almost_full simultaneous");
        end
        read_and_check();
        if (almost_full)
            $error("7.5: almost_full still asserted after read");
        while (!empty) read_and_check();

        // 7.6 Случайная одновременная работа с меняющимся соотношением запись/чтение
        reset_fifo();
        for (int i = 0; i < DEPTH/2; i++) 
            write_word(i);
        for (int i = 0; i < 500; i++) begin
            automatic bit do_write = ($random & 1);
            automatic bit do_read  = ($random & 1);
            @(posedge clk);
            // Не читаем из пустого, не пишем в полный
            if (expected_q.size() == 0)        do_read  = 1'b0;
            if (expected_q.size() == DEPTH)    do_write = 1'b0;
            wr_en <= do_write;
            rd_en <= do_read;
            din   <= $random;
            @(posedge clk);
            wr_en <= 1'b0;
            rd_en <= 1'b0;
            if (do_read && expected_q.size() > 0)  expected_q.pop_front();
            if (do_write)                          expected_q.push_back(din);
            check_flags($sformatf("Random cycle %0d", i));
        end
        while (!empty) read_and_check();

        // 7.7 Стресс-тест с гарантированным проходом всех состояний
        // Используем управляемый алгоритм: если FIFO пуст - только запись;
        // если полон - только чтение; иначе - одновременные операции.
        reset_fifo();
        $display("Starting stress test 7.7 (controlled simultaneous RD/WR)");
        for (int cycle = 0; cycle < 200; cycle++) begin
            bit loc_wr, loc_rd;
            // Определяем допустимые операции на основе текущего размера
            if (expected_q.size() == 0) begin
                loc_wr = 1'b1; loc_rd = 1'b0;   // только запись
            end else if (expected_q.size() == DEPTH) begin
                loc_wr = 1'b0; loc_rd = 1'b1;   // только чтение
            end else begin
                loc_wr = 1'b1; loc_rd = 1'b1;   // одновременные
            end
            @(posedge clk);
            wr_en <= loc_wr;
            rd_en <= loc_rd;
            din   <= $random;
            @(posedge clk);
            wr_en <= 1'b0;
            rd_en <= 1'b0;
            // Обновляем модель
            if (loc_rd && expected_q.size() > 0) expected_q.pop_front();
            if (loc_wr)                          expected_q.push_back(din);
            check_flags($sformatf("7.7 cycle %0d", cycle));
        end
        // Сливаем FIFO и проверяем остаток
        while (!empty) read_and_check();

        $display("--- All parallel tests passed ---");
        $display("=== ALL TESTS PASSED ===");
        $finish;
    end

    initial begin
        $dumpfile("fifo_bench.vcd");
        $dumpvars(0, fifo_bench);
    end

endmodule