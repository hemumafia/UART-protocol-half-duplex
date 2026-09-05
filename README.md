# Half-Duplex UART Communication Controller — Basys3 (Verilog / Vivado)

A from-scratch UART transmitter/receiver core and a half-duplex PC↔FPGA
communication protocol, implemented in Verilog and verified on a Digilent
Basys3 (Xilinx Artix-7) board.

**Toolchain:** Xilinx Vivado (RTL, synthesis, implementation, timing/power
analysis) · Tera Term (hardware bring-up / manual serial testing) · Python +
pyserial (optional automated test)

---

## Highlights

- Custom UART TX/RX cores built at the RTL level — no IP catalog block used
- Half-duplex protocol enforced in a dedicated FSM (turn-taking between PC
  and FPGA, not just raw byte pass-through)
- Design closes timing with **zero failing endpoints** at 100 MHz
- Verified on real hardware over the Basys3's onboard USB-UART bridge using
  Tera Term
- Full RTL → synthesis → implementation → timing/power sign-off flow

## Results (Vivado, Basys3 / xc7a35tcpg236-1)

*Timing*:

| Metric | Result |
|---|---|
| Worst Setup Slack (WNS) | +5.268 ns |
| Worst Hold Slack (WHS) | +0.151 ns |
| Worst Pulse Width Slack | +4.500 ns |
| Failing endpoints | 0 / 177 (setup & hold) |
| Estimated Fmax | ~211 MHz |

*Power*:

| Metric | Result |
|---|---|
| Total On-Chip Power | 0.073 W |
| Dynamic Power | 0.001 W |
| Device Static Power | 0.072 W |
| Junction Temperature | 25.4 °C |

*Resource Utilization*:

| Resource | Used |
|---|---|
| Slice LUTs | 83 |
| Slice Registers | 102 |
| Slices | 40 |
| Bonded I/O | 28 |

(Screenshots of the Vivado timing summary, power report, and utilization hierarchy are in [/reports](./reports) — add your images there.)

## What it does

The FPGA and a PC exchange data over a strict **request → response,
take-turns** protocol on the board's onboard USB-UART bridge (9600 baud,
8N1):

| PC sends | FPGA action | FPGA replies |
|---|---|---|
| `'R'` (0x52) | Reads the 8 slide switches | 1 byte = `SW[7:0]` |
| `'W'` (0x57) + 1 data byte | Writes that byte to the LEDs | ACK (`0x06`) |
| Anything else | — | NACK (`0x15`) |

The FPGA never starts replying until it has fully received the current
command, and ignores incoming bytes while it's transmitting — that's the
half-duplex enforcement, done at the protocol/FSM level rather than by
sharing a physical wire (the Basys3's onboard TX/RX are separate physical
pins to the FTDI USB bridge).

## Architecture

```
                ┌─────────────────────────────┐
   PC (Tera     │      uart_half_duplex_top    │
   Term) ──TXD─▶│  ┌────────┐                  │
                │  │uart_rx │──▶ protocol FSM ──┼──▶ LEDs
                │  └────────┘        │          │
                │                    ▼          │
                │              switches ─────────┼──▶ (read on 'R')
                │  ┌────────┐        │          │
   PC (Tera     │◀─│uart_tx │◀───────┘          │
   Term) ◀─RXD──│  └────────┘                  │
                └─────────────────────────────┘
```

- **`uart_rx.v`** — receiver: 2-flop input synchronizer, start-bit
  mid-point detection, 8 data bits sampled mid-period, stop-bit / framing
  check
- **`uart_tx.v`** — transmitter: start → 8 data bits → stop bit shifter
- **`uart_half_duplex_top.v`** — protocol FSM, command decode, switch/LED I/O

## Repository structure

```
├── uart_tx.v                  # UART transmitter core
├── uart_rx.v                  # UART receiver core
├── uart_half_duplex_top.v     # Top-level module + protocol FSM
├── basys3_uart.xdc            # Pin constraints for Basys3
├── tb_uart_half_duplex.v      # Self-checking Vivado behavioral testbench
├── test_uart.py               # Optional PC-side automated test (pyserial)
├── docs/                      # Timing / power / utilization report screenshots
└── README.md
```

## How to build

1. Open Vivado → create an RTL project, part `xc7a35tcpg236-1` (Basys3).
2. Add `uart_tx.v`, `uart_rx.v`, `uart_half_duplex_top.v` as **design
   sources**; set `uart_half_duplex_top` as top.
3. Add `basys3_uart.xdc` as the constraints file.
4. Add `tb_uart_half_duplex.v` as a **simulation** source and run
   Behavioral Simulation to check protocol correctness before generating a
   bitstream.
5. Run Synthesis → Implementation → generate bitstream → program the board.

## How to test on hardware (Tera Term)

1. Connect the Basys3 via USB and program the bitstream.
2. Open Tera Term → New connection → Serial → select the Basys3's UART COM
   port.
3. Setup → Serial port: **9600 baud, 8 data bits, no parity, 1 stop bit**.
4. Type `R` — the FPGA returns one byte reflecting the current switch
   positions. Flip switches and repeat to confirm.
5. Type `W` followed by one data byte — the FPGA writes it to the LEDs and
   returns `0x06` (ACK). Sending an unrecognized command returns `0x15`
   (NACK).

*(A `test_uart.py` script is also included for scripted testing via
pyserial, as an alternative to manual Tera Term entry.)*

## Skills demonstrated

Verilog HDL · RTL design · finite state machines · UART protocol design ·
serial communication (half-duplex vs full-duplex) · synchronous design &
metastability handling (input synchronizers) · Vivado synthesis &
implementation flow · static timing analysis · power analysis · FPGA
hardware bring-up and debug (Tera Term)

## Author

[Your name] — Final-year B.Tech ECE, preparing for GATE 2027 | [LinkedIn] | [Email]
