import React from 'react';
import { Link, useRoute, useLocation } from 'wouter';
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover';
import {
  Command,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
} from '@/components/ui/command';
import { Check, ChevronsUpDown, FileX2, ChevronLeft, UserRound } from 'lucide-react';
import { cn } from '@/lib/utils';
import { useI18n } from '@/i18n';
import { useServerStatus } from '@/hooks/use-server-status';
import { ApiUnreachableDialog } from '@/components/api-unreachable-dialog';
import logoUrl from '@assets/Waste_Connections_Logo_Symbol_-_2_Color-_12-10-09_-_transparen_1786045458506.png';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import {
  useListDistricts,
  getListDistrictsQueryKey,
  useGetEvent,
  getGetEventQueryKey,
} from '@workspace/api-client-react';
import { useCurrentUser } from '@/hooks/use-current-user';
import { UserProfileDialog } from '@/components/user-profile-dialog';

function EventHeaderCenter() {
  const [matchesEvent, params] = useRoute('/districts/:districtId/events/:eventId');
  const eventId = matchesEvent ? Number(params?.eventId) : 0;

  const { data: event } = useGetEvent(eventId, {
    query: { enabled: matchesEvent && eventId > 0, queryKey: getGetEventQueryKey(eventId) },
  });

  if (!matchesEvent) return null;

  return (
    <div className="min-w-0 max-w-full">
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

export const OPEN_EXCLUDED_ACCOUNTS_EVENT = 'open-excluded-accounts';

function HeaderExcludedAccountsButton() {
  const { t } = useI18n();
  const [matchesDistrict] = useRoute('/districts/:districtId');

  if (!matchesDistrict) return null;

  return (
    <Button
      variant="outline"
      size="sm"
      className="h-8"
      title={t('contract_accounts.button')}
      aria-label={t('contract_accounts.button')}
      onClick={() => window.dispatchEvent(new CustomEvent(OPEN_EXCLUDED_ACCOUNTS_EVENT))}
    >
      <FileX2 className="h-4 w-4 sm:mr-2" />
      <span className="hidden sm:inline">{t('contract_accounts.button')}</span>
    </Button>
  );
}

/**
 * Who the API thinks you are. Friendly name when known, raw AD login otherwise.
 * Doubles as the way into the profile dialog — the name is the thing you would
 * click to correct it.
 */
function HeaderUserName() {
  const { t } = useI18n();
  const { data: user } = useCurrentUser();
  const [profileOpen, setProfileOpen] = React.useState(false);

  if (!user?.userName) return null;

  return (
    <>
      <button
        type="button"
        aria-haspopup="dialog"
        // Must stay visible at every width: this is the only way into the profile
        // dialog, which now owns the language and theme controls. Below `md` it
        // collapses to the icon alone rather than disappearing.
        className="flex min-w-0 items-center gap-1.5 rounded-md px-1 py-0.5 text-sm text-foreground hover:bg-accent hover:text-accent-foreground transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
        aria-label={t('app.signed_in_as', { name: user.activeDirectoryName })}
        title={t('app.signed_in_as', { name: user.activeDirectoryName })}
        data-testid="header-username"
        onClick={() => setProfileOpen(true)}
      >
        <UserRound className="h-4 w-4 shrink-0 text-muted-foreground" />
        <span className="hidden md:inline truncate max-w-[9rem] font-medium">{user.userName}</span>
      </button>

      <UserProfileDialog open={profileOpen} onOpenChange={setProfileOpen} />
    </>
  );
}

/**
 * Loud reminder that this is not production. The same bundle is served by every
 * environment, so `import.meta.env.DEV` alone is not enough — a production build
 * pointed at a non-production API still needs the warning.
 */
function DevelopmentBanner() {
  const { t } = useI18n();
  const { environment } = useServerStatus();
  const isNonProdApi = !!environment && environment.toLowerCase() !== 'production';

  if (!import.meta.env.DEV && !isNonProdApi) return null;

  return (
    <div
      role="status"
      data-testid="development-banner"
      className="w-full bg-destructive px-4 py-1 text-center text-xs font-bold uppercase tracking-widest text-destructive-foreground"
    >
      {t('app.development_mode')}
      {environment ? <span className="ml-2 font-normal normal-case opacity-80">({environment})</span> : null}
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
  const show = matchesDistrict && !matchesEvent;

  const { data: districts } = useListDistricts({
    query: { enabled: show, queryKey: getListDistrictsQueryKey() },
  });

  if (!show) return null;
  const district = districts?.find(d => d.id === districtId);

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger asChild>
        <Button variant="outline" size="sm" role="combobox" aria-expanded={open} className="h-8 max-w-[120px] sm:max-w-[220px] justify-between">
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

function ApiStatusDot() {
  const { t } = useI18n();
  // Reachability comes from the shared health check, so the dot reflects whether
  // the server actually answered — not merely which URL we point at. The build
  // number is served by that same API, so it tracks the deployed backend rather
  // than whenever this bundle happened to be built.
  const { isReachable, buildNumber } = useServerStatus();
  const label = isReachable ? t('connection.online') : t('connection.offline');

  return (
    <span className="flex items-center gap-1.5">
      <span
        title={label}
        aria-label={label}
        data-testid="status-api"
        data-state={isReachable ? 'online' : 'offline'}
        className="flex items-center justify-center"
      >
        <span
          className={`block h-2.5 w-2.5 rounded-full ring-2 ring-background ${
            isReachable ? 'bg-green-500' : 'bg-red-500'
          }`}
        />
      </span>
      {buildNumber ? (
        <span
          title={`Build ${buildNumber}`}
          className="text-xs tabular-nums text-muted-foreground"
        >
          {buildNumber}
        </span>
      ) : null}
    </span>
  );
}

export function Header() {
  const { t } = useI18n();

  return (
    <header className="sticky top-0 z-50 w-full border-b bg-background shadow-sm">
      <div className="container relative flex h-14 items-center gap-2 sm:gap-4">
        <Link
          href="/?browse=1"
          className="flex shrink-0 items-center gap-2 hover:opacity-90 transition-opacity"
          title={t('app.view_all_districts')}
          aria-label={t('app.view_all_districts')}
        >
          <img src={logoUrl} alt="Waste Connections" className="h-8 w-auto object-contain" />
          <span className="font-bold hidden sm:inline-block text-primary">
            {t('app.title')}
          </span>
        </Link>
        <div className="flex flex-1 items-center justify-center min-w-[2rem]">
          <EventHeaderCenter />
        </div>
        <div className="flex shrink-0 items-center justify-end gap-1 sm:gap-4">
          <HeaderExcludedAccountsButton />
          <HeaderDistrictSwitcher />
          <HeaderUserName />
          <ApiStatusDot />
        </div>
      </div>
    </header>
  );
}

export function Shell({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-[100dvh] flex flex-col bg-background">
      <DevelopmentBanner />
      <Header />
      <main className="flex-1">
        {children}
      </main>
      <ApiUnreachableDialog />
    </div>
  );
}
