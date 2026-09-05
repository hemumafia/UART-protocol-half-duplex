# Half-Duplex UART Communication Controller — Basys3 FPGA

**Verilog HDL · Xilinx Vivado · Artix-7 (Basys3)**

A from-scratch UART transmitter/receiver core and protocol controller, implemented and timing-closed on the Basys3 FPGA, with a PC-side Python test harness for end-to-end hardware validation.

---

## Overview

This project implements a **half-duplex serial communication link** between a PC and an FPGA over the Basys3's onboard USB-UART bridge. Rather than a plain "echo" UART demo, it layers a small request/response protocol on top of the UART core so the FPGA and PC take strict turns — the FPGA never transmits while it is still receiving a command, and never begins a reply until a full command has been received.

The FPGA reads its onboard switches and drives its LEDs in response to PC commands, giving a simple, verifiable demonstration of register-style read/write access over a serial link — the same pattern used in real embedded telemetry/debug interfaces.

## Key Features

- Custom UART TX and RX cores written from scratch in Verilog (no IP catalog blocks) — start/stop bit framing, mid-bit sampling, and 2-flop input synchronization for metastability protection
- Protocol-level half-duplex enforcement via a dedicated FSM (turn-taking, not simultaneous TX/RX)
- Simple command set: read switch states, write LED byte, ACK/NACK for unknown commands
- Self-checking Verilog testbench (Vivado XSIM)
- PC-side Python (`pyserial`) test script for real hardware validation
- Fully timing-closed and implemented for the Basys3 (Artix-7 `xc7a35tcpg236-1`)

## Communication Protocol

| PC → FPGA | FPGA action | FPGA → PC |
|---|---|---|
| `'R'` (0x52) | Read slide switches | 1 byte = `SW[7:0]` |
| `'W'` (0x57) + 1 data byte | Write byte to LEDs | ACK (`0x06`) |
| Any other byte | — | NACK (`0x15`) |

8N1 framing, 9600 baud (parameterized — easily retargeted to a higher baud rate).

## Repository Structure

```
uart_tx.v                  UART transmitter core
uart_rx.v                  UART receiver core
uart_half_duplex_top.v     Top-level module: protocol FSM + I/O
basys3_uart.xdc            Pin constraints for Basys3
tb_uart_half_duplex.v      Self-checking testbench
test_uart.py               PC-side test script (pyserial)
README.md                  This file
```

## Results (Vivado , Basys3 / xc7a35tcpg236-1)

**Timing** — 100 MHz system clock, all constraints met, 0 failing endpoints:

| Metric | Result |
|---|---|
| Worst Setup Slack (WNS) | +5.268 ns |
| Worst Hold Slack (WHS) | +0.151 ns |
| Worst Pulse Width Slack | +4.500 ns |
| Failing endpoints | 0 / 177 (setup & hold) |
| Estimated Fmax | ~211 MHz |

**Power** (implemented netlist, vectorless estimate):

| Metric | Result |
|---|---|
| Total On-Chip Power | 0.073 W |
| Dynamic Power | 0.001 W |
| Device Static Power | 0.072 W |
| Junction Temperature | 25.4 °C |

**Resource Utilization**:

| Resource | Used |
|---|---|
| Slice LUTs | 83 |
| Slice Registers | 102 |
| Slices | 40 |
| Bonded I/O | 28 |

*(Screenshots of the Vivado timing summary, power report, and utilization hierarchy are in [`/reports`](./reports) — add your images there.)*

## Verification

- **Simulation:** self-checking testbench (`tb_uart_half_duplex.v`) drives simulated PC-side bytes into the RX core and checks the FSM's replies against the protocol table above, run in Vivado's behavioral simulator (XSIM).
  *(Add your pass/fail count and a waveform screenshot here once run — e.g. "3/3 test cases passed.")*
- **Hardware validation:** tested on physical Basys3 hardware against `test_uart.py`, confirming switch readback and LED write-back over the onboard USB-UART bridge.
  *(Add a short note or terminal screenshot of a real test run here.)*

## Getting Started

### Simulate
1. Open Vivado, create a project targeting the Basys3 part.
2. Add `uart_tx.v`, `uart_rx.v`, `uart_half_duplex_top.v` as design sources; add `tb_uart_half_duplex.v` as a simulation source.
3. Run Behavioral Simulation and check the Tcl console output.

### Build for hardware
1. Add `basys3_uart.xdc` as a constraints file; set `uart_half_duplex_top` as the top module.
2. Run Synthesis → Implementation → Generate Bitstream.
3. Program the Basys3.

### Test on hardware
```bash
pip install pyserial
python test_uart.py <your-serial-port>   # e.g. COM5 or /dev/ttyUSB1
```

## Skills Demonstrated

Verilog HDL · RTL design · Finite state machines · UART/serial protocol design · Xilinx Vivado (synthesis, implementation, timing & power analysis) · Constraint (XDC) authoring · Testbench development & simulation · Python (pyserial) hardware bring-up · FPGA-to-PC interfacing

## Possible Extensions

- Checksum/parity byte for error detection
- Timeout handling for dropped frames
- Physically shared single-wire (RS-485-style) variant for board-to-board half-duplex

---
