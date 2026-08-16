# files/

Static T-SQL scripts for bootstrapping the Route Events database on Microsoft SQL Server. SQL Server is the only database this project uses; nothing in this workspace provisions one.

## Scripts

| Script | Purpose |
|--------|---------|
| `01_create_tables.sql` | Creates all seven tables (`Districts`, `EventTypes`, `EventSources`, `ServiceCodes`, `RouteEvents`, `EventActions`, `AccountFlags`) with correct MSSQL types, primary keys, foreign keys, indexes, and JSON CHECK constraints. |
| `02_insert_mock_data.sql` | Inserts all lookup rows, four districts, service codes, 28 demo route events (14 event specs × 2 districts: Vancouver/2010 and Vancouver-Minimal/2010-M), 11 duplicate-cluster events across districts 2010/2012/5120, and all associated notes, close, charge, and history `EventActions`. |

## Run order

```sql
-- 1. Create schema
:r 01_create_tables.sql

-- 2. Seed data
:r 02_insert_mock_data.sql
```

Both scripts are **idempotent** — they can be re-run safely on an already-populated database using `IF NOT EXISTS` / `IF OBJECT_ID` guards throughout.

## Timestamps

All timestamps in `02_insert_mock_data.sql` are computed relative to `GETUTCDATE()` at execution time (e.g. `DATEADD(minute, -132, GETUTCDATE())`), so events remain recent on any run date.  Duplicate-cluster event times are pinned to specific hours of the current or previous day (e.g. `'T08:12:00+00:00'`) so they stay tightly clustered for the duplicate-detection UI.
