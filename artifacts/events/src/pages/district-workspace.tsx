import React, { useState, useMemo } from 'react';
import { useRoute, Link, useLocation } from 'wouter';
import { 
  useGetDistrictSummary, getGetDistrictSummaryQueryKey,
  useListEvents, getListEventsQueryKey,
  useListDistricts, getListDistrictsQueryKey
} from '@workspace/api-client-react';
import { useI18n } from '@/i18n';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Skeleton } from '@/components/ui/skeleton';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { ChevronLeft, Search, Clock, CheckCircle2, DollarSign, Camera, AlertTriangle } from 'lucide-react';
import { Button } from '@/components/ui/button';

export default function DistrictWorkspace() {
  const [, params] = useRoute('/districts/:districtId');
  const districtId = Number(params?.districtId);
  const { t, formatCurrency, formatDate } = useI18n();
  const [, setLocation] = useLocation();

  const [statusFilter, setStatusFilter] = useState<'open' | 'closed' | 'all'>('all');
  const [search, setSearch] = useState('');
  const [typeFilter, setTypeFilter] = useState<string>('all');

  const { data: districts } = useListDistricts({ query: { queryKey: getListDistrictsQueryKey() }});
  const district = districts?.find(d => d.id === districtId);

  const { data: summary, isLoading: isLoadingSummary } = useGetDistrictSummary(districtId, {
    query: { enabled: !!districtId, queryKey: getGetDistrictSummaryQueryKey(districtId) }
  });

  const { data: events, isLoading: isLoadingEvents } = useListEvents(
    { districtId, status: statusFilter === 'all' ? undefined : statusFilter, search: search || undefined, eventTypeId: typeFilter === 'all' ? undefined : Number(typeFilter) },
    { query: { enabled: !!districtId, queryKey: getListEventsQueryKey({ districtId, status: statusFilter === 'all' ? undefined : statusFilter, search: search || undefined, eventTypeId: typeFilter === 'all' ? undefined : Number(typeFilter) }) } }
  );

  const eventTypes = useMemo(() => {
    if (!summary) return [];
    return summary.byEventType.map(et => ({ id: et.eventTypeId, name: et.eventTypeName }));
  }, [summary]);

  return (
    <div className="container mx-auto py-6 px-4 max-w-7xl">
      <div className="flex items-center gap-4 mb-8">
        <Button variant="ghost" size="icon" onClick={() => setLocation('/')}>
          <ChevronLeft className="h-5 w-5" />
        </Button>
        <div>
          <h1 className="text-3xl font-bold tracking-tight flex items-center gap-3">
            {district?.name || <Skeleton className="h-8 w-48" />}
            {district && <Badge variant="secondary" className="font-mono">{district.number}</Badge>}
          </h1>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-8">
        <Card className="bg-primary/5 border-primary/20 shadow-none">
          <CardContent className="p-6">
            <div className="flex items-center gap-4">
              <div className="p-3 bg-primary/10 rounded-full text-primary">
                <AlertTriangle className="h-6 w-6" />
              </div>
              <div>
                <p className="text-sm font-medium text-muted-foreground">{t('district.open_events')}</p>
                <h3 className="text-2xl font-bold text-foreground">
                  {isLoadingSummary ? <Skeleton className="h-8 w-16" /> : summary?.openCount || 0}
                </h3>
              </div>
            </div>
          </CardContent>
        </Card>
        <Card className="shadow-none">
          <CardContent className="p-6">
            <div className="flex items-center gap-4">
              <div className="p-3 bg-muted rounded-full text-muted-foreground">
                <CheckCircle2 className="h-6 w-6" />
              </div>
              <div>
                <p className="text-sm font-medium text-muted-foreground">{t('district.closed_events')}</p>
                <h3 className="text-2xl font-bold text-foreground">
                  {isLoadingSummary ? <Skeleton className="h-8 w-16" /> : summary?.closedCount || 0}
                </h3>
              </div>
            </div>
          </CardContent>
        </Card>
        <Card className="shadow-none">
          <CardContent className="p-6">
            <div className="flex items-center gap-4">
              <div className="p-3 bg-success/10 rounded-full text-success">
                <DollarSign className="h-6 w-6" />
              </div>
              <div>
                <p className="text-sm font-medium text-muted-foreground">{t('district.charged_today')}</p>
                <h3 className="text-2xl font-bold text-foreground">
                  {isLoadingSummary ? <Skeleton className="h-8 w-16" /> : formatCurrency(summary?.chargedToday || 0)}
                </h3>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4 mb-6">
        <h2 className="text-2xl font-bold tracking-tight">{t('district.queue')}</h2>
        
        <div className="flex flex-col sm:flex-row items-center gap-3 w-full md:w-auto">
          <div className="relative w-full sm:w-64">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
            <Input 
              placeholder={t('district.search_events')} 
              value={search}
              onChange={e => setSearch(e.target.value)}
              className="pl-9 bg-background"
            />
          </div>
          
          <Select value={typeFilter} onValueChange={setTypeFilter}>
            <SelectTrigger className="w-full sm:w-48 bg-background">
              <SelectValue placeholder={t('district.event_type')} />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">{t('district.filter_all')} Types</SelectItem>
              {eventTypes.map(et => (
                <SelectItem key={et.id} value={et.id.toString()}>{et.name}</SelectItem>
              ))}
            </SelectContent>
          </Select>

          <Tabs value={statusFilter} onValueChange={(v: any) => setStatusFilter(v)} className="w-full sm:w-auto">
            <TabsList className="grid w-full grid-cols-3 sm:w-auto">
              <TabsTrigger value="all">{t('district.filter_all')}</TabsTrigger>
              <TabsTrigger value="open">{t('district.filter_open')}</TabsTrigger>
              <TabsTrigger value="closed">{t('district.filter_closed')}</TabsTrigger>
            </TabsList>
          </Tabs>
        </div>
      </div>

      <div className="bg-card border rounded-xl overflow-hidden shadow-sm">
        <div className="grid grid-cols-12 gap-4 p-4 border-b bg-muted/40 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
          <div className="col-span-1">Status</div>
          <div className="col-span-3">Customer</div>
          <div className="col-span-2">Type / Source</div>
          <div className="col-span-2">Date Occurred</div>
          <div className="col-span-2">Route / Vehicle</div>
          <div className="col-span-2 text-right">Photo</div>
        </div>

        {isLoadingEvents ? (
          <div className="p-4 space-y-4">
            {[1,2,3,4,5].map(i => <Skeleton key={i} className="h-16 w-full" />)}
          </div>
        ) : events?.length === 0 ? (
          <div className="p-12 text-center text-muted-foreground">
            <CheckCircle2 className="h-12 w-12 mx-auto mb-4 opacity-20" />
            <p className="text-lg">{t('district.no_events')}</p>
          </div>
        ) : (
          <div className="divide-y">
            {events?.map(event => (
              <div 
                key={event.id}
                onClick={() => setLocation(`/districts/${districtId}/events/${event.id}`)}
                className="grid grid-cols-12 gap-4 p-4 items-center hover:bg-muted/30 cursor-pointer transition-colors group"
              >
                <div className="col-span-1">
                  {event.eventStatus === 0 ? (
                    <Badge variant="default" className="bg-primary/10 text-primary hover:bg-primary/20 border-0">{t('event.status_open')}</Badge>
                  ) : (
                    <Badge variant="outline" className="text-muted-foreground border-muted-foreground/30">{t('event.status_closed')}</Badge>
                  )}
                </div>
                <div className="col-span-3">
                  <div className="font-medium group-hover:text-primary transition-colors line-clamp-1">{event.customerName}</div>
                  <div className="text-sm text-muted-foreground font-mono">{event.accountNumber}</div>
                </div>
                <div className="col-span-2">
                  <div className="font-medium text-sm line-clamp-1">{event.eventTypeName}</div>
                  <div className="text-xs text-muted-foreground">{event.eventSourceName}</div>
                </div>
                <div className="col-span-2">
                  <div className="text-sm flex items-center gap-1.5 text-muted-foreground">
                    <Clock className="h-3.5 w-3.5" />
                    {formatDate(event.dateOccurred)}
                  </div>
                </div>
                <div className="col-span-2 text-sm">
                  <div className="font-mono text-xs">{event.route}</div>
                  <div className="text-muted-foreground font-mono text-xs">{event.vehicle}</div>
                </div>
                <div className="col-span-2 flex justify-end">
                  {event.imageUrl ? (
                    <div className="h-10 w-16 rounded overflow-hidden border bg-muted/50 flex items-center justify-center">
                      <Camera className="h-4 w-4 text-muted-foreground" />
                    </div>
                  ) : (
                    <span className="text-xs text-muted-foreground italic">{t('event.no_photo')}</span>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
