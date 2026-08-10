# Testbench - LC signal-decode testbench

**Bug:** [back to bug README](../README.md) - reproduction-focused notes below.

**Runs on: module-level (`lc_ctrl_signal_decode` instantiated in the testbench)**

## Module under test

`hw/ip/lc_ctrl/rtl/lc_ctrl_signal_decode.sv` 

## Bug under test

`LcStProd` appears in both the test-unlocked branch (line 116, enables debug/DFT) and the production branch (line 139) of one `unique case`.

## How to build & run

**Verilator:** `code/rtl-test/lc_ctrl_signal_decode_tb.sv` + `main_manual.cpp` - exercises the decode in `LcStProd` and observes the ambiguous outputs (see `logs/rtl-test-simulation.log`). AFL harness `code/bug7_tb.sv` + `tb.sv` + `verilator.vlt` also provided.

## Expected output

Raw logs: `logs/simulation.log`, `logs/rtl_evidence.log`, `logs/rtl-test-simulation.log`.

## Files

- [code/](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-08-lcstprod-duplicate/testbench/code)
  - [Makefile](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-08-lcstprod-duplicate/testbench/code/Makefile)
  - [bug7_tb.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-08-lcstprod-duplicate/testbench/code/bug7_tb.sv)
  - [rtl-test/lc_ctrl_signal_decode_tb.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-08-lcstprod-duplicate/testbench/code/rtl-test/lc_ctrl_signal_decode_tb.sv)
  - [rtl-test/main_manual.cpp](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-08-lcstprod-duplicate/testbench/code/rtl-test/main_manual.cpp)
  - [tb.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-08-lcstprod-duplicate/testbench/code/tb.sv)
  - [verilator.vlt](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-08-lcstprod-duplicate/testbench/code/verilator.vlt)
- [logs/](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-08-lcstprod-duplicate/testbench/logs)
  - [rtl-test-simulation.log](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-08-lcstprod-duplicate/testbench/logs/rtl-test-simulation.log)
  - [rtl_evidence.log](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-08-lcstprod-duplicate/testbench/logs/rtl_evidence.log)
  - [simulation.log](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-08-lcstprod-duplicate/testbench/logs/simulation.log)
