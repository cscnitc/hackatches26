# Bug 06 - Lifecycle Token Hash Compared Only on Lower 32 Bits (2^128 - 2^32)

---

## Security feature bypassed

Lifecycle Controller token authentication - the KMAC-based 128-bit hash comparison gating all LC state transitions


## Finding

The 128-bit KMAC hash is compared only on its lower 32 bits. Both `hashed_token_i` and
`hashed_token_mux` are declared `lc_token_t` (128 bits), but the equality test uses `[31:0]`,
reducing effective security from 2^128 to 2^32:

```verilog
// lc_ctrl_fsm.sv:456 and :497
if (hashed_token_i[31:0] == hashed_token_mux[31:0] &&
    !token_hash_err_i &&
    &hashed_token_valid_mux) begin
```

Type declaration (`lc_ctrl_state_pkg.sv:412-413`): `parameter int LcTokenWidth = 128;`

## Location or code reference

- [hw/ip/lc_ctrl/rtl/lc_ctrl_fsm.sv:456](https://github.com/astroanax/opentitan-test/blob/c704e4dc7b9c76ffda0d8a72675edfd9257cea2e/hw/ip/lc_ctrl/rtl/lc_ctrl_fsm.sv#L456) - `hashed_token_i[31:0] == hashed_token_mux[31:0]` (32-bit compare)
  - [hw/ip/lc_ctrl/rtl/lc_ctrl_fsm.sv:497](https://github.com/astroanax/opentitan-test/blob/c704e4dc7b9c76ffda0d8a72675edfd9257cea2e/hw/ip/lc_ctrl/rtl/lc_ctrl_fsm.sv#L497) - second comparison site with the same 32-bit truncation
- [hw/ip/lc_ctrl/rtl/lc_ctrl_state_pkg.sv:412-413](https://github.com/astroanax/opentitan-test/blob/c704e4dc7b9c76ffda0d8a72675edfd9257cea2e/hw/ip/lc_ctrl/rtl/lc_ctrl_state_pkg.sv#L412-L413) - `LcTokenWidth = 128` - the declared token width

<script src="https://emgithub.com/embed-v2.js?target=https%3A%2F%2Fgithub.com%2Fastroanax%2Fopentitan-test%2Fblob%2Fc704e4dc7b9c76ffda0d8a72675edfd9257cea2e%2Fhw%2Fip%2Flc_ctrl%2Frtl%2Flc_ctrl_fsm.sv%23L454-L460&style=github&type=code&showBorder=on&showLineNumbers=on&showFileMeta=on&showFullPath=on&showCopy=on"></script>
<script src="https://emgithub.com/embed-v2.js?target=https%3A%2F%2Fgithub.com%2Fastroanax%2Fopentitan-test%2Fblob%2Fc704e4dc7b9c76ffda0d8a72675edfd9257cea2e%2Fhw%2Fip%2Flc_ctrl%2Frtl%2Flc_ctrl_fsm.sv%23L495-L500&style=github&type=code&showBorder=on&showLineNumbers=on&showFileMeta=on&showFullPath=on&showCopy=on"></script>


The attack flow for this bug is linked in the [Attachments](#attachment-links) section below.

## New Tools

**Yes** - custom VCS (U-2023.03) token-matching fuzzer: generated token pairs differing in the
upper 96 bits but matching in the lower 32 bits; the buggy check accepts them, the correct
128-bit check rejects them. Verified with a directed testbench on the **`lc_ctrl_fsm` RTL**
(`tb_bug03_lc_fsm.sv`, PROD-RMA transition, forged token accepted - see
`exploit/logs/bug-003-lc-fsm-vcs-simulation.log`). A standalone comparison testbench
(`bug-003-tb-token-trunc.sv`) exercised 100+ token pairs.

## AI Tools

Yes



## LLM

Yes




## LLM Details

Deepseek V4 Pro (1.6T params) from OpenCode Go https://opencode.ai/zen/go/v1


## Online LLM Details

Orchestrator session total: **81,873,919 in / 53,192 out tokens** (the agentic session that ran the custom VCS hardware-fuzzing pipeline; session ses_0336e81c1ffeFjDc6DwfGq7k4y).

Per-bug token estimates are not available: the pipeline ran as a continuous fuzzing session (compile + simulation campaigns across the three bugs) rather than per-bug agentic runs, so the orchestrator total is the only recorded figure.


## LLM Prompts

Step-by-step discovery and verification (source: Custom VCS hardware-fuzzing pipeline):

1. The VCS token-matching fuzzer generated 100+ random 128-bit token pairs and ran the buggy 32-bit comparison against the correct 128-bit comparison in parallel simulation.
2. It flagged every case where tokens differing in the upper 96 bits passed the buggy `[31:0]` check.
3. Confirmed on the RTL: `tb_bug03_lc_fsm.sv` drives a PROD->RMA transition with a forged token (matching only `[31:0]`); the FSM completes the transition with `trans_success_seen=1, tokerr_seen=0` (honest VCS log).

Evidence:
- [logs/vcs-pipeline/bug-06-lc-token/bug-003-honest-vcs-simulation.log](https://github.com/cscnitc/hackatches26/blob/main/logs/vcs-pipeline/bug-06-lc-token/bug-003-honest-vcs-simulation.log)



**Agent/session transcript:** [session transcript line 351](https://github.com/cscnitc/hackatches26/blob/main/logs/transcripts/ses_0336e81c1ffeFjDc6DwfGq7k4y.txt#L351) (writes tb_bug03_lc_token.sv).


## Detection method

Automated VCS fuzzing + width audit.

**Honest scope (corrected):** with all FSM handshakes driven (token-hash ack,
flash-RMA ack, OTP ack), the `lc_ctrl_fsm` RTL genuinely completes a
PROD->RMA transition with a forged token whose upper 96 bits are wrong
(`bug-003-honest-vcs-simulation.log`: `trans_success_seen=1 tokerr_seen=0`).
The earlier log stalled in FlashRmaSt and overclaimed; it is superseded. compared the declared signal widths (128 bits)
against the bit-select in the equality expression (`[31:0]` = 32 bits). Confirmed on the real
`lc_ctrl_fsm` RTL - a token differing only in the upper 96 bits passes the buggy check and
authorizes the transition.

## Security impact

Attacker brute-force reduced from 2^128 to 2^32 guesses (~4.3 × 10^9). Enables unauthorized
LC transitions (RAW-TEST_UNLOCKED0, DEV-RMA, PROD-PROD_END). The OTP transition counter
limits per-device attempts to 24, but multi-device attacks become feasible and the stated
128-bit security goal is violated.

## Adversary profile

Type 2 - physical attacker with access to the LC transition interface (OTP token inputs).


## Proposed mitigation

Compare the full hash width:

```verilog
if (hashed_token_i == hashed_token_mux &&
    !token_hash_err_i &&
    &hashed_token_valid_mux) begin
```

## CVSSv3.1 score and severity

**6.4 - MEDIUM**

## CVSSv3.1 Details

```
CVSS:3.1/AV:L/AC:H/PR:H/UI:N/S:U/C:H/I:H/A:H
```

- **AV:** Local - token inputs driven at the LC interface
- **AC:** High - requires 2^32 brute-force work
- **PR:** High - access to token interface / OTP
- **S:** Unchanged - within the LC domain
- **C/I/A:** High - unauthorized state transitions

## Attachment links

- [attack flow](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-06-lc-token-trunc/exploit)
- [testbench](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-06-lc-token-trunc/testbench)