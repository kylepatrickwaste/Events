import React from 'react';
import {
  useListDistrictServiceCodes, getListDistrictServiceCodesQueryKey,
  useListDistrictAccountFlags, getListDistrictAccountFlagsQueryKey,
  useDeleteAccountFlag,
  type ServiceCode, type AccountFlag,
} from '@workspace/api-client-react';
import { useQueryClient } from '@tanstack/react-query';
import { useI18n } from '@/i18n';
import { useToast } from '@/hooks/use-toast';
import { Switch } from '@/components/ui/switch';
import { Label } from '@/components/ui/label';
import { PanelCard } from '@/components/admin/panel-card';
import { EditableList } from '@/components/admin/editable-list';
import { useLocalRows } from '@/components/admin/local-rows';

/**
 * Charge codes for the district. The API can list them; creating and editing
 * one is not something it offers yet, so those edits stay in the browser.
 */
function ServiceCodesPanel({ districtId }: { districtId: number }) {
  const { t } = useI18n();
  const { data, isLoading, isError, refetch } = useListDistrictServiceCodes(districtId, {
    query: { enabled: !!districtId, queryKey: getListDistrictServiceCodesQueryKey(districtId) },
  });
  const { rows, dirty, add, update, remove, reset } = useLocalRows<ServiceCode>(data);

  return (
    <PanelCard
      title={t('admin.service_codes')}
      hint={t('admin.service_codes_hint')}
      dirty={dirty}
      onReset={reset}
      isLoading={isLoading}
      isError={isError}
      onRetry={() => void refetch()}
      testId="admin-service-codes"
    >
      <EditableList
        testId="admin-service-codes-list"
        emptyText={t('admin.service_codes_empty')}
        rows={rows}
        fields={[
          { key: 'code', label: t('admin.code'), mono: true, className: 'w-[26%]' },
          { key: 'description', label: t('admin.description') },
          { key: 'amount', label: t('admin.amount'), numeric: true, className: 'w-[20%]' },
        ]}
        onAdd={values => add({
          districtId,
          code: values.code?.trim() ?? '',
          description: values.description?.trim() ?? '',
          amount: Number(values.amount) || 0,
        })}
        onSave={(id, values) => update(id, {
          code: values.code?.trim(),
          description: values.description?.trim(),
          amount: Number(values.amount) || 0,
        })}
        onRemove={row => remove(row.id)}
      />
    </PanelCard>
  );
}

/**
 * Accounts held out of the queue. Removing a flag is a real API call -- it puts
 * that account's events back in front of the agents -- while adding one has no
 * endpoint, so a new exclusion is only ever local.
 */
function ExcludedAccountsPanel({ districtId }: { districtId: number }) {
  const { t, formatDate } = useI18n();
  const { toast } = useToast();
  const queryClient = useQueryClient();

  const { data, isLoading, isError, refetch } = useListDistrictAccountFlags(districtId, {
    query: { enabled: !!districtId, queryKey: getListDistrictAccountFlagsQueryKey(districtId) },
  });
  const { rows, dirty, add, remove, reset } = useLocalRows<AccountFlag>(data);
  const deleteFlag = useDeleteAccountFlag();

  const handleRemove = (id: number, accountNumber: string) => {
    // Locally added exclusions were never sent anywhere, so they just go away.
    if (id < 0) {
      remove(id);
      return;
    }
    deleteFlag.mutate({ flagId: id }, {
      onSuccess: () => {
        queryClient.invalidateQueries({ queryKey: getListDistrictAccountFlagsQueryKey(districtId) });
        // The account's events belong back in the queue behind us.
        queryClient.invalidateQueries({ queryKey: ['/api/events'] });
        toast({ description: t('contract_accounts.removed', { account: accountNumber }) });
      },
      onError: () => {
        toast({ variant: 'destructive', description: t('contract_accounts.remove_failed') });
      },
    });
  };

  return (
    <PanelCard
      title={t('contract_accounts.title')}
      hint={t('admin.excluded_hint')}
      dirty={dirty}
      onReset={reset}
      isLoading={isLoading}
      isError={isError}
      onRetry={() => void refetch()}
      testId="admin-excluded-accounts"
    >
      <EditableList
        testId="admin-excluded-accounts-list"
        emptyText={t('contract_accounts.empty')}
        rows={rows}
        busyId={deleteFlag.isPending ? deleteFlag.variables?.flagId ?? null : null}
        addLabel={t('admin.exclude_account')}
        fields={[
          { key: 'accountNumber', label: t('admin.account_number'), mono: true, className: 'w-[38%]' },
          {
            key: 'createdBy',
            label: t('admin.added_by'),
            readOnly: true,
            render: row => <span className="text-xs text-muted-foreground">{row.createdBy || '—'}</span>,
          },
          {
            key: 'dateCreated',
            label: t('admin.date_added'),
            readOnly: true,
            className: 'w-[24%]',
            render: row => (
              <span className="whitespace-nowrap text-xs text-muted-foreground">
                {row.dateCreated ? formatDate(row.dateCreated) : '—'}
              </span>
            ),
          },
        ]}
        onAdd={values => add({
          districtId,
          accountNumber: values.accountNumber?.trim() ?? '',
          flag: 'Excluded',
          createdBy: '',
          dateCreated: new Date().toISOString(),
        })}
        onRemove={row => handleRemove(row.id, row.accountNumber)}
      />
    </PanelCard>
  );
}

/** District switches. Nothing behind them yet, so they are browser-local. */
function FeaturesPanel() {
  const { t } = useI18n();
  const [features, setFeatures] = React.useState([
    { id: 'work_order', label: t('admin.feature_work_order'), enabled: false },
    { id: 'timestamp', label: t('admin.feature_timestamp'), enabled: false },
  ]);

  return (
    <PanelCard title={t('admin.features')} hint={t('admin.features_hint')} localOnly testId="admin-features">
      <ul className="divide-y">
        {features.map(feature => (
          <li key={feature.id} className="flex items-center justify-between gap-3 py-2">
            <Label htmlFor={`feature-${feature.id}`} className="text-sm font-normal leading-snug">
              {feature.label}
            </Label>
            <Switch
              id={`feature-${feature.id}`}
              checked={feature.enabled}
              onCheckedChange={next => setFeatures(prev => prev.map(f => (f.id === feature.id ? { ...f, enabled: next } : f)))}
            />
          </li>
        ))}
      </ul>
    </PanelCard>
  );
}

export function DistrictSettings({ districtId }: { districtId: number }) {
  return (
    <div className="grid gap-4 lg:grid-cols-3">
      <ServiceCodesPanel districtId={districtId} />
      <ExcludedAccountsPanel districtId={districtId} />
      <FeaturesPanel />
    </div>
  );
}
