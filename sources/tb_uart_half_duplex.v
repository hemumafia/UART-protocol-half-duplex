`timescale 1ns / 1ps
//============================================================
// tb_uart_half_duplex.v
// Quick simulation testbench. Uses a fast baud rate
// (CLKS_PER_BIT = 4) so simulation runs in a few microseconds.
// Drives UART_TXD_IN like a "PC" would, and checks FPGA's replies.
//============================================================
module tb_uart_half_duplex;

    parameter CLKS_PER_BIT = 4;
    parameter CLK_PERIOD   = 10; // 100 MHz

    reg clk = 0;
    reg btnC = 1;
    reg UART_TXD_IN = 1; // idle high
    wire UART_RXD_OUT;
    reg  [7:0] sw = 8'hA5;
    wire [15:0] led;

    uart_half_duplex_top #(.CLKS_PER_BIT(CLKS_PER_BIT)) dut (
        .clk(clk), .btnC(btnC),
        .UART_TXD_IN(UART_TXD_IN), .UART_RXD_OUT(UART_RXD_OUT),
        .sw(sw), .led(led)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    // task: send one byte on UART_TXD_IN (acting as the PC)
    task send_byte(input [7:0] data);
        integer i;
        begin
            UART_TXD_IN = 0; // start bit
            #(CLKS_PER_BIT*CLK_PERIOD);
            for (i = 0; i < 8; i = i + 1) begin
                UART_TXD_IN = data[i];
                #(CLKS_PER_BIT*CLK_PERIOD);
            end
            UART_TXD_IN = 1; // stop bit
            #(CLKS_PER_BIT*CLK_PERIOD);
        end
    endtask

    // task: capture one byte from UART_RXD_OUT (acting as the PC listening)
    task recv_byte(output [7:0] data);
        integer i;
        begin
            @(negedge UART_RXD_OUT); // start bit begins
            #(CLKS_PER_BIT*CLK_PERIOD*1.5); // move to middle of bit0
            for (i = 0; i < 8; i = i + 1) begin
                data[i] = UART_RXD_OUT;
                #(CLKS_PER_BIT*CLK_PERIOD);
            end
        end
    endtask

    reg [7:0] got;

    initial begin
        #(CLK_PERIOD*5) btnC = 0; // release reset

        // Test 1: 'R' command should return sw = 0xA5
        #(CLK_PERIOD*10);
        send_byte(8'h52); // 'R'
        recv_byte(got);
        if (got === 8'hA5)
            $display("PASS: R command returned 0x%02h as expected", got);
        else
            $display("FAIL: R command returned 0x%02h, expected 0xA5", got);

        // Test 2: 'W' command + data byte should update led[7:0] and ACK
        #(CLK_PERIOD*20);
        send_byte(8'h57); // 'W'
        send_byte(8'h3C); // data
        recv_byte(got);
        if (got === 8'h06 && led[7:0] === 8'h3C)
            $display("PASS: W command ACKed and led=0x%02h", led[7:0]);
        else
            $display("FAIL: W command got ack=0x%02h led=0x%02h", got, led[7:0]);

        // Test 3: unknown command should NACK
        #(CLK_PERIOD*20);
        send_byte(8'hFF);
        recv_byte(got);
        if (got === 8'h15)
            $display("PASS: unknown command NACKed");
        else
            $display("FAIL: unknown command returned 0x%02h, expected NACK", got);

        #(CLK_PERIOD*20);
        $display("Simulation complete.");
        $finish;
    end

endmodule
