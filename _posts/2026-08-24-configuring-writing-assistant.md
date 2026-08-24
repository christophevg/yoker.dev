---
layout: post
title: Configuring Writing Assistant
date: 2026-08-24 00:03:00
author: Christophe
tags: [tips 'n tricks, yoker]
excerpt: |
  While adding this blog section to the site, I once again appreciated the simplicity of the Yoker framework approach, when I wanted to use the Yoker Writing Assistant.
---

While adding this [blog](/blog) section to the site, I once again appreciated the simplicity of the Yoker framework approach, when I wanted to use the {% include external link="https://pypi.org/projects/yoker-writing-assistant" title="Yoker Writing Assistant" %}.

Yoker Writing Assistant is primarily a project designed to demonstrate how to easily create a standalone assistant agent that assists with writing projects, such as a website, a book... Since I'm already running a Yoker session to build this website, I wanted to integrate the assistant.

Here are the minimal additions to a `yoker.toml` configuration to achieve that:

```toml
[plugins]
enabled = true
packages = ["yoker_writing_assistant"]

[plugins.trusted]
yoker_writing_assistant = true

[permissions]
filesystem_paths = [".", "~/VOICE.md"]
```

These settings, from top to bottom, are:

1. Enabling the use of plugins, which I prefer to do explicitly for each project.
2. Loading the `yoker_writing_assistant` package.
3. Pre-approving the use of the package.
4. Granting explicit access to my personal `VOICE.md` description, located in my home folder.

Of course, you need to install the package. A simple `pip install yoker-writing-assistant` does the trick, or if you are already using `uv`, combine these changes with an added dependency in the `pyproject.toml`:

```toml
dependencies = [ "yoker-writing-assistant" ]
```

Et voilà... Yoker Writing Assistant is now ready to assist you!

<div class="session-prompt" markdown="block">
Ask the writing assistant to briefly describe what it can do for me.
</div>

<div class="session-agent" markdown="block">
Here's what the writing assistant says it can do for you:

---

It's your **writing coach and developmental editor** — it challenges your thinking, surfaces gaps, and tracks structure, but never writes prose for you.

**Core capabilities:**

| Skill | What it does |
|-------|-------------|
| **writing-review** | Developmental edit — claim extraction, fact verification, gap analysis, advisory report |
| **writing-continuity** | Checks references resolve, concepts introduced before use, themes stay in sync |
| **writing-voice** | Flags voice drift and \"ChatGPT smell\" against your voice profile |
| **writing-mistakes** | Flags eggcorns, redundancies, non-native errors, passive voice, throat-clearing |
| **writing-idioms** | Flags misused idioms, proposes canonical forms |
| **writing-split** | Proposes how to split long-form into social media post sequences |
| **writing-order** | Helps reorder raw material into a smooth argument flow |
| **copy-writer** | Adapts content for platforms (Twitter, LinkedIn, Mastodon, etc.) preserving your voice |

**The key rule:** Every finding becomes a `TODO:` or `TODO PROPOSAL:` — it never writes or rewrites your prose. Your voice stays yours; it provides the friction that sharpens it.
</div>
