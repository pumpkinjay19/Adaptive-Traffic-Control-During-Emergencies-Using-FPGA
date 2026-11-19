# First Iteration — What I Would Do Differently

This document captures the improvements I would make if I were starting **Adaptive Traffic Control During Emergencies Using FPGA** again. The aim is to make the development process more systematic and reduce debugging time in the next iteration.

## 1. Bring up the hardware in stages

If I were starting again, I would not connect and test the entire setup at once. I would verify each part before integrating the next:

1. Test a single GPIO-header LED.
2. Test all traffic and pedestrian LEDs.
3. Verify the traffic-light FSM independently.
4. Test UART communication using the FPGA's onboard LEDs.
5. Connect the ESP32 and verify RFID tag detection.
6. Add the pedestrian buttons and test the complete system.

This would make it easier to identify which block is causing a problem.

## 2. Check switch positions and reset conditions first

Before debugging unexpected LED or FSM behaviour, I would check every switch position and confirm the reset state.

For normal operation, I would keep SW9 (fault injection) OFF. If a fault has been latched, I would turn SW9 OFF and use KEY0 to clear the fault before continuing.

## 3. Check the Quartus Programmer chain before programming

Before selecting Start, I would verify that the DE10-Lite is detected correctly, that the intended FPGA device is selected, and that the .sof file is listed only once.

If the Programmer displays duplicate device rows or duplicate programming files, I would correct the chain before attempting to program the board.

## 4. Keep the working driver-installation method documented

For a fresh setup, I would keep the USB-Blaster driver installation steps that worked: using Device Manager's **Have Disk** option when the normal browse route does not detect the driver.

This would make the setup easier to reproduce on another computer.

## 5. Record the exact cause of every issue

Whenever a test starts working after debugging, I would note the exact change that fixed it.

For example, I would record whether the fix was a recompile, a corrected top-level entity name, a pin assignment change, or a switch/reset change. If the cause is uncertain, I would label it as unconfirmed rather than guessing.

## 6. Verify emergency-request timing in simulation first

Before testing emergency preemption on the physical board, I would create a testbench with shortened timing parameters.

I would specifically test that:
- An emergency request is received and stored.
- The current traffic phase completes safely.
- The controller transitions through yellow and all-red.
- The requested direction receives green.
- The emergency hold timer counts only while that direction has green.
- The controller returns to normal operation after the hold period.

This would help catch timing and state-transition bugs before hardware testing.

## 7. Verify every GPIO assignment against the board documentation

Before connecting the full breadboard, I would cross-check every GPIO-header pin in the QSF file against the official Terasic DE10-Lite documentation.

I would maintain a separate pin-mapping table showing the FPGA pin, GPIO header pin, connected component, and verification status. I would not treat a pin assignment as confirmed until it had been checked.

## 8. Validate the system feature by feature

After the individual blocks pass their tests, I would verify the integrated system in a fixed order:

1. Normal North-South and East-West traffic sequence.
2. Emergency preemption using the FPGA switches.
3. RFID-triggered emergency requests.
4. Pedestrian walk requests and clearance.
5. Emergency request during a pedestrian phase.
6. Fault injection using SW9 and recovery using KEY0.

I would record the expected and observed LED behaviour for each test.

## 9. Keep the iterations separate

I would preserve the original first-iteration files as a baseline and place all corrected or expanded implementations in Second_Iteration/.

I would also keep a short change log describing what changed, why it changed, and whether the update was verified in simulation, on the physical FPGA, or both.

## 10. Current verification priorities

For the existing first iteration, the next steps are:

- Recompile and reflash the updated Verilog containing the emergency hold-timer correction.
- Test emergency preemption using the FPGA switches.
- Test RFID-triggered requests.
- Test pedestrian requests and fault recovery.
- Verify the GPIO-header pin assignments against the DE10-Lite documentation.
- Add a testbench and capture waveforms for normal operation, emergency preemption, and fault handling.

The goal for the next iteration is a more methodical development process, with each feature tested independently before full-system integration.
