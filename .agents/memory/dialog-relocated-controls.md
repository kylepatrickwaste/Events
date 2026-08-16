---
name: Relocating controls into a dialog
description: Moving a header/toolbar control into a popup silently inherits the popup trigger's responsive visibility — audit every breakpoint before doing it.
---

# Relocating a control into a dialog

**Rule:** before moving a control out of a header/toolbar and into a dialog or
popover, check the responsive visibility of the thing that *opens* that dialog.
The relocated control inherits the trigger's breakpoints. If the trigger is
hidden at any width, the control is now unreachable at that width.

If the dialog has exactly one opener, that opener must be unconditionally
visible. Collapse it (icon-only, drop the label) instead of hiding it, and give
the collapsed form an `aria-label` so it is not an unlabelled icon button.

**Why:** consolidating header controls into a profile dialog made a theme toggle
that previously rendered at *every* width unreachable on phones, because the
dialog's only trigger was hidden below the `md` breakpoint. Nothing caught it:
typecheck passed, and the desktop end-to-end run passed too, because the
regression only existed below a breakpoint neither one exercised. Responsive
visibility is invisible to the type system and to any test that runs at one
viewport.

**How to apply:** whenever a change consolidates UI into a popup, grep the
trigger's className for `hidden`/`sm:`/`md:`/`lg:` prefixes, and verify at a
narrow viewport (~390px) as well as desktop.

## Related: instant-apply settings inside a Save/Cancel dialog

Settings that apply live to the whole app (theme, language) are deliberately
**not** wired to such a dialog's Save button. They commit and persist the moment
they are clicked; Save governs only the fields it owns.

**Why:** the user sees a theme change applied behind the open dialog. Routing it
through Save would oblige Cancel to visually undo something already applied, and
would make one dialog contain two contradictory commit models. Keep the
instant-apply group visually separated and label it as saving immediately.
