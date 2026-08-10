# Bug 10 - AES S-Box DOM Unhardened Stage Counter: Fault-Induced Stage Skipping - Full Key Recovery via DFA

---

## Security feature bypassed

AES S-Box Domain-Oriented Masking (DOM) stage sequencing - the 5-stage masked-inversion schedule providing first-order DPA resistance


## Finding

The entire five-cycle DOM schedule is governed by a plain 3-bit binary counter with **no
hardening whatsoever** (no redundant encoding, Hamming-distance protection, parity,
consistency check, or legal-transition validation, and **no `err_o` output**):

```verilog
// aes_sbox_dom.sv:1050-1067
logic [2:0] count_d, count_q;
assign count_d = (out_req_o && out_ack_i) ? '0             :
                 out_req_o                ? count_q        :
                 en_i                     ? count_q + 3'd1 : count_q;

always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni)  count_q <= '0;
    else          count_q <= count_d;
  end

assign out_req_o = en_i & count_q == 3'd4;
assign we[0] = en_i & count_q == 3'd0;
assign we[1] = en_i & count_q == 3'd1;
assign we[2] = en_i & count_q == 3'd2;
assign we[3] = en_i & count_q == 3'd3;
```

**Fault scenario 1 (skip all stages):** a single-bit fault on `count_q[2]` flips `3'b000` -
`3'b100`; `out_req_o` asserts **without executing any** of the four inversion stages
(`we[0:3]`). The unmasked S-Box output is consumed by the AES datapath.

**Fault scenario 2 (skip/repeat stages):** bit flips on `count_q[1:0]` skip or repeat
individual `we[]` pulses, corrupting the masked computation order.

## Location or code reference

- [hw/ip/aes/rtl/aes_sbox_dom.sv:1050-1053](https://github.com/astroanax/opentitan-test/blob/c704e4dc7b9c76ffda0d8a72675edfd9257cea2e/hw/ip/aes/rtl/aes_sbox_dom.sv#L1050-L1053) - plain 3-bit binary counter `count_d/count_q` (no hardening)
  - [hw/ip/aes/rtl/aes_sbox_dom.sv:1055-1058](https://github.com/astroanax/opentitan-test/blob/c704e4dc7b9c76ffda0d8a72675edfd9257cea2e/hw/ip/aes/rtl/aes_sbox_dom.sv#L1055-L1058) - counter register
- [hw/ip/aes/rtl/aes_sbox_dom.sv:1061](https://github.com/astroanax/opentitan-test/blob/c704e4dc7b9c76ffda0d8a72675edfd9257cea2e/hw/ip/aes/rtl/aes_sbox_dom.sv#L1061) - `out_req_o = en_i & count_q == 3'd4` - single-bit flip skips all stages
- [hw/ip/aes/rtl/aes_sbox_dom.sv:1064-1067](https://github.com/astroanax/opentitan-test/blob/c704e4dc7b9c76ffda0d8a72675edfd9257cea2e/hw/ip/aes/rtl/aes_sbox_dom.sv#L1064-L1067) - we[3:0] stage decode gated by the unhardened counter

<script src="https://emgithub.com/embed-v2.js?target=https%3A%2F%2Fgithub.com%2Fastroanax%2Fopentitan-test%2Fblob%2Fc704e4dc7b9c76ffda0d8a72675edfd9257cea2e%2Fhw%2Fip%2Faes%2Frtl%2Faes_sbox_dom.sv%23L1050-L1067&style=github&type=code&showBorder=on&showLineNumbers=on&showFileMeta=on&showFullPath=on&showCopy=on"></script>


The exploit for this bug is linked in the [Attachments](#attachment-links) section below.

## New Tools

**Yes** - custom VCS fuzzing pipeline. A minimal Verilator model replicated the counter logic
with a `fault_inject` port; the fuzzer mutated the fault value and discovered `0x40` (counter=3'd4)
triggers immediate `out_req_o` with zero `we[]` stages completed. **Crash in <10 s** from a
safe seed. Fault injection value `0x40` triggers the stage-skip; normal operation exits
cleanly.

## AI Tools

Yes



## LLM

Yes




## LLM Details

GPT-5.6-Sol from https://agentrouter.org/v1


## Online LLM Details

Orchestrator session total: **38,176,115 in / 26,998 out tokens** (the agentic session that ran the Lightsaber pipeline, session ses_031497488).

Estimated tokens for this bug's run (from `result.json` turn log: batch audit of aes_sbox_dom.sv (41,943 bytes, single file pass)): **~13,000 in / ~800 out**. Estimate = file bytes / 4 + ~2,600 system-prompt tokens per turn; the run was part of a larger multi-IP campaign, so the per-bug figure is an approximation.


## LLM Prompts

Step-by-step discovery and verification (source: Lightsaber agentic audit (batch single-file audit)):

1. Lightsaber batch-audited `aes_sbox_dom.sv` (runs `20260805_060029` / `062100` in `raw_outputs/`).
2. The model flagged: 'Fault-induced stage skipping via unhardened binary counter - a 3-bit binary counter controls the 5-cycle S-Box schedule; a single-bit fault skips/repeats stages with no error output.'
3. Verified on the RTL: module FI demo (`fi17.v`) forces `count_q` and shows the fault is SILENT; full DFA on the `aes_cipher_core` recovers the AES-128 master key from chosen-value byte faults (see exploit logs).

Evidence:
- [logs/lightsaber/bug-10-aes-sbox/result.json](https://github.com/cscnitc/hackatches26/blob/main/logs/lightsaber/bug-10-aes-sbox/result.json)



**Agent/session transcript:** [session transcript line 1971](https://github.com/cscnitc/hackatches26/blob/main/logs/transcripts/ses_031497488ffe0XqKwsri6rc7wa.txt#L1971) (aes_sbox_dom.sv unhardened counter finding).


## Detection method

Automated detection with the custom VCS fuzzing pipeline (property: `out_req_o` must not fire before all
four `we[]` stages complete - `we_history != 4'b1111` - abort), then module-level FI
confirmation on the RTL under VCS (`fi17.v` force of `count_q` - fault is SILENT, no error
output), then **full DFA key recovery on the `aes_cipher_core` RTL** (see below).

## Security impact

Complete AES key extraction via Differential Fault Analysis. A single-bit flip on `count_q[2]`
(~33% probability with an untargeted glitch, 1 of 3 counter bits) skips directly to output;
the masked S-Box emits a faulty, unmasked value consumed by the AES datapath. 1-3 faulty
ciphertexts suffice for full AES-128 key recovery (Piret-Quisquater DFA).

**Full-chain proof on the RTL (VCS):** fault injection on the `aes_cipher_core`
(counter stage-skip's observable effect - one round-9 state byte forced to a known value)
yields exactly-one-byte ciphertext faults; `dfa_recover.py` recovers the round-10 key from
256 faulted ciphertexts (16 positions × 4 values × 4 plaintexts) and the inverse key schedule
recovers the master key **exactly**:

```
K10 (round-10 key) = 13111d7fe3944a17f307a78b4d2b30c5
master key        = 000102030405060708090a0b0c0d0e0f   - EXACT (FIPS-197 KAT key)
*** DFA SUCCESS: AES-128 MASTER KEY RECOVERED ***
```

See `exploit/logs/dfa_run.log`, `run_good.log`, `run_fault5.log`, `fi17_run.log`.

## Adversary profile

Type 2 - physical attacker with fault injection equipment (EM probe or voltage glitcher).


## Proposed mitigation

- Add fault detection to the counter: parity / Hamming-distance ≥ 2 encoding
  (e.g. two counters compared, or 1-of-N stage encoding), and
- Assert an `err_o` / alert on illegal counter transitions.

## CVSSv3.1 score and severity

**4.9 - MEDIUM**

## CVSSv3.1 Details

```
CVSS:3.1/AV:P/AC:H/PR:N/UI:N/S:C/C:H/I:N/A:N
```

- **AV:** Physical - fault injection on the device
- **AC:** High - precise timing within the 5-cycle DOM window
- **PR:** None
- **S:** Changed - crosses from counter into key material
- **C:** High - full AES-128 key extraction (DFA)

## Attachment links

- [exploit](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-10-aes-sbox-dfa/exploit)
- [testbench](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-10-aes-sbox-dfa/testbench)