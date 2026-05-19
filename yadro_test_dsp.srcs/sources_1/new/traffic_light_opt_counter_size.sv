//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/13/2026 11:00:22 PM
// Design Name: 
// Module Name: traffic_light_opt
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
//
// Counter max size reduced
//
// Dependencies: 
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module traffic_light_opt_counter_size #(
    //  measured in clk posedges
    parameter int BLINK_PERIOD = 50_000_000,
    parameter int RED_TIME     = 100_000_000,
    parameter int YELLOW_TIME  = 20_000_000,
    parameter int GREEN_TIME   = 80_000_000
) (
    input  logic clk,
    input  logic rst_n, // async active low
    input  logic ctrl,  // active high, pulse
    output logic red,
    output logic yellow,
    output logic green
);

    localparam int BLINK_HALF = BLINK_PERIOD / 2;

    localparam int MAX_TIME = (RED_TIME > YELLOW_TIME) ?
        ((RED_TIME > GREEN_TIME) ?
        ((RED_TIME > BLINK_HALF) ? RED_TIME : BLINK_HALF) :
        ((GREEN_TIME > BLINK_HALF) ? GREEN_TIME : BLINK_HALF)) :
        ((YELLOW_TIME > GREEN_TIME) ?
        ((YELLOW_TIME > BLINK_HALF) ? YELLOW_TIME : BLINK_HALF) :
        ((GREEN_TIME > BLINK_HALF) ? GREEN_TIME : BLINK_HALF));

    localparam int COUNTER_WIDTH = $clog2(MAX_TIME);

    typedef enum {
        DEF,
        RED_START,
        YELLOW_UP,
        GREEN,
        YELLOW_DOWN,
        WAIT_EXTRA_YELLOW,
        RED_FINAL
    } state_t;

    state_t state, next_state;

    logic [COUNTER_WIDTH-1:0] counter;
    logic [COUNTER_WIDTH-1:0] blink_counter;
    logic                     blink_yellow;

    logic ctrl_prev;
    logic ctrl_edge;
    logic ctrl_pending;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            ctrl_prev <= 1'b0;
        else
            ctrl_prev <= ctrl;
    end
    assign ctrl_edge = ctrl & ~ctrl_prev;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= DEF;
            counter       <= 0;
            blink_counter <= BLINK_HALF - 1;
            blink_yellow  <= 1'b1;
            ctrl_pending  <= 1'b0;
        end else begin
            case (state)
                DEF: begin
                    if (blink_counter == 0) begin
                        blink_yellow  <= ~blink_yellow;
                        blink_counter <= BLINK_HALF - 1;
                    end else begin
                        blink_counter <= blink_counter - 1;
                    end
                    if (ctrl_edge) begin
                        next_state    = RED_START;
                        counter       <= RED_TIME - 1;
                        state         <= next_state;
                        ctrl_pending  <= 1'b0;
                        blink_counter <= 0;
                    end
                end

                RED_START: begin
                    if (counter == 0) begin
                        next_state = YELLOW_UP;
                        counter <= YELLOW_TIME - 1;
                        state <= next_state;
                    end else begin
                        counter <= counter - 1;
                    end
                end

                YELLOW_UP: begin
                    if (counter == 0) begin
                        next_state = GREEN;
                        counter <= GREEN_TIME - 1;
                        state <= next_state;
                    end else begin
                        counter <= counter - 1;
                    end
                end

                GREEN: begin
                    if (counter == 0) begin
                        next_state = YELLOW_DOWN;
                        counter <= YELLOW_TIME - 1;
                        state <= next_state;
                    end else begin
                        counter <= counter - 1;
                    end
                end

                YELLOW_DOWN: begin
                    if (ctrl_edge)
                        ctrl_pending <= 1'b1;
                    if (counter == 0) begin
                        if (ctrl_pending || ctrl_edge) begin 
                            next_state = WAIT_EXTRA_YELLOW;
                            counter <= YELLOW_TIME - 1;
                            state <= next_state;
                            ctrl_pending <= 1'b0;
                        end else begin
                            next_state = RED_FINAL;
                            counter <= RED_TIME - 1;
                            state <= next_state;
                        end
                    end else begin
                        counter <= counter - 1;
                    end
                end

                WAIT_EXTRA_YELLOW: begin
                    if (counter == 0) begin
                        next_state = RED_FINAL;
                        counter <= RED_TIME - 1;
                        state <= next_state;
                    end else begin
                        counter <= counter - 1;
                    end
                end

                RED_FINAL: begin
                    if (counter == 0) begin
                        next_state = DEF;
                        blink_counter <= BLINK_HALF - 1;
                        blink_yellow <= 1'b1;
                        state <= next_state;
                        ctrl_pending <= 1'b0;
                    end else begin
                        counter <= counter - 1;
                    end
                end

                default: state <= DEF;
            endcase
        end
    end

    always_comb begin
        red = 1'b0;
        yellow = 1'b0;
        green = 1'b0;

        case (state)
            DEF: begin
                yellow = blink_yellow;
            end
            RED_START, RED_FINAL: begin
                red = 1'b1;
            end
            YELLOW_UP, YELLOW_DOWN, WAIT_EXTRA_YELLOW: begin
                yellow = 1'b1;
            end
            GREEN: begin
                green = 1'b1;
            end
        endcase
    end

endmodule