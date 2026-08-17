import React from 'react';
import { useListDistricts, getListDistrictsQueryKey } from '@workspace/api-client-react';
import { useI18n } from '@/i18n';
import { useCurrentUser } from '@/hooks/use-current-user';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Skeleton } from '@/components/ui/skeleton';
import { Label } from '@/components/ui/label';
import { DistrictSettings } from '@/components/admin/district-settings';
import { GlobalSettings } from '@/components/admin/global-settings';
import { lastDistrict, rememberDistrict } from '@/lib/selected-district';
import { ShieldAlert, Info } from 'lucide-react';

export default function AdminPage() {
  const { t } = useI18n();
  const { data: user, isFetched } = useCurrentUser();
  const isAdmin = user?.role?.toLowerCase() === 'admin';

  const { data: districts } = useListDistricts({
    query: { queryKey: getListDistrictsQueryKey() },
  });

  // Whichever district you were last working in, then your home district, then
  // simply the first one -- the tab is never left without a subject.
  const [districtId, setDistrictId] = React.useState<number | null>(() => lastDistrict());
  React.useEffect(() => {
    if (districtId !== null || !districts?.length) return;
    const home = user?.homeDistrictNumber
      ? districts.find(d => d.number === user.homeDistrictNumber)
      : undefined;
    setDistrictId((home ?? districts[0]).id);
  }, [districts, districtId, user?.homeDistrictNumber]);

  const district = districts?.find(d => d.id === districtId) ?? null;

  // Only the API can really refuse: this is the affordance, not the lock.
  if (isFetched && user && !isAdmin) {
    return (
      <div className="container py-10">
        <div className="mx-auto flex max-w-md flex-col items-center gap-3 rounded-lg border bg-card p-8 text-center shadow-sm">
          <ShieldAlert className="h-8 w-8 text-muted-foreground" />
          <p className="font-medium">{t('admin.no_access')}</p>
          <p className="text-sm text-muted-foreground">{t('admin.no_access_hint')}</p>
        </div>
      </div>
    );
  }

  return (
    <div className="container space-y-4 py-4" data-testid="admin-page">
      <div className="space-y-1">
        <h1 className="text-xl font-bold">{t('admin.title')}</h1>
        <p className="text-sm text-muted-foreground">{t('admin.subtitle')}</p>
      </div>

      {/* Said once, up front: the amber rows are this browser's opinion only. */}
      <p className="flex items-start gap-2 rounded-md border border-amber-300 bg-amber-50 p-2.5 text-xs text-amber-900 dark:border-amber-500/40 dark:bg-amber-500/10 dark:text-amber-200">
        <Info className="mt-0.5 h-4 w-4 shrink-0" />
        {t('admin.local_notice')}
      </p>

      <Tabs defaultValue="district">
        <TabsList>
          <TabsTrigger value="district" data-testid="admin-tab-district">
            {district ? `${district.number} – ${district.name}` : t('admin.tab_district')}
          </TabsTrigger>
          <TabsTrigger value="global" data-testid="admin-tab-global">{t('admin.tab_global')}</TabsTrigger>
        </TabsList>

        <TabsContent value="district" className="mt-4 space-y-4">
          <div className="flex flex-wrap items-center gap-2">
            <Label htmlFor="admin-district" className="text-xs uppercase tracking-wider text-muted-foreground">
              {t('admin.district_label')}
            </Label>
            {/* Held back until a district is resolved: mounting it empty would
                flip the select from uncontrolled to controlled. */}
            {districtId === null ? <Skeleton className="h-8 w-[320px] max-w-full" /> : (
            <Select
              value={String(districtId)}
              onValueChange={value => {
                const id = Number(value);
                setDistrictId(id);
                rememberDistrict(id);
              }}
            >
              <SelectTrigger id="admin-district" className="h-8 w-[320px] max-w-full" data-testid="admin-district-select">
                <SelectValue placeholder={t('district.switch_district')} />
              </SelectTrigger>
              <SelectContent>
                {(districts ?? []).map(d => (
                  <SelectItem key={d.id} value={String(d.id)}>
                    <span className="font-mono">{d.number}</span> – {d.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            )}
          </div>

          {districtId ? (
            <DistrictSettings key={districtId} districtId={districtId} />
          ) : (
            <div className="grid gap-4 lg:grid-cols-3">
              {[1, 2, 3].map(i => <Skeleton key={i} className="h-64 w-full" />)}
            </div>
          )}
        </TabsContent>

        <TabsContent value="global" className="mt-4">
          <GlobalSettings />
        </TabsContent>
      </Tabs>
    </div>
  );
}
