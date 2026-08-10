# Bug 11 - Key Manager: EDN Entropy Error Path Unconnected, Replay Protection Disabled

---

## Security feature bypassed

Key Manager entropy reseed integrity validation - the EDN error/replay-protection path that must gate reseed acceptance


## Finding

The `prim_edn_req` instance in the Key Manager reseed controller has
`RepCheck=0` and leaves `err_o()` **physically unconnected** - any faulted entropy is
accepted silently:

```verilog
// keymgr_reseed_ctrl.sv:63-73
prim_edn_req #(.RepCheck(0)) u_edn_req (..., .err_o(), ...);
```

`.err_o()` is unconnected; `cnt_err_o` (line 109) is a dead-end local signal.

## Location or code reference

- [hw/ip/keymgr/rtl/keymgr_reseed_ctrl.sv:63-76](https://github.com/astroanax/opentitan-test/blob/c704e4dc7b9c76ffda0d8a72675edfd9257cea2e/hw/ip/keymgr/rtl/keymgr_reseed_ctrl.sv#L63-L76) - prim_edn_req instance with `.err_o()` unconnected
- [hw/ip/keymgr/rtl/keymgr_reseed_ctrl.sv:109](https://github.com/astroanax/opentitan-test/blob/c704e4dc7b9c76ffda0d8a72675edfd9257cea2e/hw/ip/keymgr/rtl/keymgr_reseed_ctrl.sv#L109) - `.err_o(cnt_err_o)` - dead-end local signal

<script src="https://emgithub.com/embed-v2.js?target=https%3A%2F%2Fgithub.com%2Fastroanax%2Fopentitan-test%2Fblob%2Fc704e4dc7b9c76ffda0d8a72675edfd9257cea2e%2Fhw%2Fip%2Fkeymgr%2Frtl%2Fkeymgr_reseed_ctrl.sv%23L63-L76&style=github&type=code&showBorder=on&showLineNumbers=on&showFileMeta=on&showFullPath=on&showCopy=on"></script>


The attack flow for this bug is linked in the [Attachments](#attachment-links) section below.

## New Tools

**Yes** - custom VCS fuzzing pipeline (standalone model) + **module instantiation**
(Verilator 4.210): `keymgr_reseed_ctrl_tb.sv` instantiates the real
`keymgr_reseed_ctrl.sv` with its genuine dependency chain; drives a reseed request, simulates
the EDN responding with a FIPS error (`edn_fips=1`), and observes `cnt_err_o` stays 0 -
the error is silently swallowed (see `testbench/logs/rtl-test-simulation.log`:
`*** BUG #18 CONFIRMED on actual OpenTitan RTL ***`).

## AI Tools

Yes



## LLM

Yes




## LLM Details

GPT-5.6-Sol from https://agentrouter.org/v1


## Online LLM Details

Orchestrator session total: **38,176,115 in / 26,998 out tokens** (the agentic session that ran the Lightsaber pipeline, session ses_031497488).

Estimated tokens for this bug's run (from `result.json` turn log: 20260805_082405 keymgr agentic run (15 turns, 168,087 bytes) - shared with bugs 03 and 12): **~81,021 in / ~2,015 out**. Estimate = file bytes / 4 + ~2,600 system-prompt tokens per turn; the run was part of a larger multi-IP campaign, so the per-bug figure is an approximation.


## LLM Prompts

Step-by-step discovery and verification (source: Lightsaber agentic audit):

1. Lightsaber's keymgr agent read 12 keymgr files including `keymgr_reseed_ctrl.sv` and `prim_edn_req.sv` (run `20260805_082405`).
2. It flagged that `prim_edn_req` is instantiated with default `RepCheck=0` and `fips_o()`/`err_o()` unconnected, and that the all-zero/all-one/previous checks are assertion-only (`INC_ASSERT`) - so a faulted/replayed EDN response is acknowledged as a successful reseed.
3. Verified on the RTL: `keymgr_reseed_ctrl_tb.sv` drives an EDN FIPS error and observes the error is silently dropped (`cnt_err_o=0`).

Evidence:
- [logs/lightsaber/bug-11-edn/result.json](https://github.com/cscnitc/hackatches26/blob/main/logs/lightsaber/bug-11-edn/result.json)



**Agent/session transcript:** [session transcript line 2455](https://github.com/cscnitc/hackatches26/blob/main/logs/transcripts/ses_031497488ffe0XqKwsri6rc7wa.txt#L2455) (finding #4 (keymgr EDN)).


## Detection method

Module instantiation (Verilator 4.210, full dependency closure) + AFL model. Security
property: an EDN error during reseed must set the error output / block acceptance; the
testbench shows the error is accepted silently.

## Security impact

Fault-injected EDN entropy poisons the reseed LFSR; all subsequent key derivations use
attacker-influenced entropy - predictable session keys. Replay protection (`RepCheck`) is
also disabled, enabling entropy replay.

## Adversary profile

Type 2 - physical attacker with the ability to fault the EDN entropy bus (voltage/EM glitch).


## Proposed mitigation

```verilog
prim_edn_req #(.RepCheck(1)) u_edn_req (..., .err_o(err), ...);  // connect + alert
```

## CVSSv3.1 score and severity

**6.8 - MEDIUM**

## CVSSv3.1 Details

```
CVSS:3.1/AV:P/AC:H/PR:N/UI:N/S:C/C:H/I:H/A:N
```

- **AV:** Physical - bus fault injection
- **AC:** High - precise glitch timing on the EDN bus
- **PR:** None
- **S:** Changed - crosses from entropy path into derived keys
- **C/I:** High - predictable session keys

## Attachment links

- [attack flow](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-11-edn-err-unconnected/exploit)
- [testbench](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-11-edn-err-unconnected/testbench)