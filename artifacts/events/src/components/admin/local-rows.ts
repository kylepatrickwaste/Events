import React from 'react';

/**
 * A list the server owns, with unsaved local edits laid over the top.
 *
 * Several administration panels describe things the API cannot change yet --
 * service codes, event types, feature switches, the action vocabulary. Rather
 * than show dead controls, those panels let the change happen here, in the
 * browser, and every row that only exists locally is flagged as such.
 *
 * Nothing is written to storage on purpose: a reload is the reset, so a local
 * edit can never quietly accumulate and look like something the server agreed
 * to.
 */
export type LocalRow<T> = T & { localAdded?: boolean; localEdited?: boolean };

export function useLocalRows<T extends { id: number }>(serverRows: T[] | undefined) {
  const [added, setAdded] = React.useState<T[]>([]);
  const [edits, setEdits] = React.useState<Record<number, Partial<T>>>({});
  const [removed, setRemoved] = React.useState<number[]>([]);
  // Locally added rows need an id the server will never mint, both to key them
  // and to tell the two apart when one is edited or deleted again.
  const nextLocalId = React.useRef(-1);

  const rows: LocalRow<T>[] = React.useMemo(() => [
    ...(serverRows ?? [])
      .filter(row => !removed.includes(row.id))
      .map(row => (edits[row.id] ? { ...row, ...edits[row.id], localEdited: true } : row)),
    ...added.map(row => ({ ...row, localAdded: true })),
  ], [serverRows, added, edits, removed]);

  const dirty = added.length > 0 || removed.length > 0 || Object.keys(edits).length > 0;

  const add = React.useCallback((row: Omit<T, 'id'>) => {
    setAdded(prev => [...prev, { ...(row as T), id: nextLocalId.current-- }]);
  }, []);

  const update = React.useCallback((id: number, patch: Partial<T>) => {
    if (id < 0) setAdded(prev => prev.map(row => (row.id === id ? { ...row, ...patch } : row)));
    else setEdits(prev => ({ ...prev, [id]: { ...prev[id], ...patch } }));
  }, []);

  const remove = React.useCallback((id: number) => {
    if (id < 0) setAdded(prev => prev.filter(row => row.id !== id));
    else setRemoved(prev => (prev.includes(id) ? prev : [...prev, id]));
  }, []);

  const reset = React.useCallback(() => {
    setAdded([]);
    setEdits({});
    setRemoved([]);
  }, []);

  return { rows, dirty, add, update, remove, reset };
}
