# Bug 07 - LC State Transition Validity Check Uses `||` Instead of `&&` (Dual-Replica FI Countermeasure Defeated)

---

## Security feature bypassed

Lifecycle Controller redundant state-transition validity check - the dual-replica fault-injection countermeasure


## Finding

The transition-validity check combines two replicated lookups with `||` (OR) instead of
`&&` (AND):

```verilog
// lc_ctrl_state_transition.sv:140-141
if (TransTokenIdxMatrix[dec_lc_state_i[0]][trans_target_i[0]] != InvalidTokenIdx ||
    TransTokenIdxMatrix[dec_lc_state_i[1]][trans_target_i[1]] != InvalidTokenIdx) begin
```

The transition is authorized if **either** replica indicates validity. The dual-replica
countermeasure requires **both** to agree - a single fault corrupting one replica suffices to
authorize a forbidden transition. The module comment (lines 138-139) states the dual-replica
intent; the operator contradicts it.

## Location or code reference

- [hw/ip/lc_ctrl/rtl/lc_ctrl_state_transition.sv:140-141](https://github.com/astroanax/opentitan-test/blob/c704e4dc7b9c76ffda0d8a72675edfd9257cea2e/hw/ip/lc_ctrl/rtl/lc_ctrl_state_transition.sv#L140-L141) - replica lookups combined with `||` instead of `&&`

<script src="https://emgithub.com/embed-v2.js?target=https%3A%2F%2Fgithub.com%2Fastroanax%2Fopentitan-test%2Fblob%2Fc704e4dc7b9c76ffda0d8a72675edfd9257cea2e%2Fhw%2Fip%2Flc_ctrl%2Frtl%2Flc_ctrl_state_transition.sv%23L138-L143&style=github&type=code&showBorder=on&showLineNumbers=on&showFileMeta=on&showFullPath=on&showCopy=on"></script>


The attack flow for this bug is linked in the [Attachments](#attachment-links) section below.

## New Tools

**Yes** - custom VCS (U-2023.03) redundancy-checker fuzzer: enumerated all pass/fail
combinations of the two replicas and verified that the OR gate allows single-replica bypass
while the AND gate requires both. Directed testbench on the real
`lc_ctrl_state_transition.sv` RTL confirms the behavior (`bug-005-tb-lc-or-and.sv`).

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

1. The VCS redundancy-checker fuzzer enumerated all four dual-replica pass/fail combinations of the transition-validity lookup.
2. It showed that the OR gate (`||`) accepts a transition when only one replica reports valid, while the correct AND (`&&`) requires both.
3. Confirmed on the RTL: `tb_bug05_lc_or_vs_and.sv` faults replica 1's state decode and shows the `||` branch is entered (`next_lc_state=LcStRma`) while the module's independent replica-consistency check still raises `trans_invalid_error=1` (honest VCS log).

Evidence:
- [logs/vcs-pipeline/bug-07-lc-or-and/bug-005-honest-vcs-simulation.log](https://github.com/cscnitc/hackatches26/blob/main/logs/vcs-pipeline/bug-07-lc-or-and/bug-005-honest-vcs-simulation.log)



**Agent/session transcript:** [session transcript line 363](https://github.com/cscnitc/hackatches26/blob/main/logs/transcripts/ses_0336e81c1ffeFjDc6DwfGq7k4y.txt#L363) (writes tb_bug05_lc_or_vs_and.sv).


## Detection method

Agent-based RTL inspection (comment-vs-operator contradiction) + automated VCS redundancy fuzzing.

**Honest scope (corrected):** the `||` at `lc_ctrl_state_transition.sv:140-141`
is a real defect in the dual-replica TOKEN-MATRIX agreement check (correct
is `&&`), but this layer alone does NOT complete an unauthorized transition:
the module's independent replica-consistency check still raises
`trans_invalid_error=1` on a single corrupted replica (defense-in-depth).
End-to-end authorization is not claimed at this module.
Security property: a transition is valid only if **both** replicas agree; the fuzzer proved
every single-replica-corrupted case is wrongly accepted.

## Security impact

A physical attacker with FI capability (laser, EM, voltage glitch) corrupts one replica's
decode path; a single-bit fault making a forbidden transition look valid in one replica passes
the OR gate. Worst case: transition from a locked state to an unlocked state **without the
correct token**.

## Adversary profile

Type 2 - physical attacker with fault injection equipment (laser/EM/voltage glitch).


## Proposed mitigation

```verilog
if (TransTokenIdxMatrix[dec_lc_state_i[0]][trans_target_i[0]] != InvalidTokenIdx &&
    TransTokenIdxMatrix[dec_lc_state_i[1]][trans_target_i[1]] != InvalidTokenIdx) begin
```

## CVSSv3.1 score and severity

**6.4 - MEDIUM**

## CVSSv3.1 Details

```
CVSS:3.1/AV:P/AC:H/PR:N/UI:N/S:U/C:H/I:H/A:H
```

- **AV:** Physical - fault injection on the device
- **AC:** High - precise timing required for one-replica corruption
- **PR:** None
- **S:** Unchanged - within the LC domain
- **C/I/A:** High - unauthorized state transitions

## Attachment links

- [attack flow](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-07-lc-or-vs-and/exploit)
- [testbench](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-07-lc-or-vs-and/testbench)