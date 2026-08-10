# Testbench - ROM controller compare testbench

**Bug:** [back to bug README](../README.md) - reproduction-focused notes below.

**Runs on: module-level (`rom_ctrl_compare` instantiated in the testbench)**

## Module under test

`hw/ip/rom_ctrl/rtl/rom_ctrl_compare.sv` 

## Bug under test

`matches_q` single-bit flip-flop holds the whole digest-match decision - no ECC / dual-rail / redundancy; only parameter is `NumWords`.

## How to build & run

**Verilator:** `code/rtl-test/rom_ctrl_compare_tb.sv` + `main_manual.cpp` (see `logs/rtl-test-simulation.log`):
```
=== Case 1 (matching): done_o=0 good_o=1001 ===
=== Case 2 (MISMATCH): done_o=1 good_o=1001 ===
*** BUG #21 VULNERABILITY CONFIRMED on the RTL ***
```
AFL harness: `code/bug21_tb.sv` + `code/tb.sv` + `verilator.vlt`.

## Expected output

Raw logs: `logs/simulation.log`, `logs/rtl_evidence.log`, `logs/rtl-test-simulation.log`.

## Files

- [code/](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-14-rom-ctrl-compare/testbench/code)
  - [bug21_tb.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-14-rom-ctrl-compare/testbench/code/bug21_tb.sv)
  - [rtl-test/main_manual.cpp](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-14-rom-ctrl-compare/testbench/code/rtl-test/main_manual.cpp)
  - [rtl-test/rom_ctrl_compare_tb.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-14-rom-ctrl-compare/testbench/code/rtl-test/rom_ctrl_compare_tb.sv)
  - [tb.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-14-rom-ctrl-compare/testbench/code/tb.sv)
  - [verilator.vlt](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-14-rom-ctrl-compare/testbench/code/verilator.vlt)
- [logs/](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-14-rom-ctrl-compare/testbench/logs)
  - [rtl-test-simulation.log](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-14-rom-ctrl-compare/testbench/logs/rtl-test-simulation.log)
  - [rtl_evidence.log](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-14-rom-ctrl-compare/testbench/logs/rtl_evidence.log)
  - [simulation.log](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-14-rom-ctrl-compare/testbench/logs/simulation.log)
