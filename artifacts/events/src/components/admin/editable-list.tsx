import React from 'react';
import { useI18n } from '@/i18n';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { cn } from '@/lib/utils';
import { Check, Pencil, Plus, Trash2, X } from 'lucide-react';
import type { LocalRow } from '@/components/admin/local-rows';

export type ListField<T> = {
  key: Extract<keyof T, string>;
  label: string;
  placeholder?: string;
  mono?: boolean;
  numeric?: boolean;
  /** A server-owned fact: shown in the row, never offered as an input. */
  readOnly?: boolean;
  render?: (row: LocalRow<T>) => React.ReactNode;
  className?: string;
};

/**
 * The one table shape every administration panel uses: a row per record, an
 * inline editor on the row itself, and a permanently open "add" line at the
 * bottom. Panels differ only in their columns and in what each handler does
 * with the values -- some write to the server, most only change what this
 * browser is showing.
 *
 * Omitting a handler removes that affordance, which is how a panel says the
 * operation is not available at all rather than merely local.
 */
export function EditableList<T extends { id: number }>({
  fields,
  rows,
  emptyText,
  onAdd,
  onSave,
  onRemove,
  busyId = null,
  addLabel,
  testId,
}: {
  fields: ListField<T>[];
  rows: LocalRow<T>[];
  emptyText: string;
  onAdd?: (values: Record<string, string>) => void;
  onSave?: (id: number, values: Record<string, string>) => void;
  onRemove?: (row: LocalRow<T>) => void;
  busyId?: number | null;
  addLabel?: string;
  testId?: string;
}) {
  const { t } = useI18n();
  const editable = fields.filter(f => !f.readOnly);
  const [editingId, setEditingId] = React.useState<number | null>(null);
  const [draft, setDraft] = React.useState<Record<string, string>>({});
  const [newRow, setNewRow] = React.useState<Record<string, string>>({});

  const valueOf = (row: LocalRow<T>, key: string) => {
    const raw = (row as Record<string, unknown>)[key];
    return raw === null || raw === undefined ? '' : String(raw);
  };

  const startEdit = (row: LocalRow<T>) => {
    setEditingId(row.id);
    setDraft(Object.fromEntries(editable.map(f => [f.key, valueOf(row, f.key)])));
  };

  const commitEdit = () => {
    if (editingId !== null) onSave?.(editingId, draft);
    setEditingId(null);
  };

  const commitAdd = () => {
    if (!onAdd) return;
    // An empty line is a stray Enter, not an intent to create a blank record.
    if (editable.every(f => !(newRow[f.key] ?? '').trim())) return;
    onAdd(newRow);
    setNewRow({});
  };

  return (
    <div className="overflow-x-auto" data-testid={testId}>
      <table className="w-full text-sm">
        <thead>
          <tr className="border-b text-xs uppercase tracking-wider text-muted-foreground">
            {fields.map(f => (
              <th key={f.key} className={cn('px-2 py-1.5 text-left font-semibold', f.className)}>
                {f.label}
              </th>
            ))}
            <th className="w-16 px-2 py-1.5" />
          </tr>
        </thead>
        <tbody className="divide-y">
          {rows.length === 0 && (
            <tr>
              <td colSpan={fields.length + 1} className="px-2 py-6 text-center text-muted-foreground">
                {emptyText}
              </td>
            </tr>
          )}

          {rows.map(row => {
            const editing = editingId === row.id;
            return (
              <tr key={row.id} className="align-middle hover:bg-muted/30" data-row-id={row.id}>
                {fields.map(f => (
                  <td key={f.key} className={cn('px-2 py-1', f.mono && 'font-mono text-xs')}>
                    {editing && !f.readOnly ? (
                      <Input
                        value={draft[f.key] ?? ''}
                        onChange={e => setDraft(d => ({ ...d, [f.key]: e.target.value }))}
                        onKeyDown={e => {
                          if (e.key === 'Enter') commitEdit();
                          if (e.key === 'Escape') setEditingId(null);
                        }}
                        inputMode={f.numeric ? 'decimal' : undefined}
                        size={1}
                        className="h-7 w-full min-w-0 text-sm"
                        aria-label={f.label}
                      />
                    ) : f.render ? (
                      f.render(row)
                    ) : (
                      <span className="flex items-center gap-1.5">
                        <span className="truncate">{valueOf(row, f.key) || '—'}</span>
                        {f.key === fields[0].key && (row.localAdded || row.localEdited) && (
                          <span className="rounded bg-amber-100 px-1 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-amber-900 dark:bg-amber-500/20 dark:text-amber-200">
                            {t('admin.local_badge')}
                          </span>
                        )}
                      </span>
                    )}
                  </td>
                ))}
                <td className="px-2 py-1">
                  <div className="flex items-center justify-end gap-1">
                    {editing ? (
                      <>
                        <Button type="button" size="icon" variant="ghost" className="h-6 w-6" onClick={commitEdit} aria-label={t('district.save')}>
                          <Check className="h-3.5 w-3.5" />
                        </Button>
                        <Button type="button" size="icon" variant="ghost" className="h-6 w-6" onClick={() => setEditingId(null)} aria-label={t('district.cancel')}>
                          <X className="h-3.5 w-3.5" />
                        </Button>
                      </>
                    ) : (
                      <>
                        {onSave && (
                          <Button type="button" size="icon" variant="ghost" className="h-6 w-6" onClick={() => startEdit(row)} aria-label={t('admin.edit_row')}>
                            <Pencil className="h-3.5 w-3.5" />
                          </Button>
                        )}
                        {onRemove && (
                          <Button
                            type="button"
                            size="icon"
                            variant="ghost"
                            className="h-6 w-6 text-destructive hover:text-destructive"
                            disabled={busyId === row.id}
                            onClick={() => onRemove(row)}
                            aria-label={t('admin.delete_row')}
                          >
                            <Trash2 className="h-3.5 w-3.5" />
                          </Button>
                        )}
                      </>
                    )}
                  </div>
                </td>
              </tr>
            );
          })}

          {onAdd && (
            <tr className="bg-muted/20">
              {fields.map(f => (
                <td key={f.key} className="px-2 py-1.5">
                  {f.readOnly ? (
                    <span className="text-xs text-muted-foreground">—</span>
                  ) : (
                    <Input
                      value={newRow[f.key] ?? ''}
                      onChange={e => setNewRow(r => ({ ...r, [f.key]: e.target.value }))}
                      onKeyDown={e => { if (e.key === 'Enter') commitAdd(); }}
                      placeholder={f.placeholder ?? f.label}
                      inputMode={f.numeric ? 'decimal' : undefined}
                      // size=1 keeps the intrinsic width out of the table's
                      // layout maths, so three inputs still fit a narrow card.
                      size={1}
                      className="h-7 w-full min-w-0 text-sm"
                      aria-label={`${addLabel ?? t('admin.add_row')} — ${f.label}`}
                    />
                  )}
                </td>
              ))}
              <td className="px-2 py-1.5">
                <div className="flex justify-end">
                  <Button type="button" size="icon" variant="outline" className="h-7 w-7" onClick={commitAdd} aria-label={addLabel ?? t('admin.add_row')}>
                    <Plus className="h-3.5 w-3.5" />
                  </Button>
                </div>
              </td>
            </tr>
          )}
        </tbody>
      </table>
    </div>
  );
}
