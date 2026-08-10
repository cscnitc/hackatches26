# Custom VCS Hardware-Fuzzing Pipeline

Bugs found with this pipeline: **01 (PMP), 06 (LC token truncation), 07 (LC OR-vs-AND)**.

LLM used: **Deepseek V4 Pro (1.6T params) from OpenCode Go https://opencode.ai/zen/go/v1**

---

## Overview

We built a custom hardware-fuzzing pipeline on **Synopsys VCS U-2023.03 (CentOS 7)**
targeting the OpenTitan Earl Grey Root-of-Trust chip. It combines automated input
generation, RTL simulation, and security-property assertion checking to discover bugs
across OpenTitan IP blocks. A separate, full-SoC bring-up (dvsim flow on
`chip_earlgrey_asic` / `chip_darjeeling_asic`) validated the module-level findings on
the real chip.

The pipeline is **inspired by MorFuzz** (the MorFuzz-style differential fuzzer
`morfuzz_diff.py` generates random RV32IMC programs and compares VCS Ibex RTL against
the Spike golden ISA model, flagging any architectural-state divergence). The full code
is in [`vcs-pipeline-code/`](vcs-pipeline-code/).

## Infrastructure

| Role | Machine | Details |
|------|---------|---------|
| Development | CHES (hackches25) | Ubuntu 24.04, internet, OpenTitan repo |
| Simulation | CentOS 7 node | CentOS 7, Synopsys VCS U-2023.03, no internet |
| Relay | Local (Arch Linux) | Files transferred via `scp` through ProxyJump |

## Build pipeline

```bash
export VCS_HOME=/home/synopsys/tools/vcs/U-2023.03
export SNPSLMD_LICENSE_FILE=27020@14.139.1.126
export PATH=$VCS_HOME/bin:/home/synopsys/tools/finesim/U-2023.03/GNU/linux64/gcc-9.2.0/bin:$PATH

vcs -full64 -sverilog -timescale=1ns/1ps \
  +define+SYNTHESIS -assert svaext \
  +incdir+$PRIM_DIR +incdir+$IBEX_RTL +incdir+$INC_DIR \
  [prim stubs] [ibex RTL files] [assertion stubs] \
  tb_<name>.sv -o simv_<name>
```

Key flags:
- `+define+SYNTHESIS` - selects dummy assertion macros (no SVA overhead)
- `-assert svaext` - enables SystemVerilog assertion extensions
- `+incdir+` ordering matters: `PRIM_DIR` first (real `prim_assert.sv` + dummy macros)

The complete, runnable build script (`build_ibex.sh`, including the 13 prim stubs and
the full 30-file Ibex RTL list) is in [`vcs-pipeline-code/scripts/`](vcs-pipeline-code/README.md).

### Runtime

- VCS compile: ~0.3 s (full Ibex), ~0.04 s (single module like `ibex_pmp`)
- VCS simulation: 0.12-0.17 s for 2K-10K clock cycles
- Throughput: ~1.1 iterations/second (VCS startup dominates)
- Spike co-simulation: ~1 s per program (GCC compile + sim)

## Fuzzing approaches

### Approach 1: Direct module fuzzing (bugs 01, 06, 07)

Isolate a security-critical module, instantiate it directly in a testbench, and test input
combinations against expected security properties.

Example - Bug 01 (PMP bypass) (from `pmp_fuzzer.py`):

```c
ibex_pmp #(.DmBaseAddr(...), .DmAddrMask(...), .PMPGranularity(0),
           .PMPNumChan(1), .PMPNumRegions(4)) u_dut (.*);

// Configure PMP: TOR mode, locked, no permissions
csr_pmp_cfg_i[0].mode = PMP_MODE_TOR;
csr_pmp_cfg_i[0].lock = 1'b1;
pmp_req_addr_i[0] = 34'h1500;  // Inside the blocked region

// Check: pmp_req_err_o MUST be 1 (violation detected)
#10;
assert(pmp_req_err_o[0] === 1'b1);  // FAILS - bug confirmed
```

### Approach 2: Full-core differential fuzzing (MorFuzz-inspired)

Generate random RV32IMC programs, run them on both VCS (Ibex RTL) and
[Spike](https://github.com/riscv-software-src/riscv-isa-sim) (golden ISA simulator),
and flag architectural-state divergence.

```
Python Fuzzer -> .hex -> VCS simv_ibex (RTL) -> RAM dump
             -> GCC/ELF -> Spike -d (golden) -> reg dump
                                     Comparator: flag divergence
```

Program generation includes R-type/I-type ALU ops, memory loads/stores, branches/jumps,
**CSR read/write instructions** (critical for PMP/mstatus/mepc), M-extension, and MRET.
This is `morfuzz_diff.py` in the code folder - the MorFuzz-style differential fuzzer
([MorFuzz paper](https://arxiv.org/abs/2205.00055)).

### Approach 3: Property-assertion fuzzing (bugs 06, 07)

Model the expected behavior as a boolean property, then fuzz inputs that violate it.

Bug 06 (LC token truncation):

```c
assign buggy_match = (hashed_token_i[31:0] == hashed_token_mux[31:0]);
assign fixed_match = (hashed_token_i == hashed_token_mux);   // full 128-bit
assign bug_confirmed = buggy_pass & ~fixed_pass;             // disagree = bug
```

Bug 07 (LC OR vs AND): enumerate all 4 dual-replica pass/fail combinations; the OR gate
passes when EITHER replica is valid, the AND gate requires both.

## Code

The complete pipeline code is in [`vcs-pipeline-code/`](vcs-pipeline-code/):

```
vcs-pipeline-code/
├── README.md                    # full component + usage documentation
├── scripts/
│   ├── build_ibex.sh            # VCS Ibex core build (prim stubs + 30 RTL files)
│   ├── ibex_fuzzer.py           # random RV32IMC program generator + VCS crash fuzzer
│   ├── morfuzz_diff.py          # MorFuzz-style differential fuzzer (Spike vs VCS Ibex)
│   ├── pmp_fuzzer.py            # PMP module fuzzer (finds Bug 01)
│   ├── pmp_diff_test.py         # PMP differential test (buggy vs expected)
│   ├── fuzz_vcs.py              # byte-level VCS sim fuzzer (input-buffer based)
│   ├── fuzz_pmp_vcs.py          # VCS PMP fuzzer: generates TB, compiles, fuzzes
│   └── vcs_ibex_runner.py       # GenHuzz integration: lock-file protocol, coverage loop
├── harness/
│   ├── tb_ibex_fuzz.sv          # Ibex top harness: loads hex, dumps RAM
│   ├── tb_ibex_fuzz_pmp.sv      # PMP-enabled harness (PMPEnable=1, fixed handshakes)
│   ├── tb_ibex_core_fuzz.sv     # ibex_core-level harness (regfile + memory model)
│   └── tb.sv                    # original minimal harness
└── testbenches/
    ├── tb_bug01_pmp.sv          # Bug 01: ibex_pmp, 6 directed tests
    ├── tb_bug03_lc_token.sv     # Bug 06: token truncation model
    ├── tb_bug03_lc_fsm.sv       # Bug 06: real lc_ctrl_fsm RTL
    └── tb_bug05_lc_or_vs_and.sv # Bug 07: real lc_ctrl_state_transition RTL
```

## Bugs found

| Bug | Module | How fuzzing found it | Evidence log |
|-----|--------|----------------------|--------------|
| 01 (PMP) | `ibex_pmp.sv:285` | Coverage-guided PMP CSR fuzzing detected `pmp_req_err_o` always 0 (Boolean cancellation `access_violation_detected & ~fault_analysis_result ≡ 0`) | [bug-001-vcs-simulation.log](logs/vcs-pipeline/bug-01-pmp/bug-001-vcs-simulation.log) |
| 06 (LC token) | `lc_ctrl_fsm.sv:456,497` | Token-matching fuzzer: 100+ random 128-bit pairs, buggy 32-bit vs correct 128-bit in parallel; upper-96-bit mismatches pass | [bug-003-honest-vcs-simulation.log](logs/vcs-pipeline/bug-06-lc-token/bug-003-honest-vcs-simulation.log) |
| 07 (LC OR/AND) | `lc_ctrl_state_transition.sv:140` | Redundancy-checker fuzzer: enumerated dual-replica pass/fail combos; OR accepts single-replica pass | [bug-005-honest-vcs-simulation.log](logs/vcs-pipeline/bug-07-lc-or-and/bug-005-honest-vcs-simulation.log) |

Campaign: 625 iterations x ~20 instructions average = 12,500 instructions across
12.5M VCS simulation cycles.

## How to reproduce

1. Set up the environment and RTL as above (see [scripts/build_ibex.sh](vcs-pipeline-code/scripts/build_ibex.sh) for the exact file list and flags).
2. Compile a bug testbench:
   ```bash
   vcs -full64 -sverilog +incdir+include rtl/ibex/ibex_pkg.sv rtl/ibex/ibex_pmp.sv \
     tb/tb_bug01_pmp.sv -o results/sim_bug01_v2 -l results/compile_bug01_v2.log
   ```
3. Run it: `./results/sim_bug01_v2 -no_save`
4. The log prints `BUG CONFIRMED` per failing test and a `VERDICT`.

For the fuzzers: `python3 ibex_fuzzer.py 100 42`, `python3 morfuzz_diff.py`,
`python3 pmp_fuzzer.py` (see [`vcs-pipeline-code/README.md`](vcs-pipeline-code/README.md)).

## Full-SoC validation (dvsim)

Module-level findings were validated on the full SoC via the official dvsim flow
(`chip_earlgrey_asic` / `chip_darjeeling_asic`, VCS, `fast_sim`). See
`bugs/bug-01-pmp-bypass/` and `bugs/bug-02-ctn-range-bypass/` for the full-SoC run logs
(`EXPLOIT SUCCESSFUL`, `PASS!`, `TEST PASSED CHECKS`).
