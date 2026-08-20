`timescale 1ns / 1ps
//============================================================
// uart_half_duplex_top.v
// Basys3 <-> PC half-duplex UART demo
//
// Protocol (all 1-byte commands from PC unless noted):
//   'R' (0x52) -> FPGA replies with 1 byte = {sw[7:0]}
//   'W' (0x57) -> FPGA waits for 1 more data byte, writes it to led[7:0],
//                 then replies with ACK (0x06)
//   anything else -> FPGA replies with NACK (0x15)
//
// Half-duplex enforcement:
//   - The RX engine is always listening, but the top FSM only acts on
//     rx_done while it is not itself transmitting (tx_busy low), and it
//     never issues tx_start until it has fully finished receiving the
//     current command. FPGA and PC are never "talking" in the same
//     window from the protocol's point of view.
//   - Note: Basys3's onboard USB-UART bridge uses two separate physical
//     wires (UART_TXD_IN, UART_RXD_OUT), so this is a logical/protocol
//     half-duplex (turn-taking), not a physically shared single wire.
//     A single shared wire would need an external transceiver (e.g. a
//     RS-485 driver on a PMOD) with a direction/enable pin.
//============================================================
module uart_half_duplex_top #(
    parameter CLKS_PER_BIT = 10417   // 100 MHz / 9600 baud
)(
    input  wire       clk,          // 100 MHz onboard clock
    input  wire        btnC,         // center button = reset
    input  wire        UART_TXD_IN,  // PC -> FPGA (this is FPGA's rx)
    output wire         UART_RXD_OUT, // FPGA -> PC (this is FPGA's tx)
    input  wire  [7:0]  sw,           // slide switches
    output reg  [15:0]  led           // LEDs (data byte shown on led[7:0])
);

    wire rst = btnC;

    //--------------------------------------------------------
    // RX / TX core instances
    //--------------------------------------------------------
    wire        rx_done, frame_error, rx_busy;
    wire [7:0]  rx_data;

    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) rx_inst (
        .clk         (clk),
        .rst         (rst),
        .rx          (UART_TXD_IN),
        .rx_busy     (rx_busy),
        .rx_data     (rx_data),
        .rx_done     (rx_done),
        .frame_error (frame_error)
    );

    reg        tx_start;
    reg [7:0]  tx_data;
    wire       tx_busy, tx_done;

    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) tx_inst (
        .clk     (clk),
        .rst     (rst),
        .tx_start(tx_start),
        .tx_data (tx_data),
        .tx      (UART_RXD_OUT),
        .tx_busy (tx_busy),
        .tx_done (tx_done)
    );

    //--------------------------------------------------------
    // Protocol FSM
    //--------------------------------------------------------
    localparam S_IDLE        = 3'd0, // waiting for a command byte
               S_GOT_CMD     = 3'd1, // decode command
               S_WAIT_WDATA  = 3'd2, // 'W' seen, waiting for data byte
               S_SEND        = 3'd3, // tx_start pulsed, waiting for tx to start
               S_SEND_WAIT   = 3'd4; // waiting for tx_done

    reg [2:0] state;
    reg [7:0] cmd_reg;

    localparam CMD_R    = 8'h52; // 'R'
    localparam CMD_W    = 8'h57; // 'W'
    localparam ACK      = 8'h06;
    localparam NACK     = 8'h15;

    always @(posedge clk) begin
        if (rst) begin
            state    <= S_IDLE;
            tx_start <= 1'b0;
            tx_data  <= 8'h00;
            cmd_reg  <= 8'h00;
            led      <= 16'h0000;
        end else begin
            tx_start <= 1'b0; // default: single-cycle pulse

            case (state)
                //---------------------------------------------
                S_IDLE: begin
                    // Only look at freshly received bytes; ignore RX
                    // activity entirely while we are transmitting.
                    if (rx_done && !tx_busy) begin
                        cmd_reg <= rx_data;
                        state   <= S_GOT_CMD;
                    end
                end

                //---------------------------------------------
                S_GOT_CMD: begin
                    if (cmd_reg == CMD_R) begin
                        tx_data  <= sw;      // reply with switch states
                        tx_start <= 1'b1;
                        state    <= S_SEND;
                    end else if (cmd_reg == CMD_W) begin
                        state <= S_WAIT_WDATA; // need one more byte
                    end else begin
                        tx_data  <= NACK;
                        tx_start <= 1'b1;
                        state    <= S_SEND;
                    end
                end

                //---------------------------------------------
                S_WAIT_WDATA: begin
                    if (rx_done) begin
                        led[7:0] <= rx_data;   // write data byte to LEDs
                        tx_data  <= ACK;
                        tx_start <= 1'b1;
                        state    <= S_SEND;
                    end
                end

                //---------------------------------------------
                S_SEND: begin
                    // wait one cycle for tx_busy to actually rise
                    if (tx_busy)
                        state <= S_SEND_WAIT;
                end

                //---------------------------------------------
                S_SEND_WAIT: begin
                    if (tx_done)
                        state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
