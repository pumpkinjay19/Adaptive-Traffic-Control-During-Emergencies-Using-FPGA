# Adaptive Traffic Control During Emergencies Using FPGA

An FPGA-based traffic-control project exploring emergency-vehicle prioritisation using RFID identification and a traffic-signal finite-state machine.

## Hardware platform

- **FPGA board:** Terasic DE10-Lite (MAX 10)
- **Controller:** ESP32
- **Identification:** MFRC522 RFID reader
- **Communication:** UART, 9600 baud, 8-N-1
- **Development tools:** Arduino IDE and Intel Quartus Prime

## Project concept

The ESP32 reads an RFID tag presented to the MFRC522 reader. In the current first iteration, the sketch recognises configured North and East emergency-vehicle tags and sends the corresponding single-character request (`N` or `E`) over UART2. The FPGA receives the UART data and uses it as an emergency request input to its traffic-control FSM.

The Verilog design also includes normal North/South and East/West signal sequencing, pedestrian request handling, an emergency-priority state sequence, and a conflict-monitor/fault indication path.

## Repository structure

```text
.
├── First_Iteration/
│   ├── esp32_ev_reader.ino
│   ├── ev_traffic.v
│   └── ev_traffic_pins.qsf
├── Second_Iteration/
│   └── (future revised implementation)
└── Documentation/
    └── (architecture, testing, and design notes)
```

## First iteration

The files in `First_Iteration/` are the initial implementation, preserved as submitted so that the design can be compared against later revisions. This version is a work in progress and contains issues that will be reviewed and corrected in subsequent iterations.

### Files

| File | Purpose |
|---|---|
| `esp32_ev_reader.ino` | ESP32 firmware for reading RFID UIDs and sending recognised direction characters over UART2 |
| `ev_traffic.v` | Verilog top-level design for traffic-signal control, pedestrian requests, UART reception, emergency pre-emption, and conflict monitoring |
| `ev_traffic_pins.qsf` | Quartus pin assignments for the DE10-Lite design |

### Current interface details from the source

- ESP32 UART2 TX is GPIO17 and is intended to connect to FPGA GPIO[18].
- The FPGA UART receiver is configured for 9600 baud with a 50 MHz clock.
- The RFID sketch currently has North and East tag UIDs configured.
- The Verilog source defines GPIO outputs for vehicle and pedestrian signals, pedestrian-button inputs, and an emergency-mode indicator.

> **Pin-assignment caution:** The QSF file itself says its pin locations were entered from memory and must be checked against the official DE10-Lite user manual before programming the board. Do not treat this file as a verified board pinout.

## Development plan

The next iteration will be developed after reviewing the first-iteration issues. Planned repository updates may include:

- corrected and tested Verilog FSM behaviour;
- verified DE10-Lite pin assignments and I/O standards;
- improved ESP32-to-FPGA UART/RFID handling;
- simulation testbenches and test cases;
- block diagrams, timing notes, and hardware validation results.

## Status

**First iteration uploaded — under review.** The source files are retained as the initial baseline; successful compilation, simulation, and hardware validation are not claimed here.
