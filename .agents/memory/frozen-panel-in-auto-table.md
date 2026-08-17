---
name: Frozen right-hand panels in an auto-layout table
description: Why a multi-cell sticky panel drifts apart in a full-width auto-layout table, and the one-cell shape that doesn't.
---

A frozen panel in a `table-layout: auto`, full-width table must be **one**
`position: sticky` cell, not several. Two adjacent sticky cells — one at
`right: 0`, the next at `right: <width of the first>` — only line up if the
table happens to hand those columns exactly the pixel widths the offset
constant assumes. It won't: an auto-layout table redistributes leftover width
across every column, including the pinned ones, so the offset goes stale, the
cells drift apart, and the scrolling columns travel through the gap between
them.

The one-cell shape:

- One `<td>` / `<th>` per row pinned at `right: 0`, with the panel's several
  content groups laid out side by side *inside* it. No offset arithmetic exists
  to get wrong, and there is no seam for content to leak through.
- Pin the width on the cell **and** on an inner box with `box-sizing:
  border-box`; the cell alone is only a suggestion the table may override. Put
  the panel's padding on the inner box so the cell's content box stays the exact
  intended width.
- Nominate exactly one ordinary body column to soak up the table's leftover
  width (`width: 100%` on its header cell). Without a designated taker the
  slack is spread over every column and the panel stops measuring its intended
  width. Pick a prose column — numeric ones look wrong stretched.
- The panel's background must be fully **opaque**, and its hover/selected states
  have to be layered as an opaque `background-image` gradient over that opaque
  colour. A translucent `background-color` for the hover tint lets the scrolling
  columns show straight through.
- Header, body rows and any full-width group-break rows all use the same single
  pinned cell, so they can never fall out of step; header/body alignment then
  comes free from the table's own column model.

**Why:** the two-cell version shipped and broke exactly this way — a strip of
empty space between the pinned groups with column values scrolling through it.

**How to apply:** whenever a table needs more than one thing frozen at an edge.
Verify by measuring `getBoundingClientRect().width` of the header's panel cell
and a body row's panel cell at several viewport widths; they must be equal and
equal to the intended width.
