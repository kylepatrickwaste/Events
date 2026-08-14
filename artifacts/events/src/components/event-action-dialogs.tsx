import React, { useState, useEffect } from 'react';
import { useChargeEvent, useCloseEvent, useBulkCloseEvents, useGetEvent, getGetEventQueryKey } from '@workspace/api-client-react';
import { triggerTruckDrive } from '@/components/layout/TruckDrive';
import { useI18n } from '@/i18n';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Checkbox } from '@/components/ui/checkbox';
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

export function CloseEventDialog({ open, onOpenChange, eventId, onSuccess }: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  eventId: number;
  onSuccess: () => void;
}) {
  const { t, formatDate } = useI18n();
  const closeMutation = useCloseEvent();
  const [checkedNearby, setCheckedNearby] = useState<Set<number>>(new Set());

  const { data: detail } = useGetEvent(eventId, {
    query: { enabled: open && !!eventId, queryKey: getGetEventQueryKey(eventId) },
  });
  const nearbyOpen = (detail?.nearbyEvents ?? []).filter((n: any) => n.status === 'Open');

  useEffect(() => {
    if (!open) setCheckedNearby(new Set());
  }, [open]);

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
            {nearbyOpen.length > 0 && (
              <div className="space-y-2">
                <p className="text-sm font-medium">{t('close.dismiss_these')}</p>
                <div className="border rounded-md divide-y max-h-48 overflow-y-auto">
                  {nearbyOpen.map((n: any) => (
                    <label key={n.id} className="flex items-center gap-3 p-2 cursor-pointer hover:bg-muted/30">
                      <Checkbox
                        checked={checkedNearby.has(n.id)}
                        onCheckedChange={() => toggleNearby(n.id)}
                      />
                      {n.imageUrl && (
                        <img src={n.imageUrl} className="w-10 h-8 object-cover rounded" alt="" />
                      )}
                      <span className="text-sm">{formatDate(n.dateOccurred, { hour: 'numeric', minute: '2-digit' })}</span>
                      <span className="text-xs text-muted-foreground ml-auto truncate max-w-[10rem]">{n.customerName}</span>
                    </label>
                  ))}
                </div>
              </div>
            )}
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

const chargeSchema = z.object({
  serviceCodeId: z.coerce.number().min(1, 'Required'),
  amount: z.coerce.number().min(0),
  quantity: z.coerce.number().min(1),
});

export function ChargeEventDialog({ open, onOpenChange, eventId, serviceCodes, onSuccess }: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  eventId: number;
  serviceCodes: Array<{ id: number; code: string; description: string; amount: number }>;
  onSuccess: () => void;
}) {
  const { t } = useI18n();
  const charge = useChargeEvent();

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
    triggerTruckDrive();
    charge.mutate({ eventId, data }, {
      onSuccess: () => {
        form.reset();
        onSuccess();
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
