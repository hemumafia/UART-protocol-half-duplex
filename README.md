# Half-Duplex UART Communication Controller — FPGA (Verilog, Vivado)

A custom UART peripheral built from scratch in Verilog and deployed on a Xilinx Basys3 (Artix-7) FPGA, implementing a half-duplex, request/response serial protocol between the FPGA and a PC.

## What it does

The FPGA and a PC exchange data over a serial link where the FPGA reads live switch states and drives onboard LEDs based on commands sent from the PC — a minimal but complete example of FPGA-to-host communication, register-style command handling, and protocol design.

| PC sends | FPGA action | FPGA replies |
|---|---|---|
| `'R'` | Reads slide switches | Switch states (1 byte) |
| `'W'` + data byte | Writes byte to LEDs | ACK |
| Unknown command | — | NACK |

## Skills demonstrated

- **RTL design in Verilog**: UART TX/RX cores built from the ground up (no vendor IP), FSM-based protocol controller, input synchronization for metastability safety
- **Verification**: self-checking testbench, simulated in Vivado
- **FPGA implementation flow**: synthesis, implementation, timing closure, and static timing analysis in Vivado
- **Hardware bring-up**: tested end-to-end on physical Basys3 hardware against a Python (pyserial) host script
- **Protocol / systems thinking**: designed and enforced half-duplex turn-taking behavior at the FSM level

## Results

| Metric | Value |
|---|---|
| Target clock | 100 MHz |
| Setup slack (WNS) | +5.268 ns |
| Hold slack (WHS) | +0.151 ns |
| Timing constraints met | ✅ 0 failing endpoints / 177 |
| On-chip power | 0.073 W |
| Slice LUTs | 83 |
| Slice registers | 102 |
| I/O pins used | 28 |

## Repo contents

- `uart_tx.v`, `uart_rx.v` — UART transmitter/receiver cores
- `uart_half_duplex_top.v` — top-level protocol FSM
- `basys3_uart.xdc` — board constraints
- `tb_uart_half_duplex.v` — testbench
- `test_uart.py` — host-side test script (Python/pyserial)

## Tools

Verilog HDL · Xilinx Vivado (synthesis, implementation, timing/power analysis) · Python (pyserial) · Basys3 (Artix-7)
