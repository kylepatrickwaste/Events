/**
 * Opens the excluded-accounts dialog, which is mounted by the district
 * workspace and therefore only reachable while a district is open.
 *
 * It lives in a module of its own rather than beside either end of the wire:
 * the administration section of the profile dialog raises it and the district
 * workspace listens for it, and those two already import each other's
 * neighbours. A shared constant here keeps that from becoming a cycle.
 */
export const OPEN_EXCLUDED_ACCOUNTS_EVENT = 'open-excluded-accounts';
