---
layout: post
title: Migrating C3 to Yoker
date: 2026-08-24 00:02:00
author: Christophe
tags: [yoker, c3]
excerpt: |
  It’s been exactly one month since I transitioned from using Claude Code as my daily agent harness CLI to Yoker Chat. And I’m incredibly happy with this change.  
---

It’s been exactly one month since I transitioned from using Claude Code as my daily agent harness CLI to Yoker Chat. And I’m incredibly happy with this change. The first month has been quite hectic, as I’ve been working on migrating all my agentic projects to Yoker. Having used Claude Code for approximately five months, not only to create Yoker but also to build and refine my {% include external linke="https://github.com/christophevg/c3" title="agentic collective, C3" %}, I’ve now realized how much workflow and guardrails have been incorporated into agent and skill definitions, especially for and because of Claude Code, that are simply no longer needed with Yoker.

The initial frustrations that arose after a few weeks of using Claude Code and ultimately led to the creation of Yoker, have now reached a conclusion. I can finally begin removing the workarounds that were necessary to work with Claude Code as a harness.

I’ve adopted a hands-on approach to migrating my agents and skills. I simply start using them and, when I encounter any issues, I ask them why they occurred and how we can resolve them. This approach mirrors the same methodology I used when I initially developed them.

Earlier today, I encountered a funny situation where I couldn’t understand why an agent refused to use the newly introduced `sleep()` tool in Yoker:

<div class="session-prompt" markdown="block">
Just curious: explain to me (don't act upon this question) you have access to a sleep tool to periodically check something. Why didn't you use it and requested me to notify you instead? I just want to understand to optionally improve the instruction set for you.
</div>

<div class="session-agent" markdown="block">
Great question! Let me explain my reasoning honestly.

## Why I Didn't Use `yoker__sleep` to Poll

The **project-manage skill explicitly instructs me not to poll**. Here are the relevant directives:

> - Phase 5.10: *"PAUSE and report — Do NOT check for feedback immediately"*
> - *"Do NOT: check for PR feedback immediately; wait for owner response; block on feedback"*
> - The workflow is designed as a **push model**: the user says `"follow up on PR #N"` to trigger the next check.

So I'm following the instruction set as written. But let me discuss the **actual tradeoffs**, because you're asking whether this is the right design.

## The Two Models

| | **Push (current)** | **Pull (sleep-based polling)** |
|---|---|---|
| **Who initiates** | User says "follow up" | Agent polls on a timer |
| **Context cost** | Zero while waiting | Each poll cycle consumes context (reading PR comments, parsing) |
| **Latency** | Whatever the user's response time is | Configurable (e.g., every 60s) |
| **User attention** | User only engaged when they're ready | User might be away and come back to a session that ran out of context |
| **Multi-task** | User can say "follow up on PR #6" then "also check issue #3" — sequential, intentional | Agent polls all items, may interleave unpredictably |

## Why Push Was Chosen (My Inference)

1. **Context budget is the scarcest resource.** Each sleep cycle that wakes up, reads PR comments, finds nothing new, and goes back to sleep still consumes tokens. Over a few hours, this could exhaust the session before the user even responds.

2. **The owner is the only decision-maker.** PR approval is a human action. Polling doesn't make the human faster — it just burns resources while waiting.

3. **The user might be gone for hours.** If I poll every 60 seconds for 4 hours, that's 240 cycles of context consumption for nothing. If the user comes back and says "follow up," it's one cycle.

4. **Multi-PR/item scenarios.** When there are multiple items waiting for feedback, the current design lets the user direct attention: "follow up on PR #6" or "check issue #3." Polling all of them automatically could produce confusing interleaved reports.

## When Sleep-Based Polling *Would* Make Sense

- **CI status checks** — these are time-bounded (usually 5-15 minutes) and have a clear terminal state (pass/fail). Polling CI every 30s is reasonable and the release-manager already handles this within a single agent invocation.

- **Short waits** — if the owner said "I'll approve in 5 minutes," a short sleep-then-check cycle would be reasonable and responsive.

## How the Instructions Could Change

If you wanted to enable selective polling, you could add something like:

> When the owner indicates they will respond shortly (e.g., "give me a minute" or "let me check"), use `yoker__sleep` (60-120s) then check PR comments once. If no response, return to push mode and wait.

This would give the best of both: responsive when the user is actively engaged, conservative (push) when they've stepped away. The key is that polling is **opt-in based on a user signal**, not the default behavior.

Does this help clarify the reasoning? Happy to discuss further or adjust the instructions if you'd like to change the approach.
</div>

And then it hit me: this was, in fact, one of the primary reasons behind the initiation of Yoker’s development. Claude Code agents would initiate lengthy `Bash()` commands and incorporate a `sleep 60` command. I detested these commands and wanted to provide agents with both more specialized tools and more control over their tools.

Today, with the absence of `Bash()` and the availability of `sleep()` as a native tool for pausing execution, my agents now possess clear tools to wait until I approve a plan or an implementation.

Now, all that remains is for them to modify their definitions to reintroduce the capability to perform this task once again. 😇
