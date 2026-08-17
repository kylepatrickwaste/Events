---
name: Hover-only styles read as absent in the testing browser
description: The testing browser can report hover:none, so correct hover CSS shows up as missing in computed styles.
---

Tailwind emits `hover:` and `group-hover:` rules inside `@media (hover: hover)`.
The browser the testing subagent drives can report `hover: none`, which drops
every hover rule there — so a tester reading `getComputedStyle` on a genuinely
`:hover`ed element reports the base styles and concludes the hover styling is
missing.

The tell: the element that owns the hover rule reads as unstyled too. If a row's
own long-standing hover tint also computes to transparent, the report says
nothing about the style under review.

**Why:** a hover style that is absent in the test browser but correct in a real
one is indistinguishable from a bug, and "fixing" it makes the code worse.

**How to apply:** confirm hover styling from the generated stylesheet rather than
from a tester's computed-style probe. A new hover rule that lands in the same
`@media (hover: hover)` block as the surrounding element's existing hover rule
toggles with it and needs no browser check.
