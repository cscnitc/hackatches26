# Testbench - CSRNG block-encrypt testbench

**Bug:** [back to bug README](../README.md) - reproduction-focused notes below.

**Runs on: module-level (`csrng_block_encrypt` instantiated in the testbench)**

## Module under test

`hw/ip/csrng/rtl/csrng_block_encrypt.sv` 

## Bug under test

`aes_cipher_core` instantiated with `.SecMasking(1'b0)` - masking explicitly disabled inside the CSRNG.

## How to build & run

**Verilator:** `code/rtl-test/csrng_block_encrypt_tb.sv` + `main_manual.cpp` - compiles the real module closure and confirms the unmasked instantiation (see `logs/rtl-test-simulation.log`). AFL harness: `code/bug20_tb.sv`.

## Expected output

Raw logs: `logs/simulation.log`, `logs/rtl_evidence.log`, `logs/rtl-test-simulation.log`.

## Files

- [code/](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-13-csrng-unmasked/testbench/code)
  - [bug20_tb.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-13-csrng-unmasked/testbench/code/bug20_tb.sv)
  - [rtl-test/csrng_block_encrypt_tb.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-13-csrng-unmasked/testbench/code/rtl-test/csrng_block_encrypt_tb.sv)
  - [rtl-test/main_manual.cpp](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-13-csrng-unmasked/testbench/code/rtl-test/main_manual.cpp)
  - [tb.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-13-csrng-unmasked/testbench/code/tb.sv)
  - [verilator.vlt](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-13-csrng-unmasked/testbench/code/verilator.vlt)
- [logs/](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-13-csrng-unmasked/testbench/logs)
  - [rtl-test-simulation.log](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-13-csrng-unmasked/testbench/logs/rtl-test-simulation.log)
  - [rtl_evidence.log](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-13-csrng-unmasked/testbench/logs/rtl_evidence.log)
  - [simulation.log](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-13-csrng-unmasked/testbench/logs/simulation.log)
