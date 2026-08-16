---
name: Verifying frontend work when the backend cannot run here
description: How to exercise UI flows end to end in this repl even though the .NET API and its SQL Server only exist off-platform.
---

The API this app talks to runs on the user's Windows box, so no backend and no
database exist in the repl. To verify a UI flow that writes to the API, stub the
API **inside the Vite dev server**: a temporary plugin whose `configureServer`
adds a `/api` middleware, plus `setBaseUrl(null)` so the client uses same-origin
relative paths. Revert both with `git checkout` when done.

**Why:** two cheaper-looking options do not work.
- A background process started from a shell command (`node stub.mjs &`, even with
  `nohup`/`setsid`) is killed as soon as that command returns, so a separate stub
  server is gone before the browser ever reaches it.
- Pointing the client at `http://localhost:<port>` assumes the test browser lives
  in this container; going through the dev server's own origin does not.

**How to apply:** make the stub answer every GET it does not recognise with `[]`.
Screens fetch more endpoints than the flow under test, and an unexpected object
where the app expects an array surfaces as a runtime-error overlay that looks
like a bug in the feature being verified.
