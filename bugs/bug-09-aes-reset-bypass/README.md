# Bug 09 - AES Data Output Register Reset Bypass (Secure Wipe Defeated)

---

## Security feature bypassed

AES output-register secure wipe on reset - the requirement that all AES state registers be zeroed when reset asserts


## Finding

In `aes_core.sv`, the `data_out_reg` always_ff block implements a **conditional reset** that
only clears the register when `data_out_we` is not equal to `SP2V_HIGH` (sparse enum
`3'b011`):

```verilog
// aes_core.sv:872-878
always_ff @(posedge clk_i or negedge rst_ni) begin : data_out_reg
    if (!rst_ni && data_out_we != SP2V_HIGH) begin   // BUG: conditional reset
      data_out_q <= '0;
    end else if (data_out_we == SP2V_HIGH) begin
      data_out_q <= data_out_d;                        // WRITES during reset!
    end
  end
```

**Mechanism:** when reset asserts (`rst_ni=0`) while `data_out_we == 3'b011` (the value
indicating valid output data):
1. The `if` condition `!rst_ni && data_out_we != SP2V_HIGH` - `1 && 0 = 0` - reset branch skipped
2. The `else if (data_out_we == SP2V_HIGH)` triggers - **writes `data_out_d` into
   `data_out_q` during reset** instead of clearing it

Contrast: `key_reg` and `IV_reg` use unconditional reset (`if (!rst_ni) ... <= '0; else if ...`).
Only `data_out_reg` has the gated reset.

## Location or code reference

- [hw/ip/aes/rtl/aes_core.sv:872-878](https://github.com/astroanax/opentitan-test/blob/c704e4dc7b9c76ffda0d8a72675edfd9257cea2e/hw/ip/aes/rtl/aes_core.sv#L872-L878) - conditional reset on `data_out_reg` (writes during reset when data_out_we == SP2V_HIGH)
  - [hw/ip/aes/rtl/aes_core.sv:860](https://github.com/astroanax/opentitan-test/blob/c704e4dc7b9c76ffda0d8a72675edfd9257cea2e/hw/ip/aes/rtl/aes_core.sv#L860) - reference: unconditional reset on reg_sp_enc_err

<script src="https://emgithub.com/embed-v2.js?target=https%3A%2F%2Fgithub.com%2Fastroanax%2Fopentitan-test%2Fblob%2Fc704e4dc7b9c76ffda0d8a72675edfd9257cea2e%2Fhw%2Fip%2Faes%2Frtl%2Faes_core.sv%23L872-L878&style=github&type=code&showBorder=on&showLineNumbers=on&showFileMeta=on&showFullPath=on&showCopy=on"></script>


The attack flow for this bug is linked in the [Attachments](#attachment-links) section below.

## New Tools

**Yes** - custom VCS fuzzing pipeline. A minimal Verilator model replicated the exact
`data_out_reg` logic (`sp2v_e` type, `SP2V_HIGH=3'b011`); the fuzzer inputs control `rst_ni`,
`data_out_we`, and 128-bit `data_in`. The model cycles reset-assert/write/deassert; if
`data_out_q` is non-zero after reset deassert - `abort()`. **Crash found within 15 s** from a
safe seed - the fuzzer mutated the control byte to `0x07` (rst=0, we=`3'b011`), triggering
write-during-reset (`logs/afl-fuzzer_stats`, `logs/afl-crash_input.bin`).

## AI Tools

Yes



## LLM

Yes




## LLM Details

Deepseek V4 Pro (1.6T params) from OpenCode Go https://opencode.ai/zen/go/v1


## Online LLM Details

Input/output token counts and a verification script are not recorded; the model was called through an OpenAI-compatible endpoint.


## LLM Prompts

Step-by-step discovery and verification (source: External scanner finding -> agent confirmation):

1. An external scanner emitted a JSON finding: 'Data output register can write sensitive data during reset instead of clearing', describing the gated reset `if (!rst_ni && data_out_we != SP2V_HIGH)`.
2. The agent confirmed it against `aes_core.sv:872-878`, noting the reset branch is skipped when `data_out_we == SP2V_HIGH`, so the `else if` writes `data_out_d` during reset.
3. Verified on the RTL with a real AES-128 encryption + timed reset glitch: `data_out_q` before glitch = 0x0, after glitch = 0x1a30325e... (ciphertext survives reset).

Evidence:
- [logs/rtl-test/bug-09-aes-reset/rtl-test-fixed-simulation.log](https://github.com/cscnitc/hackatches26/blob/main/logs/rtl-test/bug-09-aes-reset/rtl-test-fixed-simulation.log)



**Agent/session transcript:** [session transcript line 1133](https://github.com/cscnitc/hackatches26/blob/main/logs/transcripts/json_hermes-7d4d8c17aa12.txt#L1133) (out-of-band user message with the scanner finding).


## Detection method

Automated detection with the custom VCS fuzzing pipeline (property: `data_out_q` must be zero after
reset deassert), then **confirmation on the actual OpenTitan RTL** - `aes_core_tb.sv`
instantiates the `aes_core.sv` and observes write-during-reset behavior
(`testbench/logs/rtl-test-simulation.log`).

## Security impact

A physical attacker performing clock or reset fault injection times a reset glitch to
coincide with `data_out_we == SP2V_HIGH` (output data available). The output register is
**not** cleared - ciphertext/plaintext is written into `data_out_q`, survives the reset, and
software reads it back after reset. Violates the output-register secure-wipe requirement;
enables cross-reset-domain data exfiltration.

## Adversary profile

Type 2 - physical attacker with fault injection equipment (voltage/clock glitcher).


## Proposed mitigation

```verilog
always_ff @(posedge clk_i or negedge rst_ni) begin : data_out_reg
    if (!rst_ni) begin
      data_out_q <= '0;                    // Unconditional reset
    end else if (data_out_we == SP2V_HIGH) begin
      data_out_q <= data_out_d;
    end
  end
```

## CVSSv3.1 score and severity

**4.9 - MEDIUM**

## CVSSv3.1 Details

```
CVSS:3.1/AV:P/AC:H/PR:N/UI:N/S:C/C:H/I:N/A:N
```

- **AV:** Physical - fault injection equipment
- **AC:** High - precise timing needed to hit the WE=SP2V_HIGH window
- **PR:** None
- **S:** Changed - AES cryptographic data exposed across reset domain
- **C:** High - sensitive output data recoverable

## Attachment links

- [attack flow](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-09-aes-reset-bypass/exploit)
- [testbench](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-09-aes-reset-bypass/testbench)