---
name: Orval/zod codegen compatibility
description: How to avoid codegen typecheck failures with integers and path+query params in this workspace
---

Rule 1: Orval v8 emits zod-v4 `zod.int()` for non-coerced `type: integer` body/response fields, but the workspace `zod` catalog is v3 (3.25.x top-level). Fix: keep `'number'` in the orval zod `coerce.body` and `coerce.response` lists (lib/api-spec/orval.config.ts) so integers become v3-compatible `zod.coerce.number().int()`.

Rule 2: An operation with BOTH path params and query params causes TS2308 (`<Op>Params` exported from both generated/api and generated/types). Fix: design such endpoints as query-only (e.g. `GET /events?districtId=`) or path-only.

**Why:** Both failures surface as errors in `typecheck:libs` chained after orval, looking like codegen bugs.
**How to apply:** When editing lib/api-spec/openapi.yaml, avoid mixing path+query params on one operation and don't remove the number coercion overrides.
