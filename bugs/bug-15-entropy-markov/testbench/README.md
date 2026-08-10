# Testbench - Entropy-source Markov health test testbench

**Bug:** [back to bug README](../README.md) - reproduction-focused notes below.

**Runs on: module-level (`entropy_src_markov_ht` instantiated in the testbench)**

## Module under test

`hw/ip/entropy_src/rtl/entropy_src_markov_ht.sv` 

## Bug under test

`test_fail_hi_pulse_o` hardwired 0; `>=` instead of `>` comparison - the threshold value itself cannot trigger a failure.

## How to build & run

**Verilator:** `code/rtl-test/entropy_src_markov_ht_tb.sv` + `main_manual.cpp` - drives a genuinely-FAILING stream (40 ALTERNATING bits = 20 01/10 pairs, exceeding `thresh_hi=4`;
the earlier identical-bits stimulus was wrong - the hi counter counts transitions) and observes `test_fail_hi_pulse_o` stays 0 (see `logs/rtl-test-simulation.log`):
```
*** BUG #22 CONFIRMED on actual OpenTitan RTL ***
```
AFL harness: `code/bug22_tb.sv` + `code/tb.sv` + `verilator.vlt`.

## Expected output

Raw logs: `logs/simulation.log`, `logs/rtl_evidence.log`, `logs/rtl-test-simulation.log`.

## Files

- [code/](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-15-entropy-markov/testbench/code)
  - [bug22_tb.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-15-entropy-markov/testbench/code/bug22_tb.sv)
  - [rtl-test/REPRODUCE.md](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-15-entropy-markov/testbench/code/rtl-test/REPRODUCE.md)
  - [rtl-test/entropy_src_markov_ht_tb.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-15-entropy-markov/testbench/code/rtl-test/entropy_src_markov_ht_tb.sv)
  - [rtl-test/main_manual.cpp](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-15-entropy-markov/testbench/code/rtl-test/main_manual.cpp)
  - [tb.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-15-entropy-markov/testbench/code/tb.sv)
  - [verilator.vlt](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-15-entropy-markov/testbench/code/verilator.vlt)
- [logs/](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-15-entropy-markov/testbench/logs)
  - [rtl-test-simulation.log](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-15-entropy-markov/testbench/logs/rtl-test-simulation.log)
  - [rtl_evidence.log](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-15-entropy-markov/testbench/logs/rtl_evidence.log)
  - [simulation.log](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-15-entropy-markov/testbench/logs/simulation.log)
