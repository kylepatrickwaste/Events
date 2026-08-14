import React, { useState, useMemo, useEffect, useRef } from 'react';
import { useRoute, useLocation, Link } from 'wouter';
import {
  useGetDistrictSummary, getGetDistrictSummaryQueryKey,
  useListEvents, getListEventsQueryKey,
  useListDistricts, getListDistrictsQueryKey,
  useListDistrictServiceCodes, getListDistrictServiceCodesQueryKey,
  useGetEvent, getGetEventQueryKey,
} from '@workspace/api-client-react';
import { useQueryClient } from '@tanstack/react-query';
import { useI18n } from '@/i18n';
import { Card, CardContent } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Skeleton } from '@/components/ui/skeleton';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover';
import { Command, CommandEmpty, CommandGroup, CommandInput, CommandItem, CommandList } from '@/components/ui/command';
import { Checkbox } from '@/components/ui/checkbox';
import { Search, Clock, CheckCircle2, DollarSign, AlertTriangle, ChevronsUpDown, Check, XCircle, Camera, FileX2, ArrowUp, ArrowDown, ArrowUpDown, Images, X } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { useToast } from '@/hooks/use-toast';
import { cn } from '@/lib/utils';
import { ChargeEventDialog, CloseEventDialog, BulkCloseDialog } from '@/components/event-action-dialogs';
import { ContractAccountsDialog } from '@/components/contract-accounts-dialog';
import { LAST_DISTRICT_KEY } from '@/pages/home';

type SortColumn = 'status' | 'customer' | 'type' | 'severity' | 'date' | 'route';

// Higher rank = more severe; unknown/missing severities sort last
const SEVERITY_RANK: Record<string, number> = { severe: 2, minimal: 1 };
const severityRank = (s: string | null | undefined) =>
  s ? (SEVERITY_RANK[s.toLowerCase()] ?? 0) : 0;

function SortHeader({ label, column, sortColumn, sortDirection, onSort }: {
  label: string;
  column: SortColumn;
  sortColumn: SortColumn | null;
  sortDirection: 'asc' | 'desc';
  onSort: (column: SortColumn) => void;
}) {
  const active = sortColumn === column;
  return (
    <button
      type="button"
      onClick={() => onSort(column)}
      aria-label={`Sort by ${label}${active ? (sortDirection === 'asc' ? ', descending' : ', ascending') : ''}`}
      aria-sort={active ? (sortDirection === 'asc' ? 'ascending' : 'descending') : undefined}
      className={cn(
        'flex items-center gap-1 uppercase tracking-wider text-xs font-semibold transition-colors hover:text-foreground',
        active ? 'text-foreground' : 'text-muted-foreground'
      )}
    >
      {label}
      {active ? (
        sortDirection === 'asc'
          ? <ArrowUp className="h-3 w-3 shrink-0" />
          : <ArrowDown className="h-3 w-3 shrink-0" />
      ) : (
        <ArrowUpDown className="h-3 w-3 shrink-0 opacity-40" />
      )}
    </button>
  );
}

export default function DistrictWorkspace() {
  const [, params] = useRoute('/districts/:districtId');
  const districtId = Number(params?.districtId);
  const { t, formatCurrency, formatDate } = useI18n();
  const [, setLocation] = useLocation();
  const queryClient = useQueryClient();
  const { toast } = useToast();

  const [statusFilter, setStatusFilter] = useState<'open' | 'closed' | 'all'>('all');
  const [search, setSearch] = useState('');
  const [typeFilter, setTypeFilter] = useState<string>('all');
  const [severityFilter, setSeverityFilter] = useState<'all' | 'severe' | 'minimal'>('all');
  const [switcherOpen, setSwitcherOpen] = useState(false);
  const [selectedIds, setSelectedIds] = useState<Set<number>>(new Set());
  const [bulkCloseOpen, setBulkCloseOpen] = useState(false);
  const [chargeEventId, setChargeEventId] = useState<number | null>(null);
  const [closeEventId, setCloseEventId] = useState<number | null>(null);
  const [closeNearbyPreset, setCloseNearbyPreset] = useState<number[]>([]);
  const [contractAccountsOpen, setContractAccountsOpen] = useState(false);
  const [sortColumn, setSortColumn] = useState<SortColumn | null>(null);
  const [sortDirection, setSortDirection] = useState<'asc' | 'desc'>('asc');

  const toggleSort = (column: SortColumn) => {
    if (sortColumn === column) {
      setSortDirection(d => (d === 'asc' ? 'desc' : 'asc'));
    } else {
      setSortColumn(column);
      setSortDirection('asc');
    }
  };

  // Remember this district as the last one visited
  useEffect(() => {
    if (districtId) localStorage.setItem(LAST_DISTRICT_KEY, String(districtId));
  }, [districtId]);

  // Reset selection when district or filters change
  useEffect(() => {
    setSelectedIds(new Set());
  }, [districtId, statusFilter, typeFilter, severityFilter, search]);

  const { data: districts } = useListDistricts({ query: { queryKey: getListDistrictsQueryKey() }});
  const district = districts?.find(d => d.id === districtId);

  const { data: summary, isLoading: isLoadingSummary } = useGetDistrictSummary(districtId, {
    query: { enabled: !!districtId, queryKey: getGetDistrictSummaryQueryKey(districtId) }
  });

  const eventsQueryParams = {
    districtId,
    status: statusFilter === 'all' ? undefined : statusFilter,
    search: search || undefined,
    eventTypeId: typeFilter === 'all' ? undefined : Number(typeFilter),
    severity: severityFilter === 'all' ? undefined : severityFilter,
  };
  const { data: events, isLoading: isLoadingEvents } = useListEvents(
    eventsQueryParams,
    { query: { enabled: !!districtId, queryKey: getListEventsQueryKey(eventsQueryParams) } }
  );

  const { data: serviceCodes } = useListDistrictServiceCodes(districtId, {
    query: { enabled: !!districtId, queryKey: getListDistrictServiceCodesQueryKey(districtId) }
  });

  const eventTypes = useMemo(() => {
    if (!summary) return [];
    return summary.byEventType.map(et => ({ id: et.eventTypeId, name: et.eventTypeName }));
  }, [summary]);

  const sortedEvents = useMemo(() => {
    if (!events) return events;
    if (!sortColumn) return events;
    const dir = sortDirection === 'asc' ? 1 : -1;
    const cmp = (a: (typeof events)[number], b: (typeof events)[number]): number => {
      switch (sortColumn) {
        case 'status':
          return a.eventStatus - b.eventStatus;
        case 'customer':
          return (a.customerName ?? '').localeCompare(b.customerName ?? '');
        case 'type': {
          const byType = (a.eventTypeName ?? '').localeCompare(b.eventTypeName ?? '');
          return byType !== 0 ? byType : (a.eventSourceName ?? '').localeCompare(b.eventSourceName ?? '');
        }
        case 'severity':
          // Ascending = most severe first (Severe before Minimal)
          return severityRank(b.severity) - severityRank(a.severity);
        case 'date':
          return new Date(a.dateOccurred).getTime() - new Date(b.dateOccurred).getTime();
        case 'route': {
          const byRoute = (a.route ?? '').localeCompare(b.route ?? '', undefined, { numeric: true });
          return byRoute !== 0 ? byRoute : (a.vehicle ?? '').localeCompare(b.vehicle ?? '', undefined, { numeric: true });
        }
      }
    };
    return [...events].sort((a, b) => dir * cmp(a, b));
  }, [events, sortColumn, sortDirection]);

  const openEvents = useMemo(() => (events ?? []).filter(e => e.eventStatus === 0), [events]);
  const allOpenSelected = openEvents.length > 0 && openEvents.every(e => selectedIds.has(e.id));
  const someSelected = selectedIds.size > 0;

  const toggleAll = (checked: boolean) => {
    setSelectedIds(checked ? new Set(openEvents.map(e => e.id)) : new Set());
  };

  const toggleOne = (id: number, checked: boolean) => {
    setSelectedIds(prev => {
      const next = new Set(prev);
      if (checked) next.add(id); else next.delete(id);
      return next;
    });
  };

  const refreshQueue = () => {
    queryClient.invalidateQueries({ queryKey: getListEventsQueryKey(eventsQueryParams) });
    queryClient.invalidateQueries({ queryKey: getGetDistrictSummaryQueryKey(districtId) });
  };

  const handleBulkCloseSuccess = (closedCount: number) => {
    setBulkCloseOpen(false);
    setSelectedIds(new Set());
    refreshQueue();
    toast({ description: t('bulk_close.success', { count: closedCount }) });
  };

  const handleActionSuccess = () => {
    setChargeEventId(null);
    setCloseEventId(null);
    setCloseNearbyPreset([]);
    refreshQueue();
  };

  return (
    <div className="container mx-auto py-6 px-4 max-w-7xl">
      <div className="flex items-center justify-end mb-4">
        {/* Searchable district switcher */}
        <Popover open={switcherOpen} onOpenChange={setSwitcherOpen}>
          <PopoverTrigger asChild>
            <Button variant="outline" role="combobox" aria-expanded={switcherOpen} className="w-full md:w-[300px] justify-between">
              <span className="truncate">
                {district ? `${district.number} – ${district.name}` : t('district.switch_district')}
              </span>
              <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50" />
            </Button>
          </PopoverTrigger>
          <PopoverContent className="w-[300px] p-0" align="end">
            <Command>
              <CommandInput placeholder={t('district.search_district')} />
              <CommandList>
                <CommandEmpty>{t('district.no_district_found')}</CommandEmpty>
                <CommandGroup>
                  {(districts ?? []).map(d => (
                    <CommandItem
                      key={d.id}
                      value={`${d.number} ${d.name}`}
                      onSelect={() => {
                        setSwitcherOpen(false);
                        if (d.id !== districtId) setLocation(`/districts/${d.id}`);
                      }}
                    >
                      <Check className={cn('mr-2 h-4 w-4', d.id === districtId ? 'opacity-100' : 'opacity-0')} />
                      <span className="font-mono mr-2">{d.number}</span> – {d.name}
                    </CommandItem>
                  ))}
                </CommandGroup>
              </CommandList>
            </Command>
          </PopoverContent>
        </Popover>
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
        <div className="flex items-center gap-3">
          <h2 className="text-2xl font-bold tracking-tight">{t('district.queue')}</h2>
          {someSelected && (
            <Button variant="destructive" size="sm" onClick={() => setBulkCloseOpen(true)}>
              <XCircle className="h-4 w-4 mr-2" />
              {t('district.close_selected')} ({selectedIds.size})
            </Button>
          )}
        </div>

        <div className="flex flex-col sm:flex-row items-center gap-3 w-full md:w-auto">
          <Button variant="outline" className="w-full sm:w-auto" onClick={() => setContractAccountsOpen(true)}>
            <FileX2 className="h-4 w-4 mr-2" />
            {t('contract_accounts.button')}
          </Button>
          <div className="relative w-full sm:w-64">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
            <Input
              placeholder={t('district.search_events')}
              value={search}
              onChange={e => setSearch(e.target.value)}
              className="pl-9 bg-background"
            />
          </div>

          <Select value={severityFilter} onValueChange={(v) => setSeverityFilter(v as 'all' | 'severe' | 'minimal')}>
            <SelectTrigger className="w-full sm:w-40 bg-background">
              <SelectValue placeholder="Severity" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">{t('district.filter_all')} Severities</SelectItem>
              <SelectItem value="severe">Severe</SelectItem>
              <SelectItem value="minimal">Minimal</SelectItem>
            </SelectContent>
          </Select>

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
        <div className="grid grid-cols-12 gap-4 p-4 border-b bg-muted/40 text-xs font-semibold uppercase tracking-wider text-muted-foreground items-center">
          <div className="col-span-1 flex items-center gap-3">
            <Checkbox
              checked={allOpenSelected}
              onCheckedChange={(c) => toggleAll(c === true)}
              disabled={openEvents.length === 0}
              aria-label={t('district.select_all')}
            />
            <SortHeader label="Status" column="status" sortColumn={sortColumn} sortDirection={sortDirection} onSort={toggleSort} />
          </div>
          <div className="col-span-3">
            <SortHeader label="Customer" column="customer" sortColumn={sortColumn} sortDirection={sortDirection} onSort={toggleSort} />
          </div>
          <div className="col-span-2">
            <SortHeader label="Type / Source" column="type" sortColumn={sortColumn} sortDirection={sortDirection} onSort={toggleSort} />
          </div>
          <div className="col-span-1">
            <SortHeader label="Severity" column="severity" sortColumn={sortColumn} sortDirection={sortDirection} onSort={toggleSort} />
          </div>
          <div className="col-span-2">
            <SortHeader label="Date Occurred" column="date" sortColumn={sortColumn} sortDirection={sortDirection} onSort={toggleSort} />
          </div>
          <div className="col-span-1">
            <SortHeader label="Route / Vehicle" column="route" sortColumn={sortColumn} sortDirection={sortDirection} onSort={toggleSort} />
          </div>
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
            {sortedEvents?.map(event => (
              <div
                key={event.id}
                onClick={() => setLocation(`/districts/${districtId}/events/${event.id}`)}
                className="grid grid-cols-12 gap-4 p-4 items-center hover:bg-muted/30 cursor-pointer transition-colors group"
              >
                <div className="col-span-1 flex items-center gap-3" onClick={e => e.stopPropagation()}>
                  {event.eventStatus === 0 ? (
                    <>
                      <Checkbox
                        checked={selectedIds.has(event.id)}
                        onCheckedChange={(c) => toggleOne(event.id, c === true)}
                        aria-label={`Select ${event.customerName}`}
                      />
                      <Badge variant="default" className="bg-primary/10 text-primary hover:bg-primary/20 border-0">{t('event.status_open')}</Badge>
                    </>
                  ) : (
                    <>
                      <span className="w-4" />
                      <Badge variant="outline" className="text-muted-foreground border-muted-foreground/30">{t('event.status_closed')}</Badge>
                    </>
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
                <div className="col-span-1">
                  {event.severity ? (
                    <Badge
                      variant="outline"
                      className={cn(
                        'border-0',
                        event.severity.toLowerCase() === 'severe'
                          ? 'bg-destructive/10 text-destructive'
                          : 'bg-muted text-muted-foreground'
                      )}
                    >
                      {event.severity}
                    </Badge>
                  ) : (
                    <span className="text-xs text-muted-foreground">—</span>
                  )}
                </div>
                <div className="col-span-2">
                  <div className="text-sm flex items-center gap-1.5 text-muted-foreground">
                    <Clock className="h-3.5 w-3.5" />
                    {formatDate(event.dateOccurred)}
                  </div>
                </div>
                <div className="col-span-1 text-sm">
                  <div className="font-mono text-xs">{event.route}</div>
                  <div className="text-muted-foreground font-mono text-xs">{event.vehicle}</div>
                </div>
                <div className="col-span-2 flex items-center justify-end gap-2" onClick={e => e.stopPropagation()}>
                  {event.eventStatus === 0 && (
                    <Button
                      size="sm"
                      variant="destructive"
                      className="h-7 px-2"
                      onClick={() => setCloseEventId(event.id)}
                    >
                      <XCircle className="h-3.5 w-3.5 mr-1" />
                      {t('preview.close')}
                    </Button>
                  )}
                  {(event.imageUrls?.length ?? 0) > 0 && (
                    <span className="flex items-center gap-1 text-xs text-muted-foreground">
                      <Camera className="h-3.5 w-3.5" />
                      {event.imageUrls.length}
                    </span>
                  )}
                  {event.imageUrl ? (
                    <EventThumbnailPreview
                      event={event}
                      districtId={districtId}
                      onCharge={() => setChargeEventId(event.id)}
                      onClose={() => { setCloseNearbyPreset([]); setCloseEventId(event.id); }}
                      onCloseWithDuplicates={(ids) => { setCloseNearbyPreset(ids); setCloseEventId(event.id); }}
                      onNavigate={() => setLocation(`/districts/${districtId}/events/${event.id}`)}
                    />
                  ) : (
                    <span className="text-xs text-muted-foreground italic">{t('event.no_photo')}</span>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      <ContractAccountsDialog
        open={contractAccountsOpen}
        onOpenChange={setContractAccountsOpen}
        districtId={districtId}
        onUnflagged={refreshQueue}
      />
      <BulkCloseDialog
        open={bulkCloseOpen}
        onOpenChange={setBulkCloseOpen}
        eventIds={Array.from(selectedIds)}
        onSuccess={handleBulkCloseSuccess}
      />
      {chargeEventId !== null && serviceCodes && (
        <ChargeEventDialog
          open={chargeEventId !== null}
          onOpenChange={(o) => { if (!o) setChargeEventId(null); }}
          eventId={chargeEventId}
          serviceCodes={serviceCodes}
          onSuccess={handleActionSuccess}
        />
      )}
      {closeEventId !== null && (
        <CloseEventDialog
          open={closeEventId !== null}
          onOpenChange={(o) => { if (!o) { setCloseEventId(null); setCloseNearbyPreset([]); } }}
          eventId={closeEventId}
          initialCheckedNearby={closeNearbyPreset}
          onSuccess={handleActionSuccess}
        />
      )}
    </div>
  );
}

function EventThumbnailPreview({ event, districtId, onCharge, onClose, onCloseWithDuplicates, onNavigate }: {
  event: any;
  districtId: number;
  onCharge: () => void;
  onClose: () => void;
  onCloseWithDuplicates: (ids: number[]) => void;
  onNavigate: () => void;
}) {
  const { t, formatDate } = useI18n();
  const [selectedImage, setSelectedImage] = useState<string>(event.imageUrl);
  const [open, setOpen] = useState(false);
  const [checkedNearby, setCheckedNearby] = useState<Set<number>>(new Set());

  const toggleNearby = (id: number, checked: boolean) => {
    setCheckedNearby(prev => {
      const next = new Set(prev);
      if (checked) next.add(id); else next.delete(id);
      return next;
    });
  };

  // Clear the checkbox selection whenever the preview closes
  useEffect(() => {
    if (!open) setCheckedNearby(new Set());
  }, [open]);
  const openTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const closeTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  const clearTimers = () => {
    if (openTimer.current) { clearTimeout(openTimer.current); openTimer.current = null; }
    if (closeTimer.current) { clearTimeout(closeTimer.current); closeTimer.current = null; }
  };

  const scheduleOpen = () => {
    clearTimers();
    openTimer.current = setTimeout(() => setOpen(true), 150);
  };

  const scheduleClose = () => {
    clearTimers();
    closeTimer.current = setTimeout(() => setOpen(false), 200);
  };

  // Leaving the thumbnail: if the popup is already open, keep it open (the
  // popup's own mouse-leave / Escape / backdrop / X handle dismissal). If the
  // popup hasn't opened yet, just cancel the pending open so quick pass-over
  // hovers don't trigger it.
  const handleThumbnailLeave = () => {
    if (openTimer.current) { clearTimeout(openTimer.current); openTimer.current = null; }
  };

  const cancelClose = () => {
    if (closeTimer.current) { clearTimeout(closeTimer.current); closeTimer.current = null; }
  };

  useEffect(() => () => clearTimers(), []);

  // Close on Escape while open
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') setOpen(false); };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open]);

  // Load the full event detail (includes nearby events) once the preview opens
  const { data: detail, isLoading: isLoadingDetail } = useGetEvent(event.id, {
    query: { enabled: open, queryKey: getGetEventQueryKey(event.id) }
  });
  const nearbyEvents = detail?.nearbyEvents;

  // Forward-compatible with a multi-image data model (Task on detail page):
  // if the API exposes an image list use it, otherwise fall back to the single image.
  const images: string[] = Array.isArray(event.imageUrls) && event.imageUrls.length > 0
    ? event.imageUrls
    : [event.imageUrl];
  const isOpen = event.eventStatus === 0;

  const formatOffset = (seconds: number) => {
    const abs = Math.abs(seconds);
    const dir = seconds < 0 ? 'before' : 'after';
    if (abs < 60) return t(`event.nearby.offset_sec_${dir}` as any, { s: abs });
    return t(`event.nearby.offset_min_${dir}` as any, { m: Math.floor(abs / 60) });
  };

  return (
    <>
      <div
        onClick={onNavigate}
        onMouseEnter={scheduleOpen}
        onMouseLeave={handleThumbnailLeave}
        className="h-10 w-16 rounded overflow-hidden border bg-muted/50 cursor-pointer"
      >
        <img
          src={event.imageUrl}
          alt={`${event.customerName} photo`}
          loading="lazy"
          className="h-full w-full object-cover"
          onError={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }}
        />
      </div>
      {open && (
        <>
          {/* Dim backdrop; click closes the preview */}
          <div
            className="fixed inset-0 z-50 bg-black/40 animate-in fade-in-0"
            onClick={() => setOpen(false)}
          />
          <div
            role="dialog"
            aria-label={`${event.customerName} photo preview`}
            onMouseEnter={cancelClose}
            onMouseLeave={scheduleClose}
            onClick={e => e.stopPropagation()}
            className="fixed left-1/2 top-1/2 z-50 w-[min(56rem,calc(100vw-2rem))] max-h-[90vh] -translate-x-1/2 -translate-y-1/2 overflow-y-auto rounded-lg border bg-background p-4 shadow-lg space-y-3 animate-in fade-in-0 zoom-in-95"
          >
            <button
              type="button"
              onClick={() => setOpen(false)}
              className="absolute right-3 top-3 z-10 rounded-sm bg-background/80 p-1 opacity-70 transition-opacity hover:opacity-100"
              aria-label="Close preview"
            >
              <X className="h-4 w-4" />
            </button>
            <div className="bg-muted rounded-lg overflow-hidden aspect-video flex items-center justify-center">
              <img
                src={selectedImage}
                alt="Event preview"
                className="object-contain w-full h-full"
                onError={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }}
              />
            </div>
            {images.length > 1 && (
              <div className="flex gap-2 overflow-x-auto">
                {images.map((url, i) => (
                  <button
                    key={i}
                    onMouseEnter={() => setSelectedImage(url)}
                    onClick={() => setSelectedImage(url)}
                    className={cn(
                      'h-12 w-16 shrink-0 rounded overflow-hidden border-2 transition-colors',
                      selectedImage === url ? 'border-primary' : 'border-transparent hover:border-muted-foreground/40'
                    )}
                  >
                    <img src={url} alt={`Thumbnail ${i + 1}`} className="h-full w-full object-cover" />
                  </button>
                ))}
              </div>
            )}
            {isOpen && (
              <div className="flex gap-2">
                <Button size="sm" className="flex-1 bg-success text-success-foreground hover:bg-success/90" onClick={onCharge}>
                  <DollarSign className="h-4 w-4 mr-1" />
                  {t('preview.charge')}
                </Button>
                <Button size="sm" variant="destructive" className="flex-1" onClick={onClose}>
                  <XCircle className="h-4 w-4 mr-1" />
                  {t('preview.close')}
                </Button>
              </div>
            )}
            {/* Nearby events cluster */}
            <div className="pt-1">
              <h4 className="text-sm font-semibold mb-2">{t('event.nearby.title')}</h4>
              {isLoadingDetail ? (
                <div className="space-y-2">
                  <Skeleton className="h-8 w-full" />
                  <Skeleton className="h-8 w-full" />
                </div>
              ) : !nearbyEvents || nearbyEvents.length === 0 ? (
                <p className="text-sm text-muted-foreground italic">{t('event.nearby.empty')}</p>
              ) : (
                <div className="border rounded-md overflow-x-auto">
                  <table className="w-full text-sm">
                    <thead className="bg-muted/50 border-b">
                      <tr>
                        <th className="px-3 py-2 w-8"></th>
                        <th className="px-2 py-2 w-12"></th>
                        <th className="px-3 py-2 text-left font-medium">{t('event.nearby.business')}</th>
                        <th className="px-3 py-2 text-left font-medium">{t('event.nearby.account')}</th>
                        <th className="px-3 py-2 text-left font-medium">{t('event.nearby.bin_serial')}</th>
                        <th className="px-3 py-2 text-left font-medium">{t('district.date')}</th>
                        <th className="px-3 py-2 text-right font-medium">{t('district.status')}</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y">
                      {nearbyEvents.map((nearby: any) => {
                        const accountMismatch = !!nearby.accountNumber && nearby.accountNumber !== event.accountNumber;
                        return (
                          <tr
                            key={nearby.id}
                            className={`transition-colors ${accountMismatch ? 'bg-destructive/10 hover:bg-destructive/15 text-destructive' : 'hover:bg-muted/30'}`}
                          >
                            <td className="px-3 py-2">
                              {nearby.status === 'Open' ? (
                                <Checkbox
                                  checked={checkedNearby.has(nearby.id)}
                                  onCheckedChange={(c) => toggleNearby(nearby.id, c === true)}
                                  aria-label={`Select nearby event ${nearby.id}`}
                                />
                              ) : (
                                <span className="block w-4" />
                              )}
                            </td>
                            <td className="px-2 py-2">
                              <Link href={`/districts/${districtId}/events/${nearby.id}`}>
                                {nearby.imageUrl ? (
                                  <img src={nearby.imageUrl} className="w-8 h-8 object-cover rounded shadow-sm cursor-pointer" alt="Thumbnail" />
                                ) : (
                                  <div className="w-8 h-8 rounded bg-muted flex items-center justify-center cursor-pointer">
                                    <Images className="w-3 h-3 text-muted-foreground" />
                                  </div>
                                )}
                              </Link>
                            </td>
                            <td className="px-3 py-2">{nearby.customerName ?? '—'}</td>
                            <td className={`px-3 py-2 font-mono text-xs ${accountMismatch ? 'font-bold' : ''}`}>
                              {nearby.accountNumber ?? '—'}
                            </td>
                            <td className="px-3 py-2 font-mono text-xs">{nearby.binSerialNumber ?? '—'}</td>
                            <td className="px-3 py-2 whitespace-nowrap">
                              <Link href={`/districts/${districtId}/events/${nearby.id}`} className={`hover:underline ${accountMismatch ? 'text-destructive' : 'text-primary'}`}>
                                {formatDate(nearby.dateOccurred, { hour: 'numeric', minute: '2-digit' })}
                              </Link>
                              <span className={`ml-2 font-mono text-xs ${accountMismatch ? 'text-destructive/80' : 'text-muted-foreground'}`}>
                                {formatOffset(nearby.secondsOffset)}
                              </span>
                            </td>
                            <td className="px-3 py-2 text-right">
                              <Badge variant="outline" className="text-[10px]">
                                {t(`event.nearby.status_${nearby.status.toLowerCase()}` as any)}
                              </Badge>
                            </td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>
              )}
              {checkedNearby.size > 0 && (
                <Button
                  size="sm"
                  variant="destructive"
                  className="mt-2 w-full"
                  onClick={() => onCloseWithDuplicates(Array.from(checkedNearby))}
                >
                  <XCircle className="h-4 w-4 mr-1" />
                  {t('close.close_duplicates', { count: checkedNearby.size })}
                </Button>
              )}
            </div>
          </div>
        </>
      )}
    </>
  );
}
