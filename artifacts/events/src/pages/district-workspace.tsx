import React, { useState, useMemo, useEffect, useRef } from 'react';
import { createPortal } from 'react-dom';
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
import { Search, Clock, Columns3, ChevronLeft, ChevronRight, CheckCircle2, DollarSign, AlertTriangle, ChevronsUpDown, Check, XCircle, Camera, FileX2, ArrowUp, ArrowDown, ArrowUpDown, Images, X, DoorOpen, Plus, Minus, GripVertical, Layers } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { useToast } from '@/hooks/use-toast';
import { cn } from '@/lib/utils';
import { ChargeEventDialog, CloseEventDialog, BulkCloseDialog } from '@/components/event-action-dialogs';
import { OPEN_EXCLUDED_ACCOUNTS_EVENT } from '@/components/layout/Shell';
import { DropdownMenu, DropdownMenuCheckboxItem, DropdownMenuContent, DropdownMenuTrigger } from '@/components/ui/dropdown-menu';
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';

const OPTIONAL_COLUMNS: Array<{ key: SortColumn; label: string }> = [
  { key: 'qty', label: 'Qty' },
  { key: 'binSerial', label: 'Serial#' },
  { key: 'stop', label: 'Stop' },
  { key: 'wo', label: 'WO#' },
  { key: 'address', label: 'Address' },
  { key: 'lob', label: 'LOB' },
  { key: 'tabletNotes', label: 'Tablet Notes' },
  { key: 'chgAmt', label: 'Chg. Amt' },
  { key: 'prevChg', label: 'Prev. Chg' },
  { key: 'prevTotal', label: 'Prev. Total' },
];

const BASE_COLUMNS: Array<{ key: SortColumn; label: string }> = [
  { key: 'status', label: 'Status' },
  { key: 'customer', label: 'Customer' },
  { key: 'type', label: 'Type / Source' },
  { key: 'severity', label: 'Severity' },
  { key: 'date', label: 'Date Occurred' },
  { key: 'route', label: 'Vehicle' },
];
const ALL_COLUMNS = [...BASE_COLUMNS, ...OPTIONAL_COLUMNS];
const DEFAULT_COL_ORDER: SortColumn[] = ALL_COLUMNS.map(c => c.key);
const BASE_KEYS = new Set<string>(BASE_COLUMNS.map(c => c.key));
const VIEWS_KEY = 'grid-views';

type ViewConfig = {
  visibleCols: string[];
  colOrder: string[];
  groupBy: string | null;
  sortColumn: string | null;
  sortDirection: 'asc' | 'desc';
  pageSize: number;
};

const normalizeOrder = (saved: string[]): SortColumn[] => {
  const valid = [...new Set(saved)].filter((k): k is SortColumn => (DEFAULT_COL_ORDER as string[]).includes(k));
  const missing = DEFAULT_COL_ORDER.filter(k => !valid.includes(k));
  return [...valid, ...missing];
};

const sanitizeConfig = (cfg: unknown): ViewConfig | null => {
  if (!cfg || typeof cfg !== 'object' || Array.isArray(cfg)) return null;
  const c = cfg as Record<string, unknown>;
  if (!Array.isArray(c.visibleCols) || !Array.isArray(c.colOrder)) return null;
  return {
    visibleCols: c.visibleCols.filter((k): k is string => typeof k === 'string'),
    colOrder: c.colOrder.filter((k): k is string => typeof k === 'string'),
    groupBy: typeof c.groupBy === 'string' ? c.groupBy : null,
    sortColumn: typeof c.sortColumn === 'string' ? c.sortColumn : null,
    sortDirection: c.sortDirection === 'desc' ? 'desc' : 'asc',
    pageSize: typeof c.pageSize === 'number' && [10, 25, 50, 100].includes(c.pageSize) ? c.pageSize : 10,
  };
};

const loadViews = (): Record<string, ViewConfig> => {
  try {
    const raw: unknown = JSON.parse(localStorage.getItem(VIEWS_KEY) || '{}');
    if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return {};
    const out: Record<string, ViewConfig> = {};
    for (const [name, cfg] of Object.entries(raw)) {
      const c = sanitizeConfig(cfg);
      if (c) out[name] = c;
    }
    return out;
  } catch { return {}; }
};

// Load saved views once and, if a view was active last session, use its
// config as the initial grid state so the dropdown and the grid agree.
const loadInitialGridState = () => {
  const views = loadViews();
  let currentView = '';
  try { currentView = localStorage.getItem('grid-current-view') || ''; } catch {}
  if (!views[currentView]) currentView = '';
  return { views, currentView, cfg: currentView ? views[currentView] : null };
};
import { ContractAccountsDialog } from '@/components/contract-accounts-dialog';
import { LAST_DISTRICT_KEY } from '@/pages/home';
import { NearbyClusterPicker, suggestedDuplicateIds } from '@/components/nearby-cluster-picker';

type SortColumn = 'status' | 'customer' | 'type' | 'severity' | 'date' | 'route' | 'qty' | 'binSerial' | 'stop' | 'wo' | 'address' | 'lob' | 'tabletNotes' | 'chgAmt' | 'prevChg' | 'prevTotal';

// Higher rank = more severe; unknown/missing severities sort last
const SEVERITY_RANK: Record<string, number> = { severe: 2, minimal: 1 };
const sourceColor = (name: string | null | undefined) => {
  const n = (name ?? '').toLowerCase().replace(/\s/g, '');
  if (n.includes('3rdeye')) return 'text-red-600 dark:text-red-400';
  if (n.includes('wastevision')) return 'text-blue-600 dark:text-blue-400';
  if (n.includes('samsara')) return 'text-green-600 dark:text-green-400';
  return 'text-muted-foreground';
};

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

  const initialGrid = useRef(loadInitialGridState()).current;
  const [statusFilter, setStatusFilter] = useState<'open' | 'closed' | 'all'>('open');
  const [search, setSearch] = useState('');
  const [typeFilter, setTypeFilter] = useState<string>('all');
  const [severityFilter, setSeverityFilter] = useState<'all' | 'severe' | 'minimal'>('all');
  const [switcherOpen, setSwitcherOpen] = useState(false);
  const [selectedIds, setSelectedIds] = useState<Set<number>>(new Set());
  const [bulkCloseOpen, setBulkCloseOpen] = useState(false);
  const [chargeEventId, setChargeEventId] = useState<number | null>(null);
  const [chargeNearbyPreset, setChargeNearbyPreset] = useState<number[]>([]);
  const [closeEventId, setCloseEventId] = useState<number | null>(null);
  const [closeNearbyPreset, setCloseNearbyPreset] = useState<number[]>([]);
  const [contractAccountsOpen, setContractAccountsOpen] = useState(false);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(() => initialGrid.cfg?.pageSize ?? 10);
  const [visibleCols, setVisibleCols] = useState<Set<string>>(() => {
    if (initialGrid.cfg) return new Set(initialGrid.cfg.visibleCols);
    try {
      const raw = localStorage.getItem('grid-columns');
      return raw ? new Set(JSON.parse(raw) as string[]) : new Set(OPTIONAL_COLUMNS.map(c => c.key));
    } catch { return new Set(OPTIONAL_COLUMNS.map(c => c.key)); }
  });
  const toggleCol = (key: string) => {
    setVisibleCols(prev => {
      const next = new Set(prev);
      if (next.has(key)) next.delete(key); else next.add(key);
      try { localStorage.setItem('grid-columns', JSON.stringify([...next])); } catch {}
      return next;
    });
  };

  const [colOrder, setColOrder] = useState<SortColumn[]>(() => {
    if (initialGrid.cfg) return normalizeOrder(initialGrid.cfg.colOrder);
    try {
      const raw = localStorage.getItem('grid-col-order');
      if (raw) return normalizeOrder(JSON.parse(raw) as string[]);
    } catch {}
    return DEFAULT_COL_ORDER;
  });
  const setColOrderPersist = (next: SortColumn[]) => {
    setColOrder(next);
    try { localStorage.setItem('grid-col-order', JSON.stringify(next)); } catch {}
  };
  const [groupBy, setGroupBy] = useState<SortColumn | null>(() => {
    const fromView = initialGrid.cfg?.groupBy;
    if (initialGrid.cfg) return fromView && (DEFAULT_COL_ORDER as string[]).includes(fromView) ? (fromView as SortColumn) : null;
    try {
      const raw = localStorage.getItem('grid-group-by');
      return raw && (DEFAULT_COL_ORDER as string[]).includes(raw) ? (raw as SortColumn) : null;
    } catch { return null; }
  });
  const setGroupByPersist = (next: SortColumn | null) => {
    setGroupBy(next);
    setPage(1);
    try {
      if (next) localStorage.setItem('grid-group-by', next);
      else localStorage.removeItem('grid-group-by');
    } catch {}
  };
  const [dragCol, setDragCol] = useState<SortColumn | null>(null);
  const [dropTarget, setDropTarget] = useState<SortColumn | 'groupzone' | null>(null);

  const moveColumn = (from: SortColumn, to: SortColumn) => {
    if (from === to) return;
    const next = colOrder.filter(k => k !== from);
    next.splice(next.indexOf(to), 0, from);
    setColOrderPersist(next);
  };

  // Saved views
  const [views, setViews] = useState<Record<string, ViewConfig>>(initialGrid.views);
  const [currentView, setCurrentView] = useState<string>(initialGrid.currentView);
  const [saveViewOpen, setSaveViewOpen] = useState(false);
  const [newViewName, setNewViewName] = useState('');

  const applyView = (name: string) => {
    const cfg = views[name];
    if (!cfg) return;
    setCurrentView(name);
    try { localStorage.setItem('grid-current-view', name); } catch {}
    const vis = new Set(cfg.visibleCols);
    setVisibleCols(vis);
    try { localStorage.setItem('grid-columns', JSON.stringify([...vis])); } catch {}
    setColOrderPersist(normalizeOrder(cfg.colOrder));
    setGroupByPersist(cfg.groupBy && (DEFAULT_COL_ORDER as string[]).includes(cfg.groupBy) ? (cfg.groupBy as SortColumn) : null);
    setSortColumn(cfg.sortColumn && (DEFAULT_COL_ORDER as string[]).includes(cfg.sortColumn) ? (cfg.sortColumn as SortColumn) : null);
    setSortDirection(cfg.sortDirection === 'desc' ? 'desc' : 'asc');
    if ([10, 25, 50, 100].includes(cfg.pageSize)) setPageSize(cfg.pageSize);
    setPage(1);
  };

  const saveView = () => {
    const name = newViewName.trim();
    if (!name) return;
    const cfg: ViewConfig = {
      visibleCols: [...visibleCols],
      colOrder,
      groupBy,
      sortColumn,
      sortDirection,
      pageSize,
    };
    const next = { ...views, [name]: cfg };
    setViews(next);
    try {
      localStorage.setItem(VIEWS_KEY, JSON.stringify(next));
      localStorage.setItem('grid-current-view', name);
    } catch {}
    setCurrentView(name);
    setSaveViewOpen(false);
    setNewViewName('');
  };

  const deleteView = () => {
    if (!currentView) return;
    const next = { ...views };
    delete next[currentView];
    setViews(next);
    try {
      localStorage.setItem(VIEWS_KEY, JSON.stringify(next));
      localStorage.removeItem('grid-current-view');
    } catch {}
    setCurrentView('');
  };

  useEffect(() => {
    const handler = () => setContractAccountsOpen(true);
    window.addEventListener(OPEN_EXCLUDED_ACCOUNTS_EVENT, handler);
    return () => window.removeEventListener(OPEN_EXCLUDED_ACCOUNTS_EVENT, handler);
  }, []);
  const [sortColumn, setSortColumn] = useState<SortColumn | null>(() => {
    const sc = initialGrid.cfg?.sortColumn;
    return sc && (DEFAULT_COL_ORDER as string[]).includes(sc) ? (sc as SortColumn) : null;
  });
  const [sortDirection, setSortDirection] = useState<'asc' | 'desc'>(initialGrid.cfg?.sortDirection ?? 'asc');

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
    setPage(1);
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
        case 'qty':
          return (a.quantity ?? 0) - (b.quantity ?? 0);
        case 'binSerial':
          return (a.binSerialNumber ?? '').localeCompare(b.binSerialNumber ?? '', undefined, { numeric: true });
        case 'stop':
          return (a.stop ?? '').localeCompare(b.stop ?? '', undefined, { numeric: true });
        case 'wo':
          return (a.workOrderNumber ?? '').localeCompare(b.workOrderNumber ?? '', undefined, { numeric: true });
        case 'address':
          return (a.address ?? '').localeCompare(b.address ?? '');
        case 'lob':
          return (a.lob ?? '').localeCompare(b.lob ?? '');
        case 'tabletNotes':
          return (a.tabletNotes ?? '').localeCompare(b.tabletNotes ?? '');
        case 'chgAmt':
          return (a.chargedAmount ?? 0) - (b.chargedAmount ?? 0);
        case 'prevChg':
          return a.prevChargeCount - b.prevChargeCount;
        case 'prevTotal':
          return a.prevChargeTotal - b.prevChargeTotal;
      }
    };
    return [...events].sort((a, b) => dir * cmp(a, b));
  }, [events, sortColumn, sortDirection]);

  const groupValue = (key: SortColumn, e: NonNullable<typeof events>[number]): string => {
    switch (key) {
      case 'status': return e.eventStatus === 0 ? t('event.status_open') : t('event.status_closed');
      case 'customer': return e.customerName ?? '—';
      case 'type': return e.eventTypeName ?? '—';
      case 'severity': return e.severity ?? '—';
      case 'date': return new Date(e.dateOccurred).toLocaleDateString();
      case 'route': return e.route ?? '—';
      case 'qty': return String(e.quantity ?? '—');
      case 'binSerial': return e.binSerialNumber ?? '—';
      case 'stop': return e.stop ?? '—';
      case 'wo': return e.workOrderNumber ?? '—';
      case 'address': return e.address ?? '—';
      case 'lob': return e.lob ?? '—';
      case 'tabletNotes': return e.tabletNotes ?? '—';
      case 'chgAmt': return e.chargedAmount != null ? formatCurrency(e.chargedAmount) : '—';
      case 'prevChg': return String(e.prevChargeCount);
      case 'prevTotal': return formatCurrency(e.prevChargeTotal);
    }
  };

  const displayEvents = useMemo(() => {
    if (!sortedEvents || !groupBy) return sortedEvents;
    return [...sortedEvents].sort((a, b) =>
      groupValue(groupBy, a).localeCompare(groupValue(groupBy, b), undefined, { numeric: true })
    );
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [sortedEvents, groupBy]);

  const groupCounts = useMemo(() => {
    if (!groupBy || !displayEvents) return null;
    const m = new Map<string, number>();
    for (const e of displayEvents) {
      const g = groupValue(groupBy, e);
      m.set(g, (m.get(g) ?? 0) + 1);
    }
    return m;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [displayEvents, groupBy]);

  const orderedVisibleCols = useMemo(
    () => colOrder.filter(k => BASE_KEYS.has(k) || visibleCols.has(k)),
    [colOrder, visibleCols]
  );

  const totalPages = Math.max(1, Math.ceil((displayEvents?.length ?? 0) / pageSize));
  const currentPage = Math.min(page, totalPages);
  const pagedEvents = useMemo(
    () => displayEvents?.slice((currentPage - 1) * pageSize, currentPage * pageSize),
    [displayEvents, currentPage, pageSize]
  );

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
    setChargeNearbyPreset([]);
    setCloseEventId(null);
    setCloseNearbyPreset([]);
    refreshQueue();
  };

  return (
    <div className="w-full py-3 px-4">
      <div className="flex flex-col sm:flex-row items-center gap-2 mb-3 w-full">
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

          {someSelected && (
            <Button variant="destructive" size="sm" onClick={() => setBulkCloseOpen(true)}>
              <XCircle className="h-4 w-4 mr-2" />
              {t('district.close_selected')} ({selectedIds.size})
            </Button>
          )}

          <div className="flex items-center gap-1 w-full sm:w-auto sm:ml-auto">
            <Select value={currentView || undefined} onValueChange={applyView}>
              <SelectTrigger className="h-9 w-full sm:w-44 bg-background">
                <SelectValue placeholder={t('district.saved_views')} />
              </SelectTrigger>
              <SelectContent>
                {Object.keys(views).length === 0 ? (
                  <div className="px-2 py-1.5 text-xs text-muted-foreground">{t('district.no_views')}</div>
                ) : (
                  Object.keys(views).sort().map(name => (
                    <SelectItem key={name} value={name}>{name}</SelectItem>
                  ))
                )}
              </SelectContent>
            </Select>
            <Button
              variant="outline"
              size="sm"
              className="h-9 w-9 p-0 shrink-0"
              onClick={() => setSaveViewOpen(true)}
              aria-label={t('district.save_view')}
              title={t('district.save_view')}
            >
              <Plus className="h-4 w-4" />
            </Button>
            <Button
              variant="outline"
              size="sm"
              className="h-9 w-9 p-0 shrink-0"
              onClick={deleteView}
              disabled={!currentView}
              aria-label={t('district.delete_view')}
              title={t('district.delete_view')}
            >
              <Minus className="h-4 w-4" />
            </Button>
          </div>

          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="outline" size="sm" className="w-full sm:w-auto">
                <Columns3 className="h-4 w-4 mr-2" />
                {t('district.columns')}
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" className="w-48">
              {OPTIONAL_COLUMNS.map(c => (
                <DropdownMenuCheckboxItem
                  key={c.key}
                  checked={visibleCols.has(c.key)}
                  onCheckedChange={() => toggleCol(c.key)}
                  onSelect={e => e.preventDefault()}
                >
                  {c.label}
                </DropdownMenuCheckboxItem>
              ))}
            </DropdownMenuContent>
          </DropdownMenu>
      </div>

      <div
        onDragOver={e => { if (dragCol) { e.preventDefault(); setDropTarget('groupzone'); } }}
        onDragLeave={() => setDropTarget(prev => (prev === 'groupzone' ? null : prev))}
        onDrop={e => { e.preventDefault(); if (dragCol) setGroupByPersist(dragCol); setDragCol(null); setDropTarget(null); }}
        className={cn(
          'flex items-center gap-2 mb-2 rounded-lg border border-dashed px-3 py-1.5 text-xs transition-colors',
          dropTarget === 'groupzone' ? 'border-primary bg-primary/10 text-primary' : 'text-muted-foreground'
        )}
      >
        <Layers className="h-3.5 w-3.5 shrink-0" />
        {groupBy ? (
          <span className="flex items-center gap-1 rounded-md bg-primary/10 text-primary border border-primary/20 px-2 py-0.5 font-medium">
            {ALL_COLUMNS.find(c => c.key === groupBy)?.label}
            <button
              type="button"
              onClick={() => setGroupByPersist(null)}
              aria-label={t('district.clear_group')}
              title={t('district.clear_group')}
              className="hover:text-destructive"
            >
              <X className="h-3 w-3" />
            </button>
          </span>
        ) : (
          <span>{t('district.group_hint')}</span>
        )}
      </div>

      <div className="bg-card border rounded-xl overflow-hidden shadow-sm">
        <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b bg-muted/40 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
              <th className="px-3 py-2 w-8 text-left">
                <Checkbox
                  checked={allOpenSelected}
                  onCheckedChange={(c) => toggleAll(c === true)}
                  disabled={openEvents.length === 0}
                  aria-label={t('district.select_all')}
                />
              </th>
              {orderedVisibleCols.map(key => {
                const col = ALL_COLUMNS.find(c => c.key === key)!;
                return (
                  <th
                    key={key}
                    draggable
                    onDragStart={e => { setDragCol(key); e.dataTransfer.effectAllowed = 'move'; e.dataTransfer.setData('text/plain', key); }}
                    onDragEnd={() => { setDragCol(null); setDropTarget(null); }}
                    onDragOver={e => { if (dragCol && dragCol !== key) { e.preventDefault(); setDropTarget(key); } }}
                    onDrop={e => { e.preventDefault(); if (dragCol && dragCol !== key) moveColumn(dragCol, key); setDragCol(null); setDropTarget(null); }}
                    className={cn(
                      'px-3 py-2 text-left whitespace-nowrap cursor-move select-none transition-colors',
                      dropTarget === key && 'bg-primary/15',
                      dragCol === key && 'opacity-50'
                    )}
                  >
                    <div className="flex items-center gap-1">
                      <GripVertical className="h-3 w-3 opacity-30 shrink-0" />
                      <SortHeader label={col.label} column={key} sortColumn={sortColumn} sortDirection={sortDirection} onSort={toggleSort} />
                    </div>
                  </th>
                );
              })}
              <th className="sticky right-[124px] z-10 bg-background border-l px-2 py-2"></th>
              <th className="sticky right-0 z-10 bg-background px-3 py-2 text-right w-[124px]">Photo</th>
            </tr>
          </thead>
          <tbody className="divide-y">
        {isLoadingEvents ? (
          <tr><td colSpan={99} className="p-4">
            <div className="space-y-4">
              {[1,2,3,4,5].map(i => <Skeleton key={i} className="h-12 w-full" />)}
            </div>
          </td></tr>
        ) : events?.length === 0 ? (
          <tr><td colSpan={99} className="p-12 text-center text-muted-foreground">
            <CheckCircle2 className="h-12 w-12 mx-auto mb-4 opacity-20" />
            <p className="text-lg">{t('district.no_events')}</p>
          </td></tr>
        ) : (
            (() => {
              const renderCell = (key: SortColumn, event: NonNullable<typeof events>[number]) => {
                switch (key) {
                  case 'status':
                    return (
                      <td key={key} className="px-3 py-1.5">
                        {event.eventStatus === 0 ? (
                          <Badge variant="default" className="bg-primary/10 text-primary hover:bg-primary/20 border-0 text-xs">{t('event.status_open')}</Badge>
                        ) : (
                          <Badge variant="outline" className="text-muted-foreground border-muted-foreground/30 text-xs">{t('event.status_closed')}</Badge>
                        )}
                      </td>
                    );
                  case 'customer':
                    return (
                      <td key={key} className="px-3 py-1.5 min-w-[180px]">
                        <div className="font-medium text-xs group-hover:text-primary transition-colors line-clamp-1">{event.customerName}</div>
                        <div className="text-xs text-muted-foreground font-mono">{event.accountNumber}</div>
                      </td>
                    );
                  case 'type':
                    return (
                      <td key={key} className="px-3 py-1.5">
                        <div className="font-medium text-xs line-clamp-1">{event.eventTypeName}</div>
                        <div className={cn('text-xs', sourceColor(event.eventSourceName))}>{event.eventSourceName}</div>
                      </td>
                    );
                  case 'severity':
                    return (
                      <td key={key} className="px-3 py-1.5">
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
                      </td>
                    );
                  case 'date':
                    return (
                      <td key={key} className="px-3 py-1.5 whitespace-nowrap">
                        <div className="text-xs flex items-center gap-1.5 text-muted-foreground">
                          <Clock className="h-3.5 w-3.5" />
                          {formatDate(event.dateOccurred)}
                        </div>
                      </td>
                    );
                  case 'route':
                    return (
                      <td key={key} className="px-3 py-1.5">
                        <div className="font-mono text-xs">{event.route}</div>
                        <div className="text-muted-foreground font-mono text-xs">{event.vehicle}</div>
                      </td>
                    );
                  case 'qty':
                    return <td key={key} className="px-3 py-1.5 text-xs font-mono">{event.quantity ?? '—'}</td>;
                  case 'binSerial':
                    return <td key={key} className="px-3 py-1.5 text-xs font-mono whitespace-nowrap">{event.binSerialNumber ?? '—'}</td>;
                  case 'stop':
                    return <td key={key} className="px-3 py-1.5 text-xs font-mono">{event.stop ?? '—'}</td>;
                  case 'wo':
                    return <td key={key} className="px-3 py-1.5 text-xs font-mono whitespace-nowrap">{event.workOrderNumber ?? '—'}</td>;
                  case 'address':
                    return <td key={key} className="px-3 py-1.5 text-xs min-w-[160px]">{event.address}</td>;
                  case 'lob':
                    return <td key={key} className="px-3 py-1.5 text-xs">{event.lob ?? '—'}</td>;
                  case 'tabletNotes':
                    return <td key={key} className="px-3 py-1.5 text-xs min-w-[140px]">{event.tabletNotes ?? '—'}</td>;
                  case 'chgAmt':
                    return <td key={key} className="px-3 py-1.5 text-xs font-mono whitespace-nowrap">{event.chargedAmount != null ? formatCurrency(event.chargedAmount) : '—'}</td>;
                  case 'prevChg':
                    return <td key={key} className="px-3 py-1.5 text-xs font-mono">{event.prevChargeCount}</td>;
                  case 'prevTotal':
                    return <td key={key} className="px-3 py-1.5 text-xs font-mono whitespace-nowrap">{formatCurrency(event.prevChargeTotal)}</td>;
                }
              };

              const rows: React.ReactNode[] = [];
              let prevGroup: string | null = null;
              const colSpan = orderedVisibleCols.length + 3;
              pagedEvents?.forEach(event => {
                if (groupBy) {
                  const gv = groupValue(groupBy, event);
                  if (gv !== prevGroup) {
                    prevGroup = gv;
                    rows.push(
                      <tr key={`group-${gv}`} className="bg-muted/50">
                        <td colSpan={colSpan} className="px-3 py-1.5 text-xs font-semibold">
                          {ALL_COLUMNS.find(c => c.key === groupBy)?.label}: {gv}
                          <span className="ml-2 font-normal text-muted-foreground">({groupCounts?.get(gv) ?? 0})</span>
                        </td>
                      </tr>
                    );
                  }
                }
                rows.push(
                  <tr
                    key={event.id}
                    onClick={() => setLocation(`/districts/${districtId}/events/${event.id}`)}
                    className="hover:bg-muted/30 cursor-pointer transition-colors group"
                  >
                    <td className="px-3 py-1.5 w-8" onClick={e => e.stopPropagation()}>
                      {event.eventStatus === 0 ? (
                        <Checkbox
                          checked={selectedIds.has(event.id)}
                          onCheckedChange={(c) => toggleOne(event.id, c === true)}
                          aria-label={`Select ${event.customerName}`}
                        />
                      ) : (
                        <span className="inline-block w-4" />
                      )}
                    </td>
                    {orderedVisibleCols.map(key => renderCell(key, event))}
                    <td className="sticky right-[124px] z-10 bg-card border-l px-2 py-1.5" onClick={e => e.stopPropagation()}>
                      {event.eventStatus === 0 && (
                        <Button
                          size="sm"
                          variant="destructive"
                          className="h-7 w-7 p-0"
                          onClick={() => setCloseEventId(event.id)}
                          aria-label={t('preview.close')}
                          title={t('preview.close')}
                        >
                          <XCircle className="h-3.5 w-3.5" />
                        </Button>
                      )}
                    </td>
                    <td className="sticky right-0 z-10 bg-card px-3 py-1.5 w-[124px]" onClick={e => e.stopPropagation()}>
                      <div className="flex items-center justify-end gap-2">
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
                          onCharge={(ids) => { setChargeNearbyPreset(ids); setChargeEventId(event.id); }}
                          onClose={() => { setCloseNearbyPreset([]); setCloseEventId(event.id); }}
                          onCloseWithDuplicates={(ids) => { setCloseNearbyPreset(ids); setCloseEventId(event.id); }}
                          onNavigate={() => setLocation(`/districts/${districtId}/events/${event.id}`)}
                        />
                      ) : (
                        <span className="text-xs text-muted-foreground italic">{t('event.no_photo')}</span>
                      )}
                      </div>
                    </td>
                  </tr>
                );
              });
              return rows;
            })()
        )}
          </tbody>
        </table>
        </div>
        {(displayEvents?.length ?? 0) > 0 && (
          <div className="flex flex-col sm:flex-row items-center justify-between gap-3 px-3 py-2 border-t bg-muted/20 text-sm">
            <div className="flex items-center gap-2 text-muted-foreground">
              <span>
                {t('district.page_info', {
                  from: (currentPage - 1) * pageSize + 1,
                  to: Math.min(currentPage * pageSize, displayEvents?.length ?? 0),
                  total: displayEvents?.length ?? 0,
                })}
              </span>
              <Select value={String(pageSize)} onValueChange={v => { setPageSize(Number(v)); setPage(1); }}>
                <SelectTrigger className="h-7 w-[110px]">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {[10, 25, 50, 100].map(n => (
                    <SelectItem key={n} value={String(n)}>{t('district.per_page', { n })}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="flex items-center gap-1">
              <Button variant="outline" size="sm" className="h-7 px-2" disabled={currentPage <= 1} onClick={() => setPage(currentPage - 1)}>
                <ChevronLeft className="h-4 w-4" />
              </Button>
              {Array.from({ length: totalPages }, (_, i) => i + 1)
                .filter(p => p === 1 || p === totalPages || Math.abs(p - currentPage) <= 2)
                .map((p, idx, arr) => (
                  <React.Fragment key={p}>
                    {idx > 0 && arr[idx - 1] !== p - 1 && <span className="px-1 text-muted-foreground">…</span>}
                    <Button
                      variant={p === currentPage ? 'default' : 'outline'}
                      size="sm"
                      className="h-7 min-w-7 px-2"
                      onClick={() => setPage(p)}
                    >
                      {p}
                    </Button>
                  </React.Fragment>
                ))}
              <Button variant="outline" size="sm" className="h-7 px-2" disabled={currentPage >= totalPages} onClick={() => setPage(currentPage + 1)}>
                <ChevronRight className="h-4 w-4" />
              </Button>
            </div>
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
          onOpenChange={(o) => { if (!o) { setChargeEventId(null); setChargeNearbyPreset([]); } }}
          eventId={chargeEventId}
          initialCheckedNearby={chargeNearbyPreset}
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
      <Dialog open={saveViewOpen} onOpenChange={(o) => { setSaveViewOpen(o); if (!o) setNewViewName(''); }}>
        <DialogContent className="sm:max-w-sm">
          <DialogHeader>
            <DialogTitle>{t('district.save_view')}</DialogTitle>
          </DialogHeader>
          <Input
            autoFocus
            placeholder={t('district.view_name')}
            value={newViewName}
            onChange={e => setNewViewName(e.target.value)}
            onKeyDown={e => { if (e.key === 'Enter') saveView(); }}
          />
          <DialogFooter>
            <Button variant="outline" onClick={() => setSaveViewOpen(false)}>{t('district.cancel')}</Button>
            <Button onClick={saveView} disabled={!newViewName.trim()}>{t('district.save')}</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}

function EventThumbnailPreview({ event, districtId, onCharge, onClose, onCloseWithDuplicates, onNavigate }: {
  event: any;
  districtId: number;
  onCharge: (checkedDuplicateIds: number[]) => void;
  onClose: () => void;
  onCloseWithDuplicates: (ids: number[]) => void;
  onNavigate: () => void;
}) {
  const { t } = useI18n();
  const [selectedImage, setSelectedImage] = useState<string>(event.imageUrl);
  const [open, setOpen] = useState(false);
  const [checkedNearby, setCheckedNearby] = useState<Set<number>>(new Set());

  const toggleNearby = (id: number) => {
    setCheckedNearby(prev => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id); else next.add(id);
      return next;
    });
  };

  // Clear the checkbox selection whenever the preview closes
  useEffect(() => {
    if (!open) {
      setCheckedNearby(new Set());
    }
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
      {/* Rendered into <body> rather than in place. This component sits inside a
          `position: sticky` cell with a z-index, which makes that cell its own
          stacking context — any z-index the popup sets is confined to it, so the
          sticky cells of later rows paint on top no matter how high we go. The
          portal is the fix; the z-index below only has to clear the app header. */}
      {open && createPortal(
        <>
          {/* Dim backdrop; click closes the preview */}
          <div
            className="fixed inset-0 z-[60] bg-black/40 animate-in fade-in-0"
            onClick={() => setOpen(false)}
          />
          <div
            role="dialog"
            aria-label={`${event.customerName} photo preview`}
            onMouseEnter={cancelClose}
            onMouseLeave={scheduleClose}
            onClick={e => e.stopPropagation()}
            className="fixed left-1/2 top-1/2 z-[60] w-[min(56rem,calc(100vw-2rem))] max-h-[90vh] -translate-x-1/2 -translate-y-1/2 overflow-y-auto rounded-lg border bg-background p-4 shadow-lg space-y-3 animate-in fade-in-0 zoom-in-95"
          >
            <div className="flex gap-3">
              <div className="flex-1 bg-muted rounded-lg overflow-hidden aspect-video flex items-center justify-center">
                <img
                  src={selectedImage}
                  alt="Event preview"
                  className="object-contain w-full h-full"
                  onError={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }}
                />
              </div>
              {/* Right rail: close, actions, thumbnails */}
              <div className="flex flex-col items-center gap-2 w-20 shrink-0">
                <button
                  type="button"
                  onClick={() => setOpen(false)}
                  className="self-end rounded-sm bg-background/80 p-1 opacity-70 transition-opacity hover:opacity-100"
                  aria-label="Close preview"
                >
                  <X className="h-4 w-4" />
                </button>
                {isOpen && (
                  <div className="flex gap-2">
                    <Button
                      size="icon"
                      className="h-8 w-8 bg-success text-success-foreground hover:bg-success/90"
                      onClick={() => onCharge(Array.from(checkedNearby))}
                      title={t('preview.charge_customer')}
                      aria-label={t('preview.charge_customer')}
                    >
                      <DollarSign className="h-4 w-4" />
                    </Button>
                    <Button
                      size="icon"
                      variant="destructive"
                      className="h-8 w-8"
                      onClick={checkedNearby.size > 0 ? () => onCloseWithDuplicates(Array.from(checkedNearby)) : onClose}
                      title={t('preview.dismiss_event')}
                      aria-label={t('preview.dismiss_event')}
                    >
                      <DoorOpen className="h-4 w-4" />
                    </Button>
                  </div>
                )}
                {images.length > 1 && (
                  <div className="flex flex-col gap-2 overflow-y-auto max-h-[50vh] pt-1">
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
              </div>
            </div>
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
                <NearbyClusterPicker
                  nearby={nearbyEvents}
                  checked={checkedNearby}
                  onToggle={toggleNearby}
                  anchorAccountNumber={event.accountNumber}
                  title={null}
                />
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
        </>,
        document.body
      )}
    </>
  );
}
