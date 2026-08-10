# Testbench - LC state-transition testbench

**Bug:** [back to bug README](../README.md) - reproduction-focused notes below.

**Runs on: module-level (`lc_ctrl_state_transition` instantiated in the testbench)**

## Module under test

`hw/ip/lc_ctrl/rtl/lc_ctrl_state_transition.sv` 

## Bug under test

`||` combines the two replicated `TransTokenIdxMatrix` lookups instead of `&&`.

## How to build & run

```bash
vcs -full64 -sverilog -timescale=1ns/1ps \
  +incdir+<lc_ctrl/rtl> +incdir+<prim/rtl> bug-005-tb-lc-or-and.sv \
  -o sim_bug005 -q && ./sim_bug005
```
Enumerates all replica pass/fail combinations: every single-replica-corrupted case is wrongly accepted.

## Expected output

Raw logs: `logs/bug-005-vcs-compile.log` (+ simulation log under exploit/logs).

## Files

- [code/](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-07-lc-or-vs-and/testbench/code)
  - [bug-005-tb-lc-or-and.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-07-lc-or-vs-and/testbench/code/bug-005-tb-lc-or-and.sv)
  - [tb_bug05_lc_or_vs_and.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-07-lc-or-vs-and/testbench/code/tb_bug05_lc_or_vs_and.sv)
- [logs/](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-07-lc-or-vs-and/testbench/logs)
  - [bug-005-honest-vcs-simulation.log](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-07-lc-or-vs-and/testbench/logs/bug-005-honest-vcs-simulation.log)
  - [bug-005-vcs-compile.log](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-07-lc-or-vs-and/testbench/logs/bug-005-vcs-compile.log)
