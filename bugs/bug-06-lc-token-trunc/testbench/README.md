# Testbench - LC FSM token testbenches

**Bug:** [back to bug README](../README.md) - reproduction-focused notes below.

**Runs on: module-level (`lc_ctrl_fsm` instantiated in the testbench)**

## Module under test

`hw/ip/lc_ctrl/rtl/lc_ctrl_fsm.sv` (PROD-RMA); toy comparison model in `bug-003-tb-token-trunc.sv`

## Bug under test

`hashed_token_i[31:0] == hashed_token_mux[31:0]` - tokens differing only in the upper 96 bits still match.

## How to build & run

```bash
# VCS (module-level):
vcs -full64 -sverilog -timescale=1ns/1ps \
  +incdir+<lc_ctrl/rtl> +incdir+<prim/rtl> tb_bug03_lc_fsm.sv \
  prim_flop.sv prim_flop_2sync.sv -o sim_bug03_fsm -q && ./sim_bug03_fsm
# Standalone comparison model (VCS):
vcs -full64 -sverilog -timescale=1ns/1ps bug-003-tb-token-trunc.sv \
  -o sim_bug03 -q && ./sim_bug03   # 100+ token pairs, partial matches pass
```

## Expected output

Raw logs: `logs/bug-003-vcs-compile.log`, `logs/bug-003-lc-fsm-vcs-compile.log` (+ simulation logs under exploit/logs).

## Files

- [code/](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-06-lc-token-trunc/testbench/code)
  - [bug-003-tb-token-trunc.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-06-lc-token-trunc/testbench/code/bug-003-tb-token-trunc.sv)
  - [prim_flop.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-06-lc-token-trunc/testbench/code/prim_flop.sv)
  - [prim_flop_2sync.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-06-lc-token-trunc/testbench/code/prim_flop_2sync.sv)
  - [tb_bug03_lc_fsm.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-06-lc-token-trunc/testbench/code/tb_bug03_lc_fsm.sv)
  - [tb_bug03_lc_token.sv](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-06-lc-token-trunc/testbench/code/tb_bug03_lc_token.sv)
- [logs/](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-06-lc-token-trunc/testbench/logs)
  - [bug-003-honest-vcs-simulation.log](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-06-lc-token-trunc/testbench/logs/bug-003-honest-vcs-simulation.log)
  - [bug-003-lc-fsm-vcs-compile.log](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-06-lc-token-trunc/testbench/logs/bug-003-lc-fsm-vcs-compile.log)
  - [bug-003-vcs-compile.log](https://github.com/cscnitc/hackatches26/blob/main/bugs/bug-06-lc-token-trunc/testbench/logs/bug-003-vcs-compile.log)
