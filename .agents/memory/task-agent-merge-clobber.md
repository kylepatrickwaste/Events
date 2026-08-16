---
name: Task-agent merges can silently revert main
description: Merged isolated-task-agent work can overwrite changes made on main during the agent's isolation window, with no conflict reported.
---

A task agent branches from main when its task starts and works in an isolated
environment. Anything the main agent lands in the *same file* while that agent is
running can be silently reverted when the task merges — the merge reports success,
there is no conflict marker, and typecheck still passes because the reverted state
is itself valid older code.

**Why:** observed on the event detail page — a photo-gallery hover task branched
before a location-map card replaced an older tile, and its merge restored the old
tile, deleted the map, and swapped the i18n keys back. Nothing failed loudly; the
regression was only caught by looking at a screenshot for an unrelated change.

**How to apply:**
- Before starting work, check the task list for `IN_PROGRESS` / `IMPLEMENTED` /
  `MERGING` tasks that touch the same files. Warn the user that a collision is
  possible rather than assuming the merge will conflict-detect it.
- After any task merge lands, re-verify recent main-branch work in the overlapping
  files — `git diff <your-last-commit> HEAD -- <file>` shows what the merge undid.
  Do not trust a clean typecheck as evidence nothing was lost.
- When restoring clobbered work, keep the merged task's changes intact and re-apply
  only the reverted hunks; the two are usually independent edits that happen to sit
  in the same file.
