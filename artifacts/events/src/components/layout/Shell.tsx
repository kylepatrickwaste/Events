import React from 'react';
import { Link, useRoute, useLocation } from 'wouter';
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover';
import { Command, CommandEmpty, CommandGroup, CommandInput, CommandItem, CommandList } from '@/components/ui/command';
import { Check, ChevronsUpDown } from 'lucide-react';
import { cn } from '@/lib/utils';
import { useI18n, Language } from '@/i18n';
import { useTheme } from '@/components/theme-provider';
import logoUrl from '@assets/Waste_Connections_Logo_Symbol_-_2_Color-_12-10-09_-_transparen_1786045458506.png';
import { Moon, Sun, ChevronLeft } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import { useListDistricts, getListDistrictsQueryKey, useGetEvent, getGetEventQueryKey } from '@workspace/api-client-react';
import { TruckDrive } from './TruckDrive';

function DistrictHeaderCenter() {
  const { t } = useI18n();
  const [matchesDistrict, params] = useRoute('/districts/:districtId');
  const districtId = matchesDistrict ? Number(params?.districtId) : NaN;

  const { data: districts } = useListDistricts({
    query: { enabled: matchesDistrict, queryKey: getListDistrictsQueryKey() },
  });

  if (!matchesDistrict) return null;
  const district = districts?.find(d => d.id === districtId);

  return (
    <div className="absolute left-1/2 -translate-x-1/2 z-10 flex items-center gap-1 max-w-[45%] sm:max-w-[50%]">
      <Link
        href="/?browse=1"
        className="inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-md hover:bg-accent hover:text-accent-foreground transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
        title={t('app.view_all_districts')}
        aria-label={t('app.view_all_districts')}
      >
        <ChevronLeft className="h-5 w-5" />
      </Link>
      {district ? (
        <span className="flex items-center gap-2 min-w-0">
          <Link
            href="/?browse=1"
            className="min-w-0 rounded-sm font-bold text-base sm:text-lg leading-none truncate hover:text-primary hover:underline underline-offset-4 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
            aria-label={district.name}
          >
            {district.name}
          </Link>
          <Link
            href="/?browse=1"
            className="shrink-0 rounded-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
            aria-label={`${district.name} ${district.number}`}
          >
            <Badge
              variant="secondary"
              className="font-mono text-sm px-2.5 py-0.5 hover:bg-secondary/80 transition-colors"
            >
              {district.number}
            </Badge>
          </Link>
        </span>
      ) : (
        <Skeleton className="h-6 w-32" />
      )}
    </div>
  );
}

function EventHeaderCenter() {
  const [matchesEvent, params] = useRoute('/districts/:districtId/events/:eventId');
  const eventId = matchesEvent ? Number(params?.eventId) : 0;

  const { data: event } = useGetEvent(eventId, {
    query: { enabled: matchesEvent && eventId > 0, queryKey: getGetEventQueryKey(eventId) },
  });

  if (!matchesEvent) return null;

  return (
    <div className="absolute left-1/2 -translate-x-1/2 z-10 max-w-[45%] sm:max-w-[50%]">
      {event ? (
        <Link
          href={`/districts/${params?.districtId}`}
          className="flex items-center gap-1 min-w-0 rounded-sm hover:text-primary transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring group"
          aria-label={event.customerName ?? undefined}
        >
          <ChevronLeft className="h-5 w-5 shrink-0" />
          <span className="min-w-0 font-bold text-base sm:text-lg leading-none truncate group-hover:underline underline-offset-4">
            {event.customerName}
          </span>
        </Link>
      ) : (
        <Skeleton className="h-6 w-32" />
      )}
    </div>
  );
}

function HeaderDistrictSwitcher() {
  const { t } = useI18n();
  const [, setLocation] = useLocation();
  const [matchesDistrict, params] = useRoute('/districts/:districtId');
  const [matchesEvent, eventParams] = useRoute('/districts/:districtId/events/:eventId');
  const [open, setOpen] = React.useState(false);

  const districtId = Number((matchesDistrict ? params?.districtId : eventParams?.districtId) ?? NaN);
  const show = matchesDistrict || matchesEvent;

  const { data: districts } = useListDistricts({
    query: { enabled: show, queryKey: getListDistrictsQueryKey() },
  });

  if (!show) return null;
  const district = districts?.find(d => d.id === districtId);

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger asChild>
        <Button variant="outline" size="sm" role="combobox" aria-expanded={open} className="h-8 max-w-[220px] justify-between">
          <span className="truncate font-mono text-xs">
            {district ? `${district.number} – ${district.name}` : t('district.switch_district')}
          </span>
          <ChevronsUpDown className="ml-1 h-3.5 w-3.5 shrink-0 opacity-50" />
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
                    setOpen(false);
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
  );
}

export function Header() {
  const { t, language, setLanguage } = useI18n();
  const { theme, setTheme } = useTheme();
  const titleRef = React.useRef<HTMLAnchorElement>(null);
  const langRef = React.useRef<HTMLDivElement>(null);

  return (
    <header className="sticky top-0 z-50 w-full border-b bg-background shadow-sm">
      <TruckDrive startRef={titleRef} endRef={langRef} />
      <div className="container relative flex h-14 items-center justify-between">
        <DistrictHeaderCenter />
        <EventHeaderCenter />
        <Link href="/" ref={titleRef} className="flex items-center gap-2 mr-6 hover:opacity-90 transition-opacity">
          <img src={logoUrl} alt="Waste Connections" className="h-8 w-auto object-contain" />
          <span className="font-bold hidden sm:inline-block text-primary">
            {t('app.title')}
          </span>
        </Link>
        <div className="flex flex-1 items-center justify-end space-x-4">
          <HeaderDistrictSwitcher />
          <div ref={langRef} className="flex items-center space-x-1 text-sm text-muted-foreground">
            <button 
              onClick={() => setLanguage('en')}
              className={`hover:text-foreground transition-colors ${language === 'en' ? 'text-foreground font-semibold' : ''}`}
            >
              EN
            </button>
            <span>|</span>
            <button 
              onClick={() => setLanguage('es')}
              className={`hover:text-foreground transition-colors ${language === 'es' ? 'text-foreground font-semibold' : ''}`}
            >
              ES
            </button>
            <span>|</span>
            <button 
              onClick={() => setLanguage('fr')}
              className={`hover:text-foreground transition-colors ${language === 'fr' ? 'text-foreground font-semibold' : ''}`}
            >
              FR
            </button>
          </div>
          <Button
            variant="ghost"
            size="icon"
            onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}
            className="text-muted-foreground hover:text-foreground"
          >
            <Sun className="h-5 w-5 rotate-0 scale-100 transition-all dark:-rotate-90 dark:scale-0" />
            <Moon className="absolute h-5 w-5 rotate-90 scale-0 transition-all dark:rotate-0 dark:scale-100" />
            <span className="sr-only">Toggle theme</span>
          </Button>
        </div>
      </div>
    </header>
  );
}

export function Footer() {
  const { t, setLanguage, language } = useI18n();

  return (
    <footer className="border-t bg-muted/40 py-6 mt-auto">
      <div className="container flex flex-col sm:flex-row items-center justify-between gap-4">
        <div className="text-sm text-muted-foreground">
          © 2026 Waste Connections
        </div>
        <div className="flex items-center space-x-3 text-sm text-muted-foreground">
          <button 
            onClick={() => setLanguage('en')}
            className={`hover:text-foreground transition-colors ${language === 'en' ? 'text-foreground font-semibold' : ''}`}
          >
            {t('nav.english')}
          </button>
          <span>|</span>
          <button 
            onClick={() => setLanguage('es')}
            className={`hover:text-foreground transition-colors ${language === 'es' ? 'text-foreground font-semibold' : ''}`}
          >
            {t('nav.spanish')}
          </button>
          <span>|</span>
          <button 
            onClick={() => setLanguage('fr')}
            className={`hover:text-foreground transition-colors ${language === 'fr' ? 'text-foreground font-semibold' : ''}`}
          >
            {t('nav.french')}
          </button>
        </div>
      </div>
    </footer>
  );
}

export function Shell({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-[100dvh] flex flex-col bg-background">
      <Header />
      <main className="flex-1">
        {children}
      </main>
      <Footer />
    </div>
  );
}
