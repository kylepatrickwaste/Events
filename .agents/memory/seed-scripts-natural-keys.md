---
name: Seed scripts must key on natural keys, not identity Ids
description: Why a hand-run seed script that hard-codes parent Ids silently attaches rows to the wrong parent, and how to rewrite it safely
---

A hand-run seed script must resolve every foreign key through a **natural key**
(district number, code, name), never through a hard-coded identity `Id`.

**Why:** This project has two independent seeders — the API's start-up
initializer and a hand-run T-SQL script — and they assign identity values
differently. An `IF NOT EXISTS (... WHERE Id = 2)` guard finds *someone else's*
row sitting on Id 2, skips its own insert, and every child row that hard-codes
`DistrictId = 2` then attaches to the wrong parent. Nothing errors; the data
just lands in the wrong district. Id-pinning is only safe for lookup tables
where both seeders assign the same Id to the same name (event types, sources) —
and even then it is worth an explicit comment saying so.

**How to apply:**
- Insert parents guarded on the natural key, without `SET IDENTITY_INSERT`;
  let IDENTITY assign. Leave an existing parent untouched.
- Reference parents from children with an inline scalar subquery
  (`(SELECT Id FROM dbo.Parent WHERE Number = N'…')`). `DECLARE`d variables do
  not survive `GO` batch separators, and a temp table adds a failure mode.
- Add a pre-flight guard that each natural key resolves to **exactly one** row
  (`COUNT(*) <> 1`) and `THROW`s — a scalar subquery errors on duplicates and
  silently yields NULL on a miss, both of which surface as noise hundreds of
  rows later. Natural-key columns usually carry no uniqueness constraint.
- `THROW` needs the preceding statement terminated; write `;THROW` inside the
  `BEGIN`/`END` block.
- The script only adds rows carrying its own tagged external ids, so totals on
  an already-populated database are the existing rows **plus** the script's.
  Say so in the docs rather than promising exact counts.

**Verifying T-SQL with no SQL Server available:** split the file on `GO` and
parse each batch with `sqlfluff --dialect tsql` in a venv. It has a 20 KB file
limit (raise via `large_file_skip_byte_limit` in an **INI**-format `.sqlfluff`,
not YAML) and a 100k parse-node cap, which is what forces the per-batch split.
