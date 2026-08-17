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
| Vancouver (`2010`) | **110** | 14 base event specs, 4 duplicate-cluster events, and 92 volume rows (SECTION 4B) — 26 Extra / 24 Overloaded / 16 Contamination / 12 Blocked Container / 14 Not Out, spread across all four event sources, 60 open / 17 closed / 15 charged, 44 distinct customers, accounts and addresses, and 6 two-vendor duplicate pairs. |
| Vancouver-Minimal (`2010-M`) | 14 | Mirror of the 14 base Vancouver specs, severity forced to `Minimal`. |
| Cascade Disposal (`2012`) | 2 | One duplicate cluster. |
| Houston (`5120`) | 7 | Two duplicate clusters plus two Samsara-sourced events. |

Every SECTION 4B row fills each column the workspace grid renders (quantity, bin serial, stop, WO#, address, LOB, tablet notes, bill area, RMO status, customer, customer-since, event time, vehicle, route) and carries both a primary photo and a photo array, so the grid hover preview and the detail gallery agree. Closed and charged rows have matching close/charge/note `EventActions`, and 24 accounts carry prior charge history so the event-detail statistics section is populated.

Both scripts are **idempotent** — they can be re-run safely on an already-populated database using `IF NOT EXISTS` / `IF OBJECT_ID` guards throughout.

## Running against a database that already has data

`02_insert_mock_data.sql` never hard-codes a district `Id`. Districts are matched on `Number` (`2010`, `2010-M`, `2012`, `5120`), and every route event, service code and charge action resolves its district through that number.

This matters because the API seeds its own twenty-district list at start-up on an empty database, and `2011 OREGON PAPER FIBER` lands on id 2 — exactly where this script used to assume Vancouver-Minimal. An id-based guard finds that row, skips its own insert, and silently attaches fourteen events to Oregon Paper Fiber. (`2010`, `2012` and `5120` happen to get the same ids either way; `2010-M` is the one that moves.)

A district that already exists is left untouched: its name, region and hauling system belong to whoever created it. Only `2010-M` is genuinely new on an API-seeded database. Before inserting any events the script checks that each of the four numbers resolves to exactly one district row and throws if not — `Districts.Number` carries no uniqueness constraint, and a duplicate would make the lookups fail one row at a time.

Route events this script owns are tagged with a `[seed:district-demo]-…` or `DUPSEED-…` `ExternalId`, so they never collide with rows the API's own seeder inserted — those stay in place. Expect the district's total to be the API's rows **plus** the counts above. To get exactly the counts above, delete the pre-existing rows first, or start from an empty database.

## Timestamps

All timestamps in `02_insert_mock_data.sql` are computed relative to `GETUTCDATE()` at execution time (e.g. `DATEADD(minute, -132, GETUTCDATE())`), so events remain recent on any run date.  Duplicate-cluster event times are pinned to specific hours of the current or previous day (e.g. `'T08:12:00+00:00'`) so they stay tightly clustered for the duplicate-detection UI.
