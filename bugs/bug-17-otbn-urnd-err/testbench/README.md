# Testbench - OTBN RND testbench

**Bug:** [back to bug README](../README.md) - reproduction-focused notes below.

**Runs on: module-level (`otbn_rnd` instantiated in the testbench)**

## Module under test

`hw/ip/otbn/rtl/otbn_rnd.sv` 

## Bug under test

`urnd_reseed_ack_o = edn_urnd_ack_i` - ACK issued despite `edn_urnd_err_i=1`; error outputs set but never consulted by the URND path.

## How to build & run

**Verilator:** `code/rtl-test/otbn_rnd_tb.sv` + `main_manual.cpp` - drives a reseed with `edn_urnd_err_i=1`, LATCHES the seed-enable pulse and the
EDN error during the handshake (see `logs/rtl-test-simulation.log`:
`xoshiro_seed_en was seen HIGH during tx: 1 (latched)`, `err latched: 1`) (see `logs/rtl-test-simulation.log`):
```
=== URND reseed: req_i=0 req_o=0 ack_o=1 ===
=== EDN err_i=1 fips_i=0 xoshiro_seed_en=0 ===
*** BUG #24 CONFIRMED on actual OpenTitan RTL ***
```
AFL harness: `code/bug24_tb.sv` + `code/tb.sv` + `verilator.vlt`.

## Expected output

Raw logs: `logs/simulation.log`, `logs/rtl_evidence.log`, `logs/rtl-test-simulation.log`.

## Files

- [code/](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-17-otbn-urnd-err/testbench/code)
  - [bug24_tb.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-17-otbn-urnd-err/testbench/code/bug24_tb.sv)
  - [rtl-test/REPRODUCE.md](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-17-otbn-urnd-err/testbench/code/rtl-test/REPRODUCE.md)
  - [rtl-test/main_manual.cpp](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-17-otbn-urnd-err/testbench/code/rtl-test/main_manual.cpp)
  - [rtl-test/otbn_rnd_tb.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-17-otbn-urnd-err/testbench/code/rtl-test/otbn_rnd_tb.sv)
  - [tb.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-17-otbn-urnd-err/testbench/code/tb.sv)
  - [verilator.vlt](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-17-otbn-urnd-err/testbench/code/verilator.vlt)
- [logs/](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-17-otbn-urnd-err/testbench/logs)
  - [rtl-test-simulation.log](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-17-otbn-urnd-err/testbench/logs/rtl-test-simulation.log)
  - [rtl_evidence.log](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-17-otbn-urnd-err/testbench/logs/rtl_evidence.log)
  - [simulation.log](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-17-otbn-urnd-err/testbench/logs/simulation.log)
