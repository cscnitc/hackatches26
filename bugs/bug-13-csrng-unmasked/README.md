# Bug 13 - CSRNG CTR_DRBG State Leaked via Unmasked AES Datapath

---

## Security feature bypassed

CSRNG internal state confidentiality - the first-order side-channel protection on the AES-128 CTR_DRBG datapath


## Finding

The CSRNG AES cipher core is instantiated with `.SecMasking(1'b0)` - **masking explicitly
disabled**:

```verilog
// csrng_block_encrypt.sv:95
aes_cipher_core #(
  .AES192Enable  ( 1'b0 ),
  .CiphOpFwdOnly ( 1'b1 ),
  .SecMasking    ( 1'b0 ),  // BUG: Masking explicitly disabled
  .SecSBoxImpl   ( SBoxImpl )
) u_aes_cipher_core (...);
```

The CTR_DRBG secret state (key K + V) is processed with no side-channel protection. Power/EM
traces of CSRNG operations leak the AES key, which **is** the DRBG state, enabling recovery
and prediction of all future random output.

## Location or code reference

- [hw/ip/csrng/rtl/csrng_block_encrypt.sv:95](https://github.com/astroanax/opentitan-test/blob/c704e4dc7b9c76ffda0d8a72675edfd9257cea2e/hw/ip/csrng/rtl/csrng_block_encrypt.sv#L95) - `.SecMasking(1'b0)` - masking explicitly disabled

<script src="https://emgithub.com/embed-v2.js?target=https%3A%2F%2Fgithub.com%2Fastroanax%2Fopentitan-test%2Fblob%2Fc704e4dc7b9c76ffda0d8a72675edfd9257cea2e%2Fhw%2Fip%2Fcsrng%2Frtl%2Fcsrng_block_encrypt.sv%23L93-L98&style=github&type=code&showBorder=on&showLineNumbers=on&showFileMeta=on&showFullPath=on&showCopy=on"></script>


The exploit for this bug is linked in the [Attachments](#attachment-links) section below.

## New Tools

**Yes** - static RTL audit (grep for `SecMasking` parameter at instantiation sites,
cross-referenced against the secure default `1'b1`) + module instantiation
(Verilator 4.210): `csrng_block_encrypt_tb.sv` instantiates the real module with its genuine
dependency chain and confirms the unmasked instantiation (see `testbench/logs/`).

## AI Tools

Yes



## LLM

Yes




## LLM Details

GPT-5.6-Sol from https://agentrouter.org/v1


## Online LLM Details

Orchestrator session total: **38,176,115 in / 26,998 out tokens** (the agentic session that ran the Lightsaber pipeline, session ses_031497488).

Estimated tokens for this bug's run (from `result.json` turn log: 20260805_062903 agentic run (6 turns, 79,586 bytes)): **~35,496 in / ~3,534 out**. Estimate = file bytes / 4 + ~2,600 system-prompt tokens per turn; the run was part of a larger multi-IP campaign, so the per-bug figure is an approximation.


## LLM Prompts

Step-by-step discovery and verification (source: Lightsaber agentic audit):

1. Lightsaber's batch run (`20260805_062903`) read 23 RTL files including `csrng_block_encrypt.sv`, `csrng_core.sv`, `csrng_ctr_drbg_*.sv`.
2. It flagged: 'CTR_DRBG secret state is processed by an explicitly unmasked AES datapath' - `csrng_block_encrypt.sv` loads the secret DRBG key into `key_init[0]` and instantiates `aes_cipher_core` with `.SecMasking(1'b0)`, `NumShares=1`, entropy ack tied low, entropy data zero, and the LUT (unmasked) SBox.
3. Verified on the RTL: `csrng_block_encrypt_tb.sv` confirms `SecMasking=0`; the SCA analysis recovers the key algebraically from the exact RTL S-box intermediate (honest oracle framing).

Evidence:
- [logs/lightsaber/bug-13-csrng-unmasked/result.json](https://github.com/cscnitc/hackatches26/blob/main/logs/lightsaber/bug-13-csrng-unmasked/result.json)



**Agent/session transcript:** [session transcript line 2517](https://github.com/cscnitc/hackatches26/blob/main/logs/transcripts/ses_031497488ffe0XqKwsri6rc7wa.txt#L2517) (finding #2 (CSRNG unmasked)).


## Detection method

**Honest framing:** the demonstrated key recovery is **algebraic** from the
exact RTL S-box intermediate in a noise-free simulation oracle
(`key = invSBOX(obs) ^ pt`), NOT a measured power/EM-traces CPA. The
structural claim - the CSRNG AES datapath is unmasked (SecMasking=0) -
is what the RTL proves; a real physical SCA would additionally require
trace acquisition and a leakage model.

Static parameter audit: grep `SecMasking.*1'b0` in `csrng_block_encrypt.sv` (line 95
CONFIRMED unmasked), verified by compiling the the RTL module closure under Verilator and
inspecting the instantiation parameter flow. **Full attack demonstrated:** the SCA testbench
(`exploit/code/aes_sca_tb.sv`) captures 24-cycle S-box leak snapshots for 256 plaintexts on the
`aes_cipher_core`; CPA (`exploit/code/cpa_analysis.py`) and direct key recovery
(`exploit/code/key_recover.py`) recover all 16 round-1 key bytes from 261 traces
(`exploit/logs/cpa_unmasked_result.txt`).

## Security impact

**Demoed CPA result (raw `exploit/logs/cpa_unmasked_result.txt`):**

```
traces: 261
varying pt bytes: [0, 1, 2, ..., 15]
offset 0: 16 consistent (obs byte varies) mappings
    obs[ 0] candidate keys - ['03']
    obs[ 1] candidate keys - ['07']
    ... (all 16 bytes resolved)
```

Complete prediction of CSRNG output. Every key, nonce, IV, and random value derived after
state recovery is known to the attacker - TLS session keys, Key Manager keys (which use CSRNG
for entropy), and OTBN random numbers are all compromised.

## Adversary profile

Type 2 - physical attacker with power/EM measurement equipment (oscilloscope, EM probe).


## Proposed mitigation

```verilog
.SecMasking(1'b1)  // enable DPA protection on AES
```

## CVSSv3.1 score and severity

**6.8 - MEDIUM**

## CVSSv3.1 Details

```
CVSS:3.1/AV:P/AC:H/PR:N/UI:N/S:C/C:H/I:H/A:N
```

- **AV:** Physical - trace acquisition on the device
- **AC:** High - CPA/DPA analysis required
- **PR:** None
- **S:** Changed - crosses from CSRNG into all derived keys
- **C/I:** High - full DRBG state recovery and prediction

## Attachment links

- [exploit](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-13-csrng-unmasked/exploit)
- [testbench](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-13-csrng-unmasked/testbench)