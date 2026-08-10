# Bug 08 - `LcStProd` Appears in Two `unique case` Branches (Debug/DFT Ambiguity in Production)

---

## Security feature bypassed

Lifecycle Controller signal decode - debug/DFT enable semantics for the production lifecycle state


## Finding

`LcStProd` appears in **two different branches** of the `unique case` statement in
`lc_ctrl_signal_decode.sv`:

1. **Lines 109-124 (test-unlocked branch):** `LcStProd` is grouped with
   `LcStTestUnlocked0-6`, enabling:
   - `lc_dft_en = On`
   - `lc_nvm_debug_en = On`
   - `lc_hw_debug_en = On`
   - `lc_keymgr_div_d = RndCnstLcKeymgrDivTestUnlocked` (weaker constants)

2. **Lines 138-154 (production branch):** `LcStProd` is grouped with `LcStProdEnd`, enabling:
   - `lc_keymgr_en = On`
   - `lc_keymgr_div_d = RndCnstLcKeymgrDivProduction`

SystemVerilog `unique case` requires exactly one matching case item; with two matches the
behavior is **undefined** - synthesis/simulation may select either branch, and one of them
enables debug and DFT in production.

## Location or code reference

- [hw/ip/lc_ctrl/rtl/lc_ctrl_signal_decode.sv:93](https://github.com/astroanax/opentitan-test/blob/c704e4dc7b9c76ffda0d8a72675edfd9257cea2e/hw/ip/lc_ctrl/rtl/lc_ctrl_signal_decode.sv#L93) - `unique case (lc_state_i)`
- [hw/ip/lc_ctrl/rtl/lc_ctrl_signal_decode.sv:116](https://github.com/astroanax/opentitan-test/blob/c704e4dc7b9c76ffda0d8a72675edfd9257cea2e/hw/ip/lc_ctrl/rtl/lc_ctrl_signal_decode.sv#L116) - LcStProd in the test-unlocked branch (enables debug/DFT)
  - [hw/ip/lc_ctrl/rtl/lc_ctrl_signal_decode.sv:139](https://github.com/astroanax/opentitan-test/blob/c704e4dc7b9c76ffda0d8a72675edfd9257cea2e/hw/ip/lc_ctrl/rtl/lc_ctrl_signal_decode.sv#L139) - LcStProd again in the production branch

<script src="https://emgithub.com/embed-v2.js?target=https%3A%2F%2Fgithub.com%2Fastroanax%2Fopentitan-test%2Fblob%2Fc704e4dc7b9c76ffda0d8a72675edfd9257cea2e%2Fhw%2Fip%2Flc_ctrl%2Frtl%2Flc_ctrl_signal_decode.sv%23L114-L120&style=github&type=code&showBorder=on&showLineNumbers=on&showFileMeta=on&showFullPath=on&showCopy=on"></script>
<script src="https://emgithub.com/embed-v2.js?target=https%3A%2F%2Fgithub.com%2Fastroanax%2Fopentitan-test%2Fblob%2Fc704e4dc7b9c76ffda0d8a72675edfd9257cea2e%2Fhw%2Fip%2Flc_ctrl%2Frtl%2Flc_ctrl_signal_decode.sv%23L137-L141&style=github&type=code&showBorder=on&showLineNumbers=on&showFileMeta=on&showFullPath=on&showCopy=on"></script>


The attack flow for this bug is linked in the [Attachments](#attachment-links) section below.

## New Tools

**No automated detection tool.** Codex-based RTL inspection + DeepWiki AI analysis of the decode
enumeration.

## AI Tools

Yes



## LLM

Yes




## LLM Details

Codex-based inspection with DeepWiki confirmation (the DeepWiki session used the Codex model); GPT-5.6-Sol from https://agentrouter.org/v1 for the Lightsaber re-finding


## Online LLM Details

Orchestrator session total: **38,176,115 in / 26,998 out tokens** (the agentic session that ran the Lightsaber pipeline, session ses_031497488).

Estimated tokens for this bug's run (from `result.json` turn log: 20260805_162525 lc_ctrl agentic run (7 turns, 16,824 bytes)): **~22,406 in / ~2,940 out**. Estimate = file bytes / 4 + ~2,600 system-prompt tokens per turn; the run was part of a larger multi-IP campaign, so the per-bug figure is an approximation.


## LLM Prompts

Step-by-step discovery and verification (source: Codex-based inspection + Lightsaber agentic audit):

1. Candidate HW-001 (LcStProd in two `unique case` branches) was verified by the DeepWiki analysis session (Codex model), which confirmed the duplicate case items at `lc_ctrl_signal_decode.sv:109-124` and `:138-154` and that the test assertions would fail.
2. Lightsaber's lc_ctrl agent independently re-found it (run `20260805_162525`, 10 files read, DOUBT at turn 6): `LcStProd` in two case items enables debug/DFT in production.
3. Verified on the RTL: `lc_ctrl_signal_decode_tb.sv` drives `LcStProd` and observes `lc_dft_en/lc_nvm_debug_en/lc_hw_debug_en = On` in PROD.

Evidence:
- [logs/deepwiki/deepwiki-findings.txt line 77 (HW-001)](https://github.com/cscnitc/hackatches26/blob/main/logs/deepwiki/deepwiki-findings.txt#L77)
- [logs/lightsaber/bug-08-lcstprod/result.json](https://github.com/cscnitc/hackatches26/blob/main/logs/lightsaber/bug-08-lcstprod/result.json)



**Agent/session transcript:** [session transcript line 2625](https://github.com/cscnitc/hackatches26/blob/main/logs/transcripts/ses_031497488ffe0XqKwsri6rc7wa.txt#L2625) (finding #8 (LcStProd duplicate case)).


## Detection method

Codex-based RTL inspection of the `unique case` enumeration for duplicated case items
(LcStProd appears twice), cross-checked with DeepWiki. The `unique case` construct makes the
ambiguity a lint/synthesis violation by construction; the finding is the security-relevant
case-item collision.

## Security impact

If synthesis resolves `LcStProd` to the test-unlocked branch (line 116), production chips
ship with **hardware debug and DFT enabled** plus weaker key-manager diversification
constants - exposing protected memories and cryptographic material. If it resolves to the
production branch, key derivation uses weaker test constants, weakening cryptographic
isolation. Relying on tool-specific `unique case` resolution for security-critical decoding is
dangerous.

## Adversary profile

Type 2 - physical attacker with a JTAG/hardware debug probe on a production device.


## Proposed mitigation

Remove `LcStProd` from the test-unlocked case item (line 116); keep it only in the production
branch (line 139).

## CVSSv3.1 score and severity

**7.3 - HIGH**

## CVSSv3.1 Details

```
CVSS:3.1/AV:P/AC:L/PR:N/UI:N/S:C/C:H/I:H/A:N
```

- **AV:** Physical - debug probe on the device
- **AC:** Low - ambiguity resolves to debug-enabled decode
- **PR:** None
- **S:** Changed - crosses from LC domain into debug/DFT
- **C/I:** High - memory/crypto exposure and modification

## Attachment links

- [attack flow](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-08-lcstprod-duplicate/exploit)
- [testbench](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-08-lcstprod-duplicate/testbench)