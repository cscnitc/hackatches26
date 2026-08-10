# Testbench - CTN range-check testbench

**Bug:** [back to bug README](../README.md) - reproduction-focused notes below.

**Runs on: module-level (`ac_range_check` instantiated in the testbench); full-SoC dvsim run in the exploit**

## Module under test

`hw/top_darjeeling/ip_autogen/ac_range_check/rtl/ac_range_check.sv` (generated from `hw/ip_templates/ac_range_check/rtl/ac_range_check.sv.tpl`; wired from `hw/top_darjeeling/templates/chiplevel.sv.tpl:844`)

## Bug under test

With overwrite `MuBi8True` the grant is UNCONDITIONAL - an out-of-range access (`addr=0xdeadbeef`, policy=0) passes the check.

## How to build & run

**Verilator:** `code/rtl-test/ac_range_check_tb.sv` + `main_manual.cpp` - see `logs/rtl-test-simulation.log`:
```
=== CTN access-range check ===
  range_check_overwrite_i = 0x96 (MuBi8True=1)
  a_valid=1 addr=0xdeadbeef (OUTSIDE allowed ranges, policy=0)
  range_check_grant (internal) = 1 (BUG: should be 0 - request denied)
*** BUG #8 CONFIRMED on actual OpenTitan RTL ***
```
**AFL harness:** `code/bug8_tb.sv` + `code/tb.sv` + `verilator.vlt`.

## Expected output

Raw logs: `logs/simulation.log`, `logs/rtl_evidence.log`, `logs/rtl-test-simulation.log`.

## Files

- [code/](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-02-ctn-range-bypass/testbench/code)
  - [bug8_tb.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-02-ctn-range-bypass/testbench/code/bug8_tb.sv)
  - [rtl-test/ac_range_check_tb.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-02-ctn-range-bypass/testbench/code/rtl-test/ac_range_check_tb.sv)
  - [rtl-test/main_manual.cpp](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-02-ctn-range-bypass/testbench/code/rtl-test/main_manual.cpp)
  - [tb.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-02-ctn-range-bypass/testbench/code/tb.sv)
  - [verilator.vlt](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-02-ctn-range-bypass/testbench/code/verilator.vlt)
- [logs/](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-02-ctn-range-bypass/testbench/logs)
  - [rtl-test-simulation.log](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-02-ctn-range-bypass/testbench/logs/rtl-test-simulation.log)
  - [rtl_evidence.log](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-02-ctn-range-bypass/testbench/logs/rtl_evidence.log)
  - [simulation.log](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-02-ctn-range-bypass/testbench/logs/simulation.log)
