---
name: Route-name parity is not behavioral parity
description: Why swapping a frontend onto a second backend surfaced a burst of 500s that endpoint-counting had declared safe.
---

Before repointing a frontend at a replacement backend, **call every endpoint
against the real instance** — including ones with path parameters. Matching
`operationId`s to controller routes proves only that the URLs exist.

**Why:** a cutover was cleared by confirming 14 spec operations mapped 1:1 to 14
controller endpoints. Three endpoints still 500'd immediately, because the
replacement backend had never been exercised by a client — the old backend had
been serving every request. The bugs were independent, and each was only
reachable after the previous one was fixed, so they surfaced one at a time
across three deploys rather than all at once.

**How to apply:** sweep every route for status codes before declaring a cutover
done, and re-sweep after each fix instead of assuming the first error was the
only one. A smoke test of the list endpoints is not enough; detail endpoints
carry the joins and the aggregate SQL, which is where the dialect bugs live.
