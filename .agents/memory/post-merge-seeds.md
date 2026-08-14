---
name: Post-merge seed scripts
description: Merged task branches that add seed data need their lib/db seed scripts run manually afterwards
---

Task-agent merges that add or change demo/seed data land the *script* but not the *data* — the reconciliation step does not run seeds.

**Why:** Seen repeatedly (event photos, duplicate clusters): after a merge users report "no data / broken images" even though code is correct, because the dev DB was never reseeded.

**How to apply:** When a merge lands touching `lib/db/src/seed/`, check `lib/db/package.json` for `seed:*` scripts and run the relevant one (`cd lib/db && pnpm run seed:<name>`), then verify via the API.
