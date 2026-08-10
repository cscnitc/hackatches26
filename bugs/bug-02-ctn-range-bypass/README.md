# Bug 02 - CTN Access-Range Check Permanently Overridden (Secure-Island Boundary Bypass)

---

## Security feature bypassed

CTN (Chip-to-Network) address-range and permission isolation - the RACL (Resource Access Control List) boundary of the Darjeeling Secure Island SoC

## Finding

`ac_range_check_overwrite_i` is **hardwired to `MuBi8True`** in the Darjeeling chip-level
template, permanently bypassing all CTN address-range and permission checks. A `TODO` comment
in the code marks it as temporary:

```verilog
// chiplevel.sv.tpl:842-844
// TODO: Override all access range checks for now.
prim_mubi_pkg::mubi8_t ac_range_check_overwrite_i;
assign ac_range_check_overwrite_i = prim_mubi_pkg::MuBi8True;
```

In `ac_range_check.sv`, a request is granted when **either** the address falls inside an
enabled range with proper permissions **or** `range_check_overwrite_i` is true:

```verilog
assign range_check_grant = ctn_tl_h2d_i.a_valid & (
                             (|addr_hit & (grant_mask > deny_mask)) |
                             prim_mubi_pkg::mubi8_test_true_strict(range_check_overwrite_i) );
```

With the override permanently true, **every valid CTN access is granted**, skipping the RACL
checks entirely. A correct check (`overwrite=MuBi8False`) with default all-zero
`RANGE_BASE/LIMIT` and `RANGE_ATTR.enable=MuBi4False` yields `addr_hit=0` - `range_check_fail=1`, the request is squashed with a TL-error response.

## Location or code reference

- [hw/top_darjeeling/templates/chiplevel.sv.tpl:842-844](https://github.com/astroanax/opentitan-test/blob/c704e4dc7b9c76ffda0d8a72675edfd9257cea2e/hw/top_darjeeling/templates/chiplevel.sv.tpl#L842-L844) - hardwired `ac_range_check_overwrite_i = MuBi8True` (TODO left in prod)
  - [hw/top_darjeeling/ip_autogen/ac_range_check/rtl/ac_range_check.sv:226-229](https://github.com/astroanax/opentitan-test/blob/c704e4dc7b9c76ffda0d8a72675edfd9257cea2e/hw/top_darjeeling/ip_autogen/ac_range_check/rtl/ac_range_check.sv#L226-L229) - grant logic honoring the unconditional overwrite
- [hw/top_darjeeling/rtl/autogen/chip_darjeeling_asic.sv:1466-1468](https://github.com/astroanax/opentitan-test/blob/c704e4dc7b9c76ffda0d8a72675edfd9257cea2e/hw/top_darjeeling/rtl/autogen/chip_darjeeling_asic.sv#L1466-L1468) - generated ASIC netlist carrying the hardwired override

<script src="https://emgithub.com/embed-v2.js?target=https%3A%2F%2Fgithub.com%2Fastroanax%2Fopentitan-test%2Fblob%2Fc704e4dc7b9c76ffda0d8a72675edfd9257cea2e%2Fhw%2Ftop_darjeeling%2Ftemplates%2Fchiplevel.sv.tpl%23L842-L844&style=github&type=code&showBorder=on&showLineNumbers=on&showFileMeta=on&showFullPath=on&showCopy=on"></script>
<script src="https://emgithub.com/embed-v2.js?target=https%3A%2F%2Fgithub.com%2Fastroanax%2Fopentitan-test%2Fblob%2Fc704e4dc7b9c76ffda0d8a72675edfd9257cea2e%2Fhw%2Ftop_darjeeling%2Fip_autogen%2Fac_range_check%2Frtl%2Fac_range_check.sv%23L224-L231&style=github&type=code&showBorder=on&showLineNumbers=on&showFileMeta=on&showFullPath=on&showCopy=on"></script>


The exploit for this bug is linked in the [Attachments](#attachment-links) section below.

## New Tools

No
## AI Tools

Yes


## LLM

Yes



## LLM Details

Codex-based inspection, with DeepWiki confirmation (the DeepWiki session used the Codex model; see logs/deepwiki/deepwiki-findings.txt)


## Online LLM Details

Input/output token counts and a verification script were not recorded; the model was called through an OpenAI's official endpoint.


## LLM Prompts

Step-by-step discovery and verification (source: Codex-based inspection and DeepWiki confirmation):

1. The candidate bug was first identified by Codex-based inspection of the Darjeeling chip-level RTL, then sent to a DeepWiki analysis session (same Codex model) for confirmation against `astroanax/opentitan-test`.
2. The model confirmed `ac_range_check_overwrite_i` is hardwired to `MuBi8True` in `chiplevel.sv.tpl:842-844` and `chip_darjeeling_asic.sv:1467-1468`, and that the grant logic in `ac_range_check.sv:226-229` grants every request when the override is true.
3. The finding was then confirmed on the RTL with a module testbench and a full-SoC dvsim run (`EXPLOIT SUCCESSFUL`, marker readback, P:1 100%).

Evidence:
- [logs/deepwiki/deepwiki-findings.txt](https://github.com/cscnitc/hackatches26/blob/main/logs/deepwiki/deepwiki-findings.txt)



**Agent/session transcript:** [deepwiki-findings.txt line 387](https://github.com/cscnitc/hackatches26/blob/main/logs/deepwiki/deepwiki-findings.txt#L387) (HW-002 confirmation).


## Detection method

Codex-based RTL inspection of `chiplevel.sv.tpl` for illegal hardwired constants, cross-checked
with DeepWiki, and **proven end-to-end on the full Darjeeling SoC**: a main-core OTTF test
(`bug8_ctn_exploit.c`) issues a raw access through the CTN window (`0x40000000`) to the
secure-island CTN SRAM (`0x41000000`), writes marker `0xBADC8008` and reads it back.
The correct range check would squash this out-of-range request; under the planted overwrite
the access is granted and the marker reads back intact (see `exploit/logs/full-soc-run.log`:
`EXPLOIT SUCCESSFUL` - `PASS!` - `SW TEST PASSED` - `TEST PASSED CHECKS`, dvsim P:1 100%).

## Security impact

The Darjeeling variant is a "Secure Island" for larger SoCs; the CTN interface is the primary
security boundary for external accesses. Permanently disabling address-range checks defeats
the RACL system - **any** external CTN request can access **any** address range without
restriction, exposing the secure island's memories and peripherals to the main SoC.

## Adversary profile

Type 1 - unprivileged software on the main SoC with access to the CTN window, or a network-side entity able to issue CTN transactions.


## Proposed mitigation

Remove the hardwired assignment; connect `ac_range_check_overwrite_i` to a configurable
source (OTP / lifecycle controller / register) and ensure the default is `MuBi8False` in
production configurations.

## CVSSv3.1 score and severity

**8.4 - HIGH**

## CVSSv3.1 Details

```
CVSS:3.1/AV:L/AC:L/PR:L/UI:N/S:C/C:H/I:H/A:N
```

- **AV:** Local - unprivileged software on the main SoC (via the CTN window)
- **AC:** Low - override is unconditional
- **PR:** Low - unprivileged software access on the main core
- **S:** Changed - crosses the secure-island boundary
- **C/I:** High - arbitrary read/write of secure-island resources

## Attachment links

- [exploit](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-02-ctn-range-bypass/exploit)
- [testbench](https://github.com/cscnitc/hackatches26/tree/main/bugs/bug-02-ctn-range-bypass/testbench)
