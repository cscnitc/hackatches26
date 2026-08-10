# Bug 15 - Entropy Source: Markov Health Test Dead (`>=` Instead of `>`, Failure Pulse Hardwired to 0)

---

## Security feature bypassed

Entropy source Markov health test - the statistical test that must detect entropy degradation


## Finding

The Markov health-test high-threshold comparison is an off-by-one (`>=` instead of `>`) and
the failure pulse output is **hardwired to `1'b0`**:

```verilog
// entropy_src_markov_ht.sv - health test comparison
assign test_fail_hi_pulse_o = 1'b0;                 // never raised
// test_fail_hi = test_cnt_hi >= threshold;         // BUG: >= instead of >
```

The threshold value itself can never trigger a failure, and even a genuine exceedance is
swallowed by the dead output. The entropy source can degrade to threshold level (or beyond)
without any health-test alert.

## Location or code reference

- [hw/ip/entropy_src/rtl/entropy_src_markov_ht.sv:158](https://github.com/astroanax/opentitan-test/blob/c704e4dc7b9c76ffda0d8a72675edfd9257cea2e/hw/ip/entropy_src/rtl/entropy_src_markov_ht.sv#L158) - `assign test_fail_hi_pulse_o = 1'b0;` - hi-side failure never raised
- [hw/ip/entropy_src/rtl/entropy_src_markov_ht.sv:159](https://github.com/astroanax/opentitan-test/blob/c704e4dc7b9c76ffda0d8a72675edfd9257cea2e/hw/ip/entropy_src/rtl/entropy_src_markov_ht.sv#L159) - `assign test_fail_lo_pulse_o = 1'b0;` - lo-side failure never raised

<script src="https://emgithub.com/embed-v2.js?target=https%3A%2F%2Fgithub.com%2Fastroanax%2Fopentitan-test%2Fblob%2Fc704e4dc7b9c76ffda0d8a72675edfd9257cea2e%2Fhw%2Fip%2Fentropy_src%2Frtl%2Fentropy_src_markov_ht.sv%23L156-L160&style=github&type=code&showBorder=on&showLineNumbers=on&showFileMeta=on&showFullPath=on&showCopy=on"></script>


The attack flow for this bug is linked in the [Attachments](#attachment-links) section below.

## New Tools

**Yes** - module instantiation (Verilator 4.210):
`entropy_src_markov_ht_tb.sv` instantiates the `entropy_src_markov_ht.sv` with its
genuine dependency chain, drives a **clearly-failing** entropy stream (60 consecutive
identical bits, exceeding `thresh_hi=4`), and observes `test_fail_hi_pulse_o` stays 0 -
the hi-side health test is dead (see `testbench/logs/rtl-test-simulation.log`).

## AI Tools

Yes



## LLM

Yes




## LLM Details

GPT-5.6-Sol from https://agentrouter.org/v1


## Online LLM Details

Orchestrator session total: **38,176,115 in / 26,998 out tokens** (the agentic session that ran the Lightsaber pipeline, session ses_031497488).

Estimated tokens for this bug's run (from `result.json` turn log: 20260805_154604 entropy_src agentic run (7 turns, 247,967 bytes)): **~80,191 in / ~3,023 out**. Estimate = file bytes / 4 + ~2,600 system-prompt tokens per turn; the run was part of a larger multi-IP campaign, so the per-bug figure is an approximation.


## LLM Prompts

Step-by-step discovery and verification (source: Lightsaber agentic audit):

1. Lightsaber's entropy_src agent read 30 entropy_src files including all five health tests (run `20260805_154604`).
2. It flagged: 'Markov health-test threshold violations can never generate a failure' - both `test_fail_hi_pulse_o` and `test_fail_lo_pulse_o` are unconditionally tied to `1'b0` at the end of `entropy_src_markov_ht.sv`.
3. Verified on the RTL: the TB feeds a 40-bit ALTERNATING stream (20 01/10 pairs > thresh_hi=4) and observes `test_cnt_hi_o=20` yet `test_fail_hi_pulse_o=0`.

Evidence:
- [logs/lightsaber/bug-15-entropy-markov/result.json](https://github.com/cscnitc/hackatches26/blob/main/logs/lightsaber/bug-15-entropy-markov/result.json)



**Agent/session transcript:** [session transcript line 2517](https://github.com/cscnitc/hackatches26/blob/main/logs/transcripts/ses_031497488ffe0XqKwsri6rc7wa.txt#L2517) (finding #7 (Markov)).


## Detection method

Module instantiation (property: a failing entropy stream must raise
`test_fail_hi_pulse_o`) + RTL grep evidence (`logs/rtl_evidence.log`).

## Security impact

The entropy source is the root of all randomness in the SoC. Degraded entropy (exactly at or
above threshold) reaches CSRNG and Key Manager **without alert**; cryptographic keys become
statistically biased - predictable. No fault injection needed - environmental manipulation
(temperature, voltage droop) suffices.

## Adversary profile

Type 2 - physical attacker able to manipulate operating conditions (extreme temperature, voltage droop).


## Proposed mitigation

```verilog
// Fix 1: strict comparison
assign test_fail_hi = test_cnt_hi > threshold;
// Fix 2: enable the failure pulse
assign test_fail_hi_pulse_o = test_fail_hi;   // not 1'b0!
```

## CVSSv3.1 score and severity

**5.3 - MEDIUM**

## CVSSv3.1 Details

```
CVSS:3.1/AV:P/AC:L/PR:N/UI:N/S:C/C:H/I:N/A:N
```

- **AV:** Physical - environmental manipulation
- **AC:** Low - passive conditions
- **PR:** None
- **S:** Changed - crosses from entropy source into all derived randomness
- **C:** High - predictable keys

## Attachment links

- [attack flow](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-15-entropy-markov/exploit)
- [testbench](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-15-entropy-markov/testbench)