/**
 * The district you were last working in.
 *
 * The administration page has a tab of settings for "the district selected",
 * but it does not live under a district route, so it has no district in its
 * URL to read. The district workspace records where you are as you move
 * around, and the admin page picks that up -- falling back to your home
 * district, and finally to an explicit choice, when there is nothing recorded.
 */
const KEY = 'route-events:last-district';

export function rememberDistrict(districtId: number): void {
  if (!Number.isFinite(districtId) || districtId <= 0) return;
  try {
    localStorage.setItem(KEY, String(districtId));
  } catch {
    // Private browsing or a full quota: the admin page just falls back.
  }
}

export function lastDistrict(): number | null {
  try {
    const raw = localStorage.getItem(KEY);
    const id = raw ? Number(raw) : NaN;
    return Number.isFinite(id) && id > 0 ? id : null;
  } catch {
    return null;
  }
}
