---
name: Changing a stored preference's default
description: How to roll out a new default for a localStorage-backed preference without clobbering deliberate user choices.
---

# Rolling out a new default for a stored preference

**Rule:** when a preference's default changes, version the storage key. On load:
read the new key; if absent, look at the legacy key — a legacy value that
exactly equals the *old default* is treated as "no choice" (apply-view echoes
and off-then-on toggles store the default back), anything else is migrated as a
deliberate choice.

**Why:** the grid's column set defaulted to all-on and every toggle/view-apply
wrote the full set to storage, so "has a stored value" ≠ "made a choice". Just
switching the default would have pinned most users to the old layout forever.

**How to apply:** any time a default changes for a value that code writes back
to storage eagerly. Compare the legacy value against the old default set, not
against emptiness.
