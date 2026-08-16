---
name: Locale edits break Fast Refresh
description: Why the app throws "must be used within a Provider" after editing i18n JSON, and what to do before running e2e tests.
---

Editing a locale JSON file invalidates the i18n module that imports it. Vite
cannot Fast Refresh that module (its hook export is "incompatible"), so the page
is left in a half-applied state and throws `useI18n must be used within an
I18nProvider` from whichever component renders first. The code is fine; the
running page is not.

**Why:** an e2e run against that page fails in a way that looks exactly like a
broken feature -- elements missing from the DOM, blank regions -- and sends you
debugging code that was never wrong.

**How to apply:** after touching locale files, restart the dev server workflow
(or hard-reload) before screenshotting or handing the page to a test agent. If a
test reports that an element you just added is absent from the DOM, check the
workflow log for this error before touching the component.
