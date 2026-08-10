# Testbench - AES S-Box DOM testbenches

**Bug:** [back to bug README](../README.md) - reproduction-focused notes below.

**Runs on: module-level (`aes_sbox_dom` and the `aes_cipher_core` closure instantiated in the testbenches)**

## Module under test

`hw/ip/aes/rtl/aes_sbox_dom.sv` (module-level) and `hw/ip/aes/rtl/aes_cipher_core.sv` (~31-module closure, VCS DFA setup)

## Bug under test

`count_q` is a plain 3-bit binary counter (no parity/Hamming/`err_o`) gating `we[0:3]`/`out_req_o`; a single-bit flip skips/repeats S-Box stages.

## How to build & run

**Verilator:** `code/rtl-test/aes_sbox_dom_tb.sv` + `main_manual.cpp` (see `logs/rtl-test-simulation.log`).
**AFL harness:** `code/bug17_tb.sv` + `code/tb.cpp` (fault value 0x40 triggers stage skip in <10 s).
**VCS full-core DFA rig:** `code/aes_dfa_tb.sv` + `code/build_aes_core.sh` - built the `aes_cipher_core`, verified FIPS-197 KAT (`69c4e0d86a7b0430d8cdb78070b4c55a`), then produced the faulted ciphertexts for `dfa_recover.py` (see exploit/logs).

## Expected output

Raw logs: `logs/simulation.log`, `logs/rtl-test-simulation.log`.

## Files

- [code/](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-10-aes-sbox-dfa/testbench/code)
  - [aes_dfa_tb.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-10-aes-sbox-dfa/testbench/code/aes_dfa_tb.sv)
  - [bug17_tb.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-10-aes-sbox-dfa/testbench/code/bug17_tb.sv)
  - [build_aes_core.sh](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-10-aes-sbox-dfa/testbench/code/build_aes_core.sh)
  - [rtl-test/aes_sbox_dom_tb.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-10-aes-sbox-dfa/testbench/code/rtl-test/aes_sbox_dom_tb.sv)
  - [rtl-test/main_manual.cpp](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-10-aes-sbox-dfa/testbench/code/rtl-test/main_manual.cpp)
  - [tb.cpp](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-10-aes-sbox-dfa/testbench/code/tb.cpp)
  - [tb.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-10-aes-sbox-dfa/testbench/code/tb.sv)
- [logs/](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-10-aes-sbox-dfa/testbench/logs)
  - [rtl-test-simulation.log](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-10-aes-sbox-dfa/testbench/logs/rtl-test-simulation.log)
  - [simulation.log](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-10-aes-sbox-dfa/testbench/logs/simulation.log)
