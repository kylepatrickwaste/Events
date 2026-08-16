# Route Events

Rebuilt Waste Connections "Route Events" web app: district staff pick a hauling district, review camera-captured route events (extras, contamination, etc.), then charge accounts, send emails, add notes, or close events. UI supports English, Spanish, and French and is responsive.

## Run & Operate

- `pnpm --filter @workspace/events run dev` — run the frontend
- `pnpm run typecheck` — full typecheck across all packages
- `pnpm run build` — typecheck + build all packages
- `pnpm --filter @workspace/api-spec run codegen` — regenerate API hooks from the OpenAPI spec

The backend is **not** run from this workspace. It is the ASP.NET Core app in
`artifacts/dotnet-api/`, which runs on the user's own Windows server and is
published at `https://api.kpcf.us`. `Watch-AndRestart.ps1` on that box
auto-deploys from the GitHub `main` branch, so a push is the deploy step.

## Stack

- pnpm workspaces, Node.js 24, TypeScript 5.9
- Frontend: React 19 + Vite, Tailwind, shadcn/ui, wouter, TanStack Query
- API: ASP.NET Core 9 (Dapper) against SQL Server, hosted externally
- API codegen: Orval (from OpenAPI spec)

## Where things live

- Frontend: `artifacts/events` (react-vite, previewPath `/`); i18n dictionaries in `artifacts/events/src/i18n/` (en/es/fr JSON, React context)
- API contract: `lib/api-spec/openapi.yaml` (source of truth)
- API implementation: `artifacts/dotnet-api/src/Events.Api/Controllers/`
- Generated client: `lib/api-client-react` (React Query hooks)
- Event photos (AI-generated mock): `artifacts/events/public/event-photos/`

## Architecture decisions

- **The frontend talks directly to `https://api.kpcf.us`.** `setBaseUrl()` is called once in `artifacts/events/src/main.tsx`; the generated client emits relative `/api/...` paths and that base is prepended. There is no backend in this workspace and no local fallback — if the external API is down, the app has no data.
- Schema creation and mock seed data are handled by the .NET app's `DatabaseInitializer` on startup (idempotent). Actions ("charge", "email", "close", "note") are recorded in `EventActions`, and closing sets `EventStatus=1` on the event. Tables and columns are PascalCase with no underscores (`RouteEvents`, `AccountFlags.AccountNumber`); the camelCase JSON contract is unchanged.
- Maps use keyless OpenStreetMap embed iframes (no Google Maps API key).
- Email "send" is mock: it records an action, no real email is sent.
- Customer route overview stored as JSON on the event rather than a separate table.
- Current user is hardcoded as `Kyle.Patrick` (no auth yet).

## Product

_Describe the high-level user-facing capabilities of this app once they exist._

## User preferences

- Do not suggest or ask about publishing/deploying the app.

## Gotchas

- **`api.kpcf.us` is unauthenticated and CORS-open to any origin.** Real customer
  names, service addresses, and account numbers are retrievable with an
  unauthenticated request from anywhere on the internet. The browser now calls it
  directly, so any site a signed-in agent visits can read it too. Add
  authentication or a network restriction before treating this as production-safe.
- **Always increment `buildinfo.txt` (repo root) before every commit + push.** It
  holds a single integer, served by the API from `GET /api/healthz` as
  `buildNumber` and rendered next to the online/offline dot in the events header.
  It is read per request, so bumping it needs no rebuild of the frontend — the
  number reflects whichever API the client is pointed at. Implemented in
  `Services/BuildInfo.cs`; the csproj copies the file next to the assembly.
  Adding a field here means updating `lib/api-spec/openapi.yaml` and re-running
  `@workspace/api-spec codegen`.
- **The online/offline dot only reflects which base URL is configured**, not
  whether the server is actually reachable — a dead API still shows green.

## Pointers

- See the `pnpm-workspace` skill for workspace structure, TypeScript setup, and package details
