# Route Events

Rebuilt Waste Connections "Route Events" web app: district staff pick a hauling district, review camera-captured route events (extras, contamination, etc.), then charge accounts, send emails, add notes, or close events. UI supports English, Spanish, and French and is responsive.

## Run & Operate

- `pnpm --filter @workspace/api-server run dev` — run the API server (port 5000)
- `pnpm run typecheck` — full typecheck across all packages
- `pnpm run build` — typecheck + build all packages
- `pnpm --filter @workspace/api-spec run codegen` — regenerate API hooks and Zod schemas from the OpenAPI spec
- `pnpm --filter @workspace/db run push` — push DB schema changes (dev only)
- Required env: `DATABASE_URL` — Postgres connection string

## Stack

- pnpm workspaces, Node.js 24, TypeScript 5.9
- API: Express 5
- DB: PostgreSQL + Drizzle ORM
- Validation: Zod (`zod/v4`), `drizzle-zod`
- API codegen: Orval (from OpenAPI spec)
- Build: esbuild (CJS bundle)

## Where things live

- Frontend: `artifacts/events` (react-vite, previewPath `/`); i18n dictionaries in `artifacts/events/src/i18n/` (en/es/fr JSON, React context)
- API routes: `artifacts/api-server/src/routes/events.ts`
- API contract: `lib/api-spec/openapi.yaml` (source of truth)
- DB schema: `lib/db/src/schema/` (districts, lookups, routeEvents) — simplified schema derived from the user's attached proposal
- Event photos (AI-generated mock): `artifacts/events/public/event-photos/`

## Architecture decisions

- Mock data seeded in Postgres (20 districts, 8 events, service codes, actions); actions ("charge", "email", "close", "note") are recorded in `event_actions` and closing sets `event_status=1` on the event.
- Maps use keyless OpenStreetMap embed iframes (no Google Maps API key).
- Email "send" is mock: it records an action, no real email is sent.
- Customer route overview stored as JSONB (`customer_routes`) on the event rather than a separate table.
- Current user is hardcoded as `Kyle.Patrick` (no auth yet).

## Product

_Describe the high-level user-facing capabilities of this app once they exist._

## User preferences

_Populate as you build — explicit user instructions worth remembering across sessions._

## Gotchas

_Populate as you build — sharp edges, "always run X before Y" rules._

## Pointers

- See the `pnpm-workspace` skill for workspace structure, TypeScript setup, and package details
