import React, { useState, useMemo } from 'react';
import { useLocation } from 'wouter';
import { useListDistricts, getListDistrictsQueryKey } from '@workspace/api-client-react';
import { useI18n } from '@/i18n';
import { Input } from '@/components/ui/input';
import { Card } from '@/components/ui/card';
import { MapPin, Search, ChevronRight } from 'lucide-react';
import { Skeleton } from '@/components/ui/skeleton';

export default function Home() {
  const { t } = useI18n();
  const [, setLocation] = useLocation();
  const [search, setSearch] = useState('');
  
  const { data: districts, isLoading } = useListDistricts({
    query: { queryKey: getListDistrictsQueryKey() }
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

  return (
    <div className="container max-w-4xl mx-auto py-12 px-4">
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
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 max-w-4xl mx-auto">
          {[1,2,3,4,5,6].map(i => (
            <Skeleton key={i} className="h-24 w-full rounded-xl" />
          ))}
        </div>
      ) : filteredDistricts.length === 0 ? (
        <div className="text-center py-12 text-muted-foreground bg-muted/30 rounded-xl border border-dashed">
          <MapPin className="h-12 w-12 mx-auto mb-4 opacity-20" />
          <p className="text-lg">{t('app.no_districts_found')}</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 max-w-4xl mx-auto">
          {filteredDistricts.map(district => (
            <Card 
              key={district.id}
              onClick={() => setLocation(`/districts/${district.id}`)}
              className="group p-6 cursor-pointer hover:border-primary/50 hover:shadow-md transition-all flex items-center justify-between"
            >
              <div>
                <div className="flex items-center gap-2 mb-1">
                  <span className="font-mono text-sm font-semibold text-secondary px-2 py-0.5 bg-secondary/10 rounded">
                    {district.number}
                  </span>
                  <span className="text-xs text-muted-foreground uppercase tracking-wider font-semibold">
                    {district.region}
                  </span>
                </div>
                <h3 className="text-lg font-bold text-foreground group-hover:text-primary transition-colors">
                  {district.name}
                </h3>
              </div>
              <ChevronRight className="h-5 w-5 text-muted-foreground group-hover:text-primary group-hover:translate-x-1 transition-all" />
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
