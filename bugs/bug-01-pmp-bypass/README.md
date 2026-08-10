# Bug 01 - PMP Error Output Always Zero (Complete PMP Bypass)

---

## Security feature bypassed

Physical Memory Protection (PMP) - the primary hardware access-control mechanism of the Ibex RISC-V core


## Finding

Signal `pmp_req_err_o` is computed as `access_violation_detected & ~fault_analysis_result`.
Since `access_violation_detected` itself equals `~debug_bypass_active & fault_analysis_result`,
Boolean algebra simplification yields `pmp_req_err_o = 0` - **identically zero**,
regardless of actual PMP violations.

Truth table:

| fault_analysis_result | debug_bypass_active | access_violation_detected | pmp_req_err_o (buggy) | Expected |
|---|---|---|---|---|
| 0 | 0 | 0 | 0 | 0 (OK) |
| 0 | 1 | 0 | 0 | 0 (OK) |
| 1 | 0 | 1 | **0 (BUG)** | **1 (error)** |
| 1 | 1 | 0 | 0 | 0 (OK) |

## Location or code reference

- [hw/vendor/lowrisc_ibex/rtl/ibex_pmp.sv:285](https://github.com/astroanax/opentitan-test/blob/c704e4dc7b9c76ffda0d8a72675edfd9257cea2e/hw/vendor/lowrisc_ibex/rtl/ibex_pmp.sv#L285) - the buggy assignment `pmp_req_err_o[c] = access_violation_detected & ~fault_analysis_result;`

<script src="https://emgithub.com/embed-v2.js?target=https%3A%2F%2Fgithub.com%2Fastroanax%2Fopentitan-test%2Fblob%2Fc704e4dc7b9c76ffda0d8a72675edfd9257cea2e%2Fhw%2Fvendor%2Flowrisc_ibex%2Frtl%2Fibex_pmp.sv%23L283-L287&style=github&type=code&showBorder=on&showLineNumbers=on&showFileMeta=on&showFullPath=on&showCopy=on"></script>


The exploit for this bug is linked in the [Attachments](#attachment-links) section below.

## New Tools

**Yes** - custom VCS-based hardware fuzzer, plus a Python random PMP CSR configuration generator.

Detection methodology: randomly generated PMP CSR configurations (`pmpcfg0/1`, `pmpaddrN`)
with varying lock/permission bits were driven into a synthesizable VCS testbench of the real
`ibex_pmp` module; `pmp_req_err_o` was monitored for confirmed PMP violations that failed to
assert. Directed fuzzing with targeted seeds every 100 iterations guaranteed discovery; 7
directed test cases (read / write / execute / M-mode / unlocked-mode) then verified the finding.

## AI Tools

Yes


## LLM

Yes



## LLM Details

Deepseek V4 Pro (1.6T params) from OpenCode Go https://opencode.ai/zen/go/v1


## Online LLM Details

Orchestrator session total: **81,873,919 in / 53,192 out tokens** (the agentic session that ran the custom VCS hardware-fuzzing pipeline; session ses_0336e81c1ffeFjDc6DwfGq7k4y).

Per-bug token estimates are not available: the pipeline ran as a continuous fuzzing session (compile + simulation campaigns across the three bugs) rather than per-bug agentic runs, so the orchestrator total is the only recorded figure.


## LLM Prompts

Step-by-step discovery and verification (source: Custom VCS hardware-fuzzing pipeline):

1. Built a coverage-guided VCS fuzzer around the full Ibex core (30 RTL files) with Spike co-simulation; instrumented `ibex_pmp` to flag any case where `pmp_req_err_o` stays 0 during a confirmed PMP violation.
2. The fuzzer generated random RV32IMC programs and PMP CSR configs (locked TOR regions, no permissions) and observed that PMP violations NEVER assert the error signal across 500+ configurations.
3. Isolated the module and wrote a 7-test directed testbench (`tb_bug01_pmp.sv`) confirming the bug on read/write/execute/M-mode/unlocked scenarios.
4. Verified the Boolean cancellation: `pmp_req_err_o = access_violation_detected & ~fault_analysis_result`, with `access_violation_detected = ~debug_bypass_active & fault_analysis_result`, so the output is identically 0.

Evidence:
- [logs/vcs-pipeline/bug-01-pmp/bug-001-vcs-compile.log](https://github.com/cscnitc/hackatches26/blob/main/logs/vcs-pipeline/bug-01-pmp/bug-001-vcs-compile.log)
- [logs/vcs-pipeline/bug-01-pmp/bug-001-vcs-simulation.log](https://github.com/cscnitc/hackatches26/blob/main/logs/vcs-pipeline/bug-01-pmp/bug-001-vcs-simulation.log)



**Agent/session transcript:** [session transcript line 339](https://github.com/cscnitc/hackatches26/blob/main/logs/transcripts/ses_0336e81c1ffeFjDc6DwfGq7k4y.txt#L339) (writes tb_bug01_pmp.sv).


## Detection method

Automated detection with the custom VCS hardware fuzzer. Security/verification properties checked:

- `pmp_req_err_o == 1` when a locked PMP region denies access
- `pmp_req_err_o == 0` only when access is explicitly permitted

The fuzzer flags any case where a violation does not assert `pmp_req_err_o`; the buggy line
fails every violation case. Confirmed on the `ibex_pmp` RTL under VCS, and on the full
Ibex SoC via dvsim (`chip_sw_pmp_bypass_exploit`, P:1 100%).

## Security impact

Complete PMP bypass. Any code at any privilege level (U/S/M) can access any memory region
without PMP restrictions: read secure memory (keys, credentials), write protected firmware
regions, execute from non-executable memory - all without triggering a fault.

## Adversary profile

Type 1 - unprivileged software running at user level on the Ibex core.


## Proposed mitigation

```verilog
// FIXED:
assign pmp_req_err_o[c] = access_violation_detected;
```

The `~fault_analysis_result` term cancels the `fault_analysis_result` already AND-ed into
`access_violation_detected`.

## CVSSv3.1 score and severity

**8.8 - HIGH**

## CVSSv3.1 Details

```
CVSS:3.1/AV:L/AC:L/PR:L/UI:N/S:C/C:H/I:H/A:H
```

- **AV:** Local - requires code execution on the core
- **AC:** Low - bypass works for all configurations
- **PR:** Low - user-level code suffices
- **UI:** None
- **S:** Changed - crosses the memory-isolation boundary
- **C/I/A:** High - arbitrary read, write, execution

## Attachment links

- [exploit](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-01-pmp-bypass/exploit)
- [testbench](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-01-pmp-bypass/testbench)
