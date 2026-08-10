# Bug 16 - CSRNG: AES Key and State Not Zeroized After Operation (Key Remanence)

---

## Security feature bypassed

CSRNG key-material remanence protection - the post-operation zeroization of DRBG key state


## Finding

After a CSRNG AES-CTR_DRBG operation the AES key (the DRBG state) and intermediate data
remain in registers: `key_clear_i` is **hardwired to 0** and `key_clear_o` is **unconnected** -
the AES cipher core's key clearing mechanism is explicitly disabled:

```verilog
// csrng_block_encrypt.sv:116-117
.key_clear_i  ( 1'b0 ),    // BUG: Key clearing disabled
.key_clear_o  (       ),    // BUG: Clear output unconnected
```

## Location or code reference

- [hw/ip/csrng/rtl/csrng_block_encrypt.sv:116-117](https://github.com/astroanax/opentitan-test/blob/c704e4dc7b9c76ffda0d8a72675edfd9257cea2e/hw/ip/csrng/rtl/csrng_block_encrypt.sv#L116-L117) - `.key_clear_i(1'b0), .key_clear_o()` - zeroization disabled/unconnected

<script src="https://emgithub.com/embed-v2.js?target=https%3A%2F%2Fgithub.com%2Fastroanax%2Fopentitan-test%2Fblob%2Fc704e4dc7b9c76ffda0d8a72675edfd9257cea2e%2Fhw%2Fip%2Fcsrng%2Frtl%2Fcsrng_block_encrypt.sv%23L114-L119&style=github&type=code&showBorder=on&showLineNumbers=on&showFileMeta=on&showFullPath=on&showCopy=on"></script>


The attack flow for this bug is linked in the [Attachments](#attachment-links) section below.

## New Tools

**Yes** - static RTL audit (grep `key_clear_i.*1'b0` - CONFIRMED at lines 116-117) +
module instantiation (Verilator 4.210): `csrng_block_encrypt_tb.sv` instantiates
the real module and confirms the disabled zeroization path
(see `testbench/logs/rtl-test-simulation.log`).

## AI Tools

Yes



## LLM

Yes




## LLM Details

GPT-5.6-Sol from https://agentrouter.org/v1


## Online LLM Details

Orchestrator session total: **38,176,115 in / 26,998 out tokens** (the agentic session that ran the Lightsaber pipeline, session ses_031497488).

Estimated tokens for this bug's run (from `result.json` turn log: csrng agentic run crashed on quota): **not estimable (run crashed before writing result.json; finding recorded in session.json)**. Estimate = file bytes / 4 + ~2,600 system-prompt tokens per turn; the run was part of a larger multi-IP campaign, so the per-bug figure is an approximation.


## LLM Prompts

Step-by-step discovery and verification (source: Lightsaber agentic audit (salvaged from agent log)):

1. Lightsaber's csrng agent produced a finding but the run crashed before writing `result.json` (quota exhausted); the finding was recorded in `session.json` (title + `focus: csrng`). The agent log copy is empty, so `session.json` is the evidence for this finding.
2. The finding: 'AES key and internal data are not explicitly cleared after CSRNG encryption' - `csrng_block_encrypt.sv` ties `.key_clear_i(1'b0)` and leaves `.key_clear_o()` unconnected, so the DRBG key persists in the AES cipher core registers.
3. Verified on the RTL: `csrng_block_encrypt_tb.sv` confirms `key_clear_i=0` (see testbench logs).

Evidence:
- [logs/lightsaber/session.json](https://github.com/cscnitc/hackatches26/blob/main/logs/lightsaber/session.json) (entry: 'AES key and internal data are not explicitly cleared after CSRNG encryption operations')



**Agent/session transcript:** [session transcript line 2625](https://github.com/cscnitc/hackatches26/blob/main/logs/transcripts/ses_031497488ffe0XqKwsri6rc7wa.txt#L2625) (finding #9 (CSRNG remanence)).


## Detection method

Static RTL audit + module instantiation. Security property: after operation completion
the AES key registers must be zeroized; the evidence shows the zeroization request is never
generated.

## Security impact

DRBG state (128-bit K) persists in the AES cipher core registers after CSRNG operation.
Combined with a register-read capability (debug bypass, scan chain, fault-induced register
dump), an attacker recovers the DRBG state and predicts **all past and future** CSRNG output -
every key derived since the state was loaded is compromised.

## Adversary profile

Type 2 - physical attacker with register-read capability (JTAG/scan-chain access).


## Proposed mitigation

```verilog
.key_clear_i  ( key_clear_req ),    // connect to state machine
.key_clear_o  ( key_clear_done ),   // connect to state machine
```

State machine: after each CSRNG operation assert `key_clear_i`, wait for `key_clear_o`,
then idle.

## CVSSv3.1 score and severity

**4.9 - MEDIUM**

## CVSSv3.1 Details

```
CVSS:3.1/AV:P/AC:H/PR:N/UI:N/S:C/C:H/I:N/A:N
```

- **AV:** Physical - register read via debug/fault
- **AC:** High - requires a register-read primitive
- **PR:** None
- **S:** Changed - crosses from CSRNG into all derived randomness
- **C:** High - full DRBG state disclosure

## Attachment links

- [attack flow](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-16-csrng-key-remanence/exploit)
- [testbench](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-16-csrng-key-remanence/testbench)