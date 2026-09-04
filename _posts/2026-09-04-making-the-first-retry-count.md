---
layout: post
title: "Yoker 0.12.0<br>Making the First Retry Count"
date: 2026-09-04
author: Christophe and Yoker
tags: [announcement, yoker, changes]
excerpt: |
  Every failed tool call in an agent loop costs twice: the call itself and the retry. Yoker 0.12.0 is about eliminating that burden: tools that accept what models naturally send, errors that teach and loops that know when to stop.
---

Every failed tool call in an agent workflow costs more than it looks.

It never stops at one call. The model emits its arguments, the tool rejects them and the whole exchange, reasoning, tool call, error, lands back in the context. The model re-reads everything, adjusts and tries again. A single "wrong" tool call costs a retry round trip *plus* a full context re-evaluation. Multiply that by a session full of edge cases and you're paying a hidden cost on every task your agents perform.

That observation became the theme of this release: **reduce tool errors and retry loops**: eliminate error classes entirely, make the first retry succeed and stop the loops that were never going to succeed anyway.

As always, 0.12.0 was built the way we build everything now: by using Yoker to build Yoker, hitting the walls ourselves and turning every wall into a fix. Here's what changed.

## Accept what the model naturally sends

The cheapest error is the one that never happens. Several tools used to reject things models send *all the time*, guaranteeing a retry loop before any real work started. No more!

**Bare tool names now just work.** Models regularly emit `list` instead of the namespaced `yoker:list` — a perfectly reasonable guess, often as instructed in definitions that took the liberty to use short tool names. Yoker used to answer with a dead end:

```
Error: Unknown tool 'list'.
```

Dispatch now falls back to bare-name resolution and if the name really is unknown, the error lists what *is* available so the next attempt is an informed one:

```
⏺ [17:26:35] primary: lst(path=".")
  𐄂 Fail
╭────────────────────────────────── ERROR ────────────────────────────────────╮
│ Error: Unknown tool 'lst'. Available tools: yoker:existence, yoker:file,    |
| yoker:git, yoker:github, yoker:list, yoker:make, yoker:mkdir, yoker:notify, |
| yoker:read, yoker:search, yoker:sleep, yoker:update, yoker:webfetch,        |
| yoker:websearch, yoker:write, yoker:skill, yoker:agent, yoker:release_agent,|
| yoker:send_message                                                          │
╰─────────────────────────────────────────────────────────────────────────────╯
```

**Writing into a new directory no longer needs a detour.** Creating `docs/guides/new-page.md` used to fail with "Parent directory does not exist", followed by the world's most predictable `mkdir` and a retry. The `write` tool now creates missing parent directories automatically. One call, as it should be.

**The GitHub tool believes its own documentation.** The docs always promised that `repo` "defaults to the current git repository", but the write operations (`pr_create`, `issue_create`...) rejected a missing repo. Now they honor it: gh auto-detects the repository from the git remote, just like the read operations always did.

**"0 entries" no longer lies to you.** This one cost us a few debug sessions. A search that returned zero matches *because everything was gitignored* read as "the file doesn't exist" and the agent happily concluded the wrong thing, or searched again. Tools now speak up:

```
0 entries (8 entries hidden by ignore rules (use include_ignored=true to show them))
```

Silent absence and visible-but-filtered are different things. Yoker now tells them apart.

## Fail with information, not just failure

Some errors are legitimate: the model asked for something impossible. But an error that only says *what broke* invites blind retries. An error that says *what would work* enables a fix on the first retry. Invalid-argument errors are now schema-driven:

```
[17:34:24] primary: yoker:search(pattern="TODO")
 𐄂 Fail
╭─────────────────────────────────── ERROR ────────────────────────────────────╮
│ Error: Invalid tool arguments: Invalid arguments for tool 'yoker:search':    │
│ missing required argument(s): path; unknown argument(s): ctx. Expected       │
│ arguments: path (required, string), pattern (optional, string), type         │
│ (optional, string), max_results (optional, integer), timeout_ms (optional,   │
│ integer), case_insensitive (optional, boolean), context_before (optional,    │
│ integer), context_after (optional, integer), include_pattern (optional,      │
│ string), exclude_pattern (optional, string), count_only (optional, boolean), │
│ include_ignored (optional, boolean), post_filter (optional, string)          │
╰──────────────────────────────────────────────────────────────────────────────╯
```

That's a real message that fired on the agent preparing this very post and it was able to correct itself in one step. Which is rather the point.

**Edits now show their work.** This is my favorite change of the release. The `update` and `write` tools return a diff of what they actually changed, so there's no read-after-write round trip to verify an edit _and_ no silent corruption:

```
File updated successfully (+3 −0)
--- quickstart.md (before)
+++ quickstart.md (after)
@@ -1,5 +1,8 @@
 # Quickstart

+## Requirements
+
+Python 3.10 or newer.
+
 ## Installation
```

The stat line (+3 −0) tells you the shape of the change at a glance, the diff tells you the details. If an edit did something unexpected, the agent sees it *immediately*, in the same tool result.

**Anchor-based inserts kill a whole failure class.** Inserting content used to mean emulating it with a replace: find the surrounding text, swap in text-plus-insertion. This failed with "Search text not found" whenever the anchor guess was off by a whitespace. The `update` tool now has a first-class insert mode:

```python
update(
  path="docs/quickstart.md",
  anchor="## Installation",
  position="before",
  new_string="## Requirements\n\nPython 3.10 or newer.\n",
)
```

The anchor itself is never modified and ambiguity fails loud instead of guessing:

```
Error: Search text appears multiple times; ambiguous match.
Found at line(s): 12, 58. Use line_range for line-based replace,
or provide more context in old_string.
```

## Know when to stop

Fixing error messages helps the model that's still thinking clearly. But every dogfooding session also showed us the darker pattern: a model stuck in a loop, retrying the same doomed approach for the fifth time, burning context on a strategy that was never going to work.

Yoker now counts consecutive failed tool calls and after the threshold (`agent.max_consecutive_tool_failures`, default 3, `0` disables) it injects a system-side note:

```
SYSTEM NOTE: Your last 3 tool calls failed consecutively. Stop retrying
the same approach — it is not working. Reconsider your strategy: read
the error messages, adjust the arguments, use a different tool, or STOP
and ask the user for help.
```

It fires once per failure streak, resets on the next success and reads like a tap on the shoulder rather than a slap. In our live testing it turned multi-turn spiral sessions into a single "you're right, let me step back and look at this differently" moment.

Related and just as important: agents now *know their boundaries*. The environment reminder states up front that there is no shell and no Bash tool, stop and tell the user instead of improvising. And the `agent` tool's descriptions explain that spawned agents start with a fresh context: project files and instructions pre-loaded, but no conversation history. Prompts must be self-contained. If you've ever told a sub-agent to "fix the bug we discussed" and watched it stare blankly, you know exactly why.

One more honesty fix while we're at it: the approval prompt for protected paths used to fabricate a nonsense diff like `-[git] Makefile / +[git] Makefile (approved)` for a read-only `git diff`. Tools now provide their own truthful previews: git names the actual operation, write and update show the real diff and the framework has a generic, honest fallback for everything else.

## Watching the meter

You can't tune what you don't measure. Yoker now logs every LLM API call to a local JSONL file (`~/.yoker/usage.jsonl`), one record per call, not per turn, so tool-loop iterations and sub-agents are all counted. A new report turns the log into answers:

```
% make usage
uv run python scripts/usage_report.py
Usage report  2026-09-01T13:32:02.750195+00:00 → 2026-09-04T15:34:29.916191+00:00
Sessions: 212    Calls: 4285

Model              Calls   Input tokens  Output tokens           Cost
qwen3.5               90            900           1800      $0.007020
glm-5.3-flash       4190      321975194        3800665     $50.196612
glm-5.3                5          88745           1503      $0.130856
Total               4285      322064839        3803968     $50.334488

Thinking estimate (client-side chars; ratio 1.36 chars/token calibrated from thinking-off calls): glm-5.3-flash: est thinking 7308493 tok (~$3.654247) | unexplained in reported output: +2635763 tok
  glm-5.3: est thinking 2794 tok (~$0.012294) | unexplained in reported output: -539 tok
Estimated total cost incl. thinking (upper bound): $54.001028

Note: cached-input pricing exists but usage logs do not record a cached-token
breakdown; cost is computed at full input price (conservative upper bound).
```

Pricing comes from a captured Ollama pricing table, unknown models are listed unpriced rather than silently dropped and because `eval_count` may or may not include thinking tokens, the report adds a client-side thinking-token estimate calibrated from your own non-thinking calls. After the dogfooding phase, watching the usage curve flatten while the work kept shipping was quietly satisfying. This report makes that visible in numbers.

## The agents can finally see the config

One last blind spot got fixed: Yoker's effective configuration is a merge of defaults, user TOML, project TOML, manifests and CLI flags. But agents could only read fragments of it. The result was a classic: a tool suddenly behaves differently, the agent can't see why and burns a few rounds investigating and/or draws the wrong conclusion entirely.

The environment reminder now embeds a curated and redacted snapshot of the active configuration:

```
# Effective Configuration (snapshot at session start)
* github allowed_operations: 12 read ops + write ops explicitly granted
* make allowed_env_vars: test: [TEST]; lint: [LINT_FLAGS, LINT_CONFIG]
* git permissions: auto-approved: [status, log, diff, …];
  approval required: [push, rm, pull, rebase]
* filesystem_paths: ., ../yoker-test
* network_access: none
* backend: ollama (model: glm-5.3-flash:cloud)
```

Redaction is structural, not filter-based: the renderer only ever reads an explicit allowlist of fields, so credentials structurally cannot leak. And yes, the first thing it surfaced in practice was a per-target env-var allowlist from *user-level* config that the agent had previously misread as something far more sinister.

## That's the release

Thirty-plus commits since 0.11.0, all of them earned by real friction, many of them small, but together they change the way of working with Yoker: fewer dead ends, faster recoveries and agents that know when to stop and ask instead of spinning out of control.

If you're already running Yoker, the usual brings it right where you want it:

```bash
uv add yoker      # or: pip install yoker
```

And if something misbehaves, don't worry: the error message the agents get back is now designed to be the *last* one they need.
