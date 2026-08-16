import React, { useState, useMemo, useEffect, useRef } from 'react';
import { useLocation, useSearch } from 'wouter';
import { useCurrentUser } from '@/hooks/use-current-user';
import { useI18n } from '@/i18n';
import { Button } from '@/components/ui/button';
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover';
import {
  Command,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
} from '@/components/ui/command';
import { MapPin, ChevronsUpDown } from 'lucide-react';
import { useListDistricts, getListDistrictsQueryKey } from '@workspace/api-client-react';
import { Skeleton } from '@/components/ui/skeleton';
import { LoadError } from '@/components/load-error';

export default function Home() {
  const { t } = useI18n();
  const [, setLocation] = useLocation();
  const searchString = useSearch();
  const [open, setOpen] = useState(false);
  const redirected = useRef(false);

  // ?browse=1 is the escape hatch out of the home-district bypass: the header
  // logo links here, and somebody with a home district still needs a route back
  // to the picker.
  const browseAll = new URLSearchParams(searchString).has('browse');

  const { data: user, isLoading: userLoading, isError: userError } = useCurrentUser();
  const {
    data: districts,
    isLoading: districtsLoading,
    isError,
    refetch,
  } = useListDistricts({ query: { queryKey: getListDistrictsQueryKey() } });

  // The home district is stored as a district Number, so it has to be resolved
  // against the live list to get a route id.
  const homeDistrict = useMemo(
    () =>
      user?.homeDistrictNumber && districts
        ? districts.find(d => d.number === user.homeDistrictNumber)
        : undefined,
    [user?.homeDistrictNumber, districts],
  );

  const shouldRedirect = !browseAll && !!homeDistrict;

  useEffect(() => {
    if (shouldRedirect && homeDistrict && !redirected.current) {
      redirected.current = true;
      setLocation(`/districts/${homeDistrict.id}`, { replace: true });
    }
  }, [shouldRedirect, homeDistrict, setLocation]);

  const selectable = useMemo(
    () => (districts ?? []).filter(d => d.eventsCount > 0),
    [districts],
  );

  if (shouldRedirect) {
    return (
      <div className="container max-w-4xl mx-auto py-24 px-4 text-center text-muted-foreground">
        <p className="text-lg">{t('app.home_district_loading')}</p>
      </div>
    );
  }

  // Both the user and the district list feed the redirect decision, so hold the
  // picker back until both have answered — otherwise it flashes on screen for
  // someone who is about to be sent straight to their home district. A *failed*
  // user lookup is an answer, though: fall through to the picker rather than
  // stranding everyone on a skeleton because identity is unavailable.
  const isLoading = districtsLoading || (userLoading && !userError);

  return (
    <div className="container max-w-xl mx-auto py-24 px-4">
      <div className="text-center mb-10">
        <h1 className="text-4xl font-extrabold tracking-tight lg:text-5xl mb-4 text-foreground">
          {t('app.welcome')}
        </h1>
        <p className="text-xl text-muted-foreground">{t('app.select_district')}</p>
      </div>

      {isLoading ? (
        <Skeleton className="h-12 w-full rounded-md" />
      ) : isError ? (
        // A failed request is not an empty district list — say so explicitly.
        <div className="bg-muted/30 rounded-xl border border-dashed">
          <LoadError message={t('app.districts_load_failed')} onRetry={() => void refetch()} />
        </div>
      ) : (
        <Popover open={open} onOpenChange={setOpen}>
          <PopoverTrigger asChild>
            <Button
              variant="outline"
              role="combobox"
              aria-expanded={open}
              data-testid="get-started-district"
              className="w-full h-12 justify-between text-base shadow-sm border-2"
            >
              <span className="flex items-center gap-2 text-muted-foreground font-normal">
                <MapPin className="h-4 w-4" />
                {t('app.choose_district')}
              </span>
              <ChevronsUpDown className="h-4 w-4 shrink-0 opacity-50" />
            </Button>
          </PopoverTrigger>
          <PopoverContent className="w-[var(--radix-popover-trigger-width)] p-0" align="start">
            <Command>
              <CommandInput placeholder={t('app.search_districts')} />
              <CommandList>
                <CommandEmpty>{t('app.no_districts_found')}</CommandEmpty>
                <CommandGroup>
                  {selectable.map(district => (
                    <CommandItem
                      key={district.id}
                      // Searchable by number, name, or region.
                      value={`${district.number} ${district.name} ${district.region}`}
                      onSelect={() => {
                        setOpen(false);
                        setLocation(`/districts/${district.id}`);
                      }}
                      className="gap-2"
                    >
                      <span className="font-mono text-xs font-semibold text-secondary px-1.5 py-0.5 bg-secondary/10 rounded shrink-0">
                        {district.number}
                      </span>
                      <span className="truncate">{district.name}</span>
                      <span className="ml-auto shrink-0 text-xs uppercase tracking-wider text-muted-foreground">
                        {district.region}
                      </span>
                    </CommandItem>
                  ))}
                </CommandGroup>
              </CommandList>
            </Command>
          </PopoverContent>
        </Popover>
      )}
    </div>
  );
}
