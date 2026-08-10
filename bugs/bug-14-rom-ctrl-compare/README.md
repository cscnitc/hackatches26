# Bug 14 - ROM Controller Single-Bit Digest Comparison Vulnerable to Fault Injection

---

## Security feature bypassed

Secure-boot ROM integrity verification - the digest-match decision that gates execution of the boot ROM


## Finding

The entire ROM digest comparison result rests on a **single flip-flop** (`digest_match_q`)
with **no redundancy, Hamming protection, or dual-rail encoding**:

```verilog
// rom_ctrl_compare.sv - digest comparison logic
logic digest_match_q;
assign digest_match = digest_match_q;
```

A single-bit fault (clock glitch, EM pulse, laser) flipping `digest_match_q` 0-1 makes a
digest **mismatch appear as a match** - the ROM controller proceeds to execute content that
never passed verification, with machine-mode privileges.

## Location or code reference

- [hw/ip/rom_ctrl/rtl/rom_ctrl_compare.sv:82](https://github.com/astroanax/opentitan-test/blob/c704e4dc7b9c76ffda0d8a72675edfd9257cea2e/hw/ip/rom_ctrl/rtl/rom_ctrl_compare.sv#L82) - single flip-flop `matches_q` holds the whole digest-match result
- [hw/ip/rom_ctrl/rtl/rom_ctrl_compare.sv:153-162](https://github.com/astroanax/opentitan-test/blob/c704e4dc7b9c76ffda0d8a72675edfd9257cea2e/hw/ip/rom_ctrl/rtl/rom_ctrl_compare.sv#L153-L162) - FF update: `matches_d = matches_q && (digest_word == exp_digest_word)` - no redundancy

<script src="https://emgithub.com/embed-v2.js?target=https%3A%2F%2Fgithub.com%2Fastroanax%2Fopentitan-test%2Fblob%2Fc704e4dc7b9c76ffda0d8a72675edfd9257cea2e%2Fhw%2Fip%2From_ctrl%2Frtl%2From_ctrl_compare.sv%23L153-L162&style=github&type=code&showBorder=on&showLineNumbers=on&showFileMeta=on&showFullPath=on&showCopy=on"></script>


The exploit for this bug is linked in the [Attachments](#attachment-links) section below.

## New Tools

**Yes** - module instantiation (Verilator 4.210):
`rom_ctrl_compare_tb.sv` instantiates the `rom_ctrl_compare.sv` and demonstrates the
single-FF result (see `testbench/logs/rtl-test-simulation.log`); plus RTL grep evidence
(`logs/rtl_evidence.log`).

## AI Tools

Yes



## LLM

Yes




## LLM Details

GPT-5.6-Sol from https://agentrouter.org/v1


## Online LLM Details

Orchestrator session total: **38,176,115 in / 26,998 out tokens** (the agentic session that ran the Lightsaber pipeline, session ses_031497488).

Estimated tokens for this bug's run (from `result.json` turn log: 20260805_154602 rom_ctrl agentic run (8 turns, 55,728 bytes)): **~34,732 in / ~1,118 out**. Estimate = file bytes / 4 + ~2,600 system-prompt tokens per turn; the run was part of a larger multi-IP campaign, so the per-bug figure is an approximation.


## LLM Prompts

Step-by-step discovery and verification (source: Lightsaber agentic audit):

1. Lightsaber's rom_ctrl agent read all 6 `rom_ctrl` RTL files (run `20260805_154602`).
2. It flagged: 'Single-bit comparison result can be faulted from digest mismatch to valid ROM' - the decision accumulates in single-bit `matches_q` (init 1, updated `matches_q && (digest_word == exp_digest_word)`), and the MuBi4 sender only encodes that one bit, so a 0->1 upset on `matches_q` (or a transient force on the 32-bit equality) makes `good_o` become valid `MuBi4True`.
3. Verified on the RTL: FI demo (`fi21.v`) forces `matches_q` 0->1 and observes `good_o` flips to True while `alert_o` stays 0.

Evidence:
- [logs/lightsaber/bug-14-rom-ctrl/result.json](https://github.com/cscnitc/hackatches26/blob/main/logs/lightsaber/bug-14-rom-ctrl/result.json)



**Agent/session transcript:** [session transcript line 2517](https://github.com/cscnitc/hackatches26/blob/main/logs/transcripts/ses_031497488ffe0XqKwsri6rc7wa.txt#L2517) (finding #3 (rom_ctrl)).


## Detection method

Module instantiation + static inspection. VCS FI demo (`fi21.v`): drive a genuine digest
**mismatch** (`matches_q=0`), force `matches_q=1`, observe `good_o` flips to True while
`alert_o` stays 0 - **fault is silent** (see `exploit/logs/fi21_run.log`:
`*** BUG #21 FI CONFIRMED: fault is SILENT ***`).

## Security impact

Bypasses secure boot entirely. Corrupt the boot ROM image (or fault the comparison after a
clean hash computation) and glitch `digest_match_q` during the comparison window: the ROM
controller boots attacker-controlled code with M-mode privileges; all downstream security
(Key Manager, LC, OTP) is compromised from the first instruction.

## Adversary profile

Type 2 - physical attacker with fault injection equipment (single glitch during the boot comparison).


## Proposed mitigation

```verilog
// Dual-rail / multi-bit encoding with Hamming distance >= 3
logic [4:0] digest_match_encoded;  // e.g. Hamming(5,1) code
assign match_valid = (digest_match_encoded == MATCH_ENCODED) &&
                     (!digest_match_encoded == !MATCH_ENCODED);
```

Or: redundant comparison with majority vote across multiple registers, plus an alert on
disagreement.

## CVSSv3.1 score and severity

**7.6 - HIGH**

## CVSSv3.1 Details

```
CVSS:3.1/AV:P/AC:L/PR:N/UI:N/S:C/C:H/I:H/A:H
```

- **AV:** Physical - fault injection on the device
- **AC:** Low - one glitch in the comparison window
- **PR:** None
- **S:** Changed - crosses from ROM verification into all M-mode software
- **C/I/A:** High - arbitrary code execution at boot

## Attachment links

- [exploit](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-14-rom-ctrl-compare/exploit)
- [testbench](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-14-rom-ctrl-compare/testbench)