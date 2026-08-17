---
name: Sticky cells break native drag-and-drop
description: A position:sticky element will neither start nor accept an HTML5 drag; move draggable and the drop handlers to a non-sticky inner element.
---

# Sticky table headers vs. HTML5 drag-and-drop

**Rule:** when a draggable or droppable element also needs `position: sticky`,
put the `draggable` attribute and the `dragstart` / `dragover` / `drop` handlers
on a plain inner element and leave only the layout on the sticky cell.

**Why:** making grid header cells sticky so they hold their place while rows
scroll silently killed column reordering. The cells still reported
`draggable: true`, no error appeared, and document-level listeners showed the
drag events reaching the right cells — but nothing moved. Moving `draggable` to
an inner div restored dragging; the drop side had to move too.

**How to apply:** verify a drag by hand after adding stickiness — a typecheck and
a console check both stay clean. Note that synthetic `DragEvent`s dispatched back
to back in one tick prove nothing about React handlers: the state `dragstart` sets
has not committed by the time `dragover` runs, so the drop always looks broken.

## Corollary: test a reorder in both directions

A drag that inserts at `filtered.indexOf(target)` — the index looked up *after*
the dragged item is removed — always lands ahead of the target, so dragging one
place to the right is a no-op while every leftward drag works. Read the target
index before removing. Any reorder test that only drags one direction will miss
this entirely.
