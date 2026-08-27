---
layout: post
title: Permissions got an overhaul
date: 2026-08-26
author: Christophe
tags: [announcement, yoker, changes]
excerpt: |
  I've redesigned Yoker's filesystem permission system. The old model used tool-name string matching to decide which checks to run. This resulted in inconsistent enforcement where `search` could bypass `read` restrictions and `git diff` could expose files `read` would block.
---

I've redesigned Yoker's filesystem permission system. The old model used tool-name string matching to decide which checks to run. This resulted in inconsistent enforcement where `search` could bypass `read` restrictions and `git diff` could expose files `read` would block.

The new model is simpler and more robust: two annotations (`ReadPath` / `WritePath`) declare the access mode at the parameter level, and a three-layer pipeline enforces it uniformly across all tools.

## What changed

**Three-layer access control** (checked in order):

1. `filesystem_paths` lists which roots are accessible (HARD)
2. `blocked_paths` defines a universal denylist within those roots (HARD)
3. `blocked_write_paths` provides an additional write-only denylist (SOFT: user can
   approve interactively, HARD in batch mode)

All patterns are now **glob** (not regex), matched case-insensitively against the relative path from the allowed root. Full glob support is provided: `*`, `**`, `?`, `[...]`.

**Removed settings** (no longer in config):

| Removed | Replaced by |
|---|---|
| `allowed_extensions` (read) | Nothing, denylist-only now |
| `blocked_extensions` (write) | `blocked_paths` or `blocked_write_paths` (glob) |
| `blocked_patterns` (read, regex) | `blocked_paths` (glob) |
| `protected_files` (permissions) | `blocked_write_paths` (permissions) |
| `max_file_size_kb` (permissions) | `max_file_size_kb` (now on `[tools.read]`) |

## How to migrate

### `[permissions]` section

Replace `protected_files` with `blocked_write_paths` (same defaults, same purpose, just renamed and moved to the new field):

```toml
# Before
[permissions]
filesystem_paths = ["."]
protected_files = ["Makefile", "pyproject.toml"]

# After
[permissions]
filesystem_paths = [".", "plugin://"]
blocked_paths = [".git", ".venv", ".env", ".ssh"]
blocked_write_paths = ["Makefile", "pyproject.toml"]
```

The defaults already cover the old `protected_files` list, so most users can simply **remove the `protected_files` line** and rely on defaults.

### `[tools.read]` section

Remove `allowed_extensions` and `blocked_patterns`. If you had custom blocked patterns, convert them from regex to glob and move them to `[permissions] blocked_paths`:

```toml
# Before
[tools.read]
allowed_extensions = [".py", ".md"]
blocked_patterns = ["\\.env", "\\.ssh(?:$|/)"]

# After — no allowed_extensions (denylist-only now)
[permissions]
blocked_paths = [".git", ".venv", ".env", ".ssh"]  # glob, not regex

[tools.read]
max_file_size_kb = 500  # moved here from [permissions]
```

### `[tools.write]` section

Remove `blocked_extensions`. If you blocked specific file types, add them as glob patterns to `blocked_write_paths`:

```toml
# Before
[tools.write]
blocked_extensions = [".exe", ".sh", ".bat"]

# After
[permissions]
blocked_write_paths = [
  "Makefile", "pyproject.toml",  # ... defaults
  "**/*.exe", "**/*.sh", "**/*.bat",  # your additions
]
```

**Important** the configuration loading silently ignores unknown properties. So if you have `protected_files`, `allowed_extensions`, `blocked_patterns` or `blocked_extensions` in you current configuration hierarchy, **you won't be notified** (working on that one).


## Glob pattern examples

| Pattern | Matches |
|---|---|
| `.git` | `./.git` directory and everything under it |
| `**/.git` | `.git` at any depth in the tree |
| `*.sh` | `./script.sh` but not `./subdir/script.sh` |
| `**/*.sh` | any `.sh` file anywhere |
| `Makefile` | `./Makefile` only |
| `**/Makefile` | `Makefile` at any depth |

## That's it

The defaults are sensible for most projects. If you never customized these
settings, you likely don't need to change anything. Just remove any
`allowed_extensions`, `blocked_extensions`, `blocked_patterns`, or
`protected_files` entries from your `yoker.toml` and you're done.
