# Bug 03 - Key Manager Source-Key Validity Gating Bypass

---

## Security feature bypassed

Key Manager source-key validity gating - the `key_i.valid` trust bit carried by `hw_key_req_t`

## Finding

In `keymgr_input_checks.sv`, `key_i.valid` is captured into a wire named `unused_key_vld`
(a standard lint-suppression idiom) and is **never included** in the `key_vld_o` computation.
The validity output depends solely on a content check (`&key_chk`) that only rejects all-zero
and all-ones keys:

```verilog
// keymgr_input_checks.sv:80-81
logic unused_key_vld;
assign unused_key_vld = key_i.valid;   // DISCARDED - lint suppression

// keymgr_input_checks.sv:99
assign key_vld_o = &key_chk;           // key_i.valid NOT included
```

Contrast with the correct `rom_digest` handling at line 104:
`rom_digest_vld_o &= rom_digest_i[k].valid && valid_chk(...);`

If a key source (OTP / flash) signals `valid=0` while key bytes are partially programmed
(non-zero, non-all-ones), the Key Manager still derives session keys from that unvalidated
material.

## Location or code reference

- [hw/ip/keymgr/rtl/keymgr_input_checks.sv:80-81](https://github.com/astroanax/opentitan-test/blob/c704e4dc7b9c76ffda0d8a72675edfd9257cea2e/hw/ip/keymgr/rtl/keymgr_input_checks.sv#L80-L81) - `unused_key_vld = key_i.valid` - the trust bit is discarded as lint-suppression
- [hw/ip/keymgr/rtl/keymgr_input_checks.sv:99](https://github.com/astroanax/opentitan-test/blob/c704e4dc7b9c76ffda0d8a72675edfd9257cea2e/hw/ip/keymgr/rtl/keymgr_input_checks.sv#L99) - `assign key_vld_o = &key_chk;` - key_i.valid NOT included
- [hw/ip/keymgr/rtl/keymgr_input_checks.sv:104](https://github.com/astroanax/opentitan-test/blob/c704e4dc7b9c76ffda0d8a72675edfd9257cea2e/hw/ip/keymgr/rtl/keymgr_input_checks.sv#L104) - correct reference: rom_digest validity DOES include the valid bit

<script src="https://emgithub.com/embed-v2.js?target=https%3A%2F%2Fgithub.com%2Fastroanax%2Fopentitan-test%2Fblob%2Fc704e4dc7b9c76ffda0d8a72675edfd9257cea2e%2Fhw%2Fip%2Fkeymgr%2Frtl%2Fkeymgr_input_checks.sv%23L80-L101&style=github&type=code&showBorder=on&showLineNumbers=on&showFileMeta=on&showFullPath=on&showCopy=on"></script>


The exploit for this bug is linked in the [Attachments](#attachment-links) section below.

## New Tools

**Yes** - custom VCS fuzzing pipeline (coverage-guided AFL++ 4.09c + Verilator 4.210), differential
fuzzing mode:

1. Two minimal Verilator models: buggy (exact RTL logic) and fixed (`key_vld_o = key_i.valid & &key_chk`)
2. Both instantiated side-by-side in a wrapper; the custom VCS fuzzing pipeline feeds identical random inputs (valid bit + 2×256-bit key shares)
3. Any `key_vld_o` mismatch triggers `abort()` (SIGABRT); the fuzzer records the crash input

**Result:** 2 unique crash inputs found within 60 s from safe seeds - both `valid_i=0` with key
shares passing the content check: buggy returns `1`, fixed correctly returns `0`.

## AI Tools

Yes


## LLM

Yes



## LLM Details

GPT-5.6-Sol from https://agentrouter.org/v1


## Online LLM Details

Orchestrator session total: **38,176,115 in / 26,998 out tokens** (the agentic session that ran the Lightsaber pipeline, session ses_031497488).

Estimated tokens for this bug's run (from `result.json` turn log: 20260805_082405 keymgr agentic run (15 turns, 168,087 bytes of RTL read)): **~81,021 in / ~2,015 out**. Estimate = file bytes / 4 + ~2,600 system-prompt tokens per turn; the run was part of a larger multi-IP campaign, so the per-bug figure is an approximation.


## LLM Prompts

Step-by-step discovery and verification (source: Lightsaber agentic audit):

1. Lightsaber (Mjolnir fork) audited `keymgr_input_checks.sv` with the SystemVerilog auditor prompt, with DeepWiki MCP context.
2. The model flagged that `key_i.valid` is captured into `unused_key_vld` (lines 80-81) and never included in `key_vld_o = &key_chk` (line 99): a revoked key passes as valid if the shares are not all-zero/all-ones.
3. The finding was verified on the RTL: `keymgr_input_checks_tb.sv` drives `key_i.valid=0` with a non-trivial key and observes `key_vld_o=1` (see testbench logs).

Evidence:
- [logs/lightsaber/bug-03-keymgr/result.json](https://github.com/cscnitc/hackatches26/blob/main/logs/lightsaber/bug-03-keymgr/result.json)



**Agent/session transcript:** [session transcript line 1157](https://github.com/cscnitc/hackatches26/blob/main/logs/transcripts/ses_031497488ffe0XqKwsri6rc7wa.txt#L1157) (first real finding (keymgr key_i.valid)).


## Detection method

Automated detection with the custom VCS fuzzing pipeline differential fuzzer (security property: `key_vld_o`
must be 0 whenever `key_i.valid=0`). Finding then **confirmed on the OpenTitan RTL**:
`keymgr_input_checks_tb.sv` instantiates the `keymgr_input_checks.sv` with its genuine
dependency chain and observes `key_vld_o=1` while `key_i.valid=0`
(see `testbench/logs/rtl-test-simulation.log`: `*** BUG #10 CONFIRMED on actual OpenTitan RTL ***`).

## Security impact

Session keys are derived from unvalidated / attacker-influenced key material. AES, HMAC, KMAC
and OTBN keys derived from attacker-controlled source material; known-key scenarios enable
cryptanalysis of supposedly secure channels. A software attacker can write key material to the
source registers, configure shares to pass the content check, and trigger derivation via the
CONTROL register.

## Adversary profile

Type 1 - unprivileged software (user-level C) with access to the Key Manager MMIO interface, when the key source signals invalid.


## Proposed mitigation

```verilog
assign key_vld_o = key_i.valid & &key_chk;
```

## CVSSv3.1 score and severity

**5.5 - MEDIUM**

## CVSSv3.1 Details

```
CVSS:3.1/AV:L/AC:L/PR:L/UI:N/S:U/C:H/I:N/A:N
```

- **AV:** Local - requires code execution on the core
- **PR:** Low - user-level software with MMIO access
- **S:** Unchanged - key derivation within the Key Manager domain
- **C:** High - confidentiality of derived keys compromised

## Attachment links

- [exploit](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-03-keymgr-source-valid/exploit)
- [testbench](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-03-keymgr-source-valid/testbench)
