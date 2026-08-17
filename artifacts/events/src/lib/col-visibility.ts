/**
 * Column-visibility helpers for the district grid.
 *
 * Extracted so they can be unit-tested independently of the full React page.
 */

/** The optional column keys that exist in the grid. */
export const OPTIONAL_COL_KEYS = [
  'qty', 'binSerial', 'stop', 'wo', 'address',
  'lob', 'tabletNotes', 'chgAmt', 'prevChg', 'prevTotal',
] as const;

/** The columns most agents actually use. Everything else starts switched off. */
export const DEFAULT_VISIBLE_COLS: string[] = [
  'qty', 'binSerial', 'address', 'chgAmt', 'prevChg', 'prevTotal',
];

/**
 * The pre-rework default was "everything on". A legacy store holding exactly
 * that set is almost certainly the old default echoed back by a view apply or
 * an off-then-on toggle, not a deliberate choice — treat it as no choice.
 */
export const LEGACY_ALL_ON = new Set<string>(OPTIONAL_COL_KEYS);

/**
 * Current versioned storage key. v1 ('grid-columns') dates from when every
 * optional column defaulted on, so an absent v2 key means "use the new
 * default" unless the v1 value shows the user made their own pick.
 */
export const COL_VIS_KEY = 'grid-columns-v2';

/** Legacy key written by the pre-rework grid. */
export const LEGACY_COL_VIS_KEY = 'grid-columns';

/**
 * Load the user's visible-column preference from localStorage.
 *
 * Priority:
 *  1. v2 key present → always use it (user's current choice).
 *  2. Legacy key present AND not equal to the old all-on default → migrate it.
 *  3. Otherwise → new default set.
 */
export const loadVisibleCols = (): Set<string> => {
  try {
    const raw = localStorage.getItem(COL_VIS_KEY);
    if (raw) return new Set(JSON.parse(raw) as string[]);
    const legacy = localStorage.getItem(LEGACY_COL_VIS_KEY);
    if (legacy) {
      const cols = JSON.parse(legacy) as string[];
      const isStaleDefault =
        cols.length === LEGACY_ALL_ON.size && cols.every(k => LEGACY_ALL_ON.has(k));
      if (!isStaleDefault) return new Set(cols);
    }
  } catch {}
  return new Set(DEFAULT_VISIBLE_COLS);
};
