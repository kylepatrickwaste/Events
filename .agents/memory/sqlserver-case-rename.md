---
name: SQL Server snake_case → PascalCase renames
description: Why a case-only rename is invisible to SQL Server's guards, and how to migrate a legacy schema in place without dropping data.
---

# Renaming SQL Server objects from snake_case to PascalCase

## Case-only renames are invisible to the usual guards
SQL Server identifiers are case-insensitive under the default collation, so
`districts` and `Districts` are **the same object**, and `COL_LENGTH`,
`OBJECT_ID`, and a plain `name = 'Districts'` predicate cannot tell the two
apart. In a rename sweep only the names that lose an underscore
(`route_events` → `RouteEvents`) look like new objects.

**Why:** an `IF OBJECT_ID('Districts') IS NULL CREATE TABLE …` bootstrap
therefore sees the legacy single-word table, skips creation, and every query
against the new column names fails at runtime while the build stays green.

**How to apply:** compare under a binary collation
(`name = @old COLLATE Latin1_General_BIN2` against `sys.tables` / `sys.columns`)
to decide whether a rename is still outstanding, then `sp_rename` in place —
tables, then columns, then indexes and named constraints. Guard each statement
with "legacy spelling present AND new spelling absent" so the migration is a
no-op on an already-renamed or empty database. Never satisfy a rename by
dropping and re-seeding: that is data loss dressed up as a migration, and it
gets rejected in review even when the current rows are only demo seed data.

## Dapper's dynamic rows are case-sensitive even though SQL is not
`DapperRow` looks members up ordinally, and the result-set metadata carries the
column's catalog spelling — not the spelling used in the query text. So a column
left as `id` after a partial rename breaks `row.Id` at runtime even though the
SQL itself runs fine. Rename *every* column, including single-word ones.

## Mechanical renames must not touch string literals
Seed scripts store JSON payloads and external ids inside single-quoted literals
(`'{"code":…}'`, `'[seed:…]-2010-c1-wv'`). A regex sweep has to skip literals —
except the ones that name schema objects (`N'dbo.route_events'`, index names in
`sys.indexes WHERE name = …`), which must be renamed. `sys` catalog columns such
as `object_id` must be protected explicitly; they are not application columns.
