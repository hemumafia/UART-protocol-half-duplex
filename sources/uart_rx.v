`timescale 1ns / 1ps
//============================================================
// uart_rx.v
// Simple UART receiver: 8 data bits, no parity, 1 stop bit
// Samples each bit in the middle of its period for noise margin.
//============================================================
module uart_rx #(
    parameter CLKS_PER_BIT = 10417
)(
    input  wire       clk,
    input  wire       rst,
    input  wire        rx,           // serial line from PC (UART_TXD_IN on Basys3)
    output reg          rx_busy,      // high while a frame is being received
    output reg [7:0]    rx_data,      // valid when rx_done pulses
    output reg          rx_done,      // pulses 1 clk when a full byte is received
    output reg          frame_error   // pulses 1 clk if stop bit was not 1
);

    localparam IDLE  = 3'd0,
               START = 3'd1,
               DATA  = 3'd2,
               STOP  = 3'd3,
               CLEAN = 3'd4;

    reg [2:0]  state;
    reg [15:0] clk_count;
    reg [2:0]  bit_index;
    reg [7:0]  rx_shift;

    // 2-flop synchronizer for the async serial input
    reg rx_meta, rx_sync;
    always @(posedge clk) begin
        rx_meta <= rx;
        rx_sync <= rx_meta;
    end

    always @(posedge clk) begin
        if (rst) begin
            state       <= IDLE;
            rx_busy     <= 1'b0;
            rx_done     <= 1'b0;
            frame_error <= 1'b0;
            clk_count   <= 0;
            bit_index   <= 0;
        end else begin
            rx_done     <= 1'b0;
            frame_error <= 1'b0;

            case (state)
                IDLE: begin
                    rx_busy   <= 1'b0;
                    clk_count <= 0;
                    bit_index <= 0;
                    if (rx_sync == 1'b0) begin // possible start bit
                        state <= START;
                    end
                end

                START: begin
                    rx_busy <= 1'b1;
                    // sample at the middle of the start bit to confirm it's real
                    if (clk_count == (CLKS_PER_BIT - 1) / 2) begin
                        if (rx_sync == 1'b0) begin
                            clk_count <= 0;
                            state     <= DATA;
                        end else begin
                            state <= IDLE; // false start (glitch)
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                DATA: begin
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= 0;
                        rx_shift[bit_index] <= rx_sync;
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1'b1;
                        end else begin
                            bit_index <= 0;
                            state     <= STOP;
                        end
                    end
                end

                STOP: begin
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count   <= 0;
                        rx_data     <= rx_shift;
                        rx_done     <= 1'b1;
                        frame_error <= (rx_sync != 1'b1); // stop bit should be high
                        state       <= CLEAN;
                    end
                end

                CLEAN: begin
                    rx_busy <= 1'b0;
                    state   <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
