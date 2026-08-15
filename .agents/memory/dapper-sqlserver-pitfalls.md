---
name: Dapper + SQL Server pitfalls in this codebase
description: Three bug classes that compile cleanly and only fail at runtime — column aliasing, aggregates, and Sum over dynamic.
---

All three compile with zero warnings and only fail when the endpoint is called.

**1. Snake_case aliases do not bind to typed models.** `MatchNamesWithUnderscores`
is not enabled, so `SELECT 0 AS events_count` cannot populate an `EventsCount`
record parameter — Dapper throws a "parameterless default constructor ... is
required" error that names the *SQL* column list, which misleadingly looks like a
missing-constructor problem. Alias to the exact member name instead.
Queries returning `dynamic` are unaffected, which is why some endpoints worked
while others failed on the same table.

**2. `Enumerable.Sum` over `IEnumerable<dynamic>` picks its overload at runtime**
and binds to the `int` version, throwing "Cannot implicitly convert type 'decimal'
to 'int'" even though every value is a decimal. Accumulate into an explicitly
typed local in a loop; do not rely on `Convert.ToDecimal` inside the lambda,
since a dynamic receiver makes the lambda's return type dynamic too.

**3. SQL Server dialect rules that MySQL/Postgres habits violate:**
- A subquery cannot appear inside an aggregate function. Hoist `NOT EXISTS`
  filters into `WHERE` — safe when the same predicate is applied to every
  `SUM(CASE ...)` branch.
- `HAVING` without `GROUP BY` treats the result as one group, so bare columns are
  rejected. A row-level predicate belongs in `WHERE`; to filter on a computed
  alias, wrap the query in a CTE and filter in the outer `SELECT`.

**How to apply:** when a .NET endpoint 500s, read the exception type first. A
`RuntimeBinderException` means dynamic dispatch (case 2), a Dapper materialization
error means column naming (case 1), and a `SqlException` means dialect (case 3).
