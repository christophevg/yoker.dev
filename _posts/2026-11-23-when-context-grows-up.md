---
layout: post
title: "Yoker 0.13.0<br>When Context Grows Up"
date: 2026-11-23
author: Christophe and Yoker
tags: [announcement, yoker, changes]
excerpt: |
  Sessions got longer, contexts got bigger and the blunt "drop-the-oldest" compaction became the most expensive part of the loop. Yoker 0.13.0 replaces it with a pipeline, teaches the harness to count what it spends, and lets you abort a runaway turn with two keystrokes.
---

Long sessions were the best thing that happened to this codebase — and the reason compaction became unavoidable. The moment my sessions started living around the 200K ceiling, releasing 0.13.0 wasn't a choice but a deadline. This release is the pipeline that Septembers' [context management post](/2026/09/18/context-management/) promised: "in the repo, in use today in my sessions — and soon available." Now available.

## The compaction pipeline

The old behavior was one number, one cut: cross `context.max_tokens`, drop oldest messages until you're back under, repeat. Every cut rewrote the prefix the provider caches, so once you crossed the ceiling, roughly **every call became a cache miss**.

0.13.0 replaces the single cut with **four stages in sequence** — semantic removal first, destruction last:

1. `prune_tool_results` — stubs old large tool-result bodies
2. `prune_thinking` — strips old reasoning payloads
3. `force_stub_tool_results` — age-blind stubs whatever oversized tool result is left
4. `cutoff` — the backstop that drops the oldest non-setup messages

And a new `compact_ratio` (default `0.5`) decides where compaction *lands*: not at the ceiling, but at `max_tokens × 0.5`. A growing session now drifts up slowly from half the cap instead of re-crossing it immediately — fewer runs, and the server's prefix cache survives between trims. `compact_ratio = 1.0` reproduces the old behavior.

The cutting itself got a conscience too. `cutoff` protects up to one message per setup window — first user message, last user, last assistant, last tool-call batch — and clamps its target to a floor. A fully-flagged (no-op) run emits no panel at all. Every stage reports its impact:

```
╭──────────────────── ⚙ Context compacted ─────────────────────╮
│ Trimmed 210 message(s) — 130,670 tokens exceeded the cap.    │
│ prune_tool_results: −7 msg, −4.5K tokens                     │
│ prune_thinking: −59 msg, −1.4K tokens                        │
│ force_stub_tool_results: −2 msg, −2.3K tokens                │
│ cutoff: −142 msg, −36.4K tokens                              │
│ total: −210 msg, −44.6K → ≈74.8K remain (689 stored / 155 sent)
╰──────────────────────────────────────────────────────────────╯
```

Nothing is destroyed: stored history (the session JSONL) keeps everything, including thinking — every prune is a flag on a stored record, and `python scripts/context_report.py <session.jsonl>` replays every compaction run that ever happened.

## Count what you spend

The usage log (`~/.yoker/usage.jsonl`) is upgraded to a **telemetry log**: every record now carries per-agent identity (`agent_id`, `parent_agent_id`) and a `kind` — `llm_call`, `tool_call`, `turn`, `spawn`, `release`, `compaction`, `error`. Every token is counted exactly once, on the `llm_call` record — no double counting across the spawn tree.

Agents gained the right to read it: a new session-injected `stats` tool with scopes (self / subtree / session) and an optional watermark for delta measurement ("how much did that research agent actually cost?"). A `run_start` without a matching `run_end` is now the crash detector: the process died mid-run.

## Two keystrokes beat a session-resume dance

While a turn is running, `Esc Esc`(within ~0.6s) **aborts it cleanly** — partial streaming output is discarded, a tool that's mid-flight finishes and its result is kept, the remaining calls of the batch are recorded as aborted, and you land back at the prompt with a dim `■ Turn aborted.` The agent stays alive. No Ctrl+C-kill-session-restart-resume dance. Ctrl+C now participates in the same clean teardown instead of being a guillotine.

```python
# And programmatically:
agent.abort()                # False when idle; idempotent
session.abort_foreground()   # aborts the deepest in-flight agent
```

## Feeding context from the harness

Embedding code often owns live resources an agent's tools should see — a provider session, a lease, a connection. Until now "feeding it in" meant re-registering tools per agent. 0.13.0 introduces **bindings**:

```python
from yoker.tools import Binding

agent.bind(Binding(key="provider.session", value=session))  # or:
session = yoker.session(context_vars=[Binding(key="provider.session", value=session)])
```

The key is owned by the provider module, the harness passes the object, and tools read it via `ctx.get("provider.session")` — fresh on every call, merged down to spawned agents, no re-registration.

Also new: a **host-side tool-argument hook** (`Agent(tool_args_hook=...)`) — inspect or rewrite every dispatched tool call's arguments before guardrails see them (fail-safe: a raising hook never breaks the call).

## Vision, briefly

`read` now attaches image files (png/jpg/jpeg/gif/webp/bmp) as path references for vision models: session persistence stays lean (only the path is stored), a stateless send-once rule means long conversations stop re-sending the base64 payload every turn, and a calibration gate keeps the context gauge honest while images are in flight.

## And the rest of the backlog walked out the door

- **Search/websearch got budgets** — result snippets capped at 500 chars, total output capped (`max_output_kb`, default 50KB) with a remedy hint instead of a 300KB blob eating the context (field evidence: 9M chars of research snippets)
- **Reading images mid-conversation** behaves: batch image reads arrive attached on one request; the guidance tells the model that's its single chance
- **`yoker:stats`**, `--resume last`, weekday in the system prompt, tool-result previews on success lines, plugin tool-config bootstrap, schema-aware argument coercion, `make` accepts `docs/html`-style targets
- **Hermetic config loading**: `get_yoker_config(user=False, project=False)` — pure defaults, no file discovery, no plugin bootstrap. Built to keep host `yoker.toml` wiring out of tests; containers will thank you too.
- **Windows path guardrails fixed** (glob `**/` semantics + denylist depth bypass)

## Breaking changes worth your attention

- **Python 3.10 is dropped** — 3.11 through 3.14 now (CI runs the full matrix)
- **`update` flexible matching is gone** — matching is byte-exact now; flexible whitespace-normalized matching could absorb a preceding line's terminator and silently corrupt a file (reproduced live, twice). `require_exact_match` params/config keys hard-fail
- **Dead `permissions.network_access` field removed** — it never enforced anything; worse, its reminder made spawned researchers believe they had no web access (they did) and refuse work

## That's the release

Some fifty commits since 0.12.0, three months of convergence — the compaction pipeline grew from a cost observation into a real pipeline with hysteresis, protection windows and honest reporting. Install as always:

```bash
uv add yoker      # or: pip install yoker
```

If you're upgrading: `network_access` keys and `require_exact_match` settings need to leave your `yoker.toml`; everything else behaves like it did, just with more visibility into what it's doing and why.
