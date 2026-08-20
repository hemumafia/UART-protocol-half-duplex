`timescale 1ns / 1ps
//============================================================
// uart_tx.v
// Simple UART transmitter: 8 data bits, no parity, 1 stop bit
// CLKS_PER_BIT = (clock frequency) / (baud rate)
// Basys3 default: 100 MHz / 9600 baud = 10417
//============================================================
module uart_tx #(
    parameter CLKS_PER_BIT = 10417
)(
    input  wire       clk,
    input  wire       rst,        // synchronous, active-high
    input  wire        tx_start,   // pulse 1 clk to begin sending tx_data
    input  wire [7:0]  tx_data,
    output reg          tx,         // serial line to PC (UART_RXD_OUT on Basys3)
    output reg          tx_busy,    // high while a byte is being shifted out
    output reg          tx_done     // pulses 1 clk when byte fully sent
);

    localparam IDLE  = 3'd0,
               START = 3'd1,
               DATA  = 3'd2,
               STOP  = 3'd3,
               CLEAN = 3'd4;

    reg [2:0]  state;
    reg [15:0] clk_count;
    reg [2:0]  bit_index;
    reg [7:0]  tx_shift;

    always @(posedge clk) begin
        if (rst) begin
            state     <= IDLE;
            tx        <= 1'b1;   // line idles high
            tx_busy   <= 1'b0;
            tx_done   <= 1'b0;
            clk_count <= 0;
            bit_index <= 0;
        end else begin
            tx_done <= 1'b0; // default: 1-cycle pulse

            case (state)
                IDLE: begin
                    tx      <= 1'b1;
                    tx_busy <= 1'b0;
                    clk_count <= 0;
                    bit_index <= 0;
                    if (tx_start) begin
                        tx_shift <= tx_data;
                        tx_busy  <= 1'b1;
                        state    <= START;
                    end
                end

                START: begin
                    tx <= 1'b0; // start bit
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= 0;
                        state     <= DATA;
                    end
                end

                DATA: begin
                    tx <= tx_shift[bit_index];
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= 0;
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1'b1;
                        end else begin
                            bit_index <= 0;
                            state     <= STOP;
                        end
                    end
                end

                STOP: begin
                    tx <= 1'b1; // stop bit
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= 0;
                        tx_done   <= 1'b1;
                        state     <= CLEAN;
                    end
                end

                CLEAN: begin
                    tx_busy <= 1'b0;
                    state   <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
