---
layout: post
title: Fuzzy Bug Squashed
date: 2026-09-29
author: Christophe
tags: [yoker, bug]
excerpt: |
  For a while, my agents were encountering strange file corruption loops that caused them to halt their operations and report their inability to continue. Today, after a lengthy debugging session, we finally discovered the root cause of this issue.
---

Today we removed a feature that landed in the Yoker codebase almost two months ago: 

```
commit 637e22c7bdc3f1142017d7e9101e768c951adcef
Author: christophevg-agent
Date:   Mon Aug 3 16:14:42 2026 +0200

    feat(update): add line_range, fuzzy matching, and better errors

    Add line_range parameter for line-number-based replace and delete
    operations, avoiding ambiguous string matches in large files. Add
    per-call require_exact_match override enabling whitespace-insensitive
    matching. Improve error messages to show closest match with similarity
    percentage and list line numbers for multiple matches.

    🤖 Implemented together with Yoker
```

“Enabling whitespace-insensitive matching” appeared to be a good idea at the time. We incorporated it along with several other `update` tool-related features. The objective was to provide agents with enhanced file update capabilities. However, in reality, it proved to be a significant threat to session stability, subtly corrupting files. Most of the time, this corruption remained hidden by an eager agent that, after a few retries, managed to repair the damage.

What did it look like?


```
▶ [17:21:21] primary@yoker: yoker:update(
    operation: "replace",
    path: "src/yoker/builtin/__init__.py",
    old_string: "  "search",  "sleep",", (21 chars)
    new_string: "  "search",\n  "sleep"," (22 chars),
    require_exact_match: False,
  )
  ✓ Success (246 chars)
  __init__.py
  @@ -36,8 +36,8 @@
     "make",
     "mkdir",
     "notify",
  -  "read",
  -  "search",  "sleep",
  +  "read",  "search",
  +  "sleep",
     "update",
     "update2",
     "webfetch",
```

The agent intended to replace `”  “search”,  “sleep”,”` with `”  “search”,\n  “sleep”,”`, introducing a single `\n` between two fused lines due to a previous unsuccessful update.

Upon examining the resulting diff, the `”read”,` line was also affected, which was not the agent’s request. The `\n` between `”read”,` and `”search”,  “sleep”,` was absorbed into the string to be replaced, causing the fused line to literally “move up.”

This corruption led agents into a loop of consecutive updates, typically all very similar, resulting in the fused line being moved up on each subsequent line. Most of the time, the agent managed to resolve the issue. However, these update loops went not unnoticed, prompting me to implement stricter guidelines. These guidelines required agents to stop retrying similar updates and report such failing update behavior, while also reverting to a complete file rewrite discipline.

All this for a “simple” feature, hidden behind an optional `require_exact_match` tool flag. The bug only surfaced when agents explicitly turned on this flag, which they did on rare occasions and without any specific reason. This _flag lottery_ made the bug highly unpredictable and like a true cancer, it remained hidden in plain sight for almost two months.

No more...

```
commit ef5bdd9ed40505d941dec59eadce0b9f563f659a
Author: christophevg-agent
Date:   Tue Sep 29 18:24:38 2026 +0200

    fix(update): remove flexible matching — byte-exact, unique-occurrence only

    Flexible/normalized matching (require_exact_match=false) could absorb the
    preceding line's terminator as leading whitespace when the needle's first
    line was indented, fusing two lines, corrupting the file, and reporting
    success. Reproduced live on /tmp/repro (cycle.txt recording); root cause
    isolated via A/B/C probes.

    - update tool: per-call require_exact_match parameter removed from the
      surface; matching is byte-exact + unique-occurrence (ambiguity refuses
      loudly); fuzzy path deleted
    - config: UpdateToolConfig.require_exact_match field removed — stale
      configs hard-fail instead of silently keeping fuzzy semantics
    - tests: 7 flexible-mode tests removed; 2 regression tests added
      (whitespace-differing needle must refuse byte-identically; exact
      indented needle must never fuse lines)

    🤖 Implemented together with Yoker
  ```
