# Testbench - PMP testbench

**Bug:** [back to bug README](../README.md) - reproduction-focused notes below.

**Runs on: module-level (`ibex_pmp` instantiated in the testbench)**

## Module under test

`hw/vendor/lowrisc_ibex/rtl/ibex_pmp.sv`

## Bug under test

`pmp_req_err_o = access_violation_detected & ~fault_analysis_result ≡ 0`. No PMP violation ever reports an error.

## How to build & run

```bash
vcs -full64 -sverilog -timescale=1ns/1ps \
  +incdir+$PRIM_DIR +incdir+$IBEX_RTL \
  ibex_pkg.sv ibex_pmp.sv tb_bug01_pmp.sv -o sim_bug001 -q
./sim_bug001
```
7 directed test cases: read / write / execute / M-mode / locked-region violations - `pmp_req_err_o` stays 0 in every violation case.

## Expected output

Raw VCS logs: `logs/bug-001-vcs-compile.log`, `logs/bug-001-vcs-simulation.log`.

## Files

- [code/](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-01-pmp-bypass/testbench/code)
  - [tb_bug01_pmp.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-01-pmp-bypass/testbench/code/tb_bug01_pmp.sv)
  - [tb_bug01_pmp.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-01-pmp-bypass/testbench/code/tb_bug01_pmp.sv)
- [logs/](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-01-pmp-bypass/testbench/logs)
  - [bug-001-vcs-compile.log](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-01-pmp-bypass/testbench/logs/bug-001-vcs-compile.log)
  - [bug-001-vcs-simulation.log](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-01-pmp-bypass/testbench/logs/bug-001-vcs-simulation.log)
