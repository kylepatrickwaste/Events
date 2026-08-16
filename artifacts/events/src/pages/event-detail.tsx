import React, { useState, useEffect } from 'react';
import { triggerTruckDrive } from '@/components/layout/TruckDrive';
import { useRoute, useLocation, Link } from 'wouter';
import {
  useGetEvent, getGetEventQueryKey,
  useAddEventNote,
  useChargeEvent,
  useEmailEvent,
  useCloseEvent,
  useListDistrictServiceCodes, getListDistrictServiceCodesQueryKey
} from '@workspace/api-client-react';
import { useQueryClient } from '@tanstack/react-query';
import { useI18n } from '@/i18n';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Checkbox } from '@/components/ui/checkbox';
import { useToast } from '@/hooks/use-toast';
import {
  ChevronLeft,
  MapPin,
  Clock,
  Camera,
  AlertTriangle,
  DollarSign,
  Mail,
  XCircle,
  Copy,
  CheckCircle2,
  Send,
  MessageSquare,
  Images
} from 'lucide-react';
import { z } from 'zod';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from '@/components/ui/form';
import { NearbyClusterPicker, suggestedDuplicateIds } from '@/components/nearby-cluster-picker';
import { LoadError } from '@/components/load-error';

export default function EventDetailWorkspace() {
  const [, params] = useRoute('/districts/:districtId/events/:eventId');
  const districtId = Number(params?.districtId);
  const eventId = Number(params?.eventId);
  const [, setLocation] = useLocation();
  const { t, formatDate, formatCurrency } = useI18n();
  const queryClient = useQueryClient();
  const { toast } = useToast();

  const { data: event, isLoading, isError, refetch } = useGetEvent(eventId, {
    query: { enabled: !!eventId, queryKey: getGetEventQueryKey(eventId) }
  });

  const { data: serviceCodes } = useListDistrictServiceCodes(districtId, {
    query: { enabled: !!districtId, queryKey: getListDistrictServiceCodesQueryKey(districtId) }
  });

  const isClosed = event?.eventStatus === 1;

  // Dialog States
  const [chargeOpen, setChargeOpen] = useState(false);
  const [emailOpen, setEmailOpen] = useState(false);
  const [closeOpen, setCloseOpen] = useState(false);

  // Interaction States
  const [selectedImage, setSelectedImage] = useState<string | null>(null);
  const [hoveredImage, setHoveredImage] = useState<string | null>(null);
  const [checkedNearby, setCheckedNearby] = useState<Set<number>>(new Set());

  // Reset local state when eventId changes
  useEffect(() => {
    setSelectedImage(null);
    setHoveredImage(null);
    setCheckedNearby(new Set());
  }, [eventId]);

  const handleActionSuccess = () => {
    queryClient.invalidateQueries({ queryKey: getGetEventQueryKey(eventId) });
    setChargeOpen(false);
    setEmailOpen(false);
    setCloseOpen(false);
  };

  const copyLink = (url?: string) => {
    if (!url) return;
    navigator.clipboard.writeText(url);
    toast({ description: t('event.link_copied') });
  };

  const toggleNearby = (id: number) => {
    setCheckedNearby(prev => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  if (isLoading) {
    return <div className="container mx-auto p-6 max-w-7xl"><Skeleton className="h-[800px] w-full" /></div>;
  }
  if (isError || !event) {
    // Previously this rendered nothing, so a failed request looked like a blank
    // page. Say what happened and offer a way back.
    return (
      <div className="container mx-auto p-6 max-w-3xl">
        <div className="rounded-xl border border-dashed bg-muted/30">
          <LoadError message={t('event.load_failed')} onRetry={() => void refetch()} />
        </div>
        <div className="mt-4 text-center">
          <Link
            href={`/districts/${districtId}`}
            className="inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground"
          >
            <ChevronLeft className="h-4 w-4" />
            {t('event.back')}
          </Link>
        </div>
      </div>
    );
  }

  const images = event.imageUrls?.length ? event.imageUrls : (event.imageUrl ? [event.imageUrl] : []);
  const displayImage = hoveredImage || selectedImage || images[0];

  const formatOffset = (seconds: number) => {
    const abs = Math.abs(seconds);
    const dir = seconds < 0 ? 'before' : 'after';
    if (abs < 60) return t(`event.nearby.offset_sec_${dir}` as any, { s: abs });
    return t(`event.nearby.offset_min_${dir}` as any, { m: Math.floor(abs / 60) });
  };

  return (
    <div className="container mx-auto py-3 px-4 max-w-7xl">
      {/* The header's customer-name link goes to the same place, but it reads as
          a title rather than a control, so give the page its own back button. */}
      <Link
        href={`/districts/${districtId}`}
        className="group mb-3 -ml-2 inline-flex items-center gap-1 rounded-md px-2 py-1 text-sm font-medium text-muted-foreground transition-colors hover:bg-accent hover:text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
      >
        <ChevronLeft className="h-4 w-4 transition-transform group-hover:-translate-x-0.5" />
        {t('event.back')}
      </Link>
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left Column: Image, Stats, Details */}
        <div className="lg:col-span-2 space-y-6">
          
          {/* Event Detail */}
          <Card className="shadow-sm overflow-hidden">
            <CardHeader className={`py-2 ${event.severity === 'Severe' ? 'bg-destructive' : 'bg-primary'}`}>
              <CardTitle className={`text-sm ${event.severity === 'Severe' ? 'text-destructive-foreground' : 'text-primary-foreground'}`}>
                {event.severity === 'Severe'
                  ? t('event.detail_severe')
                  : event.severity
                    ? t('event.detail_minimal')
                    : t('event.detail')}
              </CardTitle>
            </CardHeader>
            <CardContent className="py-3">
              <div className="grid grid-cols-2 md:grid-cols-3 gap-x-6 gap-y-2 text-xs">
                <DetailRow
                  label={t('event.account')}
                  value={
                    <span className="flex items-center gap-2">
                      <span className="font-mono">{event.accountNumber}</span>
                      {isClosed ? (
                        <Badge variant="outline" className="border-muted-foreground/30 text-muted-foreground text-[10px] px-1.5 py-0">
                          {t('event.status_closed')}
                        </Badge>
                      ) : (
                        <Badge className="bg-primary/10 text-primary hover:bg-primary/20 border-0 text-[10px] px-1.5 py-0">
                          {t('event.status_open')}
                        </Badge>
                      )}
                    </span>
                  }
                />
                <DetailRow label={t('event.occurred')} value={formatDate(event.dateOccurred)} />
                <DetailRow label={t('event.source')} value={event.eventSourceName} />
                <DetailRow label={t('district.address')} value={event.address} />
                <DetailRow label={t('event.vehicle')} value={event.vehicle} mono />
                <DetailRow label={t('event.bin_serial')} value={event.binSerialNumber} mono />
                <DetailRow label={t('event.event_type')} value={event.eventTypeName} />
                <DetailRow label={t('event.details_field')} value={event.details} />
                <DetailRow label={t('event.quantity')} value={event.quantity != null ? String(event.quantity) : null} mono />
                <DetailRow label={t('event.bill_area')} value={event.billArea} mono />
                <DetailRow label={t('event.lob')} value={event.lob} />
                <DetailRow label={t('event.route')} value={event.route} mono />
                <DetailRow label={t('event.latitude')} value={event.latitude != null ? event.latitude.toFixed(6) : null} mono />
                <DetailRow label={t('event.longitude')} value={event.longitude != null ? event.longitude.toFixed(6) : null} mono />
                {isClosed && event.closedBy && (
                  <DetailRow label={t('event.closed_by')} value={`${event.closedBy} on ${formatDate(event.dateClosed || '')}`} />
                )}
              </div>
            </CardContent>
          </Card>

          {/* Image Gallery */}
          <Card className="overflow-hidden shadow-sm">
            <div className="bg-muted aspect-video relative flex items-center justify-center bg-black/5">
              {displayImage ? (
                <img src={displayImage} alt="Event" className="object-contain w-full h-full" />
              ) : (
                <div className="text-muted-foreground flex flex-col items-center">
                  <Camera className="h-12 w-12 mb-2 opacity-20" />
                  <span>{t('event.no_photo')}</span>
                </div>
              )}
            </div>
            {images.length > 1 && (
              <div className="flex gap-2 p-3 bg-muted/30 border-t overflow-x-auto">
                {images.slice(0, 5).map((img, idx) => (
                  <button 
                    key={idx}
                    onClick={() => setSelectedImage(img)}
                    onMouseEnter={() => setHoveredImage(img)}
                    onMouseLeave={() => setHoveredImage(null)}
                    onFocus={() => setHoveredImage(img)}
                    onBlur={() => setHoveredImage(null)}
                    className={`relative rounded-md overflow-hidden border-2 transition-all w-20 h-16 shrink-0 ${displayImage === img ? 'border-primary shadow-sm' : 'border-transparent opacity-70 hover:opacity-100'}`}
                  >
                    <img src={img} className="w-full h-full object-cover" />
                  </button>
                ))}
              </div>
            )}
          </Card>

          <Card className="shadow-sm">
            <CardHeader className="py-3">
              <CardTitle className="text-base">{t('event.nearby.title')}</CardTitle>
            </CardHeader>
            <CardContent className="pt-0">
              {event.nearbyEvents?.length === 0 ? (
                <p className="text-sm text-muted-foreground italic">{t('event.nearby.empty')}</p>
              ) : (
                <div className="border rounded-md overflow-x-auto">
                  <table className="w-full text-sm">
                    <thead className="bg-muted/50 border-b">
                      <tr>
                        <th className="px-3 py-1 w-8"></th>
                        <th className="px-2 py-1 w-12"></th>
                        <th className="px-3 py-1 text-left font-medium">{t('event.nearby.business')}</th>
                        <th className="px-3 py-1 text-left font-medium">{t('event.nearby.account')}</th>
                        <th className="px-3 py-1 text-left font-medium">{t('event.nearby.bin_serial')}</th>
                        <th className="px-3 py-1 text-left font-medium">{t('event.nearby.truck')}</th>
                        <th className="px-3 py-1 text-left font-medium">{t('district.date')}</th>
                        <th className="px-3 py-1 text-right font-medium">{t('district.status')}</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y">
                      {event.nearbyEvents?.map(nearby => {
                        const accountMismatch = !!nearby.accountNumber && nearby.accountNumber !== event.accountNumber;
                        return (
                          <tr
                            key={nearby.id}
                            className={`transition-colors ${accountMismatch ? 'bg-destructive/10 hover:bg-destructive/15 text-destructive' : 'hover:bg-muted/30'}`}
                          >
                            <td className="px-3 py-1">
                              <Checkbox 
                                checked={checkedNearby.has(nearby.id)} 
                                onCheckedChange={() => toggleNearby(nearby.id)} 
                              />
                            </td>
                            <td className="px-2 py-1">
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
                            <td className="px-3 py-1">{nearby.customerName ?? '—'}</td>
                            <td className={`px-3 py-1 font-mono text-xs ${accountMismatch ? 'font-bold' : ''}`}>
                              {nearby.accountNumber ?? '—'}
                            </td>
                            <td className="px-3 py-1 font-mono text-xs">{nearby.binSerialNumber ?? '—'}</td>
                            <td className="px-3 py-1 font-mono text-xs">{nearby.vehicle ?? '—'}</td>
                            <td className="px-3 py-1 whitespace-nowrap">
                              <Link href={`/districts/${districtId}/events/${nearby.id}`} className={`hover:underline ${accountMismatch ? 'text-destructive' : 'text-primary'}`}>
                                {formatDate(nearby.dateOccurred, { hour: 'numeric', minute: '2-digit' })}
                              </Link>
                              <span className={`ml-2 font-mono text-xs ${accountMismatch ? 'text-destructive/80' : 'text-muted-foreground'}`}>
                                {formatOffset(nearby.secondsOffset)}
                              </span>
                            </td>
                            <td className="px-3 py-1 text-right">
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
            </CardContent>
          </Card>
        </div>

        {/* Right Column: Timeline */}
        <div className="space-y-6">
          {!isClosed && (
            <div className="flex justify-end items-center gap-2">
              <Button size="sm" onClick={() => setChargeOpen(true)} className="bg-success text-success-foreground hover:bg-success/90">
                <DollarSign className="w-4 h-4 mr-1" />
                {t('event.charge')}
              </Button>
              <Button size="sm" onClick={() => setEmailOpen(true)} variant="secondary">
                <Mail className="w-4 h-4 mr-1" />
                {t('event.email')}
              </Button>
              <Button size="sm" onClick={() => setCloseOpen(true)} variant="destructive">
                <XCircle className="w-4 h-4 mr-1" />
                {t('event.close')}
              </Button>
            </div>
          )}
          <Card className="shadow-sm overflow-hidden">
            <CardContent className="p-0">
              <div className="flex items-center justify-between gap-2 px-3 py-2 border-b bg-muted/10">
                <span className="text-[10px] text-muted-foreground uppercase tracking-wider font-semibold">{t('event.location')}</span>
                {/* Share actions live here now that the simulate tile is gone. This
                    header renders even without coordinates so they never disappear. */}
                <div className="flex gap-2">
                  <Button variant="ghost" size="icon" className="h-6 w-6" onClick={() => copyLink(event.shareLinks?.photo)} title={t('event.copy_link')}>
                    <Camera className="h-3 w-3" />
                  </Button>
                  <Button variant="ghost" size="icon" className="h-6 w-6" onClick={() => copyLink(event.shareLinks?.event)} title={t('event.share')}>
                    <Copy className="h-3 w-3" />
                  </Button>
                </div>
              </div>
              {event.latitude != null && event.longitude != null ? (
                <iframe
                  title={t('event.location')}
                  data-testid="map-event-location"
                  className="block w-full h-52 border-0"
                  loading="lazy"
                  referrerPolicy="no-referrer-when-downgrade"
                  src={`https://maps.google.com/maps?q=${event.latitude},${event.longitude}&z=16&output=embed`}
                />
              ) : (
                <div className="px-3 py-6 text-center text-xs text-muted-foreground">
                  {t('event.no_location')}
                </div>
              )}
            </CardContent>
          </Card>

          {/* Overage Statistics */}
          {event.statistics && (
            <OverageStatisticsTile stats={event.statistics} t={t} formatCurrency={formatCurrency} formatDate={formatDate} />
          )}

          <Card className="shadow-sm flex-1 flex flex-col h-[600px]">
            <CardHeader className="border-b pb-4">
              <CardTitle className="text-lg">{t('event.history_and_notes')}</CardTitle>
            </CardHeader>
            <CardContent className="flex-1 overflow-auto p-0">
              <div className="divide-y">
                {event.actions.length === 0 ? (
                  <div className="p-8 text-center text-muted-foreground italic">
                    {t('event.no_history')}
                  </div>
                ) : (
                  event.actions.map(action => (
                    <div key={action.id} className="p-4 hover:bg-muted/10 transition-colors">
                      <div className="flex items-center gap-2 mb-2">
                        {action.actionType === 'Note' ? <MessageSquare className="h-4 w-4 text-muted-foreground" /> :
                         action.actionType === 'Charge' ? <DollarSign className="h-4 w-4 text-success" /> :
                         action.actionType === 'Email' ? <Mail className="h-4 w-4 text-secondary" /> :
                         <XCircle className="h-4 w-4 text-destructive" />}
                        <span className="font-semibold text-sm">{action.actionType}</span>
                        <span className="text-xs text-muted-foreground ml-auto">{formatDate(action.dateCreated)}</span>
                      </div>
                      <div className="text-sm">
                        {action.actionType === 'Charge' && (
                          <div className="text-success font-medium mb-1">
                            {formatCurrency(action.chargeAmount || 0)} (Qty: {action.chargeQuantity})
                          </div>
                        )}
                        {action.actionType === 'Close' && action.closeReason && (
                          <div className="font-medium mb-1">{action.closeReason}</div>
                        )}
                        {action.notes && <p className="text-muted-foreground whitespace-pre-wrap">{action.notes}</p>}
                      </div>
                      <div className="text-xs text-muted-foreground mt-2">by {action.createdBy}</div>
                    </div>
                  ))
                )}
              </div>
            </CardContent>
            {!isClosed && (
              <div className="p-4 border-t bg-muted/5">
                <NoteForm eventId={eventId} onSuccess={handleActionSuccess} />
              </div>
            )}
          </Card>
        </div>
      </div>

      {/* Dialogs */}
      {serviceCodes && (
        <ChargeDialog 
          open={chargeOpen} 
          onOpenChange={setChargeOpen} 
          eventId={eventId} 
          event={event}
          serviceCodes={serviceCodes}
          onSuccess={handleActionSuccess} 
        />
      )}
      <EmailDialog 
        open={emailOpen} 
        onOpenChange={setEmailOpen} 
        eventId={eventId} 
        event={event}
        onSuccess={handleActionSuccess} 
      />
      <CloseDialog 
        open={closeOpen} 
        onOpenChange={setCloseOpen} 
        eventId={eventId} 
        event={event}
        checkedNearby={checkedNearby}
        onSuccess={handleActionSuccess} 
      />
    </div>
  );
}

function OverageStatisticsTile({ stats, t, formatCurrency, formatDate }: any) {
  // Header cells and window rows share one column template so they stay aligned.
  const columns = "grid grid-cols-[1.4fr_0.6fr_1fr] items-center gap-2 px-3";

  return (
    <Card className="shadow-sm">
      <CardContent className="p-0">
        <div className="grid grid-cols-2 divide-x border-b bg-muted/10">
           <div className="p-2 flex flex-col gap-0.5">
              <span className="text-[10px] text-muted-foreground uppercase tracking-wider font-semibold">{t('event.statistics.customer_since')}</span>
              <span className="font-mono text-xs">{stats.customerSince ? formatDate(stats.customerSince) : t('event.statistics.never')}</span>
           </div>
           <div className="p-2 flex flex-col gap-0.5">
              <span className="text-[10px] text-muted-foreground uppercase tracking-wider font-semibold">{t('event.statistics.last_charge')}</span>
              <span className="font-mono text-xs">{stats.lastChargeDate ? formatDate(stats.lastChargeDate) : t('event.statistics.never')}</span>
           </div>
        </div>
        <div className={`${columns} py-1.5 border-b bg-muted/30 text-[10px] text-muted-foreground font-bold uppercase tracking-widest`}>
          <span>{t('event.statistics.period')}</span>
          <span className="text-right">{t('event.statistics.count')}</span>
          <span className="text-right">{t('event.statistics.charges')}</span>
        </div>
        <div className="divide-y bg-card">
           {stats.windows.map((w: any) => (
             <div key={w.days} className={`${columns} py-1.5 text-xs`}>
               <span className="text-[11px] font-semibold text-muted-foreground">{t(`event.statistics.past_days_${w.days}` as any)}</span>
               <span className="text-right text-destructive font-bold">{w.eventsCount}</span>
               <span className="text-right text-success font-bold">{formatCurrency(w.chargedAmount)}</span>
             </div>
           ))}
        </div>
      </CardContent>
    </Card>
  );
}

function DetailRow({ label, value, icon, mono }: { label: string, value: React.ReactNode, icon?: React.ReactNode, mono?: boolean }) {
  if (value === null || value === undefined || value === '') return null;
  return (
    <div className="flex flex-col gap-1">
      <span className="text-[10px] text-muted-foreground font-semibold uppercase tracking-widest">{label}</span>
      <div className="flex items-center gap-2">
        {icon && <span className="text-muted-foreground">{icon}</span>}
        <span className={mono ? "font-mono" : ""}>{value}</span>
      </div>
    </div>
  );
}

function NoteForm({ eventId, onSuccess }: { eventId: number, onSuccess: () => void }) {
  const { t } = useI18n();
  const { toast } = useToast();
  const [notes, setNotes] = useState('');
  const addNote = useAddEventNote();

  const submit = () => {
    if (!notes.trim()) return;
    addNote.mutate({ eventId, data: { notes } }, {
      onSuccess: () => {
        setNotes('');
        onSuccess();
      },
      onError: () => {
        toast({ variant: 'destructive', description: t('event.note_failed') });
      }
    });
  };

  return (
    <div className="space-y-2">
      <Textarea 
        placeholder={t('event.add_note')}
        value={notes}
        onChange={e => setNotes(e.target.value)}
        className="min-h-[80px] resize-none"
      />
      <div className="flex justify-end">
        <Button size="sm" onClick={submit} disabled={!notes.trim() || addNote.isPending}>
          <Send className="w-3 h-3 mr-2" />
          {t('event.save_note')}
        </Button>
      </div>
    </div>
  );
}

const chargeSchema = z.object({
  serviceCodeId: z.coerce.number().min(1, 'Required'),
  amount: z.coerce.number().min(0),
  quantity: z.coerce.number().min(1),
});

function ChargeDialog({ open, onOpenChange, eventId, event, serviceCodes, onSuccess }: any) {
  const { t, formatCurrency, formatDate } = useI18n();
  const { toast } = useToast();
  const charge = useChargeEvent();
  const [selectedCodeAmount, setSelectedCodeAmount] = useState<number | null>(null);
  const [customAmount, setCustomAmount] = useState('');
  const [checkedNearby, setCheckedNearby] = useState<Set<number>>(new Set());

  const toggleNearby = (id: number) => {
    setCheckedNearby(prev => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id); else next.add(id);
      return next;
    });
  };

  const onCustomAmountChange = (value: string) => {
    setCustomAmount(value);
    const parsed = parseFloat(value);
    if (!isNaN(parsed) && parsed >= 0) {
      form.setValue('amount', parsed as any);
    }
  };
  
  const form = useForm({
    resolver: zodResolver(chargeSchema),
    defaultValues: { serviceCodeId: '', amount: 0, quantity: 1 }
  });

  useEffect(() => {
    if (open) {
      form.reset({ serviceCodeId: '', amount: 0, quantity: 1 });
      setSelectedCodeAmount(null);
      setCustomAmount('');
      setCheckedNearby(new Set(suggestedDuplicateIds(event?.nearbyEvents)));
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, form]);

  const onSelectCode = (idStr: string) => {
    const id = parseInt(idStr);
    form.setValue('serviceCodeId', id as any);
    const code = serviceCodes.find((c: any) => c.id === id);
    if (code) {
      setSelectedCodeAmount(code.amount);
      form.setValue('amount', code.amount);
    }
  };

  const submit = (data: any) => {
    triggerTruckDrive();
    charge.mutate({ eventId, data: { ...data, duplicateEventIds: Array.from(checkedNearby) } }, {
      onSuccess: () => {
        onSuccess();
      },
      onError: () => {
        toast({ variant: 'destructive', description: t('charge.failed') });
      }
    });
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('charge.title')}</DialogTitle>
        </DialogHeader>
        <Form {...form}>
          <form onSubmit={form.handleSubmit(submit)} className="space-y-4">
            <FormField control={form.control} name="serviceCodeId" render={({ field }) => (
              <FormItem>
                <FormLabel>{t('charge.service_code')}</FormLabel>
                <Select onValueChange={onSelectCode} value={field.value?.toString()}>
                  <FormControl>
                    <SelectTrigger><SelectValue placeholder={t('charge.select_code')} /></SelectTrigger>
                  </FormControl>
                  <SelectContent>
                    {serviceCodes.map((c: any) => (
                      <SelectItem key={c.id} value={c.id.toString()}>{c.code} - {c.description}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                <FormMessage />
              </FormItem>
            )} />
            
            <div className="border rounded-md p-4 bg-muted/10 space-y-4">
              <div className="flex justify-between items-center pb-3 border-b border-border/50">
                <span className="font-medium text-sm">{t('charge.service_price')}</span>
                <span className="font-mono text-success font-bold text-lg">
                  {selectedCodeAmount !== null ? formatCurrency(selectedCodeAmount) : '—'}
                </span>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <FormField control={form.control} name="amount" render={({ field }) => (
                  <FormItem>
                    <FormLabel>{t('charge.amount')}</FormLabel>
                    <FormControl><Input type="number" step="0.01" {...field} /></FormControl>
                    <FormMessage />
                  </FormItem>
                )} />
                <FormField control={form.control} name="quantity" render={({ field }) => (
                  <FormItem>
                    <FormLabel>{t('charge.quantity')}</FormLabel>
                    <FormControl><Input type="number" {...field} /></FormControl>
                    <FormMessage />
                  </FormItem>
                )} />
              </div>
              <div className="space-y-2">
                <Label htmlFor="custom-amount">{t('charge.custom_amount')}</Label>
                <Input
                  id="custom-amount"
                  type="number"
                  step="0.01"
                  min="0"
                  placeholder={t('charge.custom_amount_placeholder')}
                  value={customAmount}
                  onChange={e => onCustomAmountChange(e.target.value)}
                  data-testid="input-custom-amount"
                />
              </div>
            </div>

            <NearbyClusterPicker
              nearby={event?.nearbyEvents ?? []}
              checked={checkedNearby}
              onToggle={toggleNearby}
              anchorAccountNumber={event?.accountNumber}
            />

            {event.lastCharges?.length > 0 && (
              <div className="mt-6 pt-4 border-t border-border/50">
                 <h4 className="text-xs font-semibold text-muted-foreground uppercase tracking-widest mb-3">{t('charge.last_charges')}</h4>
                 <div className="space-y-2">
                   {event.lastCharges.map((charge: any) => (
                      <div key={charge.id} className="flex justify-between items-center text-sm px-3 py-2 bg-muted/30 rounded border border-border/50">
                         <span className="text-muted-foreground">{formatDate(charge.dateCreated)}</span>
                         <div className="flex items-center gap-3">
                           <span className="font-mono font-medium">{formatCurrency(charge.amount)}</span>
                           <Badge variant={charge.paymentStatus === 'PAID' ? 'default' : charge.paymentStatus === 'REFUNDED' ? 'secondary' : 'outline'} className="text-[10px] w-20 justify-center">
                             {charge.paymentStatus ? t(`charge.status_${charge.paymentStatus.toLowerCase()}` as any) : t('charge.status_pending')}
                           </Badge>
                         </div>
                      </div>
                   ))}
                 </div>
              </div>
            )}

            <DialogFooter className="pt-2">
              <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>{t('charge.cancel')}</Button>
              <Button type="submit" disabled={charge.isPending}>{t('charge.submit')}</Button>
            </DialogFooter>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}

const emailSchema = z.object({
  toType: z.string().min(1, 'Required'),
  to: z.string().email(),
  cc: z.string().optional(),
  subject: z.string().min(1, 'Required'),
  body: z.string().optional()
});

function EmailDialog({ open, onOpenChange, eventId, event, onSuccess }: any) {
  const { t } = useI18n();
  const { toast } = useToast();
  const email = useEmailEvent();
  
  const form = useForm({
    resolver: zodResolver(emailSchema),
    defaultValues: { 
      toType: '', 
      to: '', 
      cc: '', 
      subject: `${event?.customerName} | Account ${event?.accountNumber}`, 
      body: '' 
    }
  });

  const submit = (data: any) => {
    email.mutate({ eventId, data }, {
      onSuccess: () => {
        form.reset();
        onSuccess();
      },
      onError: () => {
        toast({ variant: 'destructive', description: t('email.failed') });
      }
    });
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[500px]">
        <DialogHeader>
          <DialogTitle>{t('email.title')}</DialogTitle>
        </DialogHeader>
        <Form {...form}>
          <form onSubmit={form.handleSubmit(submit)} className="space-y-4">
            <FormField control={form.control} name="toType" render={({ field }) => (
              <FormItem>
                <FormLabel>{t('email.to_type')}</FormLabel>
                <Select onValueChange={field.onChange} value={field.value}>
                  <FormControl>
                    <SelectTrigger><SelectValue /></SelectTrigger>
                  </FormControl>
                  <SelectContent>
                    <SelectItem value="Billing">{t('email.types.billing')}</SelectItem>
                    <SelectItem value="Customer Service">{t('email.types.customer_service')}</SelectItem>
                    <SelectItem value="Operations">{t('email.types.operations')}</SelectItem>
                  </SelectContent>
                </Select>
                <FormMessage />
              </FormItem>
            )} />
            
            <FormField control={form.control} name="to" render={({ field }) => (
              <FormItem>
                <FormLabel>{t('email.to')}</FormLabel>
                <FormControl><Input type="email" {...field} /></FormControl>
                <FormMessage />
              </FormItem>
            )} />
            
            <FormField control={form.control} name="cc" render={({ field }) => (
              <FormItem>
                <FormLabel>{t('email.cc')}</FormLabel>
                <FormControl><Input {...field} /></FormControl>
                <FormMessage />
              </FormItem>
            )} />

            <FormField control={form.control} name="subject" render={({ field }) => (
              <FormItem>
                <FormLabel>{t('email.subject')}</FormLabel>
                <FormControl><Input {...field} /></FormControl>
                <FormMessage />
              </FormItem>
            )} />

            <FormField control={form.control} name="body" render={({ field }) => (
              <FormItem>
                <FormLabel>{t('email.body')}</FormLabel>
                <FormControl><Textarea className="resize-none min-h-[100px]" {...field} /></FormControl>
                <FormMessage />
              </FormItem>
            )} />

            <DialogFooter>
              <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>{t('email.cancel')}</Button>
              <Button type="submit" disabled={email.isPending}>{t('email.send')}</Button>
            </DialogFooter>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}

const closeSchema = z.object({
  closeReason: z.string().min(1, 'Required'),
  notes: z.string().optional()
});

function CloseDialog({ open, onOpenChange, eventId, event, checkedNearby, onSuccess }: any) {
  const { t } = useI18n();
  const { toast } = useToast();
  const closeMutation = useCloseEvent();
  const [checkedDuplicates, setCheckedDuplicates] = useState<Set<number>>(new Set());

  const toggleDuplicate = (id: number) => {
    setCheckedDuplicates(prev => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id); else next.add(id);
      return next;
    });
  };

  const form = useForm({
    resolver: zodResolver(closeSchema),
    defaultValues: { closeReason: '', notes: '' }
  });

  useEffect(() => {
    if (open) {
      form.reset({ closeReason: '', notes: '' });
      // Seed from the page's checked nearby rows, else the server suggestions
      setCheckedDuplicates(
        checkedNearby?.size > 0
          ? new Set<number>(checkedNearby)
          : new Set(suggestedDuplicateIds(event?.nearbyEvents))
      );
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, checkedNearby, form]);

  const submit = (data: any) => {
    closeMutation.mutate({ eventId, data: { ...data, duplicateEventIds: Array.from(checkedDuplicates) } }, {
      onSuccess: () => {
        onSuccess();
      },
      onError: () => {
        toast({ variant: 'destructive', description: t('close.failed') });
      }
    });
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('close.title')}</DialogTitle>
        </DialogHeader>
        <Form {...form}>
          <form onSubmit={form.handleSubmit(submit)} className="space-y-4">
            <FormField control={form.control} name="closeReason" render={({ field }) => (
              <FormItem>
                <FormLabel>{t('close.reason')}</FormLabel>
                <Select onValueChange={field.onChange} value={field.value}>
                  <FormControl>
                    <SelectTrigger><SelectValue placeholder={t('close.select_reason')} /></SelectTrigger>
                  </FormControl>
                  <SelectContent>
                    <SelectItem value="Not an Overfill">{t('close.reasons.not_overfill')}</SelectItem>
                    <SelectItem value="District Declined to Charge">{t('close.reasons.district_declined')}</SelectItem>
                    <SelectItem value="New Customer">{t('close.reasons.new_customer')}</SelectItem>
                    <SelectItem value="Duplicate">{t('close.reasons.duplicate')}</SelectItem>
                    <SelectItem value="Contract - No Overages">{t('close.reasons.contract_no_overages')}</SelectItem>
                  </SelectContent>
                </Select>
                <FormMessage />
              </FormItem>
            )} />

            <NearbyClusterPicker
              nearby={event?.nearbyEvents ?? []}
              checked={checkedDuplicates}
              onToggle={toggleDuplicate}
              anchorAccountNumber={event?.accountNumber}
              title={t('close.dismiss_these')}
            />


            <FormField control={form.control} name="notes" render={({ field }) => (
              <FormItem>
                <FormLabel>{t('close.notes')}</FormLabel>
                <FormControl><Textarea className="resize-none" {...field} /></FormControl>
                <FormMessage />
              </FormItem>
            )} />

            <DialogFooter>
              <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>{t('close.cancel')}</Button>
              <Button type="submit" variant="destructive" disabled={closeMutation.isPending}>{t('close.submit')}</Button>
            </DialogFooter>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
