# Events API — ASP.NET Core 9.0

Backend API for the **Route Events** internal tool (Waste Connections). ASP.NET Core 9.0 + Dapper targeting SQL Server. This is the only backend — the former Express/Node.js API has been removed, and the frontend in `artifacts/events` calls this service directly.

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

Tables are created and seeded idempotently on startup by `src/Events.Api/Services/DatabaseInitializer.cs`, which is now the authoritative schema definition. Key tables:

- `Districts`
- `EventTypes` / `EventSources`
- `RouteEvents`
- `EventActions`
- `ServiceCodes`
- `AccountFlags`

Tables and columns are PascalCase with no underscores (`RouteEvents.DateOccurred`, `AccountFlags.AccountNumber`), matching the names used in the C# code. The JSON contract is unaffected: DTOs are serialized to camelCase as before.
