import { beforeEach, describe, expect, it } from 'vitest';
import {
  COL_VIS_KEY,
  DEFAULT_VISIBLE_COLS,
  LEGACY_ALL_ON,
  LEGACY_COL_VIS_KEY,
  loadVisibleCols,
} from './col-visibility';

// Vitest's jsdom environment provides a localStorage stub, but we reset it
// before every test so cases cannot bleed into each other.
beforeEach(() => {
  localStorage.clear();
});

// ─── loadVisibleCols ──────────────────────────────────────────────────────────

describe('loadVisibleCols – no stored value', () => {
  it('returns the new default set when localStorage is empty', () => {
    const result = loadVisibleCols();
    expect([...result].sort()).toEqual([...DEFAULT_VISIBLE_COLS].sort());
  });
});

describe('loadVisibleCols – legacy key equal to the old all-on set', () => {
  it('treats the stale default as no choice and returns the new default', () => {
    // Store exactly the old all-on set in the legacy key.
    localStorage.setItem(LEGACY_COL_VIS_KEY, JSON.stringify([...LEGACY_ALL_ON]));

    const result = loadVisibleCols();
    expect([...result].sort()).toEqual([...DEFAULT_VISIBLE_COLS].sort());
  });

  it('is order-independent: shuffled all-on is still treated as stale', () => {
    const shuffled = [...LEGACY_ALL_ON].reverse();
    localStorage.setItem(LEGACY_COL_VIS_KEY, JSON.stringify(shuffled));

    const result = loadVisibleCols();
    expect([...result].sort()).toEqual([...DEFAULT_VISIBLE_COLS].sort());
  });
});

describe('loadVisibleCols – legacy partial set (deliberate user choice)', () => {
  it('migrates the partial set as-is', () => {
    const userPick = ['qty', 'address'];
    localStorage.setItem(LEGACY_COL_VIS_KEY, JSON.stringify(userPick));

    const result = loadVisibleCols();
    expect([...result].sort()).toEqual([...userPick].sort());
  });

  it('migrates a single-column choice', () => {
    localStorage.setItem(LEGACY_COL_VIS_KEY, JSON.stringify(['chgAmt']));

    const result = loadVisibleCols();
    expect([...result]).toEqual(['chgAmt']);
  });

  it('migrates an almost-all-on set (one column removed)', () => {
    // One fewer than the full all-on set → clearly deliberate.
    const almostAll = [...LEGACY_ALL_ON].filter(k => k !== 'wo');
    localStorage.setItem(LEGACY_COL_VIS_KEY, JSON.stringify(almostAll));

    const result = loadVisibleCols();
    expect([...result].sort()).toEqual([...almostAll].sort());
  });
});

describe('loadVisibleCols – v2 key always wins', () => {
  it('uses v2 value even when a legacy key is also present', () => {
    const v2Pick = ['prevChg', 'prevTotal'];
    localStorage.setItem(COL_VIS_KEY, JSON.stringify(v2Pick));
    // Legacy all-on – would trigger stale-default logic if v2 were ignored.
    localStorage.setItem(LEGACY_COL_VIS_KEY, JSON.stringify([...LEGACY_ALL_ON]));

    const result = loadVisibleCols();
    expect([...result].sort()).toEqual([...v2Pick].sort());
  });

  it('uses v2 value when legacy partial choice is also present', () => {
    const v2Pick = ['binSerial'];
    const legacyPick = ['qty', 'stop'];
    localStorage.setItem(COL_VIS_KEY, JSON.stringify(v2Pick));
    localStorage.setItem(LEGACY_COL_VIS_KEY, JSON.stringify(legacyPick));

    const result = loadVisibleCols();
    expect([...result]).toEqual(v2Pick);
  });

  it('restores an empty visible set when v2 stores []', () => {
    localStorage.setItem(COL_VIS_KEY, JSON.stringify([]));

    const result = loadVisibleCols();
    expect([...result]).toEqual([]);
  });
});

// ─── toggleCol write path ─────────────────────────────────────────────────────

describe('toggleCol write path', () => {
  /**
   * toggleCol is defined inline in the React component, but its persistence
   * contract is: write only to COL_VIS_KEY, never to the legacy key.
   * Simulate what the handler does and verify the storage side-effects.
   */
  const simulateToggle = (prev: Set<string>, key: string): Set<string> => {
    const next = new Set(prev);
    if (next.has(key)) next.delete(key); else next.add(key);
    localStorage.setItem(COL_VIS_KEY, JSON.stringify([...next]));
    return next;
  };

  it('writes only the v2 key when adding a column', () => {
    const initial = new Set(DEFAULT_VISIBLE_COLS);
    simulateToggle(initial, 'stop');

    expect(localStorage.getItem(COL_VIS_KEY)).not.toBeNull();
    // The legacy key must remain untouched.
    expect(localStorage.getItem(LEGACY_COL_VIS_KEY)).toBeNull();
  });

  it('writes only the v2 key when removing a column', () => {
    const initial = new Set(DEFAULT_VISIBLE_COLS);
    simulateToggle(initial, 'qty');

    expect(localStorage.getItem(COL_VIS_KEY)).not.toBeNull();
    expect(localStorage.getItem(LEGACY_COL_VIS_KEY)).toBeNull();
  });

  it('the stored v2 value reflects the toggled state', () => {
    const initial = new Set(['qty', 'address']);
    simulateToggle(initial, 'stop'); // add
    const stored = JSON.parse(localStorage.getItem(COL_VIS_KEY)!);
    expect(stored.sort()).toEqual(['address', 'qty', 'stop'].sort());
  });

  it('a subsequent loadVisibleCols picks up what toggleCol wrote', () => {
    const initial = new Set(DEFAULT_VISIBLE_COLS);
    const after = simulateToggle(initial, 'lob');

    const loaded = loadVisibleCols();
    expect([...loaded].sort()).toEqual([...after].sort());
  });
});
