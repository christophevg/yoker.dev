---
layout: post
title: Context Management
date: 2026-09-18
author: Christophe
tags: [announcement, yoker, changes]
excerpt: |
  Context equals tokens and tokens mean cost. With growing sessions, contexts also grow. Keeping contexts limited and on-topic is an important task for harnesses. The upcoming Yoker release is adding major steps at the level of context management.
---

A topic that has been on my TODO list for a long time is "context management". There was already an embryonic implementation in the codebase, yet with the upcoming 0.13.0 release, that has been expanded into a more functional pipeline.

Up to now, context compaction was actually rather hidden. A high watermark configuration, `context.max_tokens` set at 200_000 tokens, resulted in few occurrences and the implementation removed just enough messages to get back below the configured ceiling. 

I knew this implementation had landed in the codebase before, yet I only noticed it being active rather recently. Yoker is becoming more and more useful and stable and my sessions were becoming longer and longer, eventually reaching the 200K ceiling, and turn statistics suddenly showed declining numbers... context compaction in action.

So, this was the absolute right moment to finally address this topic. "Why? It works." Well, that compaction strategy comes at a cost. As long as context simply grows, repetitive calls to the LLM/server-side reuse previously cached contexts. In such a situation, usage consumption is lower than when a fresh context is sent.

By compacting the context, by literally removing old messages, it gets altered in such a way that its cached version becomes useless and a full recompute is needed. Combine that with only removing what is needed to go back below the high watermark and you get a constant going back and forth of a context that grows beyond the level, goes back below the level, grows immediately back beyond the level, and so on. That implies that as soon as we reached the ceiling, almost every call became a cache-miss. Costly.

So, this was _definitely_ the absolute right moment to finally address this topic.

Today, Yoker has a multi-stage compaction pipeline, with four phases, executed in sequence:
- `prune_tool_results` stubs old tool results.
- `prune_thinking` strips old thinking messages. On backends that submit thinking to the provider, like Anthropic, this reclaims real tokens. Elsewhere it mainly marks the history and keeps the report honest.
- `force_stub_tool_results` not only stubs old tool results, but also more recent ones
- `cutoff` simply cuts off what is still above the low watermark

We also have introduced a `compact_ratio` which, expressed as a fraction of the high watermark, determines the low watermark where after compaction we need to land. The pipeline first runs `prune_tool_results`, `prune_thinking` and `force_stub_tool_results`. These are semantic pruning operations that remove messages that are inherently not really useful anymore. Next, `cutoff` further trims until the low watermark is reached. It operates as a destructive fail-safe.

And even `cutoff` is restricted in what it can _cut_. The configuration enables you to protect the most important messages for every role. That way, at least your most recent messages will never be pruned. 

This results in a more advanced and useful context compaction, which now is also fully reported on in the UI. Here's an example from a session with a 125_000 tokens high watermark:

```
╭──────────────────────────── ⚙ Context compacted ────────────────────────────╮
│ Trimmed 210 message(s) — estimated 130,670 tokens exceeded the 125,000 cap. │
│ 689 messages remain (stored).                                               │
│ History starts at: assistant → tools: yoker__read | I'll read the feedback  │
│ prune_tool_results: −7 msg, −4.5K tokens                                    │
│ prune_thinking: −59 msg, −1.4K tokens                                       │
│ force_stub_tool_results: −2 msg, −2.3K tokens                               │
│ cutoff: −142 msg, −36.4K tokens                                             │
│ total: −210 msg, −44.6K → ≈74.8K remain (689 stored / 155 sent)             │
│ Trimmed to: ≈74.8K tokens.                                                  │
╰─────────────────────────────────────────────────────────────────────────────╯
```

It's in the repo, in use today in my sessions and soon available in the upcoming 0.13.0 release.
