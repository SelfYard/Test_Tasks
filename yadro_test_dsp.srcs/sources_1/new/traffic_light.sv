//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/13/2026 06:00:22 PM
// Design Name: 
// Module Name: traffic_light
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
//
// Ctrl handling:
//   - A rising edge on ctrl is detected via register ctrl_prev.
//   - In YELLOW_DOWN, a rising edge sets ctrl_pending (sticky flag).
//   - The flag is cleared upon entering WAIT_EXTRA_YELLOW, RED_FINAL, or after
//     a new cycle starts in DEF.
//
// Timing:
//   - All state durations are parameterized in clock cycles.
//   - In DEF, yellow blinks with period BLINK_PERIOD (half on, half off)
//     using a dedicated blink_counter.
//   - When leaving DEF, blink_counter is reset.
//
// Counters:
//   - counter:       32-bit down-counter for state dwell times.
//   - blink_counter: 32-bit down-counter for half-blink period in DEF.
//   - blink_yellow:  toggles when blink_counter reaches zero.
//
// Outputs:
//   red, yellow, green are generated combinationally from the current state.
//   Only one output is active at any time except during DEF when yellow blinks.
//
// Reset:
//   Asynchronous active-low reset (rst_n) initializes all registers to the
//   DEF state with blink_yellow = 1 and all pending flags cleared.
//
// Dependencies: 
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module traffic_light #(
    //  measured in clk posedges
    parameter int BLINK_PERIOD = 50_000_000,
    parameter int RED_TIME = 100_000_000,
    parameter int YELLOW_TIME = 20_000_000,
    parameter int GREEN_TIME = 80_000_000
) (
    input  logic clk,
    input  logic rst_n, // async active low
    input  logic ctrl, // active high, pulse
    output logic red,
    output logic yellow,
    output logic green
);

    localparam int BLINK_HALF = BLINK_PERIOD / 2;

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

    logic [31:0] counter;
    logic [31:0] blink_counter;
    logic        blink_yellow;

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
            state <= DEF;
            counter <= 0;
            blink_counter <= BLINK_HALF - 1;
            blink_yellow <= 1'b1;
            ctrl_pending <= 1'b0;
        end else begin
            case (state)
                DEF: begin
                    if (blink_counter == 0) begin
                        blink_yellow <= ~blink_yellow;
                        blink_counter <= BLINK_HALF - 1;
                    end else begin
                        blink_counter <= blink_counter - 1;
                    end
                    if (ctrl_edge) begin
                        next_state = RED_START;
                        counter <= RED_TIME - 1;
                        state <= next_state;
                        ctrl_pending <= 1'b0;
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