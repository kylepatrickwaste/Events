---
name: Reachability recovery must refetch, not just re-render
description: Why clearing an "API unreachable" dialog is only half of recovery in a React Query app.
---

When a health-check poll drives an "app can't reach the server" state, restoring
the flag is not restoring the app. Every data query that failed during the
outage stays in its error state until something asks again, so the blocking
dialog vanishes and the user is left staring at error panels underneath it.

**Rule:** on the down -> up transition, invalidate the whole query cache (not
just the health query) so failed reads refetch themselves.

**Why:** React Query does not retry an errored query on its own once its retries
are exhausted; only an invalidate/refetch or a remount will. This was caught
only by an e2e run that unblocked the network without reloading the page — a
manual test that reloads after "fixing" the outage will never see it.

**How to apply:** any polled connectivity/session/auth gate that renders a
blocking overlay in front of cached queries. Test recovery *without* a page
reload, otherwise the reload hides the bug.
