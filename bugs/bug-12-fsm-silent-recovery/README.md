# Bug 12 - Key Manager: Data-Enable FSM Illegal-State Silent Recovery (No Alert)

---

## Security feature bypassed

Key Manager FSM integrity monitoring - the alert path that must report fault-injected illegal FSM states


## Finding

The data-enable FSM uses a 10-bit state encoding (1024 encodings, 7 legal states). The
`unique case default` recovers to the safe state but leaves `fsm_err_o = 0` - fault-injected
states recover **silently**:

```verilog
// keymgr_data_en_state.sv:80,127-132
unique case (state_q)
  ...
  default: begin
    state_d = StIdle;   // Safe recovery - correct
    // BUG: fsm_err_o stays 0 - alert never fires
  end
endcase
```

## Location or code reference

- [hw/ip/keymgr/rtl/keymgr_data_en_state.sv:127-132](https://github.com/astroanax/opentitan-test/blob/c704e4dc7b9c76ffda0d8a72675edfd9257cea2e/hw/ip/keymgr/rtl/keymgr_data_en_state.sv#L127-L132) - `default:` recovers to StIdle but never sets fsm_err_o
- [hw/ip/keymgr/rtl/keymgr_data_en_state.sv:80](https://github.com/astroanax/opentitan-test/blob/c704e4dc7b9c76ffda0d8a72675edfd9257cea2e/hw/ip/keymgr/rtl/keymgr_data_en_state.sv#L80) - 10-bit sparse FSM state register

<script src="https://emgithub.com/embed-v2.js?target=https%3A%2F%2Fgithub.com%2Fastroanax%2Fopentitan-test%2Fblob%2Fc704e4dc7b9c76ffda0d8a72675edfd9257cea2e%2Fhw%2Fip%2Fkeymgr%2Frtl%2Fkeymgr_data_en_state.sv%23L125-L134&style=github&type=code&showBorder=on&showLineNumbers=on&showFileMeta=on&showFullPath=on&showCopy=on"></script>


The exploit for this bug is linked in the [Attachments](#attachment-links) section below.

## New Tools

**Yes** - module instantiation (Verilator 4.210):
`keymgr_data_en_state_tb.sv` instantiates the `keymgr_data_en_state.sv` with its genuine
dependency chain, exercises the FSM through valid operations, and verifies `fsm_err_o` stays 0
throughout (see `testbench/logs/rtl-test-simulation.log`). Also custom VCS fuzzing pipeline
(standalone model).

## AI Tools

Yes



## LLM

Yes




## LLM Details

GPT-5.6-Sol from https://agentrouter.org/v1


## Online LLM Details

Orchestrator session total: **38,176,115 in / 26,998 out tokens** (the agentic session that ran the Lightsaber pipeline, session ses_031497488).

Estimated tokens for this bug's run (from `result.json` turn log: 20260805_082405 keymgr agentic run (15 turns, 168,087 bytes) - shared with bugs 03 and 11): **~81,021 in / ~2,015 out**. Estimate = file bytes / 4 + ~2,600 system-prompt tokens per turn; the run was part of a larger multi-IP campaign, so the per-bug figure is an approximation.


## LLM Prompts

Step-by-step discovery and verification (source: Lightsaber agentic audit):

1. Lightsaber's keymgr agent (same run `20260805_082405`) read `keymgr_data_en_state.sv`.
2. It flagged that the `unique case (state_q)` default branch forces `state_d = StCtrlDataDis` but leaves `fsm_err_o=0` - an illegal FSM state is silently recovered with no alert (the sparse-FSM flop macro adds no independent illegal-state alert).
3. Verified on the RTL: FI demo (`fi19.v`) forces an illegal 10-bit state and observes `fsm_err_o` stays 0 (fault is SILENT).

Evidence:
- [logs/lightsaber/bug-12-fsm/result.json](https://github.com/cscnitc/hackatches26/blob/main/logs/lightsaber/bug-12-fsm/result.json)



**Agent/session transcript:** [session transcript line 2455](https://github.com/cscnitc/hackatches26/blob/main/logs/transcripts/ses_031497488ffe0XqKwsri6rc7wa.txt#L2455) (finding #5 (keymgr FSM)).


## Detection method

Module instantiation (property: illegal states must raise `fsm_err_o`) + VCS FI demo:
`fi19.v` forces an illegal 10-bit state (`10'b1111111111`) into the real FSM; it silently
recovers with `fsm_err_o=0` (see `exploit/logs/fi19_run.log`:
`*** BUG #19 FI CONFIRMED: fault is SILENT ***`).

## Security impact

FSM corruption during key derivation can skip/repeat data-enable stages; the system is
unaware - no alert, no log. Key derivation may produce corrupted or predictable output while
the security monitors report healthy.

## Adversary profile

Type 2 - physical attacker with clock-glitch / EM fault injection on the FSM state register.


## Proposed mitigation

```verilog
default: begin
  state_d = StIdle;
  fsm_err_o = 1'b1;   // raise alert on illegal state
end
```

Or use Hamming-protected state encoding (distance ≥ 2).

## CVSSv3.1 score and severity

**4.2 - MEDIUM**

## CVSSv3.1 Details

```
CVSS:3.1/AV:P/AC:H/PR:N/UI:N/S:U/C:H/I:N/A:N
```

- **AV:** Physical - fault injection on the device
- **AC:** High - precise timing during derivation
- **PR:** None
- **S:** Unchanged - within the Key Manager domain
- **C:** High - corrupted/predictable derived keys

## Attachment links

- [exploit](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-12-fsm-silent-recovery/exploit)
- [testbench](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-12-fsm-silent-recovery/testbench)