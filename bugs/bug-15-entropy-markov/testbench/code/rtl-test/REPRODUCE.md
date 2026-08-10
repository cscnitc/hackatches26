# Bug #22 - Reproduction

## Module under test
`hw/ip/entropy_src/rtl/entropy_src_markov_ht.sv`

## Bug
entropy_src_markov_ht.sv:157-158 - BOTH test_fail_hi_pulse_o and test_fail_lo_pulse_o hardwired to 1'b0. With a 40-bit ALTERNATING stream (01/10 pairs = what the hi Markov counter counts), test_cnt_hi_o reaches 20 (> thresh_hi=4) yet no failure pulse fires - the health-test failure path is dead.

## How to reproduce (Verilator 4.210, manual-clock harness)

The testbench uses the synthesizable stimulus-FSM + `main_manual.cpp`
pattern (Verilator 4.210's `--main` harness does not advance time, so the
C++ harness toggles `top->clk` explicitly; reset held 2 cycles, then the
FSM runs to completion and prints the result).

```bash
# Files: entropy_src_markov_ht_tb.sv, main_manual.cpp (this dir) + actual OpenTitan RTL + prim deps
verilator -Wno-fatal -Wno-WIDTH -Wno-UNUSED -Wno-IMPLICIT -Wno-CASEINCOMPLETE \
  -Wno-DECLFILENAME -Wno-PINMISSING -Wno-MODDUP -Wno-UNOPTFLAT -Wno-MULTIDRIVEN \
  --cc --exe --top-module tb +incdir+<ip>/rtl +incdir+... \
  <pkg/prim files in dependency order> <module>.sv entropy_src_markov_ht_tb.sv main_manual.cpp
make -C obj_dir -f Vtb.mk
./obj_dir/Vtb
```

Dependency notes: packages must precede modules (e.g. `prim_util_pkg` before
`prim_*`), generated/abstract prims come from the fuseSoC/primgen build at
`hw/build.verilator_real/src/lowrisc_prim_abstract_*`. The exact full
file list used for the confirmed run is preserved in the session build
scripts (`/tmp/build_bug*.sh` pattern); all files referenced are the
competition RTL at the paths above.

## Output (simulation.log)
```
=== After failing stream: test_fail_hi_pulse_o=0 test_cnt_hi_o=    0 ===
*** BUG #22 CONFIRMED on actual OpenTitan RTL ***
```

## Files
- `entropy_src_markov_ht_tb.sv` - testbench (synthesizable stimulus FSM, module instantiation)
- `simulation.log` - raw Verilator output (CONFIRMED token present)
- `main_manual.cpp` - manual-clock C++ harness (clk toggling, reset)

## Impact
High-threshold Markov (repetition count) health test dead - biased/stuck entropy passes health checks.
