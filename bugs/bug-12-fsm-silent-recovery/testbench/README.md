# Testbench - Key Manager data-enable FSM testbench

**Bug:** [back to bug README](../README.md) - reproduction-focused notes below.

**Runs on: module-level (`keymgr_data_en_state` instantiated in the testbench)**

## Module under test

`hw/ip/keymgr/rtl/keymgr_data_en_state.sv` 

## Bug under test

10-bit sparse FSM (1024 encodings, 7 legal); `default:` recovers safely but never sets `fsm_err_o`.

## How to build & run

**Verilator:** `code/rtl-test/keymgr_data_en_state_tb.sv` + `main_manual.cpp` - exercises the FSM through valid operations and verifies `fsm_err_o` stays 0 throughout (see `logs/rtl-test-simulation.log`):
```
=== After exercising FSM: fsm_err_o=0 data_hw_en_o=0 ===
*** BUG #19 CONFIRMED on actual OpenTitan RTL ***
```
AFL harness: `code/bug19_tb.sv` + `code/tb.cpp`.

## Expected output

Raw logs: `logs/simulation.log`, `logs/rtl-test-simulation.log`.

## Files

- [code/](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-12-fsm-silent-recovery/testbench/code)
  - [bug19_tb.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-12-fsm-silent-recovery/testbench/code/bug19_tb.sv)
  - [rtl-test/keymgr_data_en_state_tb.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-12-fsm-silent-recovery/testbench/code/rtl-test/keymgr_data_en_state_tb.sv)
  - [rtl-test/main_manual.cpp](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-12-fsm-silent-recovery/testbench/code/rtl-test/main_manual.cpp)
  - [tb.cpp](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-12-fsm-silent-recovery/testbench/code/tb.cpp)
  - [tb.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-12-fsm-silent-recovery/testbench/code/tb.sv)
- [logs/](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-12-fsm-silent-recovery/testbench/logs)
  - [rtl-test-simulation.log](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-12-fsm-silent-recovery/testbench/logs/rtl-test-simulation.log)
  - [simulation.log](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-12-fsm-silent-recovery/testbench/logs/simulation.log)
