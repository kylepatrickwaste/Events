import React, { useState, useMemo, useEffect, useRef } from 'react';
import { useLocation, useSearch } from 'wouter';
import { useListDistricts, getListDistrictsQueryKey } from '@workspace/api-client-react';
import { useI18n } from '@/i18n';
import { Input } from '@/components/ui/input';
import { Card } from '@/components/ui/card';
import { MapPin, Search, ChevronRight } from 'lucide-react';
import { Skeleton } from '@/components/ui/skeleton';

export const LAST_DISTRICT_KEY = 'last-district-id';

export default function Home() {
  const { t } = useI18n();
  const [, setLocation] = useLocation();
  const searchString = useSearch();
  const [search, setSearch] = useState('');
  const redirected = useRef(false);

  // Remember the last district the user worked in and jump straight there,
  // unless they explicitly asked to browse all districts (?browse=1).
  const browseAll = new URLSearchParams(searchString).has('browse');
  const lastDistrictId = typeof window !== 'undefined' ? localStorage.getItem(LAST_DISTRICT_KEY) : null;
  const shouldRedirect = !browseAll && !!lastDistrictId && /^\d+$/.test(lastDistrictId);

  useEffect(() => {
    if (shouldRedirect && !redirected.current) {
      redirected.current = true;
      setLocation(`/districts/${lastDistrictId}`, { replace: true });
    }
  }, [shouldRedirect, lastDistrictId, setLocation]);

  const { data: districts, isLoading } = useListDistricts({
    query: { queryKey: getListDistrictsQueryKey(), enabled: !shouldRedirect }
  });

  const filteredDistricts = useMemo(() => {
    if (!districts) return [];
    if (!search) return districts;
    const lowerSearch = search.toLowerCase();
    return districts.filter(d =>
      d.name.toLowerCase().includes(lowerSearch) ||
      d.number.toLowerCase().includes(lowerSearch) ||
      d.region.toLowerCase().includes(lowerSearch)
    );
  }, [districts, search]);

  if (shouldRedirect) {
    return (
      <div className="container max-w-4xl mx-auto py-24 px-4 text-center text-muted-foreground">
        <p className="text-lg">{t('app.last_district')}</p>
      </div>
    );
  }

  return (
    <div className="container max-w-6xl mx-auto py-12 px-4">
      <div className="text-center mb-10">
        <h1 className="text-4xl font-extrabold tracking-tight lg:text-5xl mb-4 text-foreground">
          {t('app.welcome')}
        </h1>
        <p className="text-xl text-muted-foreground">
          {t('app.select_district')}
        </p>
      </div>

      <div className="relative max-w-2xl mx-auto mb-8">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-5 w-5 text-muted-foreground" />
        <Input
          value={search}
          onChange={e => setSearch(e.target.value)}
          placeholder={t('app.search_districts')}
          className="pl-10 h-12 text-lg shadow-sm border-2 focus-visible:ring-primary"
        />
      </div>

      {isLoading ? (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
          {[1,2,3,4,5,6,7,8].map(i => (
            <Skeleton key={i} className="h-32 w-full rounded-xl" />
          ))}
        </div>
      ) : filteredDistricts.length === 0 ? (
        <div className="text-center py-12 text-muted-foreground bg-muted/30 rounded-xl border border-dashed">
          <MapPin className="h-12 w-12 mx-auto mb-4 opacity-20" />
          <p className="text-lg">{t('app.no_districts_found')}</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
          {filteredDistricts.map(district => (
            <Card
              key={district.id}
              onClick={() => setLocation(`/districts/${district.id}`)}
              className="group p-5 cursor-pointer hover:border-primary/50 hover:shadow-md transition-all flex flex-col justify-between gap-3"
            >
              <div>
                <div className="flex items-center gap-2 mb-2">
                  <span className="font-mono text-sm font-semibold text-secondary px-2 py-0.5 bg-secondary/10 rounded">
                    {district.number}
                  </span>
                  <span className="text-xs text-muted-foreground uppercase tracking-wider font-semibold">
                    {district.region}
                  </span>
                </div>
                <h3 className="text-lg font-bold text-foreground group-hover:text-primary transition-colors leading-tight">
                  {district.name}
                </h3>
              </div>
              <ChevronRight className="h-5 w-5 text-muted-foreground group-hover:text-primary group-hover:translate-x-1 transition-all self-end" />
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
