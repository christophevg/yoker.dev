---
layout: post
title: "Dogfooding Yoker: Building Yoker with Yoker"
date: 2026-08-27
author: Christophe
tags: [yoker, changes]
excerpt: |
  There's a moment in every build journey where you have to ask: "Does this thing actually work?" You can write tests, you can run demos, you can craft perfect examples, but until you've eaten your own dog food, you don't really know.
---

There's a moment in every build journey where you have to ask: "Does this thing actually work?" You can write tests, you can run demos, you can craft perfect examples, but until you've eaten your own dog food, you don't really know.

For Yoker, that moment came right after the v0.8.0 release. I had a working agent harness, a CLI, a tool framework, and a session system. But the real question was: could Yoker fix Yoker? Could it improve Yoker? Could Yoker _be_ Yoker's development companion?

## Let's Go!

As of July 29, I began using Yoker to continue its development, as well as all other projects I used to work on using Claude Code. Since then, I haven’t looked back. Although I sometimes feel a bit constrained, this new agentic environment has been an absolute delight to work in.

With each commit, Yoker has become more stable, more user-friendly, and numerous bugs have been fixed. In just a few weeks, I’ve achieved a more productive environment and can already feel the advantages of my own interactive harness, built using my own harness framework.

While Yoker 0.10.0 was a worthy first majorly announced release, it wasn’t yet ready for a 1.0.0 label. I soon discovered several significant issues that I clearly wanted to address, and these require substantial changes.

## The Setup

The first signs of this transition are clearly visible in the git log itself: `🤖 Implemented together with Yoker`. I consolidated scattered notes and instructions (`CLAUDE.md`, `DEVELOPMENT.md`, `NOTES.md`) into a single `AGENTS.md`. At startup, Yoker reads this file to understand the project it’s working on. Additionally, I migrated the Makefile from supporting Claude Code tooling to Yoker itself.

From a split-screen GhosTTY terminal, one side displayed Yoker working on one of our projects, while the other side had Yoker working on Yoker. Consequently, issues arising from working on the project on the left were addressed on the right. A simple restart of the sessions enabled the fixes and new features. Everything was set to continue evolving Yoker with Yoker.

> **Public Service Announcement**: Since Yoker development is inherently done within or by Yoker, and primarily by the underlying LLM, I can no longer simply claim that _I_ added a feature or fixed a bug. Therefore, I'm clearly not using the **royal we** when I continue below using the **we** form.

## Expanding the Toolbox

One of the most tangible outcomes of dogfooding was discovering what tools were missing. When you're actually _using_ your own tool framework every day, the gaps become painful fast.

### The `notify` Tool

When long-running agent tasks finish, you want to know. We added a `notify` tool that sends macOS notifications. Simple, but extremely useful for a smooth workflow where you kick off a task and step away while the agents do their thing.

### The `sleep` Tool

For workflows that require polling, for example to wait for CI to finish, we added a `sleep` tool. It's the kind of tool you don't think you need until you're building an inherently asynchronous workflow and realize the agent has no way to wait. 

### File Operations (copy, move, delete)

The tool suite already had `read`, `write` and `update` tools, but no way to move or delete files. The `file` tool filled that gap with three operations: `copy`, `move`, and `delete`.

### Git Tool Expansion

The `git` tool grew substantially during dogfooding. It got additional subcommands and options to enable the agents to be more autonomous: `rebase`, `tag create`,`checkout`, `set_upstream` on push, `ref` argument for log/diff/show, a `files` array on `add` and `rm`.

### GitHub Tool Expansion

Similarly, the GitHub tool went from basic read operations to a full PR lifecycle toolkit: `pr_create`, `pr_ready`, `pr_draft`, `pr_edit`, `pr_comment`, `pr_reviews`, `pr_comments`, `pr_view`, `release_create` and `workflow_logs` transformed Yoker from a read-only GitHub observer into a full GitHub workflow participant.

### Search & List Improvements

The `search` tool now accepts a file path (not just directories), so you can "grep" within one file. It now also allows to ignore paths already defined in e.g. `.gitignore`.

### Update Tool Evolution

The initial `update` tool had simple string replace support. Seeing agents struggle often enough, we added `line_range` support, fuzzy matching, operation inference and explicit `delete`.

These changes made the update tool much more robust against the kinds of edge cases that real-world editing produces.

## The Post-Filter Revolution

This was arguably the single most important improvement to come out of dogfooding.

When running an agent with tools that return large outputs, for example a `make test` with hundreds of test cases, `git log` with 100 commits, `search` across an entire codebase, the context window fills up fast. We needed a way to let the agent request *only the relevant lines* from tool output.

With `Bash()` available LLMs often used `| grep ...` to filter out what they actually were looking for. Out of this common pattern the **`post_filter`** parameter was born. _Every tool_ now accepts an optional regex pattern that filters output line-by-line, keeping only matching lines. The agent learned to use patterns like `FAILED|Traceback|assert` on test runs, or `class |def |import ` on file reads.

This feature fundamentally changed how efficiently Yoker operates. It's now baked into the agent instructions as a mandatory practice. It was the first step towards context management and the agents are in control.

## Path Guardrail: From Hardcoded to Spec-Driven

The security model underwent a major redesign. The original `PathGuardrail` had a hardcoded tool name lists to decide which tools needed path approval. This was brittle and didn't scale.

We replaced it with a **spec-driven guard lookup**. The guardrail now introspects the `ToolSpec` to find `Path` annotations on parameters, rather than maintaining a hardcoded list. This means any new tool that annotates a parameter with `Path` automatically gets guardrail protection.

Other guardrail improvements include separate read and write permission models instead of a single gate, an allowed scope check before prompting, extension checks were generalized to paths in general, a new three layer permission system simplified and made the overall system more robust.

## Session & Agent Lifecycle

Dogfooding revealed several issues with how spawned agents behave in a session: spawned agents were released too early, making follow-up messages impossible. We fixed this so agents stay active and can be addressed with `send_message`. In addition we again put agents in control and added the `ephemeral` parameter to `agent` spawning. Ephemeral agents are automatically released after responding, perfect for one-shot tasks like research or code review. Also added: the `release_agent` tool** which enables agents to explicitly release persistent agents to free session capacity.

In the UI the `/session` command allows to list all active agents in the session. When the UI terminates, it now also prints a hint showing how to resume the session.

## UI Polish

Talking about the UI. Although Yoker primarily is an agent harness frameworks, of course I spent most of my time in the `chat` subcommand, in an interactive session with the agents. The interactive UI received extensive polish, all driven by the friction of using it daily:

- **Markdown streaming** — Rich-powered markdown rendering of agent responses as they stream in
- **Timestamps** — events now show timestamps for better traceability
- **MOTD config** — customizable Message of the Day banner
- **Agent name in output** — every agent's output now shows the agent name with color coding
- **Unified tool output formatting** — tool results are displayed with middle-collapse previews (long output is truncated in the middle, not at the end, so you see both the beginning and the error)
- **Approval preview** — unified into a single Panel for cleaner display

## Configuration Improvements

Yoker is highly configurable. I basically want every feature to be controllable from the `yoker.toml` configuration files. This got further expanded with an `enabled` master switch to enable/disable the entire agent system, configurable context files replaced the hardcoded `AGENTS.md` with a configurable list of context files, dict-based directories added support for explicit namespace mapping in directory configuration...

## The Numbers

And many, many more small and larger bug fixes, tweaks, experiments and improvements over the entire spectrum of the Yoker ecosystem.

Across this initial dogfooding phase we really picked up the pace:

| Metric | Value |
|--------|-------|
| Commits | ~150+ |
| New tools | 3 (notify, sleep, file) |
| New git operations | 6+ (rebase, tag, checkout -b, set_upstream, rm, ref arg) |
| New github operations | 8+ (pr_create, pr_ready, pr_draft, pr_edit, pr_comment, pr_reviews, pr_comments, release_create, workflow_logs) |
| Major guardrail redesigns | 2 (spec-driven lookup, read/write split) |
| Versions released | 3 (v0.9.0, v0.10.0, v0.10.1) |

## What We Learned

The biggest lesson is also the most obvious one: **using your own tool reveals exactly what it's missing.** Every feature added during dogfooding came from a real friction point. The `post_filter` system, the JSON repair, the ephemeral agents, the gitignore-aware search — none of these came from a roadmap. They came from the agent hitting a wall and us saying "we need a tool for this."

The second lesson: **security models need to be spec-driven, not hardcoded.** The moment we added a new tool that touched the filesystem, the hardcoded guardrail list was wrong. Moving to spec-driven guard lookup made the security model self-maintaining.

The third lesson: **context management is the #1 agent performance factor.** The `post_filter` system alone probably doubled the effective context budget. When you're dogfooding, you feel every wasted token.

## The Net Effect?

With every change, I can observe a drop in my Ollama credit usage statistics. The workflow becomes more and more tuned, using less and less resources, while doing more and more work. After roughly a month of dogfooding, I'm really starting to see how my ideas on how a harness should work, start to pay off.
