# Testbench - AES core testbenches

**Bug:** [back to bug README](../README.md) - reproduction-focused notes below.

**Runs on: module-level (`aes_core` instantiated in the testbench)**

## Module under test

`hw/ip/aes/rtl/aes_core.sv` (`data_out_reg` block)

## Bug under test

Conditional reset: `if (!rst_ni && data_out_we != SP2V_HIGH) ... else if (data_out_we == SP2V_HIGH) data_out_q <= data_out_d;` - write during reset.

## How to build & run

**Verilator:** `code/rtl-test/aes_core_glitch_tb.sv` +
`aes_reset_glitch_main.cpp` - runs a REAL AES-128 encryption, waits for
`data_out_we == SP2V_HIGH` on the completion cycle (t=14), asserts reset
exactly there, and reads back `data_out_q` (see `logs/rtl-test-simulation.log`:
before glitch `0x000..0`, after glitch `0x1a30325e...` - ciphertext survives).
The old TB (which never hit the bug condition and printed CONFIRMED
unconditionally) is removed.
**AFL harnesses:** `code/bug16_tb.sv` (model) and `code/bug16_real_tb.sv` (RTL) + `code/tb.cpp` (`tb_debug.cpp` available); crash input in `logs/afl-crash_input.bin`.

## Expected output

Raw logs: `logs/simulation.log`, `logs/rtl-test-simulation.log`, `logs/afl-fuzzer_stats`.

## Files

- [code/](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-09-aes-reset-bypass/testbench/code)
  - [bug16_real_tb.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-09-aes-reset-bypass/testbench/code/bug16_real_tb.sv)
  - [bug16_tb.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-09-aes-reset-bypass/testbench/code/bug16_tb.sv)
  - [rtl-test/aes_core_glitch_tb.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-09-aes-reset-bypass/testbench/code/rtl-test/aes_core_glitch_tb.sv)
  - [rtl-test/aes_reset_glitch_main.cpp](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-09-aes-reset-bypass/testbench/code/rtl-test/aes_reset_glitch_main.cpp)
  - [tb.cpp](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-09-aes-reset-bypass/testbench/code/tb.cpp)
  - [tb.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-09-aes-reset-bypass/testbench/code/tb.sv)
- [logs/](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-09-aes-reset-bypass/testbench/logs)
  - [afl-crash_input.bin](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-09-aes-reset-bypass/testbench/logs/afl-crash_input.bin)
  - [afl-fuzzer_stats](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-09-aes-reset-bypass/testbench/logs/afl-fuzzer_stats)
  - [afl-inputs.txt](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-09-aes-reset-bypass/testbench/logs/afl-inputs.txt)
  - [rtl-test-simulation.log](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-09-aes-reset-bypass/testbench/logs/rtl-test-simulation.log)
  - [simulation.log](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-09-aes-reset-bypass/testbench/logs/simulation.log)
