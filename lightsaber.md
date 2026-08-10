# Lightsaber - Agentic RTL Security Audit Pipeline

Bugs found with this pipeline: **03 (keymgr valid), 04 (AES force-masks), 08 (LcStProd),
10 (AES sbox counter), 11 (EDN), 12 (FSM), 13 (CSRNG unmasked), 14 (ROM ctrl), 15 (Markov),
16 (CSRNG remanence), 17 (OTBN URND)**.

LLM used: **GPT-5.6-Sol from [https://agentrouter.org/v1](https://agentrouter.org/v1)**

---

## Overview

**Lightsaber** ([github.com/cscnitc/lightsaber](https://github.com/cscnitc/lightsaber))
is our fork of [chipsalliance/mjolnir](https://github.com/chipsalliance/mjolnir),
an AI-driven security-audit framework for Root-of-Trust projects, upgraded into an
**agentic RTL security auditor**. Mjolnir's stock two-phase pipeline (Phase 1: per-file LLM
auditor; Phase 2: adversarial LLM reviewer) was extended so a single LLM agent iterates over
an IP: reads files, raises DOUBT questions, uses DeepWiki MCP for cross-file context, and
files findings with evidence levels. The agentic runs happened on the **ches1 machine**;
all logs are in [logs/lightsaber/](https://github.com/cscnitc/hackatches26/tree/main/logs/lightsaber) (copied from
`~/workspaces/ches/lightsaber-logs/`).

## What we added to Mjolnir (the Lightsaber fork)

1. **OpenAI-compatible provider** (`app/mjolnir/providers/openai/`) - calls
   `agentrouter.org/v1` (GPT-5.6-Sol) with the RooCode header set required to pass the
   provider's WAF, using the chat-completions path.
2. **SystemVerilog auditor prompt** (`systemverilog_auditor.md`) - RTL-specific coverage:
   fault injection and hardened FSMs, secret handling and data remanence, masking/DOM/power-EM
   side channels, reset/clock/CDC security, access control, width/index/parameter hazards,
   entropy and crypto control, alerts/escalation.
3. **Evidence levels (E0-E5)** in the finding model, and per-finding
   `deepwiki_context_status` / `deepwiki_verified` / `deepwiki_queries` tracking.
4. **DeepWiki MCP integration** - the agent queries
   `read_wiki_structure` / `read_wiki_contents` / `ask_question` for architecture and
   related-file context before filing cross-file claims.
5. **Agentic per-IP runs** (`run_agentic_audit.py --focus <ip>`): the agent gets a
   threat-model + SystemVerilog prompt, reads files, asks DOUBTs, and produces findings;
   crash-proof autosave writes `result.json` per turn and salvages findings on crash.

All changes were developed TDD-first (27 passing tests, including live API calls to
agentrouter and the DeepWiki MCP server).

## Run structure

```
lightsaber-logs/                       (copied to logs/lightsaber/)
├── session.json                       # 10 findings, deduplicated
├── agentic_runs/<ts>/result.json      # per-IP run (focus, files_read, findings)
├── agent_*.log                        # per-IP console log (turns, files, DOUBTs)
└── raw_outputs/<ts>/                  # batch single-file audit JSONs (AES, keymgr RTL)
```

Each `agentic_runs/<ts>/result.json` contains `files_read` (every file the agent examined)
and the finding's `file`/`location` (the exact place it was examining when it filed).

## Per-IP runs and what they found

| Run (ts) | Focus | Finding | Our bug |
|---|---|---|---|
| `20260805_062903` | (batch) | CTR_DRBG state through unmasked AES datapath | 13 |
| `20260805_065040` | (batch, aes) | AES mask-forcing feature unconditionally enabled | 04 |
| `20260805_082405` | keymgr | EDN data accepted without synthesized error path | 11 |
| `20260805_082405` | keymgr | Data-enable FSM illegal states recover silently | 12 |
| `20260805_154602` | rom_ctrl | Single-bit digest compare faultable mismatch->match | 14 |
| `20260805_154604` | entropy_src | Markov health-test thresholds never fail | 15 |
| `20260805_162525` | lc_ctrl | LcStProd in two `unique case` items | 08 |
| (csrng run crashed; finding recorded in session.json) | csrng | AES key/intermediate not zeroized | 16 |
| (otbn run crashed; finding in agent_otbn.log) | otbn | URND reseed accepts EDN without err check | 17 |
| batch (`raw_outputs/...060029+062100`) | aes | `aes_sbox_dom.sv` unhardened counter | 10 |
| first single-file run | keymgr | `key_i.valid` qualifier ignored | 03 |

## How to reproduce

Clone [github.com/cscnitc/lightsaber](https://github.com/cscnitc/lightsaber) and
install its dependencies. The agentic audit requires an OpenAI-compatible endpoint
reachable from the run machine. With `OPENAI_API_KEY` and `OPENAI_BASE_URL` set
(e.g. `https://agentrouter.org/v1`), run:

```bash
export OPENAI_API_KEY="<your-key>" OPENAI_BASE_URL="https://agentrouter.org/v1"
python3 run_agentic_audit.py --focus keymgr   # or any IP / rtl file path
```

Per-bug logs are in [logs/lightsaber/](https://github.com/cscnitc/hackatches26/tree/main/logs/lightsaber); each `result.json` is
self-contained (files read + finding + recommendation).
