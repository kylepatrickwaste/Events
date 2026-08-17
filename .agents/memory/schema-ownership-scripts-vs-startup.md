---
name: Moving schema ownership out of app start-up
description: What to check before deleting a start-up initializer that creates and seeds the database
---

When an app's start-up initializer owns `CREATE TABLE` and seed data, deleting
it is never a one-file change. The initializer has almost always drifted ahead
of the checked-in SQL scripts, and the drift is invisible until somebody builds
a fresh database.

**Why:** an initializer accretes tables and columns one feature at a time
(`ALTER TABLE ... ADD` back-fill passes are the tell). Nobody re-syncs the
`create_tables.sql` that was written once at the start, so the script silently
becomes a subset. The running production database is fine — it got the columns
from the initializer — so nothing fails until a new environment is built.

**How to apply**, before deleting the initializer:

1. Diff what the initializer creates against the SQL script, object by object.
   Grep the repositories for every table name and confirm the script covers it.
   Tables an initializer creates but no query touches still belong in the script
   if a foreign key points at them.
2. Carry over the **column back-fill** pass as guarded `ALTER TABLE ... ADD`
   statements. Existing databases were created before those columns existed, and
   a `CREATE TABLE` guarded on table existence will never add them.
3. Separate access control from seeding. A "promote these configured logins to
   admin" step reads like seeding but is the break-glass path back in — keep it,
   and give it its own file so its purpose is not mistaken again.
4. Preserve any **legacy rename/migration** logic as a numbered script rather
   than losing it to git history. Order it before the create script and say so:
   a create script guarded on the new names will happily build a second, empty
   set of tables next to the old ones.
5. State the new contract loudly in the README and in a comment at the call
   site: the app creates nothing and will fail on the first query against an
   unprepared database. That failure is the feature.

Verifying T-SQL with no SQL Server available: split the file on `GO` and parse
each batch with `sqlfluff --dialect tsql` (INI-format `.sqlfluff`, `rules = none`,
raised `large_file_skip_byte_limit`). It catches syntax errors, not semantics.
