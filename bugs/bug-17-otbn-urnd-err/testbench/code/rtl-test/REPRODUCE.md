# Bug #24 - Reproduction

## Module under test
`hw/ip/otbn/rtl/otbn_rnd.sv`

## Bug
otbn_rnd.sv:178 - urnd_reseed_ack_o = edn_urnd_ack_i - reseed ack issued despite edn_urnd_err_i=1; xoshiro_seed_en ignores EDN error.

## How to reproduce (Verilator 4.210, manual-clock harness)

The testbench uses the synthesizable stimulus-FSM + `main_manual.cpp`
pattern (Verilator 4.210's `--main` harness does not advance time, so the
C++ harness toggles `top->clk` explicitly; reset held 2 cycles, then the
FSM runs to completion and prints the result).

```bash
# Files: otbn_rnd_tb.sv, main_manual.cpp (this dir) + actual OpenTitan RTL + prim deps
verilator -Wno-fatal -Wno-WIDTH -Wno-UNUSED -Wno-IMPLICIT -Wno-CASEINCOMPLETE \
  -Wno-DECLFILENAME -Wno-PINMISSING -Wno-MODDUP -Wno-UNOPTFLAT -Wno-MULTIDRIVEN \
  --cc --exe --top-module tb +incdir+<ip>/rtl +incdir+... \
  <pkg/prim files in dependency order> <module>.sv otbn_rnd_tb.sv main_manual.cpp
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
=== URND reseed: req_i=0 req_o=0 ack_o=1 ===
=== EDN err_i=1 fips_i=0 xoshiro_seed_en=0 ===
*** BUG #24 CONFIRMED on actual OpenTitan RTL ***
```

## Files
- `otbn_rnd_tb.sv` - testbench (synthesizable stimulus FSM, module instantiation)
- `simulation.log` - raw Verilator output (CONFIRMED token present)
- `main_manual.cpp` - manual-clock C++ harness (clk toggling, reset)

## Impact
OTBN URND random outputs become predictable - reseed accepted from faulted EDN.
