---
name: SQL Server snake_case → PascalCase renames
description: Why a case-only table rename is a no-op in SQL Server, and how to make a startup initializer converge on the new schema.
---

# Renaming SQL Server objects from snake_case to PascalCase

## Case-only renames are not renames
SQL Server identifiers are case-insensitive under the default collation, so
`districts` and `Districts` are **the same object**. In a rename sweep, only the
names that lose an underscore (`route_events` → `RouteEvents`) become new
objects; single-word tables silently keep their old columns.

**Why:** a `IF OBJECT_ID('Districts') IS NULL CREATE TABLE …` guard therefore
sees the legacy table, skips creation, and every query against the new column
names fails at runtime while the build stays green.

**How to apply:** detect the legacy schema by probing a legacy *column*
(`COL_LENGTH('dbo.Districts','hauling_system') IS NOT NULL`), OR'd with
`OBJECT_ID` checks on the underscore-named tables. Inside that branch, drop both
name spellings child-first so foreign keys never block the drop, then let the
normal creation + seed path rebuild everything.

## Dapper's dynamic rows are case-sensitive even though SQL is not
Column names come back exactly as the query spells them and member lookup on the
`dynamic` row is ordinal. `r.Id` only works because the SELECT list says `Id`.
Renaming the SQL without renaming every read site compiles fine and throws only
when that endpoint is called.

## Mechanical renames must not touch string literals
Seed scripts store JSON payloads and external ids inside single-quoted literals
(`'{"code":…}'`, `'[seed:…]-2010-c1-wv'`). A regex sweep has to skip literals —
except the ones that name schema objects (`N'dbo.route_events'`, index names in
`sys.indexes WHERE name = …`), which must be renamed. `sys` catalog columns such
as `object_id` must be protected explicitly; they are not application columns.
