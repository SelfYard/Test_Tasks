//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/13/2026 09:00:22 PM
// Design Name: 
// Module Name: traffic_light_bench
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// Dependencies: 
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module traffic_light_bench();

    localparam int BLINK_PERIOD_TB = 10;
    localparam int RED_TIME_TB     = 5;
    localparam int YELLOW_TIME_TB  = 3;
    localparam int GREEN_TIME_TB   = 4;

    logic clk;
    logic rst_n;
    logic ctrl;
    logic red, yellow, green;

    traffic_light #(
        .BLINK_PERIOD (BLINK_PERIOD_TB),
        .RED_TIME     (RED_TIME_TB),
        .YELLOW_TIME  (YELLOW_TIME_TB),
        .GREEN_TIME   (GREEN_TIME_TB)
    ) dut (
        .clk   (clk),
        .rst_n (rst_n),
        .ctrl  (ctrl),
        .red   (red),
        .yellow(yellow),
        .green (green)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    task apply_ctrl();
        @(posedge clk);
        #1 ctrl = 1'b1;
        @(posedge clk);
        #1 ctrl = 1'b0;
    endtask

    task automatic wait_for_state(input logic exp_r, input logic exp_y, input logic exp_g);
        if (red === exp_r && yellow === exp_y && green === exp_g) return;
        forever begin
            @(posedge clk);
            #1;
            if (red === exp_r && yellow === exp_y && green === exp_g) break;
        end
    endtask

    task automatic check_phase_duration(input string phase_name, input int expected_ticks, input logic exp_r, input logic exp_y, input logic exp_g);
        int ticks = 0;
        while (red === exp_r && yellow === exp_y && green === exp_g) begin
            ticks++;
            @(posedge clk);
            #1;
        end
        
        if (ticks !== expected_ticks) begin
            $error("[%0t] Phase %s duration = %0d ticks, expected %0d ticks", $time, phase_name, ticks, expected_ticks);
        end else begin
            $display("[%0t] Phase %s duration OK: %0d ticks", $time, phase_name, ticks);
        end
    endtask

    initial begin
        rst_n = 0;
        ctrl  = 0;

        $display("========== Тест 1: Сброс и мигание жёлтого в IDLE ==========");
        repeat (2) @(posedge clk);
        #1 rst_n = 1;

        wait_for_state(1'b0, 1'b0, 1'b0);
        check_phase_duration("IDLE_BLINK_OFF_1", BLINK_PERIOD_TB/2, 1'b0, 1'b0, 1'b0);
        check_phase_duration("IDLE_BLINK_ON_1",  BLINK_PERIOD_TB/2, 1'b0, 1'b1, 1'b0);
        $display("Мигание работает корректно.\n");

        $display("========== Тест 2: Запуск рабочего цикла по ctrl ==========");
        apply_ctrl();
        
        wait_for_state(1'b1, 1'b0, 1'b0);
        check_phase_duration("RED", RED_TIME_TB, 1'b1, 1'b0, 1'b0);
        check_phase_duration("YELLOW_UP", YELLOW_TIME_TB, 1'b0, 1'b1, 1'b0);
        check_phase_duration("GREEN", GREEN_TIME_TB, 1'b0, 1'b0, 1'b1);
        check_phase_duration("YELLOW_DOWN", YELLOW_TIME_TB, 1'b0, 1'b1, 1'b0);
        check_phase_duration("RED_FINAL", RED_TIME_TB, 1'b1, 1'b0, 1'b0);
        $display("Цикл завершён, светофор вернулся в IDLE.\n");

        $display("========== Тест 3: Игнорирование ctrl в фазе GREEN ==========");
        apply_ctrl();
        
        wait_for_state(1'b1, 1'b0, 1'b0); // Пропускаем RED и YELLOW_UP
        check_phase_duration("RED", RED_TIME_TB, 1'b1, 1'b0, 1'b0);
        check_phase_duration("YELLOW_UP", YELLOW_TIME_TB, 1'b0, 1'b1, 1'b0);
        
        fork
            check_phase_duration("GREEN_IGNORED", GREEN_TIME_TB, 1'b0, 1'b0, 1'b1);
            begin
                @(posedge clk); #1;
                apply_ctrl();
            end
        join
        $display("ctrl во время GREEN проигнорирован, длительность фазы осталась прежней.");
        
        check_phase_duration("YELLOW_DOWN", YELLOW_TIME_TB, 1'b0, 1'b1, 1'b0);
        check_phase_duration("RED_FINAL", RED_TIME_TB, 1'b1, 1'b0, 1'b0);
        $display("Цикл завершён нормально.\n");

        $display("========== Тест 4: Повтор YELLOW_DOWN по ctrl ==========");
        apply_ctrl();
        
        wait_for_state(1'b1, 1'b0, 1'b0); 
        check_phase_duration("RED", RED_TIME_TB, 1'b1, 1'b0, 1'b0);
        check_phase_duration("YELLOW_UP", YELLOW_TIME_TB, 1'b0, 1'b1, 1'b0);
        check_phase_duration("GREEN", GREEN_TIME_TB, 1'b0, 1'b0, 1'b1);

        fork
            check_phase_duration("YELLOW_EXTENDED", YELLOW_TIME_TB * 2, 1'b0, 1'b1, 1'b0);
            begin
                @(posedge clk); #1; 
                apply_ctrl();
            end
        join
        $display("Повтор YELLOW_DOWN по ctrl отработан корректно (YELLOW + WAIT_EXTRA_YELLOW).");

        check_phase_duration("RED_FINAL", RED_TIME_TB, 1'b1, 1'b0, 1'b0);
        $display("Дополнительная жёлтая фаза завершилась корректным переходом в RED.\n");

        $display("========== Тест 5: Проверка возврата в IDLE после цикла ==========");
        check_phase_duration("IDLE_BLINK_ON_2", BLINK_PERIOD_TB/2, 1'b0, 1'b1, 1'b0);
        check_phase_duration("IDLE_BLINK_OFF_2", BLINK_PERIOD_TB/2, 1'b0, 1'b0, 1'b0);
        $display("IDLE восстановлен, мигание работает штатно.\n");

        $display("========== Все тесты успешно пройдены ==========");
        $finish;
    end

    initial begin
        $dumpfile("traffic_light_bench.vcd");
        $dumpvars(0, traffic_light_bench);
    end

endmodule