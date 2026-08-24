# yoker.dev

The public website for [Yoker](https://github.com/christophevg/yoker) — a Python-first agent harness framework.

## What's here

A Jekyll-based website showcasing Yoker and its showcase projects:

- [Yoker](https://github.com/christophevg/yoker) — the framework
- [Yoker Assistant](https://github.com/christophevg/yoker-assistant) — an email-based personal assistant (yoker-as-SDK)
- [Yoker Writing Assistant](https://github.com/christophevg/yoker-writing-assistant) — a writing coach (yoker-as-runtime)

## Structure

```
_config.yml          Jekyll configuration
Gemfile              Ruby dependencies
_layouts/            Page layouts (default, post)
_includes/           Reusable components (nav, footer)
_posts/              Blog posts (YYYY-MM-DD-title.md)
blog/index.html      Blog index page
index.html           Homepage
assets/css/          Stylesheet
media/               Videos and screenshots
```

## Local Development

```bash
make install   # Install Ruby dependencies (first time only)
make serve     # Start Jekyll dev server at http://localhost:4000
make build     # Build the site into _site/
```

## Writing Blog Posts

Create a new file in `_posts/` following the naming convention:

```
_posts/YYYY-MM-DD-your-post-title.md
```

With front matter:

```yaml
---
layout: post
title: "Your Post Title"
date: YYYY-MM-DD
author: Your Name
tags: [tag1, tag2]
excerpt: "A short summary for the blog index."
---
```

Write your content in Markdown below the front matter.