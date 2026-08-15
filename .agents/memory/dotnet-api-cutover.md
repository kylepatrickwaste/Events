---
name: .NET API is the only backend, hosted off-platform
description: Route Events has no backend in the repl; the frontend calls an externally hosted ASP.NET Core API that auto-deploys from GitHub.
---

The frontend calls `https://api.kpcf.us` directly via a single `setBaseUrl()` call.
There is no backend service in this workspace and no local fallback.

**Why:** the Express/Postgres backend was removed once the ASP.NET Core app
reached full endpoint parity. Keeping two backends meant every contract change
had to be written twice.

**How to apply:**
- Do not add API routes to this repo expecting them to run. Backend changes go in
  the .NET project and reach production only via a git push.
- **A push to GitHub `main` IS the deploy.** A watcher script on the user's
  Windows box rebuilds and restarts within roughly 15-30 seconds. Confirm a
  deploy landed by polling `GET /api/healthz` until `buildNumber` matches what
  you just pushed — that is the only reliable readiness signal.
- If the external host is down, the app has no data at all. There is nothing to
  fall back to and nothing to fix locally.
- The API is unauthenticated and CORS-open to any origin while serving real
  customer names, addresses, and account numbers. Treat any change that widens
  its exposure as security-relevant.

**Environment:** `dotnet` is not on PATH. Prepend the SDK's `bin` directory
(under `/nix/store/...-dotnet-sdk-*/bin`) — the binary is in `bin/`, not the SDK
root. Resolve the exact path with a glob rather than hardcoding a store hash.
