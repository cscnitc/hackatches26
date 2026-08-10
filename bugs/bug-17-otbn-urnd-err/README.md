# Bug 17 - OTBN: URND Reseeding Accepts EDN Entropy Without Error Checking

---

## Security feature bypassed

OTBN cryptographic PRNG entropy integrity - the URND reseed validation path


## Finding

The EDN response error signals are generated but **never checked** by the URND reseed path -
`urnd_reseed_req_i` triggers reseeding regardless of EDN response quality, and the ACK is
sent even on bad entropy:

```verilog
// otbn_rnd.sv:38-51
output logic rnd_rep_err_o,    // EDN repetition error - set but UNCHECKED by URND
output logic rnd_fips_err_o,   // EDN FIPS error - set but UNCHECKED by URND
input  logic urnd_reseed_req_i, // URND reseed request - accepted unconditionally
output logic urnd_reseed_ack_o, // ACK sent even on bad entropy
```

The URND reseed state machine accepts the request and acknowledges without checking EDN
response validity - a faulted EDN bus (all-zeros or replayed entropy) reseeds the OTBN PRNG
silently.

## Location or code reference

- [hw/ip/otbn/rtl/otbn_rnd.sv:38-51](https://github.com/astroanax/opentitan-test/blob/c704e4dc7b9c76ffda0d8a72675edfd9257cea2e/hw/ip/otbn/rtl/otbn_rnd.sv#L38-L51) - EDN error outputs set but unchecked by the URND reseed path
- [hw/ip/otbn/rtl/otbn_rnd.sv:178](https://github.com/astroanax/opentitan-test/blob/c704e4dc7b9c76ffda0d8a72675edfd9257cea2e/hw/ip/otbn/rtl/otbn_rnd.sv#L178) - `urnd_reseed_ack_o = edn_urnd_ack_i` - ACK issued despite edn_urnd_err_i=1

<script src="https://emgithub.com/embed-v2.js?target=https%3A%2F%2Fgithub.com%2Fastroanax%2Fopentitan-test%2Fblob%2Fc704e4dc7b9c76ffda0d8a72675edfd9257cea2e%2Fhw%2Fip%2Fotbn%2Frtl%2Fotbn_rnd.sv%23L36-L52&style=github&type=code&showBorder=on&showLineNumbers=on&showFileMeta=on&showFullPath=on&showCopy=on"></script>
<script src="https://emgithub.com/embed-v2.js?target=https%3A%2F%2Fgithub.com%2Fastroanax%2Fopentitan-test%2Fblob%2Fc704e4dc7b9c76ffda0d8a72675edfd9257cea2e%2Fhw%2Fip%2Fotbn%2Frtl%2Fotbn_rnd.sv%23L176-L180&style=github&type=code&showBorder=on&showLineNumbers=on&showFileMeta=on&showFullPath=on&showCopy=on"></script>


The attack flow for this bug is linked in the [Attachments](#attachment-links) section below.

## New Tools

**Yes** - module instantiation (Verilator 4.210):
`otbn_rnd_tb.sv` instantiates the `otbn_rnd.sv` with its genuine dependency chain,
drives a reseed with `edn_urnd_err_i=1`, and observes the ACK is still issued while
`xoshiro_seed_en` ignores the error (see `testbench/logs/rtl-test-simulation.log`:
`*** BUG #24 CONFIRMED on actual OpenTitan RTL ***`).

## AI Tools

Yes



## LLM

Yes




## LLM Details

GPT-5.6-Sol from https://agentrouter.org/v1


## Online LLM Details

Orchestrator session total: **38,176,115 in / 26,998 out tokens** (the agentic session that ran the Lightsaber pipeline, session ses_031497488).

Estimated tokens for this bug's run (from `result.json` turn log: otbn agentic run crashed on quota): **not estimable (run crashed before writing result.json; finding in agent_otbn.log)**. Estimate = file bytes / 4 + ~2,600 system-prompt tokens per turn; the run was part of a larger multi-IP campaign, so the per-bug figure is an approximation.


## LLM Prompts

Step-by-step discovery and verification (source: Lightsaber agentic audit (salvaged from agent log)):

1. Lightsaber's otbn agent read `otbn.sv`, `otbn_start_stop_control.sv`, then `otbn_rnd.sv` twice (with a DOUBT) before filing the finding; the run crashed before writing `result.json` and was salvaged from `agent_otbn.log`.
2. The finding: 'URND reseeding accepts EDN responses without validating response error or health' - `otbn_rnd.sv` passes `edn_urnd_ack_i` through to `urnd_reseed_ack_o` without checking `edn_rnd_err_i`/`edn_rnd_fips_i`.
3. Verified on the RTL: the TB latches the seed-enable pulse and the EDN error during the handshake (`xoshiro_seed_en seen HIGH: 1 (latched)`, `err latched: 1`).

Evidence:
- [logs/lightsaber/bug-17-otbn/agent_otbn.log](https://github.com/cscnitc/hackatches26/blob/main/logs/lightsaber/bug-17-otbn/agent_otbn.log)



**Agent/session transcript:** [session transcript line 2625](https://github.com/cscnitc/hackatches26/blob/main/logs/transcripts/ses_031497488ffe0XqKwsri6rc7wa.txt#L2625) (finding #10 (OTBN URND)).


## Detection method

Module instantiation (property: reseed ACK must be gated on EDN response validity) +
RTL grep evidence (`logs/rtl_evidence.log`).

## Security impact

OTBN PRNG state poisoned with attacker-controlled entropy; all OTBN cryptographic operations
using URND (key generation, masking, blinding) produce predictable output - secure-computation
results compromised.

## Adversary profile

Type 2 - physical attacker faulting the EDN bus during an OTBN URND reseed.


## Proposed mitigation

```verilog
// Only acknowledge the reseed if the EDN response was valid:
assign urnd_reseed_ack_o = urnd_reseed_req_i && !rnd_fips_err_o && !rnd_rep_err_o;
```

## CVSSv3.1 score and severity

**4.9 - MEDIUM**

## CVSSv3.1 Details

```
CVSS:3.1/AV:P/AC:H/PR:N/UI:N/S:C/C:H/I:N/A:N
```

- **AV:** Physical - EDN bus fault injection
- **AC:** High - precise glitch timing
- **PR:** None
- **S:** Changed - crosses from entropy path into OTBN outputs
- **C:** High - predictable OTBN randomness

## Attachment links

- [attack flow](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-17-otbn-urnd-err/exploit)
- [testbench](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-17-otbn-urnd-err/testbench)