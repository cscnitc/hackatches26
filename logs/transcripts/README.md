# Agent Session Transcripts

Exact agent/session transcripts extracted from the local session database, cited
line-by-line from each bug's README (LLM Prompts section). Each `.txt` file is a
line-stable rendering (use `#L<line>` anchors to jump to the cited line); each
`.json` is the same session's structured extract (messages + parts).

| File | Session | Bugs citing it |
|------|---------|----------------|
| [ses_031497488ffe0XqKwsri6rc7wa.txt](ses_031497488ffe0XqKwsri6rc7wa.txt) | Lightsaber agentic audit runs (Kimi K3 fork #1) | 03, 04, 08, 10-17 |
| [ses_0336e81c1ffeFjDc6DwfGq7k4y.txt](ses_0336e81c1ffeFjDc6DwfGq7k4y.txt) | Custom VCS hardware-fuzzing pipeline | 01, 06, 07 |
| [ses_0d76e16e5ffefIIdzKXDm5dqXt.txt](ses_0d76e16e5ffefIIdzKXDm5dqXt.txt) | Manual JTAG/Debug Module RTL analysis | 05 |
| [json_hermes-7d4d8c17aa12.txt](json_hermes-7d4d8c17aa12.txt) | AFL-bugs session (external-scanner handoff) | 09 |

Credentials (API keys, tokens) present in the original sessions are redacted
(`[REDACTED]`) in these extracts.
