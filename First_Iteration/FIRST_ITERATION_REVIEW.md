# First Iteration — Mistakes and Lessons Learned

This document records the problems encountered during the first iteration of **Adaptive Traffic Control During Emergencies Using FPGA**. It is a development log, not a claim that every part of the system failed. The original source files in this folder are preserved as the first-iteration baseline.

## 1. Development and testing issues

These were mainly issues in the order of implementation, setup, and debugging.

### 1.1 Built and tested too many parts at once

The initial setup combined 16 traffic and pedestrian LEDs, two pedestrian buttons, the ESP32, and the MFRC522 RFID reader before each part had been independently verified.

When the LEDs behaved unexpectedly, several possible causes had to be considered at once.

**Lesson:** Bring the system up incrementally:
1. Test one GPIO-header LED.
2. Test all required LEDs.
3. Verify the traffic-light FSM independently.
4. Test UART communication using the FPGA's onboard LEDs.
5. Connect and test RFID tag detection.
6. Integrate the pedestrian controls and test the complete system.

### 1.2 Switch state was not checked early enough

SW9, used for fault injection, was left ON after an earlier switch-to-LED test. The fault monitor latched the fault, which made the traffic LEDs appear unresponsive.

**Lesson:** Before debugging a design, check the switch positions. For normal operation, keep SW9 OFF. After disabling fault injection, use KEY0 to clear the latched fault and recover.

### 1.3 Quartus Programmer chain was misconfigured

The Programmer setup contained the same `.sof` file twice and displayed two device rows. This caused programming to fail.

**Lesson:** Check the detected device chain and ensure the programming file is listed only once for the intended FPGA device before selecting Start.

### 1.4 USB-Blaster driver installation required a different method

The normal “Browse my computer” driver installation route did not work. The driver was installed successfully using the “Have Disk” option.

**Lesson:** Record the working driver-installation method for future setup or troubleshooting. This was a tool-setup issue rather than a design-logic error.

### 1.5 The cause of the first switch-test issue was not confirmed

The first switch-to-LED test began working after several possible causes were considered, including recompiling the design, checking the top-level entity name, and checking pin assignments. The exact change that fixed it was not established.

A missed recompile or a top-level entity-name mismatch were possibilities, but the actual cause is unknown.

**Lesson:** When a fix works, record exactly what was changed and retest it. Avoid treating an unconfirmed explanation as the root cause.

## 2. Design and guidance issues

These were issues in the implementation or guidance, rather than mistakes made during the hardware setup.

### 2.1 Emergency-vehicle request hold-timer bug

In the initial Verilog logic, the emergency-vehicle request could expire before the controller reached the emergency green phase. The request-hold timer was counting at the wrong stage of the sequence.

**Correction:** The timer was changed so that it counts only while the emergency direction has green. This fix still needs to be verified on the physical FPGA after recompiling and reflashing the updated Verilog.

### 2.2 GPIO pin assignments were not fully verified

Some pin assignments in the QSF file were entered from memory. The onboard switches and LEDs were tested successfully, but the GPIO-header pin assignments have not all been independently checked against the official DE10-Lite pin information.

**Lesson:** Verify every external GPIO pin against the board documentation before treating the pin map as final.

### 2.3 A simulation testbench was not prepared early

A testbench should have been prepared and run before integrating the complete hardware setup. A simulation with shortened timing parameters could have exposed the emergency-request hold-timer bug earlier.

**Lesson:** Add a testbench in the next iteration to verify normal traffic sequencing, emergency preemption, pedestrian requests, and fault handling before hardware testing.

## 3. What worked in the first iteration

The first iteration also established several working parts:

- Quartus detected the DE10-Lite after the USB-Blaster driver was installed.
- The FPGA project was created, compiled, and programmed for the basic switch-to-LED test.
- The ESP32 successfully read RFID tags.
- The ESP32 serial monitor displayed the East tag identifier (`E`).
- The traffic-light sequence ran after the latched fault was cleared.
- The breadboard wiring and ESP32-side RFID detection worked during the reported tests.

These observations do not, by themselves, confirm that the updated emergency-preemption logic has passed a complete physical-board test.

## 4. Lessons to carry into the second iteration

1. Test each hardware and software block independently before integration.
2. Check switch states and reset conditions before debugging apparent LED or FSM failures.
3. Record the exact cause of every issue once it has been identified.
4. Simulate the FSM and emergency-preemption timing before programming the FPGA.
5. Verify GPIO assignments against the official board documentation.
6. Recompile and reflash after every HDL change, then verify the result on the physical board.
7. Keep the original first-iteration files unchanged and place corrected implementations in `Second_Iteration/`.

## 5. Current verification status

The emergency hold-timer correction has been made in the updated Verilog, but it still needs to be recompiled, reflashed, and tested on the physical board. The GPIO-header pin assignments also remain to be checked against the DE10-Lite documentation.

The first iteration should therefore be treated as a preserved baseline with documented issues, not as a fully validated final implementation.
