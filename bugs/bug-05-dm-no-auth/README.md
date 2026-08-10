# Bug 05 - Debug Module Authentication Hardwired to 1 (Unauthenticated JTAG Debug)

---

## Security feature bypassed

RISC-V Debug Specification v0.13 password authentication - the mandatory `dmstatus.authenticated` gate


## Finding

`dmstatus.authenticated` is hardwired to `1'b1` with the comment "no authentication
implemented". The `AuthData` CSR (address 0x30, defined in `dm_pkg.sv:80`) is declared but
**never handled** in any read/write case statement - writes are silently dropped, reads return 0:

```verilog
// dm_csrs.sv:231
dmstatus.authenticated = 1'b1;  // No authentication implemented
```

## Location or code reference

- [hw/vendor/pulp_riscv_dbg/src/dm_csrs.sv:231](https://github.com/astroanax/opentitan-test/blob/c704e4dc7b9c76ffda0d8a72675edfd9257cea2e/hw/vendor/pulp_riscv_dbg/src/dm_csrs.sv#L231) - `dmstatus.authenticated = 1'b1;` hardwired
- [hw/vendor/pulp_riscv_dbg/src/dm_pkg.sv:80](https://github.com/astroanax/opentitan-test/blob/c704e4dc7b9c76ffda0d8a72675edfd9257cea2e/hw/vendor/pulp_riscv_dbg/src/dm_pkg.sv#L80) - AuthData CSR defined but never handled

<script src="https://emgithub.com/embed-v2.js?target=https%3A%2F%2Fgithub.com%2Fastroanax%2Fopentitan-test%2Fblob%2Fc704e4dc7b9c76ffda0d8a72675edfd9257cea2e%2Fhw%2Fvendor%2Fpulp_riscv_dbg%2Fsrc%2Fdm_csrs.sv%23L229-L233&style=github&type=code&showBorder=on&showLineNumbers=on&showFileMeta=on&showFullPath=on&showCopy=on"></script>


The exploit for this bug is linked in the [Attachments](#attachment-links) section below.

## New Tools

**No automated detection tool.** Agent-based RTL inspection: a grep for "authenticated" across the
vendor subtree returns only the constant assignment; a grep for "AuthData" confirms the CSR
address is never handled.

## AI Tools

Yes



## LLM

Yes




## LLM Details

Deepseek V4 Pro (1.6T params) from OpenCode Go https://opencode.ai/zen/go/v1


## Online LLM Details

Input/output token counts and a verification script are not recorded; the model was called through an OpenAI-compatible endpoint.


## LLM Prompts

Step-by-step discovery and verification (source: Agent-based RTL analysis):

1. The agent analyzed the JTAG/Debug Module RTL and grepped for auth-related signals (`authenticated`, `AuthData`, `password`).
2. It found `dmstatus.authenticated = 1'b1` hardwired at `dm_csrs.sv:231` with the comment 'no authentication implemented', and confirmed `AuthData` (0x30) is never handled in the read/write case statements.
3. Verified on the RTL: a DMI read of DMSTATUS returns `authenticated=1` with no AuthData handshake (see testbench logs), and later on the full SoC via OpenOCD (`dmstatus =0x00000c82`).

Evidence:
- [logs/rtl-test/bug-05-dm/rtl-test-simulation.log](https://github.com/cscnitc/hackatches26/blob/main/logs/rtl-test/bug-05-dm/rtl-test-simulation.log)



**Agent/session transcript:** [session transcript line 67](https://github.com/cscnitc/hackatches26/blob/main/logs/transcripts/ses_0d76e16e5ffefIIdzKXDm5dqXt.txt#L67) (dm_csrs.sv:231 authenticated hardwired).


## Detection method

Agent-based RTL inspection (constant-assignment grep).

**Full-SoC evidence (real OpenOCD against the Verilator dmidpi socket):**
`exploit/full-soc-openocd/ocd_dmi_read.log` - a genuine remote_bitbang session
returns `dmstatus =0x00000c82` (authenticated bit set) with zero AuthData
writes. The earlier MMIO-based exploit C (wrong base address; DMI is not
TL-UL MMIO) was corrected - DMSTATUS is a DMI CSR, reachable only via the
debug interface. **Confirmed on the actual OpenTitan RTL:**
`dm_csrs_tb.sv` instantiates the `dm_csrs.sv` with its genuine dependency chain
(`dm_pkg`, prims) and performs a DMI read of DMSTATUS **with no AuthData handshake** -
the response carries `authenticated=1` (see `testbench/logs/rtl-test-simulation.log`:
`*** BUG #2 CONFIRMED on actual OpenTitan RTL ***`, `data=0x000c0c82`, bit 10 set).

## Security impact

Any entity with JTAG/DMI access obtains full, unauthenticated debug control: halt/resume
harts, read/write all CSRs, system-bus access, and arbitrary code execution via the program
buffer. In TEST_UNLOCKED / DEV / RMA lifecycle states (where LC gating is open), a ~$30 JTAG
probe (FT2232H) suffices for complete device compromise - key extraction, firmware
modification, code injection.

## Adversary profile

Type 2 - physical attacker with a JTAG probe (e.g. FT2232H + OpenOCD).


## Proposed mitigation

```verilog
// Implement a proper authentication FSM:
dmstatus.authenticated = auth_state_q;   // not 1'b1
// Add AuthData write handler: compare write against provisioned secret
```

## CVSSv3.1 score and severity

**7.6 - HIGH**

## CVSSv3.1 Details

```
CVSS:3.1/AV:P/AC:L/PR:N/UI:N/S:C/C:H/I:H/A:H
```

- **AV:** Physical - requires JTAG connection to the device
- **AC:** Low - no negotiation, no timing constraints
- **PR:** None - no password, no credentials
- **S:** Changed - crosses from debug port into all SoC domains
- **C/I/A:** High - full register/memory read-write, code execution

## Attachment links

- [exploit](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-05-dm-no-auth/exploit)
- [testbench](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-05-dm-no-auth/testbench)