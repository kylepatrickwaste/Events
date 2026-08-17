# files/

Static T-SQL scripts for bootstrapping the Route Events database on Microsoft SQL Server. SQL Server is the only database this project uses; nothing in this workspace provisions one.

## Scripts

| Script | Purpose |
|--------|---------|
| `01_create_tables.sql` | Creates all seven tables (`Districts`, `EventTypes`, `EventSources`, `ServiceCodes`, `RouteEvents`, `EventActions`, `AccountFlags`) with correct MSSQL types, primary keys, foreign keys, indexes, and JSON CHECK constraints. |
| `02_insert_mock_data.sql` | Inserts all lookup rows, four districts, service codes, 133 demo route events, and all associated notes, close, charge, and history `EventActions`. |

## Run order

```sql
-- 1. Create schema
:r 01_create_tables.sql

-- 2. Seed data
:r 02_insert_mock_data.sql
```

### Route-event counts in `02_insert_mock_data.sql`

| District | Events | Make-up |
|----------|--------|---------|
| Vancouver (`2010`, id 1) | **110** | 14 base event specs, 4 duplicate-cluster events, and 92 volume rows (SECTION 4B) — 26 Extra / 24 Overloaded / 16 Contamination / 12 Blocked Container / 14 Not Out, spread across all four event sources, 60 open / 17 closed / 15 charged, 44 distinct customers, accounts and addresses, and 6 two-vendor duplicate pairs. |
| Vancouver-Minimal (`2010-M`, id 2) | 14 | Mirror of the 14 base Vancouver specs, severity forced to `Minimal`. |
| Cascade Disposal (`2012`, id 3) | 2 | One duplicate cluster. |
| Houston (`5120`, id 20) | 7 | Two duplicate clusters plus two Samsara-sourced events. |

Every SECTION 4B row fills each column the workspace grid renders (quantity, bin serial, stop, WO#, address, LOB, tablet notes, bill area, RMO status, customer, customer-since, event time, vehicle, route) and carries both a primary photo and a photo array, so the grid hover preview and the detail gallery agree. Closed and charged rows have matching close/charge/note `EventActions`, and 24 accounts carry prior charge history so the event-detail statistics section is populated.

Both scripts are **idempotent** — they can be re-run safely on an already-populated database using `IF NOT EXISTS` / `IF OBJECT_ID` guards throughout.

## Timestamps

All timestamps in `02_insert_mock_data.sql` are computed relative to `GETUTCDATE()` at execution time (e.g. `DATEADD(minute, -132, GETUTCDATE())`), so events remain recent on any run date.  Duplicate-cluster event times are pinned to specific hours of the current or previous day (e.g. `'T08:12:00+00:00'`) so they stay tightly clustered for the duplicate-detection UI.
