# AGENTS.md

## What this is?

This is the Yoker public website. It's used as a top-level introduction/show case of what Yoker is and can do. It's meant to be very user-oriented. So, very simple, only highlights.

It covers Yoker and some of its direct showcase projects:

* ../yoker - the Python-first agent harness framework
* ../yoker-assistant - a standalone demo that runs its own loop and calls into yoker as an SDK
* ../yoker-writing-assistant - a plugin running inside a yoker chat loop

These are the authoritative sources for information to be used on this website.

## Content

A Jekyll-based multi-page website with a blog section:

- Home page (`index.html`) — links to Yoker's online resources, main features with visual showcase (video, screenshot,...)
- Blog (`/blog/`) — posts about the Yoker project, development experiences, tips & tricks
- Blog posts live in `_posts/` following Jekyll's classic naming convention: `YYYY-MM-DD-title.md`

## Yoker Writing Assistant

The Yoker Writing Assistant plugin is enabled in this project's `yoker.toml`. It provides a set of writing skills (review, voice check, continuity, mistakes, idioms, etc.) that can be used to review and improve blog post content before publishing.

### Starting a Writing Assistant Review

Spawn the writing assistant as a sub-agent and ask it to review a post:

> Ask the writing assistant to review the content of the post at `_posts/YYYY-MM-DD-title.md`

This will launch the assistant, which will read the post, propose a review plan, and execute it on confirmation. It delegates to its skills (writing-review, writing-mistakes, writing-voice, writing-continuity, etc.) and surfaces findings as `TODO:` and `TODO PROPOSAL:` markers.

### Continuing a Review Conversation

Once the writing assistant is active, use `SendMessage` to continue the conversation — do not spawn a new agent:

> Ask the writing assistant to review the changes (after addressing feedback)

### Key Rules

- The writing assistant **never writes or rewrites prose** — it only flags issues as `TODO:` or `TODO PROPOSAL:` markers
- The author's voice profile is at `~/VOICE.md`
- The assistant can review multiple posts in sequence; just point it at each file
- Session excerpts from Yoker chat sessions inside the agent response blocks are the agent's voice, not the author's — the assistant does not review those

## Blog Post Conventions

### Session Excerpts

Blog posts often include excerpts from Yoker chat sessions. These are rendered using two CSS classes with kramdown's `markdown="block"` attribute:

```markdown
<div class="session-prompt" markdown="block">
Your prompt text here.
</div>

<div class="session-agent" markdown="block">
Agent response with full **Markdown** support — tables, headings, code blocks, etc.
</div>
```

The "Me" and "Agent" labels are added automatically via CSS `::before` pseudo-elements. The styling mimics Rich terminal output (off-white background, magenta headings/quotes, cyan tables, dodger blue code).

### Unicode Escape Sequences

Content pasted from agent session outputs may contain `\u2014` Unicode escape sequences (commonly em dashes). These render as literal text in Jekyll/kramdown and must be replaced with the actual character:

- `\u2014` → `—` (em dash)
- `\u2013` → `–` (en dash)
- `\u2019` → `'` (right single quotation mark)
- `\u201c` / `\u201d` → `"` / `"` (curly double quotes)

Always scan new post content for `\u` escape sequences before publishing.

### Frontmatter

Every post requires:

```yaml
---
layout: post
title: "Post Title"
date: YYYY-MM-DD
author: Christophe
tags: [tag1, tag2]
excerpt: |
  A 1-2 sentence summary (20-40 words) for the blog index page.
---
```

The `excerpt` should be concise enough to invite clicking through, not a full summary. The filename date must match the frontmatter date.

## Style

Color Pallette: #1B3C53, #234C6A, #456882, #D2C1B6

### Development

The site uses Jekyll. Local development:

```bash
make install   # Install Ruby dependencies (first time only)
make serve     # Start Jekyll dev server at http://localhost:4000
make build     # Build the site into _site/
```

### Structure

```
_config.yml          Jekyll configuration
Gemfile              Ruby dependencies
_layouts/            Page layouts (default, post)
_includes/           Reusable components (nav, footer)
_posts/              Blog posts (YYYY-MM-DD-title.md)
blog/index.html      Blog index page
index.html           Homepage
assets/css/          Stylesheets (style.css, syntax.css)
media/               Videos and screenshots
```

## Media

The `media/` folder contains videos and screenshots that can be used on the site.

Yoker also has a `media/` folder with demo outputs, which are screenshots in SVG format. The official icon/logo for Yoker is also found there.
