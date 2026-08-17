import React, { useState, useEffect, useRef } from 'react';
import { useChargeEvent, useCloseEvent, useBulkCloseEvents, useGetEvent, getGetEventQueryKey } from '@workspace/api-client-react';
import { useI18n } from '@/i18n';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { NearbyClusterPicker, suggestedDuplicateIds } from '@/components/nearby-cluster-picker';
import { useToast } from '@/hooks/use-toast';
import { z } from 'zod';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from '@/components/ui/form';

const CLOSE_REASONS = [
  { value: 'Not an Overfill', key: 'close.reasons.not_overfill' },
  { value: 'District Declined to Charge', key: 'close.reasons.district_declined' },
  { value: 'New Customer', key: 'close.reasons.new_customer' },
  { value: 'Duplicate', key: 'close.reasons.duplicate' },
  { value: 'Contract - No Overages', key: 'close.reasons.contract_no_overages' },
];

const closeSchema = z.object({
  closeReason: z.string().min(1, 'Required'),
  notes: z.string().optional(),
});

function CloseReasonFields({ form }: { form: any }) {
  const { t } = useI18n();
  return (
    <>
      <FormField control={form.control} name="closeReason" render={({ field }) => (
        <FormItem>
          <FormLabel>{t('close.reason')}</FormLabel>
          <Select onValueChange={field.onChange} value={field.value}>
            <FormControl>
              <SelectTrigger><SelectValue placeholder={t('close.select_reason')} /></SelectTrigger>
            </FormControl>
            <SelectContent>
              {CLOSE_REASONS.map(r => (
                <SelectItem key={r.value} value={r.value}>{t(r.key)}</SelectItem>
              ))}
            </SelectContent>
          </Select>
          <FormMessage />
        </FormItem>
      )} />
      <FormField control={form.control} name="notes" render={({ field }) => (
        <FormItem>
          <FormLabel>{t('close.notes')}</FormLabel>
          <FormControl><Textarea className="resize-none" {...field} /></FormControl>
          <FormMessage />
        </FormItem>
      )} />
    </>
  );
}

export function CloseEventDialog({ open, onOpenChange, eventId, onSuccess, initialCheckedNearby }: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  eventId: number;
  onSuccess: () => void;
  initialCheckedNearby?: number[];
}) {
  const { t } = useI18n();
  const { toast } = useToast();
  const closeMutation = useCloseEvent();
  const [checkedNearby, setCheckedNearby] = useState<Set<number>>(new Set());
  const [preChecked, setPreChecked] = useState(false);

  const { data: detail } = useGetEvent(eventId, {
    query: { enabled: open && !!eventId, queryKey: getGetEventQueryKey(eventId) },
  });
  const nearby = detail?.nearbyEvents ?? [];

  useEffect(() => {
    if (!open) {
      setCheckedNearby(new Set());
      setPreChecked(false);
    } else if (initialCheckedNearby?.length) {
      setCheckedNearby(new Set(initialCheckedNearby));
      setPreChecked(true);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open]);

  // Pre-check server-suggested same-cluster duplicates once the detail loads
  useEffect(() => {
    if (!open || preChecked || !detail) return;
    setCheckedNearby(new Set(suggestedDuplicateIds(detail.nearbyEvents)));
    setPreChecked(true);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, detail]);

  const form = useForm({
    resolver: zodResolver(closeSchema),
    defaultValues: { closeReason: '', notes: '' },
  });

  const toggleNearby = (id: number) => {
    setCheckedNearby(prev => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id); else next.add(id);
      return next;
    });
  };

  const submit = (data: any) => {
    closeMutation.mutate(
      { eventId, data: { ...data, duplicateEventIds: Array.from(checkedNearby) } },
      {
        onSuccess: () => {
          form.reset();
          setCheckedNearby(new Set());
          onSuccess();
        },
        onError: () => {
          toast({ variant: 'destructive', description: t('close.failed') });
        },
      },
    );
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('close.title')}</DialogTitle>
        </DialogHeader>
        <Form {...form}>
          <form onSubmit={form.handleSubmit(submit)} className="space-y-4">
            <CloseReasonFields form={form} />
            <NearbyClusterPicker
              nearby={nearby}
              checked={checkedNearby}
              onToggle={toggleNearby}
              anchorAccountNumber={detail?.accountNumber}
              title={t('close.dismiss_these')}
            />

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

export function BulkCloseDialog({ open, onOpenChange, eventIds, onSuccess }: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  eventIds: number[];
  onSuccess: (closedCount: number) => void;
}) {
  const { t } = useI18n();
  const { toast } = useToast();
  const bulkClose = useBulkCloseEvents();

  const form = useForm({
    resolver: zodResolver(closeSchema),
    defaultValues: { closeReason: '', notes: '' },
  });

  const submit = (data: any) => {
    bulkClose.mutate(
      { data: { eventIds, closeReason: data.closeReason, notes: data.notes || null } },
      {
        onSuccess: (result) => {
          form.reset();
          onSuccess(result.closedCount);
        },
        onError: () => {
          toast({ variant: 'destructive', description: t('bulk_close.failed') });
        },
      },
    );
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('bulk_close.title')}</DialogTitle>
          <DialogDescription>{t('bulk_close.description', { count: eventIds.length })}</DialogDescription>
        </DialogHeader>
        <Form {...form}>
          <form onSubmit={form.handleSubmit(submit)} className="space-y-4">
            <CloseReasonFields form={form} />
            <DialogFooter>
              <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>{t('close.cancel')}</Button>
              <Button type="submit" variant="destructive" disabled={bulkClose.isPending}>
                {t('district.close_selected')}
              </Button>
            </DialogFooter>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}

/**
 * Bulk charge: one service code, amount and quantity applied to every selected
 * open event, submitted through the existing per-event charge call. There is no
 * bulk endpoint, so each event is charged in turn and the tally reported back.
 *
 * While running, a progress bar and "X of Y charged" label are shown and the
 * dialog cannot be closed. A "Stop" button lets the user cancel mid-run — the
 * loop checks a ref after every charge and stops issuing further requests as
 * soon as it is set, then calls onDone with only the events that were attempted.
 */
export function BulkChargeDialog({ open, onOpenChange, eventIds, serviceCodes, onDone }: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  eventIds: number[];
  serviceCodes: Array<{ id: number; code: string; description: string; amount: number }>;
  onDone: (chargedCount: number, failedCount: number) => void;
}) {
  const { t } = useI18n();
  const charge = useChargeEvent();
  const [submitting, setSubmitting] = useState(false);
  const [progress, setProgress] = useState<{ done: number; charged: number; total: number } | null>(null);
  // A ref so the loop can read the latest value without a closure-staleness issue.
  const cancelledRef = useRef(false);

  // Reset progress state whenever the dialog is closed so reopening it starts fresh.
  useEffect(() => {
    if (!open) {
      setProgress(null);
      cancelledRef.current = false;
    }
  }, [open]);

  const form = useForm({
    resolver: zodResolver(chargeSchema),
    defaultValues: { serviceCodeId: '' as any, amount: 0, quantity: 1 },
  });

  const onSelectCode = (idStr: string) => {
    const id = parseInt(idStr);
    form.setValue('serviceCodeId', id as any);
    const code = serviceCodes.find(c => c.id === id);
    if (code) form.setValue('amount', code.amount);
  };

  const handleCancel = () => {
    if (submitting) {
      // Signal the in-flight loop to stop after the current request finishes.
      cancelledRef.current = true;
    } else {
      onOpenChange(false);
    }
  };

  const submit = async (data: any) => {
    setSubmitting(true);
    cancelledRef.current = false;
    setProgress({ done: 0, charged: 0, total: eventIds.length });
    let charged = 0;
    let processed = 0;
    // Sequential on purpose: each success/failure is counted, and a burst of
    // parallel charges would hammer the same per-event endpoint.
    for (const eventId of eventIds) {
      if (cancelledRef.current) break;
      try {
        await charge.mutateAsync({ eventId, data: { ...data, duplicateEventIds: [] } });
        charged++;
      } catch {
        // counted below as a failure; the summary toast names how many
      }
      processed++;
      setProgress({ done: processed, charged, total: eventIds.length });
    }
    setSubmitting(false);
    setProgress(null);
    form.reset();
    // Only count the events we actually attempted — if cancelled early, the
    // remaining ones are neither charged nor failed.
    onDone(charged, processed - charged);
  };

  return (
    <Dialog open={open} onOpenChange={(o) => { if (!submitting) onOpenChange(o); }}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('bulk_charge.title')}</DialogTitle>
          <DialogDescription>{t('bulk_charge.description', { count: eventIds.length })}</DialogDescription>
        </DialogHeader>
        <Form {...form}>
          <form onSubmit={form.handleSubmit(submit)} className="space-y-4">
            <FormField control={form.control} name="serviceCodeId" render={({ field }) => (
              <FormItem>
                <FormLabel>{t('charge.service_code')}</FormLabel>
                <Select onValueChange={onSelectCode} value={field.value?.toString()} disabled={submitting}>
                  <FormControl>
                    <SelectTrigger><SelectValue placeholder={t('charge.select_code')} /></SelectTrigger>
                  </FormControl>
                  <SelectContent>
                    {serviceCodes.map(c => (
                      <SelectItem key={c.id} value={c.id.toString()}>{c.code} - {c.description}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                <FormMessage />
              </FormItem>
            )} />

            <div className="grid grid-cols-2 gap-4">
              <FormField control={form.control} name="amount" render={({ field }) => (
                <FormItem>
                  <FormLabel>{t('charge.amount')}</FormLabel>
                  <FormControl><Input type="number" step="0.01" disabled={submitting} {...field} /></FormControl>
                  <FormMessage />
                </FormItem>
              )} />
              <FormField control={form.control} name="quantity" render={({ field }) => (
                <FormItem>
                  <FormLabel>{t('charge.quantity')}</FormLabel>
                  <FormControl><Input type="number" disabled={submitting} {...field} /></FormControl>
                  <FormMessage />
                </FormItem>
              )} />
            </div>

            {progress && (
              <div className="space-y-1.5">
                <p className="text-sm text-muted-foreground">
                  {t('bulk_charge.progress', { done: progress.done, total: progress.total, charged: progress.charged })}
                </p>
                <div className="h-2 w-full overflow-hidden rounded-full bg-muted">
                  <div
                    className="h-full bg-primary transition-[width] duration-200"
                    style={{ width: `${Math.round((progress.done / progress.total) * 100)}%` }}
                  />
                </div>
              </div>
            )}

            <DialogFooter>
              <Button type="button" variant="outline" onClick={handleCancel}>
                {submitting ? t('bulk_charge.stop') : t('charge.cancel')}
              </Button>
              <Button type="submit" disabled={submitting}>
                {t('bulk_charge.submit', { count: eventIds.length })}
              </Button>
            </DialogFooter>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}

const chargeSchema = z.object({
  serviceCodeId: z.coerce.number().min(1, 'Required'),
  amount: z.coerce.number().min(0),
  quantity: z.coerce.number().min(1),
});

export function ChargeEventDialog({ open, onOpenChange, eventId, serviceCodes, onSuccess, initialCheckedNearby }: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  eventId: number;
  serviceCodes: Array<{ id: number; code: string; description: string; amount: number }>;
  onSuccess: () => void;
  initialCheckedNearby?: number[];
}) {
  const { t } = useI18n();
  const { toast } = useToast();
  const charge = useChargeEvent();
  const [checkedNearby, setCheckedNearby] = useState<Set<number>>(new Set());
  const [preChecked, setPreChecked] = useState(false);

  const { data: detail } = useGetEvent(eventId, {
    query: { enabled: open && !!eventId, queryKey: getGetEventQueryKey(eventId) },
  });
  const nearby = detail?.nearbyEvents ?? [];

  useEffect(() => {
    if (!open) {
      setCheckedNearby(new Set());
      setPreChecked(false);
    } else if (initialCheckedNearby?.length) {
      setCheckedNearby(new Set(initialCheckedNearby));
      setPreChecked(true);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open]);

  // Pre-check server-suggested same-cluster duplicates once the detail loads
  useEffect(() => {
    if (!open || preChecked || !detail) return;
    setCheckedNearby(new Set(suggestedDuplicateIds(detail.nearbyEvents)));
    setPreChecked(true);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, detail]);

  const toggleNearby = (id: number) => {
    setCheckedNearby(prev => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id); else next.add(id);
      return next;
    });
  };

  const form = useForm({
    resolver: zodResolver(chargeSchema),
    defaultValues: { serviceCodeId: '' as any, amount: 0, quantity: 1 },
  });

  const onSelectCode = (idStr: string) => {
    const id = parseInt(idStr);
    form.setValue('serviceCodeId', id as any);
    const code = serviceCodes.find(c => c.id === id);
    if (code) form.setValue('amount', code.amount);
  };

  const submit = (data: any) => {
    charge.mutate({ eventId, data: { ...data, duplicateEventIds: Array.from(checkedNearby) } }, {
      onSuccess: () => {
        form.reset();
        setCheckedNearby(new Set());
        onSuccess();
      },
      onError: () => {
        toast({ variant: 'destructive', description: t('charge.failed') });
      },
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
                    {serviceCodes.map(c => (
                      <SelectItem key={c.id} value={c.id.toString()}>{c.code} - {c.description}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                <FormMessage />
              </FormItem>
            )} />

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

            <NearbyClusterPicker
              nearby={nearby}
              checked={checkedNearby}
              onToggle={toggleNearby}
              anchorAccountNumber={detail?.accountNumber}
            />

            <DialogFooter>
              <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>{t('charge.cancel')}</Button>
              <Button type="submit" disabled={charge.isPending}>{t('charge.submit')}</Button>
            </DialogFooter>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
