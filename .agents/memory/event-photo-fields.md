---
name: Event photo fields
description: Route events store a primary photo and a JSON photo array separately; queries that read only one of them silently render "no photo".
---

A route event carries its photos in two places: a single primary-photo column
and a JSON array column holding the rest. They can disagree — an event can have
an empty primary photo while the array is populated.

**Rule:** any endpoint that returns a thumbnail must read *both* and fall back
to the first entry of the array when the primary is empty.

**Why:** a "thumbnails never show up" report traced to a query that selected
only the primary column. Nothing errors, the payload is valid, the UI just draws
its empty-state placeholder — so it reads like a frontend bug and gets chased in
the wrong layer. It is also invisible in most data, because rows usually have
both fields populated.

**How to apply:** when adding or reviewing a query that projects a photo for a
list/table row, check the CTE and the outer select actually carry the array
column too, not just the primary. The repository already has a JSON-array
parse helper and a primary-with-fallback helper — reuse them instead of
re-deriving the fallback at each call site.
