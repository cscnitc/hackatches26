# Testbench - CSRNG block-encrypt testbench

**Bug:** [back to bug README](../README.md) - reproduction-focused notes below.

**Runs on: module-level (`csrng_block_encrypt` instantiated in the testbench)**

## Module under test

`hw/ip/csrng/rtl/csrng_block_encrypt.sv` 

## Bug under test

`.key_clear_i(1'b0), .key_clear_o()` - key clearing explicitly disabled, output left unconnected.

## How to build & run

**Verilator:** `code/rtl-test/csrng_block_encrypt_tb.sv` + `main_manual.cpp` - confirms the disabled zeroization path on the real module (see `logs/rtl-test-simulation.log`). AFL harness: `code/bug23_tb.sv`.

## Expected output

Raw logs: `logs/simulation.log`, `logs/rtl_evidence.log`, `logs/rtl-test-simulation.log`.

## Files

- [code/](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-16-csrng-key-remanence/testbench/code)
  - [bug23_tb.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-16-csrng-key-remanence/testbench/code/bug23_tb.sv)
  - [rtl-test/csrng_block_encrypt_tb.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-16-csrng-key-remanence/testbench/code/rtl-test/csrng_block_encrypt_tb.sv)
  - [rtl-test/main_manual.cpp](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-16-csrng-key-remanence/testbench/code/rtl-test/main_manual.cpp)
  - [tb.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-16-csrng-key-remanence/testbench/code/tb.sv)
  - [verilator.vlt](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-16-csrng-key-remanence/testbench/code/verilator.vlt)
- [logs/](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-16-csrng-key-remanence/testbench/logs)
  - [rtl-test-simulation.log](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-16-csrng-key-remanence/testbench/logs/rtl-test-simulation.log)
  - [rtl_evidence.log](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-16-csrng-key-remanence/testbench/logs/rtl_evidence.log)
  - [simulation.log](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-16-csrng-key-remanence/testbench/logs/simulation.log)
