import React, { useState } from 'react';
import { useRoute, useLocation } from 'wouter';
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
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import { Tabs, TabsList, TabsTrigger, TabsContent } from '@/components/ui/tabs';
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
  FileText,
  DollarSign,
  Mail,
  XCircle,
  Copy,
  CheckCircle2,
  Send,
  MessageSquare
} from 'lucide-react';
import { z } from 'zod';
import { useForm, Controller } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from '@/components/ui/form';

export default function EventDetailWorkspace() {
  const [, params] = useRoute('/districts/:districtId/events/:eventId');
  const districtId = Number(params?.districtId);
  const eventId = Number(params?.eventId);
  const [, setLocation] = useLocation();
  const { t, formatDate, formatCurrency } = useI18n();
  const queryClient = useQueryClient();
  const { toast } = useToast();

  const { data: event, isLoading } = useGetEvent(eventId, {
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

  // Mutations
  const addNote = useAddEventNote();
  const chargeEvent = useChargeEvent();
  const emailEvent = useEmailEvent();
  const closeEvent = useCloseEvent();

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

  if (isLoading) {
    return <div className="container mx-auto p-6 max-w-7xl"><Skeleton className="h-[800px] w-full" /></div>;
  }
  if (!event) return null;

  return (
    <div className="container mx-auto py-6 px-4 max-w-7xl">
      {/* Header */}
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4 mb-6">
        <div className="flex items-center gap-4">
          <Button variant="ghost" size="icon" onClick={() => setLocation(`/districts/${districtId}`)}>
            <ChevronLeft className="h-5 w-5" />
          </Button>
          <div>
            <div className="flex items-center gap-3">
              <h1 className="text-2xl font-bold tracking-tight">{event.customerName}</h1>
              {isClosed ? (
                <Badge variant="outline" className="border-muted-foreground/30 text-muted-foreground">
                  <CheckCircle2 className="w-3 h-3 mr-1" />
                  {t('event.status_closed')}
                </Badge>
              ) : (
                <Badge className="bg-primary/10 text-primary hover:bg-primary/20 border-0">
                  <AlertTriangle className="w-3 h-3 mr-1" />
                  {t('event.status_open')}
                </Badge>
              )}
            </div>
            <div className="text-sm text-muted-foreground font-mono mt-1">
              {t('event.account')}: {event.accountNumber}
            </div>
          </div>
        </div>

        <div className="flex items-center gap-2">
          {!isClosed && (
            <>
              <Button onClick={() => setChargeOpen(true)} className="bg-success text-success-foreground hover:bg-success/90">
                <DollarSign className="w-4 h-4 mr-2" />
                {t('event.charge')}
              </Button>
              <Button onClick={() => setEmailOpen(true)} variant="secondary">
                <Mail className="w-4 h-4 mr-2" />
                {t('event.email')}
              </Button>
              <Button onClick={() => setCloseOpen(true)} variant="destructive">
                <XCircle className="w-4 h-4 mr-2" />
                {t('event.close')}
              </Button>
            </>
          )}
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left Column: Image & Details */}
        <div className="lg:col-span-2 space-y-6">
          <Card className="overflow-hidden shadow-sm">
            <div className="bg-muted aspect-video relative flex items-center justify-center">
              {event.imageUrl ? (
                <img src={event.imageUrl} alt="Event" className="object-contain w-full h-full" />
              ) : (
                <div className="text-muted-foreground flex flex-col items-center">
                  <Camera className="h-12 w-12 mb-2 opacity-20" />
                  <span>{t('event.no_photo')}</span>
                </div>
              )}
            </div>
          </Card>

          <Card className="shadow-sm">
            <CardHeader>
              <CardTitle className="text-lg">{t('event.detail')}</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-x-8 gap-y-4 text-sm">
                <DetailRow label={t('event.occurred')} value={formatDate(event.dateOccurred)} icon={<Clock className="h-4 w-4" />} />
                <DetailRow label={t('event.source')} value={event.eventSourceName} />
                <DetailRow label={t('district.event_type')} value={event.eventTypeName} />
                <DetailRow label={t('district.address')} value={event.address} icon={<MapPin className="h-4 w-4" />} />
                <DetailRow label={t('event.route')} value={event.route} mono />
                <DetailRow label={t('event.vehicle')} value={event.vehicle} mono />
                <DetailRow label={t('event.bin_serial')} value={event.binSerialNumber} mono />
                <DetailRow label={t('event.lob')} value={event.lob} />
                {isClosed && event.closedBy && (
                  <DetailRow label={t('event.closed_by')} value={`${event.closedBy} on ${formatDate(event.dateClosed || '')}`} />
                )}
              </div>
            </CardContent>
          </Card>

          <Card className="shadow-sm">
            <CardHeader>
              <CardTitle className="text-lg">{t('event.customer_routes')}</CardTitle>
            </CardHeader>
            <CardContent>
              {event.routes.length === 0 ? (
                <p className="text-sm text-muted-foreground italic">{t('event.no_routes')}</p>
              ) : (
                <div className="border rounded-md overflow-hidden">
                  <table className="w-full text-sm">
                    <thead className="bg-muted/50 border-b">
                      <tr>
                        <th className="px-4 py-2 text-left font-medium">{t('event.code')}</th>
                        <th className="px-4 py-2 text-left font-medium">{t('event.service')}</th>
                        <th className="px-4 py-2 text-left font-medium">{t('event.material')}</th>
                        <th className="px-4 py-2 text-left font-medium">{t('event.day')}</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y">
                      {event.routes.map((route, i) => (
                        <tr key={i}>
                          <td className="px-4 py-2 font-mono">{route.code}</td>
                          <td className="px-4 py-2">{route.service}</td>
                          <td className="px-4 py-2">{route.material}</td>
                          <td className="px-4 py-2">{route.day}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </CardContent>
          </Card>
        </div>

        {/* Right Column: Map & Timeline */}
        <div className="space-y-6">
          <Card className="shadow-sm">
            <div className="h-48 rounded-t-xl overflow-hidden bg-muted">
              <iframe
                width="100%"
                height="100%"
                frameBorder="0"
                scrolling="no"
                marginHeight={0}
                marginWidth={0}
                src={`https://www.openstreetmap.org/export/embed.html?bbox=${event.longitude-0.01},${event.latitude-0.01},${event.longitude+0.01},${event.latitude+0.01}&layer=mapnik&marker=${event.latitude},${event.longitude}`}
                className="border-none"
              ></iframe>
            </div>
            <CardContent className="p-4 bg-muted/10">
              <div className="text-xs text-muted-foreground flex justify-between items-center">
                <span>{event.latitude.toFixed(5)}, {event.longitude.toFixed(5)}</span>
                <div className="flex gap-2">
                  <Button variant="ghost" size="icon" className="h-6 w-6" onClick={() => copyLink(event.shareLinks.photo)} title="Copy Photo Link">
                    <Camera className="h-3 w-3" />
                  </Button>
                  <Button variant="ghost" size="icon" className="h-6 w-6" onClick={() => copyLink(event.shareLinks.event)} title="Copy Event Link">
                    <Copy className="h-3 w-3" />
                  </Button>
                </div>
              </div>
            </CardContent>
          </Card>

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
                    <div key={action.id} className="p-4 hover:bg-muted/20 transition-colors">
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
              <div className="p-4 border-t bg-muted/10">
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
        onSuccess={handleActionSuccess} 
      />
    </div>
  );
}

function DetailRow({ label, value, icon, mono }: { label: string, value: string | number | null | undefined, icon?: React.ReactNode, mono?: boolean }) {
  if (!value) return null;
  return (
    <div className="flex flex-col gap-1">
      <span className="text-xs text-muted-foreground font-semibold uppercase tracking-wider">{label}</span>
      <div className="flex items-center gap-2">
        {icon && <span className="text-muted-foreground">{icon}</span>}
        <span className={mono ? "font-mono" : ""}>{value}</span>
      </div>
    </div>
  );
}

function NoteForm({ eventId, onSuccess }: { eventId: number, onSuccess: () => void }) {
  const { t } = useI18n();
  const [notes, setNotes] = useState('');
  const addNote = useAddEventNote();

  const submit = () => {
    if (!notes.trim()) return;
    addNote.mutate({ eventId, data: { notes } }, {
      onSuccess: () => {
        setNotes('');
        onSuccess();
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
  keepOpen: z.boolean().default(false)
});

function ChargeDialog({ open, onOpenChange, eventId, serviceCodes, onSuccess }: any) {
  const { t } = useI18n();
  const charge = useChargeEvent();
  
  const form = useForm({
    resolver: zodResolver(chargeSchema),
    defaultValues: { serviceCodeId: '', amount: 0, quantity: 1, keepOpen: false }
  });

  const onSelectCode = (idStr: string) => {
    const id = parseInt(idStr);
    form.setValue('serviceCodeId', id as any);
    const code = serviceCodes.find((c: any) => c.id === id);
    if (code) form.setValue('amount', code.amount);
  };

  const submit = (data: any) => {
    charge.mutate({ eventId, data }, {
      onSuccess: () => {
        form.reset();
        onSuccess();
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

            <FormField control={form.control} name="keepOpen" render={({ field }) => (
              <FormItem className="flex flex-row items-start space-x-3 space-y-0 rounded-md border p-4 shadow-sm">
                <FormControl><Checkbox checked={field.value} onCheckedChange={field.onChange} /></FormControl>
                <div className="space-y-1 leading-none">
                  <FormLabel>{t('charge.keep_open')}</FormLabel>
                </div>
              </FormItem>
            )} />

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

const emailSchema = z.object({
  toType: z.string().min(1, 'Required'),
  to: z.string().email(),
  cc: z.string().optional(),
  subject: z.string().min(1, 'Required'),
  body: z.string().optional()
});

function EmailDialog({ open, onOpenChange, eventId, event, onSuccess }: any) {
  const { t } = useI18n();
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

function CloseDialog({ open, onOpenChange, eventId, onSuccess }: any) {
  const { t } = useI18n();
  const closeMutation = useCloseEvent();
  
  const form = useForm({
    resolver: zodResolver(closeSchema),
    defaultValues: { closeReason: '', notes: '' }
  });

  const submit = (data: any) => {
    closeMutation.mutate({ eventId, data }, {
      onSuccess: () => {
        form.reset();
        onSuccess();
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
                    <SelectItem value="Duplicate charge">{t('close.reasons.duplicate')}</SelectItem>
                    <SelectItem value="Unclear picture">{t('close.reasons.unclear')}</SelectItem>
                    <SelectItem value="Below minimum">{t('close.reasons.below_minimum')}</SelectItem>
                    <SelectItem value="No charge per driver/office">{t('close.reasons.no_charge')}</SelectItem>
                    <SelectItem value="Holiday delay">{t('close.reasons.holiday')}</SelectItem>
                    <SelectItem value="Route delay">{t('close.reasons.route_delay')}</SelectItem>
                    <SelectItem value="Weather">{t('close.reasons.weather')}</SelectItem>
                    <SelectItem value="Other">{t('close.reasons.other')}</SelectItem>
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
