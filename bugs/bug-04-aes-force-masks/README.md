# Bug 04 - Production ASIC Allows Software to Disable AES First-Order DPA Masking (`SecAesAllowForcingMasks=1`)

---

## Security feature bypassed

AES DPA/SCA masking countermeasure - the pseudo-random masking PRNG used for first-order differential power analysis protection


## Finding

The production ASIC chip-level template (`chiplevel.sv.tpl`) sets
`SecAesAllowForcingMasks=1'b1` for the ASIC / CW310 / CW340 / CW305 targets, overriding the
secure parameter default of `1'b0` (set in `top_earlgrey.sv:85`). This enables a
software-writable CSR bit (`CTRL_AUX_SHADOWED.FORCE_MASKS`) that forces the AES masking PRNG
(Bivium stream cipher) into an all-zero lockup state, **completely disabling the first-order
DPA countermeasure** while the AES core keeps producing correct ciphertext.

Data flow:

1. `chiplevel.sv.tpl` (lines 997, 1142, 1156): `.SecAesAllowForcingMasks(1'b1)` - **the bug**
2. `top_earlgrey.sv` (autogen, line 85): secure default `parameter bit SecAesAllowForcingMasks = 1'b0`
3. `aes_prng_masking.sv` (line 17): `parameter bit SecAllowForcingMasks = 0` - overridden at instantiation.
   Line 68 has a static lint assertion (`AesSecAllowForcingMasksNonDefault`) that fires when
   non-zero - **lint only, not a synthesis gate**
4. `aes_prng_masking.sv` (lines 102-103):
   ```verilog
   .allow_lockup_i(SecAllowForcingMasks & force_masks_i),
   .StrictLockupProtection(!SecAllowForcingMasks),
   ```
   With `SecAllowForcingMasks=1` AND software setting `force_masks_i=1`, the PRNG enters and
   stays in all-zero lockup, producing constant-zero masks.

## Location or code reference

- [hw/top_earlgrey/rtl/autogen/chip_earlgrey_asic.sv:1155-1157](https://github.com/astroanax/opentitan-test/blob/c704e4dc7b9c76ffda0d8a72675edfd9257cea2e/hw/top_earlgrey/rtl/autogen/chip_earlgrey_asic.sv#L1155-L1157) - `.SecAesAllowForcingMasks(1'b1)` on the production ASIC instance
- [hw/ip/aes/rtl/aes_prng_masking.sv:17](https://github.com/astroanax/opentitan-test/blob/c704e4dc7b9c76ffda0d8a72675edfd9257cea2e/hw/ip/aes/rtl/aes_prng_masking.sv#L17) - secure parameter default `SecAllowForcingMasks = 0`
- [hw/ip/aes/rtl/aes_prng_masking.sv:68](https://github.com/astroanax/opentitan-test/blob/c704e4dc7b9c76ffda0d8a72675edfd9257cea2e/hw/ip/aes/rtl/aes_prng_masking.sv#L68) - static lint guard that would flag the override
- [hw/ip/aes/rtl/aes_prng_masking.sv:102-103](https://github.com/astroanax/opentitan-test/blob/c704e4dc7b9c76ffda0d8a72675edfd9257cea2e/hw/ip/aes/rtl/aes_prng_masking.sv#L102-L103) - `.allow_lockup_i(SecAllowForcingMasks & force_masks_i)`

<script src="https://emgithub.com/embed-v2.js?target=https%3A%2F%2Fgithub.com%2Fastroanax%2Fopentitan-test%2Fblob%2Fc704e4dc7b9c76ffda0d8a72675edfd9257cea2e%2Fhw%2Ftop_earlgrey%2Frtl%2Fautogen%2Fchip_earlgrey_asic.sv%23L1155-L1159&style=github&type=code&showBorder=on&showLineNumbers=on&showFileMeta=on&showFullPath=on&showCopy=on"></script>
<script src="https://emgithub.com/embed-v2.js?target=https%3A%2F%2Fgithub.com%2Fastroanax%2Fopentitan-test%2Fblob%2Fc704e4dc7b9c76ffda0d8a72675edfd9257cea2e%2Fhw%2Fip%2Faes%2Frtl%2Faes_prng_masking.sv%23L100-L106&style=github&type=code&showBorder=on&showLineNumbers=on&showFileMeta=on&showFullPath=on&showCopy=on"></script>


The exploit for this bug is linked in the [Attachments](#attachment-links) section below.

## New Tools

**Yes** - custom VCS fuzzing pipeline. A minimal Verilator model replicated the exact
`aes_prng_masking` lockup logic; the fuzzer input is the `force_masks` control bit plus PRNG seed;
the property monitored is "mask output must not freeze to constant zero". the fuzzer mutated the
seed to all-zeros while setting `force_masks=1` - PRNG stays locked at zero - `abort()`.
Crash found within seconds from a safe seed (`logs/afl-fuzzer_stats`, `logs/afl-crash_input.bin`).

## AI Tools

Yes



## LLM

Yes




## LLM Details

GPT-5.6-Sol from https://agentrouter.org/v1


## Online LLM Details

Orchestrator session total: **38,176,115 in / 26,998 out tokens** (the agentic session that ran the Lightsaber pipeline, session ses_031497488).

Estimated tokens for this bug's run (from `result.json` turn log: 20260805_065040 aes agentic run (12 turns, 84,732 bytes)): **~52,383 in / ~5,445 out**. Estimate = file bytes / 4 + ~2,600 system-prompt tokens per turn; the run was part of a larger multi-IP campaign, so the per-bug figure is an approximation.


## LLM Prompts

Step-by-step discovery and verification (source: Lightsaber agentic audit (also flagged by static audit)):

1. Lightsaber audited the AES IP with the SystemVerilog auditor prompt, reading `aes.sv`, `aes_core.sv`, `aes_cipher_core.sv`, `aes_prng_masking.sv`, `aes.hjson`, and the top-level wrappers.
2. The model found that the AES wrapper exposes a secure default `SecAllowForcingMasks=0` but hard-codes `1` on the `u_aes_core` instance (`.SecAllowForcingMasks(1)`), so the software-controlled force-mask path (`CTRL_AUX_SHADOWED.FORCE_MASKS`) is reachable regardless of the top-level setting.
3. Verified on the RTL: `aes_prng_masking_tb.sv` shows masks lock to all-zero when `force_masks=1` with a zero seed (Phase A nonzero -> Phase B zero).

Evidence:
- [logs/lightsaber/bug-04-aes/result.json](https://github.com/cscnitc/hackatches26/blob/main/logs/lightsaber/bug-04-aes/result.json)



**Agent/session transcript:** [session transcript line 2455](https://github.com/cscnitc/hackatches26/blob/main/logs/transcripts/ses_031497488ffe0XqKwsri6rc7wa.txt#L2455) (finding #1 (AES mask-forcing)).


## Detection method

Automated detection with the custom VCS fuzzing pipeline (property: PRNG masks must not stay constant),
then a static parameter audit of every `SecAesAllowForcingMasks` instantiation site vs. the
secure default, and finally **confirmation on the actual OpenTitan RTL** - `aes_prng_masking_tb.sv`
instantiates the real module and shows `mask=0x0000…` constant under `force_masks=1` with a
zero seed (see `testbench/logs/rtl-test-simulation.log`).

## Security impact

Any software with TL-UL write access to `CTRL_AUX_SHADOWED` sets `FORCE_MASKS=1`, zeroing the
masking stream. Masked AES degenerates to effectively unmasked logic - all intermediate values
become linear functions of key and plaintext, and standard CPA/DPA with a few hundred traces
recovers the full AES key. The side-channel countermeasure is silently disabled.

## Adversary profile

Type 1 - unprivileged software on the Ibex core with MMIO access to the AES peripheral.


## Proposed mitigation

```verilog
.SecAesAllowForcingMasks(1'b0),   // production ASIC config
```

## CVSSv3.1 score and severity

**6.0 - MEDIUM**

## CVSSv3.1 Details

```
CVSS:3.1/AV:L/AC:L/PR:H/UI:N/S:C/C:H/I:N/A:N
```

- **AV:** Local - requires code execution on the core
- **AC:** Low - single CSR write
- **PR:** High - needs TL-UL access to the AES CSR (driver/privileged software)
- **S:** Changed - crosses from software into the cryptographic boundary
- **C:** High - AES key material recoverable via SCA

## Attachment links

- [exploit](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-04-aes-force-masks/exploit)
- [testbench](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-04-aes-force-masks/testbench)