---
name: ASP.NET config key collisions with ambient env vars
description: Why single-word top-level appsettings keys are unsafe on Windows, and how the collision hides itself
---

Never read a single-word, top-level key from `IConfiguration` (`cfg["UserName"]`,
`cfg["Path"]`, `cfg["Temp"]`, `cfg["ComputerName"]`, `cfg["Home"]`, …). Nest it
under a section instead: `cfg["AppSettings:UserName"]`.

**Why:** the environment-variable configuration provider is registered *after*
`appsettings.json` and `appsettings.{Environment}.json`, so it wins. It is also
case-insensitive. Windows defines `USERNAME` (plus `PATH`, `TEMP`,
`COMPUTERNAME`, `HOMEPATH`, …) in every process, so a top-level `UserName` in
appsettings is silently shadowed by the service or app-pool account. Overriding
a *nested* key requires the double-underscore form (`AppSettings__UserName`),
which nothing sets by accident.

The failure is quiet and looks like a deployment problem, not a code problem:
appsettings plainly contains the value you expect, the app reads a different
one, and nothing logs a warning. It bit the Route Events API — the deployed
backend resolved the service account number instead of the configured user, and
the same collision would have outranked the real IIS Windows-authenticated
identity in production, silently mis-stamping every audit column.

**How to apply:** whenever an identity/config value falls back through a chain
like "config → ambient identity → default", verify the *deployed* resolution by
calling the endpoint, not by re-reading the JSON file. If the value comes back
as something plausible-but-wrong (a machine name, an account id, a path), a
shadowing env var is the first suspect.
