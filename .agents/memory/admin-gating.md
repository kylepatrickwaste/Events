---
name: Gating an existing feature behind an admin role
description: Two traps when making a shipped feature admin-only under Windows auth — client-side hiding that enforces nothing, and a break-glass admin whose configured name is not the name the server sees.
---

## Removing the button is not removing the capability

When a feature becomes admin-only, deleting its entry point does not withhold
it. Every endpoint behind that entry point stays open to anyone who calls it
directly, and a list endpoint leaks exactly the data the gate was meant to
protect.

**Why:** an "admins only" decision was implemented by deleting a header button
and gating the new UI on the caller's role. The endpoints behind it kept no
authorization at all, so a demoted user could still read and mutate through the
API. Nothing in the UI diff hinted at it.

**How to apply:** when a feature is re-gated, grep for every endpoint the
feature's components call and guard each one, including the read. Then check
whether any *other* component calls those endpoints — if a non-admin screen
does, the gate belongs on the mutation only, and the read has to stay open.
Put the decision in one shared service rather than a private helper on the
first controller that needed it, or the second controller will not get it.

## A break-glass admin must be matched at request time, not seeded at startup

Promoting a configured login to admin by writing a row at startup is wrong
whenever the server sees a different spelling of the caller's name than
configuration uses.

**Why:** with Windows auth, config carries the bare login (e.g. `123456`) while
IIS reports it domain-qualified (`DOMAIN\123456`). On a fresh database the startup
`INSERT` created an Admin row under the bare name; the caller's first request
then created a *second*, Agent row under the qualified name and was refused.
The configured way back in did not work, and the roster showed two rows for
one person.

**How to apply:** at startup, only `UPDATE` rows that already exist — never
`INSERT` a login that has not been seen, because you are guessing at its name.
Do the real check per-request: normalize the caller's login (strip `DOMAIN\`
and `@suffix`), compare case-insensitively against the configured list, and
promote the row that actually exists. Treating the config as authoritative on
every request also makes a zero-admin lockout impossible, which is a stronger
guarantee than any self-demotion guard — a per-request self-lock cannot stop
two admins from demoting each other concurrently.
