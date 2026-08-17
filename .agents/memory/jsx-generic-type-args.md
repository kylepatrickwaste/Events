---
name: JSX generic type arguments break the dev build
description: Explicit type args on a JSX element (<List<Row> ...>) crash vite:react-babel here, with a parse error that looks like corrupted source.
---

Never write explicit type arguments on a JSX element in this repl:
`<EditableList<District> rows={rows} />` typechecks fine and fails at dev-server
transform time with `[plugin:vite:react-babel] Unexpected token`, quoting a line
that looks mangled — the metadata attributes the plugin injects land *before*
the type argument, producing source Babel cannot parse.

**Why:** the dev setup injects `data-replit-metadata` / `data-component-name`
attributes into every JSX opening element, and its inserter does not know about
the type-argument slot. The failure only shows in the browser (a 500 from the
module), so a clean `tsc --noEmit` proves nothing.

**How to apply:** let the generic infer from props — passing `rows` and `fields`
of the concrete type is enough for a generic component. If inference genuinely
cannot work, annotate at the call boundary (a typed variable or an
instantiation expression assigned to a const), never on the JSX tag.
