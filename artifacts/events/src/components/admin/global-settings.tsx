import React from 'react';
import {
  useListDistricts, getListDistrictsQueryKey,
  useListEventTypes, getListEventTypesQueryKey,
  type District, type EventType,
} from '@workspace/api-client-react';
import { useI18n } from '@/i18n';
import { PanelCard } from '@/components/admin/panel-card';
import { EditableList } from '@/components/admin/editable-list';
import { useLocalRows } from '@/components/admin/local-rows';
import { AdminUserList } from '@/components/admin-user-list';

/** Every district the API knows about. Read on the server, edited only here. */
function DistrictsPanel() {
  const { t } = useI18n();
  const { data, isLoading, isError, refetch } = useListDistricts({
    query: { queryKey: getListDistrictsQueryKey() },
  });
  const { rows, dirty, add, update, remove, reset } = useLocalRows<District>(data);

  return (
    <PanelCard
      title={t('admin.districts')}
      hint={t('admin.districts_hint')}
      dirty={dirty}
      onReset={reset}
      isLoading={isLoading}
      isError={isError}
      onRetry={() => void refetch()}
      testId="admin-districts"
    >
      <div className="max-h-[26rem] overflow-y-auto">
        <EditableList
          testId="admin-districts-list"
          emptyText={t('admin.districts_empty')}
          rows={rows}
          fields={[
            { key: 'number', label: t('admin.number'), mono: true, className: 'w-[22%]' },
            { key: 'name', label: t('admin.name') },
            { key: 'region', label: t('admin.region'), className: 'w-[24%]' },
          ]}
          onAdd={values => add({
            number: values.number?.trim() ?? '',
            name: values.name?.trim() ?? '',
            region: values.region?.trim() ?? '',
            eventsCount: 0,
          })}
          onSave={(id, values) => update(id, {
            number: values.number?.trim(),
            name: values.name?.trim(),
            region: values.region?.trim(),
          })}
          onRemove={row => remove(row.id)}
        />
      </div>
    </PanelCard>
  );
}

/** The event vocabulary: Extra, Contamination, Overloaded and friends. */
function EventTypesPanel() {
  const { t } = useI18n();
  const { data, isLoading, isError, refetch } = useListEventTypes({
    query: { queryKey: getListEventTypesQueryKey() },
  });
  const { rows, dirty, add, update, remove, reset } = useLocalRows<EventType>(data);

  return (
    <PanelCard
      title={t('admin.event_types')}
      hint={t('admin.event_types_hint')}
      dirty={dirty}
      onReset={reset}
      isLoading={isLoading}
      isError={isError}
      onRetry={() => void refetch()}
      testId="admin-event-types"
    >
      <EditableList
        testId="admin-event-types-list"
        emptyText={t('admin.event_types_empty')}
        rows={rows}
        fields={[{ key: 'name', label: t('admin.name') }]}
        onAdd={values => add({ name: values.name?.trim() ?? '' })}
        onSave={(id, values) => update(id, { name: values.name?.trim() })}
        onRemove={row => remove(row.id)}
      />
    </PanelCard>
  );
}

type ActionRow = { id: number; name: string };

/**
 * The action vocabulary written against every event -- "Account charged",
 * "Email sent", and so on. The API has no endpoint for it at all: it is not
 * even readable, so this panel starts empty rather than inventing a list that
 * would not match what the server actually records.
 */
function ActionsPanel() {
  const { t } = useI18n();
  const { rows, dirty, add, update, remove, reset } = useLocalRows<ActionRow>([]);

  return (
    <PanelCard title={t('admin.actions')} hint={t('admin.actions_hint')} localOnly dirty={dirty} onReset={reset} testId="admin-actions">
      <EditableList
        testId="admin-actions-list"
        emptyText={t('admin.actions_empty')}
        rows={rows}
        fields={[{ key: 'name', label: t('admin.name') }]}
        onAdd={values => add({ name: values.name?.trim() ?? '' })}
        onSave={(id, values) => update(id, { name: values.name?.trim() })}
        onRemove={row => remove(row.id)}
      />
    </PanelCard>
  );
}

export function GlobalSettings() {
  const { t } = useI18n();

  return (
    <div className="space-y-4">
      <div className="grid gap-4 lg:grid-cols-3">
        <DistrictsPanel />
        <EventTypesPanel />
        <ActionsPanel />
      </div>
      <PanelCard title={t('profile.users')} hint={t('profile.users_hint')} testId="admin-users">
        <AdminUserList enabled />
      </PanelCard>
    </div>
  );
}
