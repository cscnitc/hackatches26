# Testbench - Debug-module CSRs testbench

**Bug:** [back to bug README](../README.md) - reproduction-focused notes below.

**Runs on: module-level (`dm_csrs` instantiated in the testbench); full-SoC OpenOCD evidence in the exploit**

## Module under test

`hw/vendor/pulp_riscv_dbg/src/dm_csrs.sv` (competition RTL, MD5-verified)

## Bug under test

`dmstatus.authenticated = 1'b1` hardwired, with `AuthData` (0x30) never handled in any read/write case.

## How to build & run

**Verilator:** `code/rtl-test/dm_csrs_tb.sv` + `main_manual.cpp`:
```bash
verilator -Wno-fatal -Wno-WIDTH -Wno-UNUSED -Wno-IMPLICIT \
  -Wno-CASEINCOMPLETE -Wno-DECLFILENAME -Wno-PINMISSING -Wno-MODDUP \
  --cc --exe --top-module tb \
  +incdir+hw/vendor/pulp_riscv_dbg/src +incdir+hw/ip/prim/rtl +incdir+hw/ip/prim_generic/rtl \
  prim_pkg.sv prim_flop.sv prim_generic_flop.sv prim_flop_en.sv prim_generic_flop_en.sv \
  prim_count_pkg.sv prim_count.sv prim_util_pkg.sv dm_pkg.sv \
  prim_fifo_sync.sv prim_fifo_sync_cnt.sv dm_csrs.sv dm_csrs_tb.sv main_manual.cpp
make -C obj_dir -f Vtb.mk && ./obj_dir/Vtb
```
Output: `*** BUG #2 CONFIRMED on actual OpenTitan RTL ***` - DMI read of DMSTATUS returns `authenticated=1` with NO AuthData handshake (see `logs/rtl-test-simulation.log`).

## Expected output

Raw logs: `logs/simulation.log`, `logs/rtl_evidence.log`, `logs/rtl-test-simulation.log`.

## Files

- [code/](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-05-dm-no-auth/testbench/code)
  - [Makefile](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-05-dm-no-auth/testbench/code/Makefile)
  - [bug2_tb.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-05-dm-no-auth/testbench/code/bug2_tb.sv)
  - [rtl-test/dm_csrs_tb.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-05-dm-no-auth/testbench/code/rtl-test/dm_csrs_tb.sv)
  - [rtl-test/main_manual.cpp](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-05-dm-no-auth/testbench/code/rtl-test/main_manual.cpp)
  - [tb.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-05-dm-no-auth/testbench/code/tb.sv)
  - [verilator.vlt](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-05-dm-no-auth/testbench/code/verilator.vlt)
- [logs/](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-05-dm-no-auth/testbench/logs)
  - [rtl-test-simulation.log](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-05-dm-no-auth/testbench/logs/rtl-test-simulation.log)
  - [rtl_evidence.log](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-05-dm-no-auth/testbench/logs/rtl_evidence.log)
  - [simulation.log](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-05-dm-no-auth/testbench/logs/simulation.log)
