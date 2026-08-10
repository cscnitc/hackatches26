# Testbench - AES masking-PRNG testbench

**Bug:** [back to bug README](../README.md) - reproduction-focused notes below.

**Runs on: module-level (`aes_prng_masking` instantiated in the testbench)**

## Module under test

`hw/ip/aes/rtl/aes_prng_masking.sv` (parameter set by `chip_earlgrey_verilator.sv:499` `SecAesAllowForcingMasks=1'b1`)

## Bug under test

`allow_lockup_i = SecAllowForcingMasks & force_masks_i` with `StrictLockupProtection=0`: force_masks=1 + zero seed - all-zero masks KEPT.

## How to build & run

**Verilator:** `code/rtl-test/aes_prng_masking_tb.sv` + `main_manual.cpp` - see `logs/rtl-test-simulation.log`:
```
=== AES masking PRNG (SecAllowForcingMasks=1) ===
  Phase A (force_masks=0, zero seed): mask=0xaf04... (auto-restored)
  Phase B (force_masks=1, zero seed): mask=0x0000... (lockup kept)
*** BUG #15 CONFIRMED on actual OpenTitan RTL ***
```
**AFL model:** `code/aes_prng_bug15_model.sv` + `code/bug15_tb.sv`; crash input in `logs/afl-crash_input.bin`.

## Expected output

Raw logs: `logs/simulation.log`, `logs/rtl-test-simulation.log`, `logs/afl-fuzzer_stats`.

## Files

- [code/](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-04-aes-force-masks/testbench/code)
  - [aes_prng_bug15_model.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-04-aes-force-masks/testbench/code/aes_prng_bug15_model.sv)
  - [bug15_tb.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-04-aes-force-masks/testbench/code/bug15_tb.sv)
  - [ctrlavx_shadowed.vlt](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-04-aes-force-masks/testbench/code/ctrlavx_shadowed.vlt)
  - [rtl-test/aes_prng_masking_tb.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-04-aes-force-masks/testbench/code/rtl-test/aes_prng_masking_tb.sv)
  - [rtl-test/main_manual.cpp](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-04-aes-force-masks/testbench/code/rtl-test/main_manual.cpp)
  - [tb.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-04-aes-force-masks/testbench/code/tb.sv)
- [logs/](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-04-aes-force-masks/testbench/logs)
  - [afl-crash_input.bin](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-04-aes-force-masks/testbench/logs/afl-crash_input.bin)
  - [afl-fuzzer_stats](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-04-aes-force-masks/testbench/logs/afl-fuzzer_stats)
  - [afl-inputs.txt](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-04-aes-force-masks/testbench/logs/afl-inputs.txt)
  - [rtl-test-simulation.log](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-04-aes-force-masks/testbench/logs/rtl-test-simulation.log)
  - [simulation.log](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-04-aes-force-masks/testbench/logs/simulation.log)
