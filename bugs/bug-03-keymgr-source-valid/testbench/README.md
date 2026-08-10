# Testbench - Key Manager input checks testbench

**Bug:** [back to bug README](../README.md) - reproduction-focused notes below.

**Runs on: module-level (`keymgr_input_checks` instantiated in the testbench)**

## Module under test

`hw/ip/keymgr/rtl/keymgr_input_checks.sv` 

## Bug under test

`key_vld_o` asserts (=1) despite `valid=0` on the key input - key material is accepted without validation.

## How to build & run

**Verilator:** `code/rtl-test/keymgr_input_checks_tb.sv` + `main_manual.cpp` - see `logs/rtl-test-simulation.log`:
```
*** BUG #10 CONFIRMED on actual OpenTitan RTL ***
```
**AFL differential pair:** `code/keymgr_key_check_buggy.sv` vs `code/keymgr_key_check_fixed.sv` (fixed: `key_vld_o = key_i.valid & &key_chk`), fed by AFL - 2 unique crash inputs in ~60 s; see `logs/afl-fuzzer_stats`.

## Expected output

Raw logs: `logs/simulation.log`, `logs/rtl-test-simulation.log`, `logs/afl-fuzzer_stats`, `logs/afl-inputs.txt`.

## Files

- [code/](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-03-keymgr-source-valid/testbench/code)
  - [Makefile](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-03-keymgr-source-valid/testbench/code/Makefile)
  - [keymgr_key_check_buggy.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-03-keymgr-source-valid/testbench/code/keymgr_key_check_buggy.sv)
  - [keymgr_key_check_fixed.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-03-keymgr-source-valid/testbench/code/keymgr_key_check_fixed.sv)
  - [rtl-test/keymgr_input_checks_tb.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-03-keymgr-source-valid/testbench/code/rtl-test/keymgr_input_checks_tb.sv)
  - [rtl-test/main_manual.cpp](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-03-keymgr-source-valid/testbench/code/rtl-test/main_manual.cpp)
  - [tb.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-03-keymgr-source-valid/testbench/code/tb.sv)
  - [top.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-03-keymgr-source-valid/testbench/code/top.sv)
- [logs/](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-03-keymgr-source-valid/testbench/logs)
  - [afl-fuzzer_stats](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-03-keymgr-source-valid/testbench/logs/afl-fuzzer_stats)
  - [afl-inputs.txt](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-03-keymgr-source-valid/testbench/logs/afl-inputs.txt)
  - [rtl-test-simulation.log](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-03-keymgr-source-valid/testbench/logs/rtl-test-simulation.log)
  - [simulation.log](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-03-keymgr-source-valid/testbench/logs/simulation.log)
