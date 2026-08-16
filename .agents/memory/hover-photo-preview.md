---
name: Row hover photo previews
description: Convention for the enlarged-photo-on-row-hover panels in this app — non-interactive portal plus open/close delays.
---

Tables in this app that pop an enlarged photo when a row is hovered all follow
the same shape:

- One preview for the whole table, owned by the page, with rows only reporting
  which one is hovered. Never one preview component per row.
- Rendered through a portal into `<body>`, `position: fixed`, and
  **`pointer-events: none`**. The pointer never needs to travel onto the panel,
  so the panel can overlap the rows without stealing hover from the row beneath.
- An open delay (~150ms) so a quick pass-over doesn't flash, and a close delay
  (~220ms) so leaving the table momentarily doesn't blink it shut.
- While a preview is already open, moving to another row **swaps** the image
  immediately instead of closing and re-opening. Rows with no photo close it
  rather than opening an empty panel.
- Placement is measured from the hovered row's photo cell and clamped to the
  viewport, with a centred fallback when there isn't room beside it.

**Why:** the "blink" between adjacent rows and previews that eat their own hover
target are the two failure modes users notice immediately; both come from
treating the panel as an interactive popover (hover-card/tooltip primitives
default to that).

**How to apply:** copying these timings into a second table is deliberate —
prefer duplicating the small constants with a comment over refactoring an
existing table's preview, since concurrent task agents editing the same file
have silently clobbered each other before.
