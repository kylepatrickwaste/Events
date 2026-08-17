import React, { useState, useMemo, useEffect, useLayoutEffect, useRef } from 'react';
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
import { Search, Settings, ChevronLeft, ChevronRight, CheckCircle2, DollarSign, AlertTriangle, ChevronsUpDown, Check, CheckCheck, Square, XCircle, Camera, FileX2, ArrowUp, ArrowDown, ArrowUpDown, Images, X, DoorOpen, Plus, Minus, GripVertical, Layers } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { useToast } from '@/hooks/use-toast';
import { cn } from '@/lib/utils';
import { EventSourceGlyph, EventStatusGlyph, EventTypeGlyph } from '@/components/grid-glyphs';
import { ChargeEventDialog, CloseEventDialog, BulkCloseDialog, BulkChargeDialog } from '@/components/event-action-dialogs';
import { rememberDistrict } from '@/lib/selected-district';
import {
  DropdownMenu,
  DropdownMenuCheckboxItem,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuRadioGroup,
  DropdownMenuRadioItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { COL_VIS_KEY, DEFAULT_VISIBLE_COLS, LEGACY_ALL_ON, loadVisibleCols } from '@/lib/col-visibility';

type ColumnDef = {
  key: SortColumn;
  /** Always set: it names the column for sorting and for assistive tech. */
  label: string;
  /** Marks-only columns carry their meaning in the cells, not in a heading. */
  hideLabel?: boolean;
};

const OPTIONAL_COLUMNS: ColumnDef[] = [
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

const BASE_COLUMNS: ColumnDef[] = [
  { key: 'customer', label: 'Customer' },
  { key: 'date', label: 'Event Time' },
  { key: 'route', label: 'Vehicle' },
];
const ALL_COLUMNS = [...BASE_COLUMNS, ...OPTIONAL_COLUMNS];
/**
 * Reading order for a charge agent: who was it, where, and when. The marks
 * column (status / type / source / severity) is no longer part of this order:
 * it is pinned to the right edge beside the photo panel and cannot be moved.
 */
const DEFAULT_COL_ORDER: SortColumn[] = [
  'customer', 'address', 'date',
  'route',
  'qty', 'binSerial', 'stop', 'wo', 'lob', 'tabletNotes', 'chgAmt', 'prevChg', 'prevTotal',
];
const BASE_KEYS = new Set<string>(BASE_COLUMNS.map(c => c.key));
// Numeric-ish columns read better centered; everything else stays left-aligned.
const CENTERED_KEYS = new Set<string>(['qty', 'binSerial', 'chgAmt', 'prevChg', 'prevTotal']);
// The columns most agents actually use. Everything else starts switched off.
// The pre-rework default was "everything on". A legacy store holding exactly
// that set is almost certainly the old default echoed back by a view apply or
// an off-then-on toggle, not a deliberate choice — treat it as no choice.
const VIEWS_KEY = 'grid-views';
// Versioned: a saved order from before the columns were re-sequenced would pin
// everyone to the old layout, since a stored order always wins over the default.
const COL_ORDER_KEY = 'grid-col-order-v2';
// Versioned for the same reason: v1 ('grid-columns') dates from when every
// optional column defaulted on, so an absent v2 key means "use the new default"
// unless the v1 value shows the user made their own pick.
// (COL_VIS_KEY, DEFAULT_VISIBLE_COLS, LEGACY_ALL_ON, loadVisibleCols imported from @/lib/col-visibility)
// Pinned right-hand panel geometry. The marks (status / type / source /
// severity) and the photo live in ONE cell pinned to the right edge, not in two
// cells whose sticky offsets have to agree: an auto-layout table hands columns
// whatever width it likes, so any right-offset arithmetic drifts and opens a
// seam for the scrolling columns to travel through.
// Sized to its contents, not rounded up: the photo group is right-aligned
// inside the panel, so any width beyond what the marks and the photo need opens
// as dead space in the middle of the panel, between the icons and the
// thumbnails. Widen these only together with what they hold.
const PANEL_W = 192;
// Inside the panel: the marks group gets a fixed slot on the left, the photo
// group takes the rest. PANEL_PAD is the panel's own horizontal padding, which
// lives on the inner box so the cell's content box stays exactly PANEL_W.
const PANEL_PAD = 8;
// Three 16px glyphs and their two gaps (60px), rounded up to clear the widest
// severity badge sitting underneath them.
const PANEL_MARKS_W = 72;

/** Left shadow marking the edge of the frozen right-hand panel. */
const PINNED_LEFT_SHADOW = '-4px 0 6px -2px rgba(0,0,0,0.08)';

/**
 * The panel is a fixed-width island in an auto-layout, full-width table. Fixing
 * the cell alone isn't enough -- the table happily stretches a cell past its
 * stated width to fill the row -- so the width is pinned on the inner box too,
 * and one body column is told to absorb all the leftover width instead (see
 * flexColKey below).
 */
const PANEL_CELL_STYLE: React.CSSProperties = {
  width: PANEL_W,
  minWidth: PANEL_W,
  maxWidth: PANEL_W,
  padding: 0,
};
const PANEL_INNER_STYLE: React.CSSProperties = {
  width: PANEL_W,
  boxSizing: 'border-box',
  paddingLeft: PANEL_PAD,
  paddingRight: PANEL_PAD,
};
const PAGE_SIZES = [25, 50, 100];
const DEFAULT_PAGE_SIZE = 25;
// A view saved before the columns were re-sequenced carries the old order, and a
// view's order wins over the default -- so an old view would quietly undo the new
// layout. Stamping the version lets us keep everything else the view remembers
// and drop only its stale ordering.
const VIEW_CONFIG_VERSION = 3;

/**
 * The header band: the brand's dark green, carried by the same token the rest of
 * the app uses so it tracks the light and dark themes. It has to be fully opaque
 * -- rows slide underneath it -- and the inset shadow stands in for the row's
 * bottom border, which a sticky cell would otherwise leave behind.
 */
const STICKY_HEADER_BG: React.CSSProperties = {
  backgroundColor: 'hsl(var(--primary))',
  boxShadow: 'inset 0 -1px 0 rgba(0, 0, 0, 0.25)',
};

/** Same, lit up for the column a drag is hovering over. */
const STICKY_HEADER_DROP: React.CSSProperties = {
  ...STICKY_HEADER_BG,
  backgroundImage: 'linear-gradient(rgba(255, 255, 255, 0.25), rgba(255, 255, 255, 0.25))',
  boxShadow: 'inset 2px 0 0 #fff, inset 0 -1px 0 rgba(0, 0, 0, 0.25)',
};

type ViewConfig = {
  v: number;
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
  const stale = c.v !== VIEW_CONFIG_VERSION;
  return {
    v: VIEW_CONFIG_VERSION,
    visibleCols: c.visibleCols.filter((k): k is string => typeof k === 'string'),
    colOrder: stale ? [...DEFAULT_COL_ORDER] : c.colOrder.filter((k): k is string => typeof k === 'string'),
    groupBy: typeof c.groupBy === 'string' ? c.groupBy : null,
    sortColumn: typeof c.sortColumn === 'string' ? c.sortColumn : null,
    sortDirection: c.sortDirection === 'desc' ? 'desc' : 'asc',
    pageSize: typeof c.pageSize === 'number' && PAGE_SIZES.includes(c.pageSize) ? c.pageSize : DEFAULT_PAGE_SIZE,
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
import { LoadError } from '@/components/load-error';
import { NearbyClusterPicker, suggestedDuplicateIds } from '@/components/nearby-cluster-picker';

type SortColumn = 'status' | 'customer' | 'type' | 'severity' | 'date' | 'route' | 'qty' | 'binSerial' | 'stop' | 'wo' | 'address' | 'lob' | 'tabletNotes' | 'chgAmt' | 'prevChg' | 'prevTotal';

// Photo preview hover timings (ms). The open delay keeps quick pass-over
// hovers from popping anything; the close delay is a grace period so the
// pointer can travel from a thumbnail to the preview (or to the next
// thumbnail) without the preview blinking shut.
const PREVIEW_OPEN_DELAY = 150;
const PREVIEW_CLOSE_DELAY = 220;
// How long the pointer must settle on a row before we fetch its detail, so
// sliding through many rows doesn't fan out a request per row.
const PREVIEW_DETAIL_SETTLE_DELAY = 250;
// Gap between the preview panel and the frozen photo column.
const PREVIEW_GAP = 12;
// Below this much free space left of the frozen panel we can't place the
// preview beside it, so we fall back to a centered panel.
const PREVIEW_MIN_WIDTH = 560;

/**
 * The element the preview should be placed to the left of: the hovered
 * thumbnail's frozen cell, so the whole pinned panel (close button included)
 * stays visible and clickable while the preview is open.
 */
const previewAnchorFor = (el: HTMLElement): HTMLElement => {
  // Anchor on the row's pinned panel cell — the left edge of the whole frozen
  // panel — so the preview lands beside the panel rather than under it. The
  // marks and the photo share one cell, so this is the panel's own left edge.
  const row = el.closest('tr');
  const panel = row?.querySelector('[data-pinned-marks]') as HTMLElement | null;
  return panel ?? (el.closest('td') as HTMLElement | null) ?? el;
};

// Higher rank = more severe; unknown/missing severities sort last
const SEVERITY_RANK: Record<string, number> = { severe: 2, minimal: 1 };

const severityRank = (s: string | null | undefined) =>
  s ? (SEVERITY_RANK[s.toLowerCase()] ?? 0) : 0;

function SortHeader({ label, hideLabel, column, sortColumn, sortDirection, onSort }: {
  label: string;
  hideLabel?: boolean;
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
        'flex items-center gap-1 uppercase tracking-wider text-xs font-semibold transition-colors hover:text-white',
        active ? 'text-white' : 'text-header-dim'
      )}
    >
      {hideLabel ? <span className="sr-only">{label}</span> : label}
      {active ? (
        sortDirection === 'asc'
          ? <ArrowUp className="h-3 w-3 shrink-0" />
          : <ArrowDown className="h-3 w-3 shrink-0" />
      ) : (
        <ArrowUpDown className="h-3 w-3 shrink-0" />
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
  const [bulkChargeOpen, setBulkChargeOpen] = useState(false);
  const [chargeEventId, setChargeEventId] = useState<number | null>(null);
  const [chargeNearbyPreset, setChargeNearbyPreset] = useState<number[]>([]);
  const [closeEventId, setCloseEventId] = useState<number | null>(null);
  const [closeNearbyPreset, setCloseNearbyPreset] = useState<number[]>([]);
  // Exactly one photo preview is open for the whole table. Thumbnails only
  // report hover/click; this controller decides which event is previewed.
  const [previewEventId, setPreviewEventId] = useState<number | null>(null);
  const previewAnchorRef = useRef<HTMLElement | null>(null);
  const previewOpenTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const previewCloseTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(() => initialGrid.cfg?.pageSize ?? DEFAULT_PAGE_SIZE);
  const [visibleCols, setVisibleCols] = useState<Set<string>>(() => {
    if (initialGrid.cfg) return new Set(initialGrid.cfg.visibleCols);
    return loadVisibleCols();
  });
  const toggleCol = (key: string) => {
    setVisibleCols(prev => {
      const next = new Set(prev);
      if (next.has(key)) next.delete(key); else next.add(key);
      try { localStorage.setItem(COL_VIS_KEY, JSON.stringify([...next])); } catch {}
      return next;
    });
  };

  const [colOrder, setColOrder] = useState<SortColumn[]>(() => {
    if (initialGrid.cfg) return normalizeOrder(initialGrid.cfg.colOrder);
    try {
      const raw = localStorage.getItem(COL_ORDER_KEY);
      if (raw) return normalizeOrder(JSON.parse(raw) as string[]);
    } catch {}
    return DEFAULT_COL_ORDER;
  });
  const setColOrderPersist = (next: SortColumn[]) => {
    setColOrder(next);
    try { localStorage.setItem(COL_ORDER_KEY, JSON.stringify(next)); } catch {}
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
    // Take the target's index before the dragged column is removed. Looking it
    // up afterwards always inserts ahead of the target, which makes a drag one
    // place to the right land the column back where it started.
    const toIdx = colOrder.indexOf(to);
    if (toIdx < 0) return;
    const next = colOrder.filter(k => k !== from);
    next.splice(toIdx, 0, from);
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
    try { localStorage.setItem(COL_VIS_KEY, JSON.stringify([...vis])); } catch {}
    setColOrderPersist(normalizeOrder(cfg.colOrder));
    setGroupByPersist(cfg.groupBy && (DEFAULT_COL_ORDER as string[]).includes(cfg.groupBy) ? (cfg.groupBy as SortColumn) : null);
    setSortColumn(cfg.sortColumn && (DEFAULT_COL_ORDER as string[]).includes(cfg.sortColumn) ? (cfg.sortColumn as SortColumn) : null);
    setSortDirection(cfg.sortDirection === 'desc' ? 'desc' : 'asc');
    if (PAGE_SIZES.includes(cfg.pageSize)) setPageSize(cfg.pageSize);
    setPage(1);
  };

  const saveView = () => {
    const name = newViewName.trim();
    if (!name) return;
    const cfg: ViewConfig = {
      v: VIEW_CONFIG_VERSION,
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

  // The administration page has a tab of settings for the district you are
  // working in, and no district in its own URL to work that out from.
  useEffect(() => { rememberDistrict(districtId); }, [districtId]);
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
  const { data: events, isLoading: isLoadingEvents, isError: isEventsError, refetch: refetchEvents } = useListEvents(
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

  // The table is full-width and auto-laid-out, so the leftover width has to go
  // somewhere -- and if we don't say where, it gets spread across every column
  // including the frozen panel, which then no longer measures PANEL_W. Nominate
  // one free-text column to soak it all up; prose columns stretch gracefully,
  // the numeric ones don't. Falls back to the last visible column so there is
  // always exactly one taker.
  const flexColKey = useMemo(() => {
    const preferred = ['address', 'customer', 'tabletNotes'];
    return (
      preferred.find(k => orderedVisibleCols.includes(k as SortColumn)) ??
      orderedVisibleCols[orderedVisibleCols.length - 1] ??
      null
    );
  }, [orderedVisibleCols]);

  const totalPages = Math.max(1, Math.ceil((displayEvents?.length ?? 0) / pageSize));
  const totalRows = displayEvents?.length ?? 0;
  const currentPage = Math.min(page, totalPages);
  const pagedEvents = useMemo(
    () => displayEvents?.slice((currentPage - 1) * pageSize, currentPage * pageSize),
    [displayEvents, currentPage, pageSize]
  );

  // ---- Photo preview controller -------------------------------------------
  const previewEvent = useMemo(
    () => pagedEvents?.find(e => e.id === previewEventId) ?? null,
    [pagedEvents, previewEventId]
  );

  const clearPreviewOpenTimer = () => {
    if (previewOpenTimer.current) { clearTimeout(previewOpenTimer.current); previewOpenTimer.current = null; }
  };
  const clearPreviewCloseTimer = () => {
    if (previewCloseTimer.current) { clearTimeout(previewCloseTimer.current); previewCloseTimer.current = null; }
  };

  const closePreview = () => {
    clearPreviewOpenTimer();
    clearPreviewCloseTimer();
    setPreviewEventId(null);
  };

  const schedulePreviewClose = () => {
    clearPreviewOpenTimer();
    clearPreviewCloseTimer();
    previewCloseTimer.current = setTimeout(() => setPreviewEventId(null), PREVIEW_CLOSE_DELAY);
  };

  // Hovering a thumbnail: swap instantly when a preview is already open,
  // otherwise wait out the open delay.
  const handleThumbnailEnter = (id: number, el: HTMLElement) => {
    clearPreviewOpenTimer();
    clearPreviewCloseTimer();
    previewAnchorRef.current = previewAnchorFor(el);
    if (previewEventId !== null) {
      setPreviewEventId(id);
      return;
    }
    previewOpenTimer.current = setTimeout(() => setPreviewEventId(id), PREVIEW_OPEN_DELAY);
  };

  // Leaving a thumbnail cancels a pending open, or starts the grace period so
  // the pointer can reach the preview or the next thumbnail.
  const handleThumbnailLeave = () => {
    clearPreviewOpenTimer();
    if (previewEventId !== null) schedulePreviewClose();
  };

  useEffect(() => () => { clearPreviewOpenTimer(); clearPreviewCloseTimer(); }, []);

  // The rows scroll under the pointer now, so a preview left open would end up
  // showing the photos of whichever row slid into its place. Capture, because
  // scroll events from the grid container do not bubble.
  useEffect(() => {
    if (previewEventId === null) return;
    const onScroll = () => closePreview();
    window.addEventListener('scroll', onScroll, true);
    return () => window.removeEventListener('scroll', onScroll, true);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [previewEventId]);

  // Never leave a preview orphaned when its row leaves the page (pagination,
  // filtering, sorting or a refetch that drops the event).
  useEffect(() => {
    if (previewEventId !== null && !previewEvent) closePreview();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [previewEventId, previewEvent]);

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

  const handleBulkChargeDone = (chargedCount: number, failedCount: number) => {
    setBulkChargeOpen(false);
    setSelectedIds(new Set());
    refreshQueue();
    if (failedCount > 0) {
      toast({
        variant: 'destructive',
        description: t('bulk_charge.partial', { charged: chargedCount, failed: failedCount }),
      });
    } else {
      toast({ description: t('bulk_charge.success', { count: chargedCount }) });
    }
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
    <div className="flex h-full w-full flex-col py-3 px-4">
      <div className="flex flex-col sm:flex-row items-center gap-2 mb-3 w-full shrink-0">
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

          {/* Saved views and column visibility are both "how I want this grid
              to look", so they share one menu rather than three controls. */}
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="outline" size="sm" className="w-full sm:w-auto sm:ml-auto">
                <Settings className="h-4 w-4 mr-2" />
                {t('district.customize')}
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" className="w-56 max-h-[70vh] overflow-y-auto">
              <DropdownMenuLabel>{t('district.saved_views')}</DropdownMenuLabel>
              {Object.keys(views).length === 0 ? (
                <div className="px-2 py-1 text-xs text-muted-foreground">
                  {t('district.no_views')}
                </div>
              ) : (
                <DropdownMenuRadioGroup value={currentView} onValueChange={applyView}>
                  {Object.keys(views).sort().map(name => (
                    <DropdownMenuRadioItem key={name} value={name}>
                      {name}
                    </DropdownMenuRadioItem>
                  ))}
                </DropdownMenuRadioGroup>
              )}
              <DropdownMenuItem onSelect={() => setSaveViewOpen(true)}>
                <Plus className="h-4 w-4 mr-2" />
                {t('district.save_view')}
              </DropdownMenuItem>
              <DropdownMenuItem onSelect={deleteView} disabled={!currentView}>
                <Minus className="h-4 w-4 mr-2" />
                {t('district.delete_view')}
              </DropdownMenuItem>

              <DropdownMenuSeparator />

              <DropdownMenuLabel>{t('district.columns')}</DropdownMenuLabel>
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

      {/* One row: the group-by drop zone, shortened, with the bulk-action panel
          beside it — right-aligned so it sits directly under Customize. */}
      <div className="mb-2 flex shrink-0 flex-col sm:flex-row items-stretch gap-2">
        <div
          onDragOver={e => { if (dragCol) { e.preventDefault(); setDropTarget('groupzone'); } }}
          onDragLeave={() => setDropTarget(prev => (prev === 'groupzone' ? null : prev))}
          onDrop={e => { e.preventDefault(); if (dragCol) setGroupByPersist(dragCol); setDragCol(null); setDropTarget(null); }}
          className={cn(
            'flex min-w-0 flex-1 items-center gap-2 rounded-lg border border-dashed px-2 py-1 text-xs transition-colors',
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

        {/* Bulk actions: one compact panel, icon-led small buttons, with the
            selected count anchoring it. Actions stay visible but disabled with
            nothing selected, so the entry point never disappears. */}
        <div
          className="flex shrink-0 items-center gap-1 rounded-lg border bg-card px-2 py-1"
          data-testid="bulk-action-panel"
        >
          <span className="px-1 text-xs font-medium tabular-nums text-muted-foreground whitespace-nowrap">
            {t('district.selected_count', { count: selectedIds.size })}
          </span>
          <Button
            variant="ghost"
            size="sm"
            className="h-7 px-2 text-xs"
            onClick={() => toggleAll(true)}
            disabled={openEvents.length === 0}
          >
            <CheckCheck className="h-3.5 w-3.5 mr-1" />
            {t('district.select_all')}
          </Button>
          <Button
            variant="ghost"
            size="sm"
            className="h-7 px-2 text-xs"
            onClick={() => toggleAll(false)}
            disabled={!someSelected}
          >
            <Square className="h-3.5 w-3.5 mr-1" />
            {t('district.select_none')}
          </Button>
          <Button
            size="sm"
            className="h-7 px-2 text-xs bg-success text-success-foreground hover:bg-success/90"
            onClick={() => setBulkChargeOpen(true)}
            disabled={!someSelected}
          >
            <DollarSign className="h-3.5 w-3.5 mr-1" />
            {t('district.charge_selected')}
          </Button>
          <Button
            variant="destructive"
            size="sm"
            className="h-7 px-2 text-xs"
            onClick={() => setBulkCloseOpen(true)}
            disabled={!someSelected}
          >
            <XCircle className="h-3.5 w-3.5 mr-1" />
            {t('district.close_selected')}
          </Button>
        </div>
      </div>

      {/* The floor matters: on a short viewport (or a phone with the keyboard up)
          the stacked filters would otherwise squeeze the grid to nothing. Below
          it the page simply outgrows the shell and <main> scrolls, which beats
          a frozen toolbar sitting on top of an invisible grid. */}
      <div className="flex min-h-[16rem] flex-1 flex-col bg-card border rounded-xl overflow-hidden shadow-sm">
        {/* The one scrolling region on the page: the filters, the group-by bar,
            the column headers and the pager all hold their place. */}
        <div className="min-h-0 flex-1 overflow-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="text-xs font-semibold uppercase tracking-wider text-primary-foreground">
              <th className="sticky top-0 z-20 px-2 py-1.5 w-8 text-left" style={STICKY_HEADER_BG}>
                <Checkbox
                  checked={allOpenSelected}
                  onCheckedChange={(c) => toggleAll(c === true)}
                  disabled={openEvents.length === 0}
                  aria-label={t('district.select_all')}
                  className="border-header-dim data-[state=checked]:bg-white data-[state=checked]:text-primary"
                />
              </th>
              {orderedVisibleCols.map(key => {
                const col = ALL_COLUMNS.find(c => c.key === key)!;
                const centered = CENTERED_KEYS.has(key);
                return (
                  <th
                    key={key}
                    className={cn(
                      'sticky top-0 z-20 px-2 py-1.5 whitespace-nowrap cursor-move select-none transition-colors',
                      centered ? 'text-center' : 'text-left',
                      dragCol === key && 'opacity-50'
                    )}
                    style={{
                      ...(dropTarget === key ? STICKY_HEADER_DROP : STICKY_HEADER_BG),
                      // The one column that absorbs the table's leftover width,
                      // so the frozen panel keeps its exact width.
                      ...(key === flexColKey ? { width: '100%' } : null),
                    }}
                  >
                    {/* Both halves of the drag live on this inner div rather than on
                        the cell. The header cells have to stay sticky to hold their
                        place while rows scroll, and a sticky element neither starts a
                        native drag nor receives one. */}
                    <div
                      draggable
                      onDragStart={e => { setDragCol(key); e.dataTransfer.effectAllowed = 'move'; e.dataTransfer.setData('text/plain', key); }}
                      onDragEnd={() => { setDragCol(null); setDropTarget(null); }}
                      onDragOver={e => { if (dragCol && dragCol !== key) { e.preventDefault(); setDropTarget(key); } }}
                      onDragLeave={() => setDropTarget(prev => (prev === key ? null : prev))}
                      onDrop={e => { e.preventDefault(); if (dragCol && dragCol !== key) moveColumn(dragCol, key); setDragCol(null); setDropTarget(null); }}
                      className={cn('flex items-center gap-0.5', centered && 'justify-center')}
                    >
                      <GripVertical className="h-3 w-3 shrink-0 text-header-dim" />
                      <SortHeader label={col.label} hideLabel={col.hideLabel} column={key} sortColumn={sortColumn} sortDirection={sortDirection} onSort={toggleSort} />
                    </div>
                  </th>
                );
              })}
              {/* The panel's header band: one cell covering the whole frozen
                  panel, so it can never fall out of step with the panel below
                  it. Frozen both ways -- against sideways scrolling like the
                  cells below, and against vertical scrolling like the rest of
                  the header, so it outranks both. Not draggable, droppable or
                  sortable: it is chrome, not part of the reorderable set. */}
              <th
                className="sticky right-0 top-0 z-30"
                style={{
                  ...STICKY_HEADER_BG,
                  ...PANEL_CELL_STYLE,
                  boxShadow: `${PINNED_LEFT_SHADOW}, inset 0 -1px 0 rgba(0, 0, 0, 0.25)`,
                }}
              >
                <div className="flex items-center py-2" style={PANEL_INNER_STYLE}>
                  <span className="sr-only">Status / Type / Source / Severity</span>
                  <span className="ml-auto font-semibold uppercase tracking-wider text-xs text-white pr-1">Photo</span>
                </div>
              </th>
            </tr>
          </thead>
          <tbody className="divide-y">
        {isLoadingEvents ? (
          <tr><td colSpan={orderedVisibleCols.length + 2} className="p-4">
            <div className="space-y-4">
              {[1,2,3,4,5].map(i => <Skeleton key={i} className="h-12 w-full" />)}
            </div>
          </td></tr>
        ) : isEventsError ? (
          // The request failed — don't imply the queue is empty.
          <tr><td colSpan={orderedVisibleCols.length + 2} className="p-4">
            <LoadError message={t('district.events_load_failed')} onRetry={() => void refetchEvents()} />
          </td></tr>
        ) : events?.length === 0 ? (
          <tr><td colSpan={orderedVisibleCols.length + 2} className="p-12 text-center text-muted-foreground">
            <CheckCircle2 className="h-12 w-12 mx-auto mb-4 opacity-20" />
            <p className="text-lg">{t('district.no_events')}</p>
          </td></tr>
        ) : (
            (() => {
              const renderCell = (key: SortColumn, event: NonNullable<typeof events>[number]) => {
                switch (key) {
                  case 'status':
                    // Folded into the marks cell; it is no longer a column of its
                    // own, but a layout saved before that can still name it.
                    return null;
                  case 'customer':
                    return (
                      <td key={key} className="px-2 py-1 min-w-[140px]">
                        <div className="font-medium text-xs group-hover:text-primary transition-colors line-clamp-1">{event.customerName}</div>
                        <div className="text-xs text-muted-foreground font-mono">{event.accountNumber}</div>
                      </td>
                    );
                  case 'type':
                    // Now lives in the pinned marks cell beside the photo panel;
                    // kept only so a layout saved while it was still a reorderable
                    // column cannot break.
                    return null;
                  case 'severity':
                    // Folded into the marks cell above; kept only so a layout saved
                    // while it was still a column of its own cannot break.
                    return null;
                  case 'date':
                    return (
                      <td key={key} className="px-2 py-1 whitespace-nowrap">
                        <div className="text-xs">{formatDate(event.dateOccurred, { hour: undefined, minute: undefined })}</div>
                        <div className="text-xs text-muted-foreground font-mono">
                          {formatDate(event.dateOccurred, { year: undefined, month: undefined, day: undefined })}
                        </div>
                      </td>
                    );
                  case 'route':
                    return (
                      <td key={key} className="px-2 py-1">
                        <div className="font-mono text-xs">{event.route}</div>
                        <div className="text-muted-foreground font-mono text-xs">{event.vehicle}</div>
                      </td>
                    );
                  case 'qty':
                    return <td key={key} className="px-2 py-1 text-xs font-mono text-center">{event.quantity ?? '—'}</td>;
                  case 'binSerial':
                    return <td key={key} className="px-2 py-1 text-xs font-mono whitespace-nowrap text-center">{event.binSerialNumber ?? '—'}</td>;
                  case 'stop':
                    return <td key={key} className="px-2 py-1 text-xs font-mono">{event.stop ?? '—'}</td>;
                  case 'wo':
                    return <td key={key} className="px-2 py-1 text-xs font-mono whitespace-nowrap">{event.workOrderNumber ?? '—'}</td>;
                  case 'address':
                    return <td key={key} className="px-2 py-1 text-xs min-w-[130px]">{event.address}</td>;
                  case 'lob':
                    return <td key={key} className="px-2 py-1 text-xs">{event.lob ?? '—'}</td>;
                  case 'tabletNotes':
                    return <td key={key} className="px-2 py-1 text-xs min-w-[115px]">{event.tabletNotes ?? '—'}</td>;
                  case 'chgAmt':
                    return <td key={key} className="px-2 py-1 text-xs font-mono whitespace-nowrap text-center">{event.chargedAmount != null ? formatCurrency(event.chargedAmount) : '—'}</td>;
                  case 'prevChg':
                    return <td key={key} className="px-2 py-1 text-xs font-mono text-center">{event.prevChargeCount}</td>;
                  case 'prevTotal':
                    return <td key={key} className="px-2 py-1 text-xs font-mono whitespace-nowrap text-center">{formatCurrency(event.prevChargeTotal)}</td>;
                }
              };

              const rows: React.ReactNode[] = [];
              let prevGroup: string | null = null;
              // checkbox column + the visible columns + the one pinned panel cell.
              const colSpan = orderedVisibleCols.length + 2;
              pagedEvents?.forEach(event => {
                if (groupBy) {
                  const gv = groupValue(groupBy, event);
                  if (gv !== prevGroup) {
                    prevGroup = gv;
                    rows.push(
                      <tr key={`group-${gv}`} className="bg-muted/50">
                        <td colSpan={colSpan - 1} className="px-2 py-1 text-xs font-semibold">
                          {ALL_COLUMNS.find(c => c.key === groupBy)?.label}: {gv}
                          <span className="ml-2 font-normal text-muted-foreground">({groupCounts?.get(gv) ?? 0})</span>
                        </td>
                        {/* Group rows need the frozen panel too, otherwise the
                            panel has a hole at every group break and the label
                            scrolls through it. Opaque equivalent of this row's
                            bg-muted/50, same single cell as every other row. */}
                        <td
                          className="sticky right-0 z-10 border-l"
                          style={{
                            ...PANEL_CELL_STYLE,
                            backgroundColor: 'hsl(var(--card))',
                            backgroundImage: 'linear-gradient(hsl(var(--muted) / 0.5), hsl(var(--muted) / 0.5))',
                            boxShadow: PINNED_LEFT_SHADOW,
                          }}
                        >
                          <div className="py-1" style={PANEL_INNER_STYLE} />
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
                    <td className="px-2 py-1 w-8" onClick={e => e.stopPropagation()}>
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
                    {/* The frozen panel: marks and photo in ONE pinned cell, so
                        there is no offset to get wrong and no seam between them
                        for a scrolling column to show through. It carries the
                        row's only divider and edge shadow, and repeats the
                        row's hover tint as an opaque overlay -- a translucent
                        background here would let the columns underneath through. */}
                    <td
                      data-pinned-marks=""
                      className="sticky right-0 z-10 bg-card border-l group-hover:[background-image:linear-gradient(hsl(var(--muted)/0.3),hsl(var(--muted)/0.3))]"
                      style={{ ...PANEL_CELL_STYLE, boxShadow: PINNED_LEFT_SHADOW }}
                    >
                      <div className="flex items-center gap-2 py-1" style={PANEL_INNER_STYLE}>
                        <div className="shrink-0" style={{ width: PANEL_MARKS_W }}>
                          <div className="flex items-center gap-1.5">
                            <EventStatusGlyph
                              open={event.eventStatus === 0}
                              openLabel={t('event.status_open')}
                              closedLabel={t('event.status_closed')}
                            />
                            <EventTypeGlyph name={event.eventTypeName} />
                            <EventSourceGlyph name={event.eventSourceName} />
                          </div>
                          {event.severity ? (
                            <div className="mt-0.5">
                              <Badge
                                variant="outline"
                                className={cn(
                                  'border-0 px-1.5 py-0 text-[10px]',
                                  event.severity.toLowerCase() === 'severe'
                                    ? 'bg-destructive/10 text-destructive'
                                    : 'bg-muted text-muted-foreground'
                                )}
                              >
                                {event.severity}
                              </Badge>
                            </div>
                          ) : null}
                        </div>
                        {/* The click-stop stays wrapped around the photo controls
                            only: clicking the icons half still opens the event,
                            as it does anywhere else in the row. */}
                        <div
                          className="flex flex-1 items-center justify-end gap-1.5 min-w-0 overflow-hidden"
                          onClick={e => e.stopPropagation()}
                        >
                          {(event.imageUrls?.length ?? 0) > 0 && (
                            <span className="flex items-center gap-1 text-xs text-muted-foreground shrink-0">
                              <Camera className="h-3.5 w-3.5" />
                              {event.imageUrls.length}
                            </span>
                          )}
                          {event.imageUrl ? (
                            <EventThumbnail
                              imageUrl={event.imageUrl}
                              alt={`${event.customerName} photo`}
                              onHoverStart={(el) => handleThumbnailEnter(event.id, el)}
                              onHoverEnd={handleThumbnailLeave}
                              onNavigate={() => setLocation(`/districts/${districtId}/events/${event.id}`)}
                            />
                          ) : (
                            <span
                              className="text-xs text-muted-foreground italic truncate"
                              title={t('event.no_photo')}
                            >
                              {t('event.no_photo_short')}
                            </span>
                          )}
                        </div>
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
          <div className="flex flex-col sm:grid sm:grid-cols-[minmax(0,1fr)_auto_minmax(0,1fr)] items-center gap-3 px-3 py-2 border-t bg-muted/20 text-sm">
            <div className="flex items-center gap-2 text-muted-foreground sm:justify-self-start">
              <span>
                {t('district.page_info', {
                  from: (currentPage - 1) * pageSize + 1,
                  to: Math.min(currentPage * pageSize, totalRows),
                  total: totalRows,
                })}
              </span>
              <Select value={String(pageSize)} onValueChange={v => { setPageSize(Number(v)); setPage(1); }}>
                <SelectTrigger className="h-7 w-[110px]">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {PAGE_SIZES.map(n => (
                    <SelectItem key={n} value={String(n)}>{t('district.per_page', { n })}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="text-muted-foreground sm:justify-self-center" data-testid="grid-total-rows">
              {t(totalRows === 1 ? 'district.total_rows_one' : 'district.total_rows', { count: totalRows })}
            </div>
            <div className="flex items-center gap-1 sm:justify-self-end">
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

      {previewEvent && (
        <EventPhotoPreview
          event={previewEvent}
          anchorRef={previewAnchorRef}
          onPointerEnter={clearPreviewCloseTimer}
          onPointerLeave={schedulePreviewClose}
          onDismiss={closePreview}
          onCharge={(ids) => { closePreview(); setChargeNearbyPreset(ids); setChargeEventId(previewEvent.id); }}
          onClose={() => { closePreview(); setCloseNearbyPreset([]); setCloseEventId(previewEvent.id); }}
          onCloseWithDuplicates={(ids) => { closePreview(); setCloseNearbyPreset(ids); setCloseEventId(previewEvent.id); }}
        />
      )}

      {serviceCodes && (
        <BulkChargeDialog
          open={bulkChargeOpen}
          onOpenChange={setBulkChargeOpen}
          eventIds={Array.from(selectedIds)}
          serviceCodes={serviceCodes}
          onDone={handleBulkChargeDone}
        />
      )}
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
/**
 * Photo cell thumbnail. Purely presentational: it reports hover enter/leave and
 * clicks to the table's shared preview controller and owns no preview state, so
 * only one preview is ever on screen no matter how many rows are hovered.
 */
function EventThumbnail({ imageUrl, alt, onHoverStart, onHoverEnd, onNavigate }: {
  imageUrl: string;
  alt: string;
  onHoverStart: (el: HTMLElement) => void;
  onHoverEnd: () => void;
  onNavigate: () => void;
}) {
  return (
    <div
      onClick={onNavigate}
      onMouseEnter={e => onHoverStart(e.currentTarget)}
      onMouseLeave={onHoverEnd}
      className="h-10 w-16 rounded overflow-hidden border bg-muted/50 cursor-pointer"
      data-event-thumbnail=""
    >
      <img
        src={imageUrl}
        alt={alt}
        loading="lazy"
        className="h-full w-full object-cover"
        onError={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }}
      />
    </div>
  );
}

/** Where the preview panel sits relative to the frozen photo column. */
type PreviewPlacement = { mode: 'beside'; right: number; width: number } | { mode: 'center' };

/**
 * Place the panel to the left of the frozen photo column so the thumbnails stay
 * hoverable; if there isn't room for a usable panel (narrow viewport), fall back
 * to a centered one.
 */
const computePreviewPlacement = (anchor: HTMLElement | null): PreviewPlacement => {
  if (!anchor || !anchor.isConnected) return { mode: 'center' };
  // clientWidth, not innerWidth: a fixed element is laid out against the
  // viewport minus the scrollbar, so innerWidth would push the panel off the
  // left edge by the scrollbar's width.
  const viewportWidth = document.documentElement.clientWidth;
  const columnLeft = anchor.getBoundingClientRect().left;
  const right = Math.max(PREVIEW_GAP, viewportWidth - columnLeft + PREVIEW_GAP);
  const available = viewportWidth - right - PREVIEW_GAP;
  if (available < PREVIEW_MIN_WIDTH) return { mode: 'center' };
  return { mode: 'beside', right, width: Math.min(896, available) };
};

/**
 * The single shared photo preview. Mounted by the table for whichever event is
 * currently being previewed; swapping rows re-renders this same panel rather
 * than closing and reopening a per-row one.
 */
function EventPhotoPreview({ event, anchorRef, onPointerEnter, onPointerLeave, onDismiss, onCharge, onClose, onCloseWithDuplicates }: {
  event: any;
  anchorRef: React.MutableRefObject<HTMLElement | null>;
  onPointerEnter: () => void;
  onPointerLeave: () => void;
  onDismiss: () => void;
  onCharge: (checkedDuplicateIds: number[]) => void;
  onClose: () => void;
  onCloseWithDuplicates: (ids: number[]) => void;
}) {
  const { t } = useI18n();
  const panelRef = useRef<HTMLDivElement | null>(null);
  const [selectedImage, setSelectedImage] = useState<string>(event.imageUrl);
  const [hoveredImage, setHoveredImage] = useState<string | null>(null);
  const [checkedNearby, setCheckedNearby] = useState<Set<number>>(new Set());
  // Detail (and therefore Nearby Overages) is only requested once the pointer
  // has settled on a row, so sliding through the column doesn't fan out one
  // request per row skimmed past.
  const [settled, setSettled] = useState(false);

  // Reset every piece of per-event state the moment the previewed event
  // changes, before this render's children see it — otherwise a fast slide can
  // paint one frame of the previous row's image or checkbox selection.
  const [renderedEventId, setRenderedEventId] = useState<number>(event.id);
  if (renderedEventId !== event.id) {
    setRenderedEventId(event.id);
    setSelectedImage(event.imageUrl);
    setHoveredImage(null);
    setCheckedNearby(new Set());
    setSettled(false);
  }

  const toggleNearby = (id: number) => {
    setCheckedNearby(prev => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id); else next.add(id);
      return next;
    });
  };

  useEffect(() => {
    setSettled(false);
    const timer = setTimeout(() => setSettled(true), PREVIEW_DETAIL_SETTLE_DELAY);
    return () => clearTimeout(timer);
  }, [event.id]);

  // Escape dismisses.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') onDismiss(); };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onDismiss]);

  // There is no click-blocking backdrop any more (it would steal hover from the
  // photo column), so outside clicks are caught here instead.
  useEffect(() => {
    const onPointerDown = (e: MouseEvent) => {
      const target = e.target as Node | null;
      if (target && panelRef.current?.contains(target)) return;
      onDismiss();
    };
    document.addEventListener('mousedown', onPointerDown);
    return () => document.removeEventListener('mousedown', onPointerDown);
  }, [onDismiss]);

  // Measured before the first paint so the panel never lands centered and then
  // jumps sideways.
  const [placement, setPlacement] = useState<PreviewPlacement>(() => computePreviewPlacement(anchorRef.current));
  useLayoutEffect(() => {
    const measure = () => setPlacement(computePreviewPlacement(anchorRef.current));
    measure();
    window.addEventListener('resize', measure);
    return () => window.removeEventListener('resize', measure);
    // Re-measure per previewed event: rows share the frozen column, but the
    // anchor element itself changes as the pointer moves down the column.
  }, [anchorRef, event.id]);

  // Load the full event detail (includes nearby events) once the pointer settles
  const { data: detail, isLoading: isLoadingDetail } = useGetEvent(event.id, {
    query: { enabled: settled, queryKey: getGetEventQueryKey(event.id) }
  });
  // Guard against a late response for a row we've already slid past.
  const nearbyEvents = detail?.id === event.id ? detail?.nearbyEvents : undefined;
  const isLoadingNearby = !settled || isLoadingDetail || detail?.id !== event.id;

  // Forward-compatible with a multi-image data model (Task on detail page):
  // if the API exposes an image list use it, otherwise fall back to the single image.
  const images: string[] = Array.isArray(event.imageUrls) && event.imageUrls.length > 0
    ? event.imageUrls
    : [event.imageUrl];
  const isOpen = event.eventStatus === 0;

  // Rendered into <body> rather than in place. The photo cell is
  // `position: sticky` with a z-index, which makes it its own stacking context —
  // any z-index the panel sets would be confined to it, so the sticky cells of
  // later rows would paint on top no matter how high we go. The portal is the
  // fix; the z-index below only has to clear the app header.
  return createPortal(
    <div
      ref={panelRef}
      role="dialog"
      aria-label={`${event.customerName} photo preview`}
      onMouseEnter={onPointerEnter}
      onMouseLeave={onPointerLeave}
      className={cn(
        'fixed top-1/2 z-[60] max-h-[90vh] -translate-y-1/2 overflow-y-auto rounded-lg border bg-background p-4 shadow-2xl space-y-3 animate-in fade-in-0 zoom-in-95',
        placement.mode === 'center' && 'left-1/2 -translate-x-1/2 w-[min(56rem,calc(100vw-2rem))]'
      )}
      style={placement.mode === 'beside' ? { right: placement.right, width: placement.width } : undefined}
      data-testid="event-photo-preview"
      data-preview-event-id={event.id}
    >
      <div className="flex gap-3">
        <div className="flex-1 bg-muted rounded-lg overflow-hidden aspect-video flex items-center justify-center">
          <img
            key={hoveredImage ?? selectedImage}
            src={hoveredImage ?? selectedImage}
            alt="Event preview"
            className="object-contain w-full h-full"
            onError={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }}
          />
        </div>
        {/* Right rail: close, actions, thumbnails */}
        <div className="flex flex-col items-center gap-2 w-20 shrink-0">
          <button
            type="button"
            onClick={onDismiss}
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
                  onMouseEnter={() => setHoveredImage(url)}
                  onMouseLeave={() => setHoveredImage(null)}
                  onFocus={() => setHoveredImage(url)}
                  onBlur={() => setHoveredImage(null)}
                  onClick={() => setSelectedImage(url)}
                  className={cn(
                    'h-12 w-16 shrink-0 rounded overflow-hidden border-2 transition-colors',
                    (hoveredImage ?? selectedImage) === url ? 'border-primary' : 'border-transparent hover:border-muted-foreground/40'
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
        {isLoadingNearby ? (
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
    </div>,
    document.body
  );
}
