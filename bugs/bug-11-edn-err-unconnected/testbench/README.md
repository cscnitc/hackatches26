# Testbench - Key Manager reseed testbench

**Bug:** [back to bug README](../README.md) - reproduction-focused notes below.

**Runs on: module-level (`keymgr_reseed_ctrl` instantiated in the testbench)**

## Module under test

`hw/ip/keymgr/rtl/keymgr_reseed_ctrl.sv` 

## Bug under test

`prim_edn_req #(.RepCheck(0)) u_edn_req (..., .err_o(), ...)` - error output unconnected; `cnt_err_o` is a dead-end local signal.

## How to build & run

**Verilator:** `code/rtl-test/keymgr_reseed_ctrl_tb.sv` + `main_manual.cpp` - drives a reseed request, simulates EDN FIPS error (`edn_fips=1`), observes `cnt_err_o` stays 0 (see `logs/rtl-test-simulation.log`):
```
*** BUG #18 CONFIRMED on actual OpenTitan RTL ***
```
AFL harness: `code/bug18_tb.sv` + `code/tb.sv` + `code/tb.cpp`.

## Expected output

Raw logs: `logs/simulation.log`, `logs/rtl-test-simulation.log`.

## Files

- [code/](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-11-edn-err-unconnected/testbench/code)
  - [bug18_tb.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-11-edn-err-unconnected/testbench/code/bug18_tb.sv)
  - [rtl-test/keymgr_reseed_ctrl_tb.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-11-edn-err-unconnected/testbench/code/rtl-test/keymgr_reseed_ctrl_tb.sv)
  - [rtl-test/main_manual.cpp](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-11-edn-err-unconnected/testbench/code/rtl-test/main_manual.cpp)
  - [tb.cpp](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-11-edn-err-unconnected/testbench/code/tb.cpp)
  - [tb.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-11-edn-err-unconnected/testbench/code/tb.sv)
- [logs/](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-11-edn-err-unconnected/testbench/logs)
  - [rtl-test-simulation.log](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-11-edn-err-unconnected/testbench/logs/rtl-test-simulation.log)
  - [simulation.log](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-11-edn-err-unconnected/testbench/logs/simulation.log)
