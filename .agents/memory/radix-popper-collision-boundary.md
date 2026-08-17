---
name: Radix popper content must be portalled or collision detection lies
description: Why an unportalled HoverCard/Popover/Tooltip runs off the screen even though it visually escapes its scroll container
---

A Radix popper-based component (HoverCard, Popover, Tooltip, DropdownMenu)
rendered **without** its `Portal` will position itself against the wrong
boundary. Radix positions with `strategy: 'fixed'`, so the content *paints*
outside an `overflow-y-auto` ancestor and looks fine — but floating-ui's
`detectOverflow` defaults to `boundary: 'clippingAncestors'`, which is that
scroll container. The card is dutifully "kept in view" of a box a couple of
hundred pixels tall while running clean off the bottom of the screen.

**Why:** shadcn's generated `hover-card.tsx` omits the `Portal` wrapper that
`dialog.tsx` and `popover.tsx` include. The symptom looks like "collision
detection is broken" or "avoidCollisions isn't working", so the instinct is to
tune `side`/`align`/`sticky` — none of which help, because the boundary itself
is wrong.

**How to apply:**
- Wrap the content in `<XPrimitive.Portal>` inside the shared ui component, and
  give the call site a `z-` value above every hand-rolled portal and dialog
  overlay it can appear inside.
- Also give the popper content a **definite size before its contents load**. An
  `<img>` with no width/height is measured as a sliver, positioned, then grows
  downward past the point collision detection had cleared. A fixed
  `aspect-video` (or explicit height) box with `object-contain` fixes it.
- Prefer `align="center"` over `align="start"` for a card anchored to a row: a
  row near the bottom of the screen then only has half a card to fit below it.
- Verify by measuring, not by eye: hover at a short viewport (e.g. 1280x700)
  and assert the `[data-radix-popper-content-wrapper]` bounding box is inside
  `window.innerWidth/innerHeight`.
