---
name: Removing navigation affordances
description: Before deleting a nav control, check whether the remaining entry points are themselves subject to a redirect — a "home" link is not a safe fallback when a home-redirect exists.
---

# Removing a navigation affordance

**Rule:** when deleting a back link, breadcrumb, or similar nav control, do not
justify it with "the logo/home link still goes there." Follow the surviving
entry point all the way through its own routing logic first. A landing route
that redirects some users elsewhere is not a fallback for those users.

**Why:** a header back-link to the district list was removed on the grounds that
the logo pointed at `/` and the list lived at `/`. But `/` redirects any user
with a home district straight into that district, so for exactly those users the
list became unreachable from anywhere in the app. The list was only reachable via
an explicit query-param escape hatch (`?browse=1`) that the deleted control had
been the sole source of. Typecheck passed, and an end-to-end run passed too,
because the test account had no home district — the trap was invisible to every
check except reading the redirect logic.

**How to apply:** grep the destination route's component for `setLocation`,
`Redirect`, or a conditional early return before claiming it as a fallback. If
the route has an escape-hatch query param, something visible must still link to
the param form, not the bare path. Watch for personalization flags (home/default
/preferred X) — they make a route behave differently per user, so "it works for
me" proves nothing.

## Corollary: deleting a component orphans its translation keys

Removing a component leaves its i18n keys behind in every locale file with no
call site. They are invisible to the type system and to the running app. After
deleting UI, grep each key the component used across the codebase and drop the
ones with zero references, in all locales at once.
