# Custom VCS + MorFuzz-Style Hardware Fuzzing Pipeline

Custom automation tooling developed for Hack@CHES 2026. This is the
in-house VCS-based fuzzing framework used to detect the submitted bugs on a
CentOS 7 node (Synopsys VCS U-2023.03).

**This pipeline qualifies for the custom automation tool bonus (100 pts):**
it is a self-developed fuzzing methodology (custom program generation,
differential co-simulation, and property-based module fuzzing) built on top of
the existing VCS simulator (separate 50-pt existing-tool bonus).

---

## Components

```
custom-pipeline/
├── scripts/
│   ├── ibex_fuzzer.py        -> Random RV32IMC program generator + VCS crash fuzzer
│   ├── morfuzz_diff.py       -> MorFuzz-style differential fuzzer: Spike (golden) vs VCS Ibex
│   ├── pmp_fuzzer.py         -> PMP module fuzzer: builds ibex_pmp TB, fuzzes CSR configs (Bug-001)
│   ├── pmp_diff_test.py      -> PMP differential test: buggy ibex_pmp vs expected behavior
│   ├── fuzz_vcs.py           -> Byte-level VCS sim fuzzer (input-buffer based)
│   ├── fuzz_pmp_vcs.py       -> VCS PMP fuzzer: generates fuzz TB, compiles, fuzzes
│   ├── vcs_ibex_runner.py    -> GenHuzz integration: lock-file protocol, VCS+Spike coverage loop
│   └── build_ibex.sh         -> Builds the VCS Ibex core simulation (simv_ibex)
├── harness/
│   ├── tb_ibex_fuzz.sv       -> Ibex top harness: loads ibex_program.hex, dumps RAM
│   ├── tb_ibex_fuzz_pmp.sv   -> PMP-enabled harness (PMPEnable=1, fixed handshakes)
│   ├── tb_ibex_core_fuzz.sv  -> ibex_core-level harness with regfile + memory model
│   └── tb.sv                 -> Original minimal harness
└── testbenches/
    ├── tb_bug01_pmp.sv       -> Directed testbench: Bug-001 (ibex_pmp, 6 tests)
    ├── tb_bug03_lc_token.sv  -> Directed testbench: Bug-003 (token truncation model)
    ├── tb_bug03_lc_fsm.sv    -> Directed testbench: Bug-003 (REAL lc_ctrl_fsm RTL)
    └── tb_bug05_lc_or_vs_and.sv -> Directed testbench: Bug-005 (real lc_ctrl_state_transition)
```

## How the fuzzing works

### 1. Random program generation (Ibex ISA level)
`ibex_fuzzer.py` / `morfuzz_diff.py` generate random RV32IMC instruction
sequences (R-type ALU, I-type ALU, loads, stores, LUI/AUIPC, branches,
M-extension, plus CSR writes for `pmpcfg*`/`pmpaddr*`/`mstatus`/`mepc`/`mtvec`
in the differential fuzzer). Programs are emitted as `<addr> <word>` hex files
loaded by the harness.

### 2. VCS simulation harness
`build_ibex.sh` compiles the full Ibex core (30 RTL files) with VCS
U-2023.03. `tb_ibex_fuzz.sv` loads `ibex_program.hex` into a 256KB memory
model, runs 2000 cycles, and dumps the full memory to `ibex_ram_dump.hex` for
post-analysis. `tb_ibex_fuzz_pmp.sv` adds `PMPEnable=1` plus the correct bus
handshakes (`instr_gnt_i`/`data_gnt_i` high, `fetch_enable_i = IbexMuBiOn`).

### 3. Differential co-simulation (golden reference)
`morfuzz_diff.py` runs each generated program on **Spike** (RISC-V ISA golden
model) and on the **VCS Ibex** simulation, then compares architectural state.
A mismatch between Spike and VCS signals a potential hardware bug.

### 4. Property-based module fuzzing (Bug-001)
`pmp_fuzzer.py` / `fuzz_pmp_vcs.py` build a standalone VCS testbench around
`ibex_pmp`, then fuzz random PMP CSR configurations (lock bits, TOR/NAPOT
modes, R/W/X permissions, privilege levels, debug bypass). The fuzzer flags
any case where `pmp_req_err_o` stays 0 during a confirmed violation -
this is exactly how **Bug-001** (the always-zero error output) was detected.

### 5. GenHuzz integration (optional)
`vcs_ibex_runner.py` implements the GenHuzz lock-file protocol: receives test
cases from the GenHuzz RL agent, compiles them to RISC-V, simulates on VCS,
extracts FSM/line/condition coverage, and writes coverage back for the
mutator to learn from.

## Usage

```bash
# Build the Ibex VCS simulation
cd ~/vcs_work/morfuzz_ibex
./build_ibex.sh                  # -> simv_ibex (and simv_ibex_pmp for PMP tests)

# Random program fuzzing
python3 ibex_fuzzer.py 100 42            # 100 iterations, seed 42
python3 morfuzz_diff.py                  # differential Spike vs VCS

# PMP module fuzzing (Bug-001 discovery)
python3 pmp_fuzzer.py                    # builds /tmp/sim_pmp_fuzz, fuzzes CSR configs
python3 pmp_diff_test.py                 # differential PMP behavior test

# Directed bug testbenches
# (see per-bug READMEs in ../bug-00X-*/ for exact vcs commands)
```

## Notes / pitfalls

- The harness memory is 256KB (`mem[0:65535]`) indexed via `imem_addr[17:2]`;
  the Ibex boot PC is `{boot_addr[31:8], 8'h80}` = 0x100080, so programs must
  be laid out from 0x100080 (hex file offsets are `addr - 0x100000`).
- VCS on vlsilab requires `-no_save` at runtime to capture `$display` output
  (ASLR re-exec otherwise loses it), and `g++44` (GCC 4.4) via a `~/bin/g++`
  symlink for the VCS link step.
- `prim_flop.sv` / `prim_flop_2sync.sv` stubs used for standalone RTL
  compilation live in `../bug-003-lc-token/` (width-matched `ResetValue` is
  critical for sparse-FSM reset correctness).

## Bugs detected with this pipeline

| Bug | Fuzzer component | Detection signal |
|-----|------------------|------------------|
| Bug-001 (PMP bypass) | pmp_fuzzer / pmp_diff_test | `pmp_req_err_o` always 0 on locked-region violations |
| Bug-003 (LC token truncation) | token comparison fuzzer | 32-bit vs 128-bit match divergence |
| Bug-005 (LC OR/AND) | replica combination fuzzer | OR accepts what AND rejects |
