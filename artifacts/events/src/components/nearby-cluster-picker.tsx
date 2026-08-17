import React from 'react';
import { Checkbox } from '@/components/ui/checkbox';
import { Badge } from '@/components/ui/badge';
import { HoverCard, HoverCardContent, HoverCardTrigger } from '@/components/ui/hover-card';
import { Images } from 'lucide-react';
import { useI18n } from '@/i18n';

export interface NearbyClusterEvent {
  id: number;
  imageUrl?: string | null;
  dateOccurred: string;
  secondsOffset: number;
  status: string; // Open | Charged | Dismissed
  distanceMeters?: number;
  isSuggestedDuplicate?: boolean;
  eventSourceName?: string | null;
  customerName?: string | null;
  accountNumber?: string | null;
}

/** IDs of open nearby events the server suggests as same-cluster duplicates. */
export function suggestedDuplicateIds(nearby: NearbyClusterEvent[] | undefined): number[] {
  return (nearby ?? [])
    .filter(n => n.status === 'Open' && n.isSuggestedDuplicate)
    .map(n => n.id);
}

/**
 * Reusable nearby-cluster list with a checkbox per open duplicate, showing
 * status, source, time offset and distance. Used inside charge/close flows.
 */
export function NearbyClusterPicker({ nearby, checked, onToggle, anchorAccountNumber, title }: {
  nearby: NearbyClusterEvent[];
  checked: Set<number>;
  onToggle: (id: number) => void;
  anchorAccountNumber?: string | null;
  title?: string | null;
}) {
  const { t, formatDate } = useI18n();

  if (nearby.length === 0) return null;

  const formatOffset = (seconds: number) => {
    const abs = Math.abs(seconds);
    const dir = seconds < 0 ? 'before' : 'after';
    if (abs < 60) return t(`event.nearby.offset_sec_${dir}` as any, { s: abs });
    return t(`event.nearby.offset_min_${dir}` as any, { m: Math.floor(abs / 60) });
  };

  return (
    <div className="space-y-2" data-testid="nearby-cluster-picker">
      {title !== null && <p className="text-sm font-medium">{title ?? t('nearby_picker.label')}</p>}
      <div className="border rounded-md divide-y max-h-56 overflow-y-auto">
        {nearby.map(n => {
          const isOpen = n.status === 'Open';
          const accountMismatch = !!n.accountNumber && !!anchorAccountNumber && n.accountNumber !== anchorAccountNumber;
          return (
            <label
              key={n.id}
              className={`flex items-center gap-3 p-2 text-sm ${isOpen ? 'cursor-pointer hover:bg-muted/30' : 'opacity-60'} ${accountMismatch ? 'bg-destructive/10' : ''}`}
              data-testid={`nearby-picker-row-${n.id}`}
            >
              {isOpen ? (
                <Checkbox
                  checked={checked.has(n.id)}
                  onCheckedChange={() => onToggle(n.id)}
                  aria-label={`Select nearby event ${n.id}`}
                />
              ) : (
                <span className="block w-4 shrink-0" />
              )}
              {n.imageUrl ? (
                <HoverCard openDelay={150} closeDelay={100}>
                  <HoverCardTrigger asChild>
                    <img src={n.imageUrl} className="w-10 h-8 object-cover rounded shrink-0" alt="" />
                  </HoverCardTrigger>
                  {/*
                    Centred on the row rather than top-aligned, so a row near the
                    bottom of the screen only has half a card below it to fit.
                    z-[70] clears the photo preview panel and the action dialogs
                    this picker also appears inside.
                  */}
                  <HoverCardContent side="right" align="center" sideOffset={8} className="w-auto p-1 z-[70]">
                    {/*
                      Fixed 16:9 box, not an auto-height <img>. The photo has no
                      intrinsic size until it loads, so an auto-height card is
                      measured as a sliver, placed, and only then grows -- downward,
                      past the point collision detection had cleared.
                    */}
                    <div className="w-80 max-w-[70vw] aspect-video overflow-hidden rounded bg-muted">
                      <img src={n.imageUrl} className="h-full w-full object-contain" alt="" />
                    </div>
                  </HoverCardContent>
                </HoverCard>
              ) : (
                <div className="w-10 h-8 rounded bg-muted flex items-center justify-center shrink-0">
                  <Images className="w-3 h-3 text-muted-foreground" />
                </div>
              )}
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-2">
                  <span className="whitespace-nowrap">
                    {formatDate(n.dateOccurred, { hour: 'numeric', minute: '2-digit' })}
                  </span>
                  <span className="font-mono text-xs text-muted-foreground">{formatOffset(n.secondsOffset)}</span>
                  {n.isSuggestedDuplicate && isOpen && (
                    <Badge className="bg-warning/20 text-warning-foreground border-0 text-[10px] px-1.5 py-0 bg-amber-100 text-amber-800">
                      {t('nearby_picker.suggested')}
                    </Badge>
                  )}
                </div>
                <div className="flex items-center gap-2 text-xs text-muted-foreground">
                  {n.eventSourceName && <span className="truncate">{n.eventSourceName}</span>}
                  {typeof n.distanceMeters === 'number' && (
                    <span className="font-mono whitespace-nowrap">{t('nearby_picker.distance_m', { m: n.distanceMeters })}</span>
                  )}
                  {n.customerName && <span className={`truncate ${accountMismatch ? 'text-destructive' : ''}`}>{n.customerName}</span>}
                </div>
              </div>
              {/* Green only for Open: it marks the rows still worth acting on,
                  so Charged and Dismissed stay a plain outline pill. */}
              <Badge
                variant="outline"
                className={`text-[10px] shrink-0 ${isOpen ? 'border-transparent bg-success text-success-foreground' : ''}`}
              >
                {t(`event.nearby.status_${n.status.toLowerCase()}` as any)}
              </Badge>
            </label>
          );
        })}
      </div>
    </div>
  );
}
