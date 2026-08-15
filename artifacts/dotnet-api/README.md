# Events API — ASP.NET Core 9.0

Backend API for the **Route Events** internal tool (Waste Connections). Replaces the Express/Node.js API with ASP.NET Core 9.0 + Dapper targeting SQL Server.

## Stack

| Layer | Technology |
|-------|-----------|
| Framework | ASP.NET Core 9.0 Web API |
| Database client | Dapper 2.1 |
| Database | SQL Server (Microsoft.Data.SqlClient) |
| Logging | Serilog |

## Prerequisites

- [.NET 9 SDK](https://dotnet.microsoft.com/download/dotnet/9)
- SQL Server accessible at the configured connection string

## Configuration

Edit `src/Events.Api/appsettings.json` or set environment variables:

```
ConnectionStrings__Default=Server=...;Database=events;User Id=...;Password=...;
AppSettings__CurrentUser=Kyle.Patrick
```

## Run locally

```bash
cd src/Events.Api
dotnet run
```

Default port: **5000** (HTTP) / **5001** (HTTPS)

## Build for production

```bash
dotnet publish Events.sln -c Release -o ./publish
```

## API Routes

All routes prefixed with `/api`.

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/healthz` | Health check |
| GET | `/api/districts` | List active districts |
| GET | `/api/districts/{id}/summary` | Open/closed counts, charges |
| GET | `/api/districts/{id}/service-codes` | Charge service codes |
| GET | `/api/districts/{id}/account-flags` | Contract-flagged accounts |
| DELETE | `/api/account-flags/{id}` | Remove a flag |
| GET | `/api/event-types` | Event type lookup |
| GET | `/api/events` | List events (filter by district, status, type, severity, search) |
| GET | `/api/events/{id}` | Event detail with nearby events & statistics |
| POST | `/api/events/{id}/notes` | Add note |
| POST | `/api/events/{id}/charge` | Charge customer |
| POST | `/api/events/{id}/email` | Record email sent |
| POST | `/api/events/{id}/close` | Close event |
| POST | `/api/events/bulk-close` | Bulk close events |

## Database schema

Targets the same schema as the Node.js version. See `lib/db/src/schema/` in the monorepo for the full Drizzle schema definition. Key tables:

- `districts`
- `event_types` / `event_sources`
- `route_events`
- `event_actions`
- `service_codes`
- `account_flags`
