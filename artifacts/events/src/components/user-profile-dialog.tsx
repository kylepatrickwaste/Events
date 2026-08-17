import React from 'react';
import {
  useUpdateProfile,
  useListDistricts,
  getListDistrictsQueryKey,
  getGetLoginNameQueryKey,
  type District,
} from '@workspace/api-client-react';
import { useQueryClient } from '@tanstack/react-query';
import { useI18n, type Language } from '@/i18n';
import { useTheme } from '@/components/theme-provider';
import { useCurrentUser } from '@/hooks/use-current-user';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover';
import {
  Command,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
} from '@/components/ui/command';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { useToast } from '@/hooks/use-toast';
import { cn } from '@/lib/utils';
import { AlertTriangle, Check, ChevronsUpDown, Moon, Sun, X } from 'lucide-react';

const LANGUAGES: { code: Language; label: string }[] = [
  { code: 'en', label: 'EN' },
  { code: 'es', label: 'ES' },
  { code: 'fr', label: 'FR' },
];

/**
 * Picks a home district by its user-facing Number. A typed number that matches
 * no loaded district is still accepted — the districts list can lag behind the
 * server, and the API is the authority on what exists.
 */
function HomeDistrictPicker({ value, districts, disabled, onChange }: {
  value: string;
  districts: District[];
  disabled?: boolean;
  onChange: (districtNumber: string) => void;
}) {
  const { t } = useI18n();
  const [open, setOpen] = React.useState(false);
  const [search, setSearch] = React.useState('');

  const selected = districts.find(d => d.number === value);
  const typed = search.trim();
  // Only offer the free-text escape hatch when it isn't just a slower way to
  // pick something already in the list.
  const showTyped = typed.length > 0 && !districts.some(d => d.number.toLowerCase() === typed.toLowerCase());

  const choose = (districtNumber: string) => {
    setOpen(false);
    setSearch('');
    onChange(districtNumber);
  };

  return (
    <Popover
      open={open}
      onOpenChange={next => {
        setOpen(next);
        if (!next) setSearch('');
      }}
    >
      <PopoverTrigger asChild>
        <Button
          type="button"
          variant="outline"
          role="combobox"
          aria-expanded={open}
          disabled={disabled}
          className="w-full justify-between font-normal"
          data-testid="profile-home-district"
        >
          <span className={cn('truncate', !value && 'text-muted-foreground')}>
            {selected
              ? `${selected.number} – ${selected.name}`
              : value || t('profile.no_home_district')}
          </span>
          <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50" />
        </Button>
      </PopoverTrigger>
      <PopoverContent className="w-[var(--radix-popover-trigger-width)] p-0" align="start">
        <Command>
          <CommandInput
            value={search}
            onValueChange={setSearch}
            placeholder={t('profile.search_district')}
          />
          <CommandList>
            <CommandEmpty>{t('district.no_district_found')}</CommandEmpty>
            <CommandGroup>
              {showTyped && (
                // value === search always scores a match, so this stays visible
                // no matter what was typed.
                <CommandItem value={search} onSelect={() => choose(typed)}>
                  <Check className="mr-2 h-4 w-4 opacity-0" />
                  {t('profile.use_typed_district', { number: typed })}
                </CommandItem>
              )}
              <CommandItem
                value={`${t('profile.no_home_district')} __none__`}
                onSelect={() => choose('')}
                data-testid="profile-clear-home-district"
              >
                <X className="mr-2 h-4 w-4 opacity-50" />
                {t('profile.no_home_district')}
              </CommandItem>
              {districts.map(d => (
                <CommandItem
                  key={d.id}
                  value={`${d.number} ${d.name} ${d.region ?? ''}`}
                  onSelect={() => choose(d.number)}
                >
                  <Check className={cn('mr-2 h-4 w-4', d.number === value ? 'opacity-100' : 'opacity-0')} />
                  <span className="font-mono mr-2">{d.number}</span>
                  <span className="truncate">{d.name}</span>
                  {d.region ? (
                    <span className="ml-auto pl-2 text-xs text-muted-foreground">{d.region}</span>
                  ) : null}
                </CommandItem>
              ))}
            </CommandGroup>
          </CommandList>
        </Command>
      </PopoverContent>
    </Popover>
  );
}

/**
 * The signed-in user's own profile: the name the header shows and the district
 * the app opens into. Both are saved in one request so a half-applied edit is
 * not possible, and the dialog stays open on failure with what was typed.
 */
export function UserProfileDialog({ open, onOpenChange }: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  const { t, language, setLanguage } = useI18n();
  const { theme, setTheme } = useTheme();
  const { toast } = useToast();
  const queryClient = useQueryClient();
  const { data: user } = useCurrentUser();

  const { data: districts } = useListDistricts({
    query: { enabled: open, queryKey: getListDistrictsQueryKey() },
  });

  const [friendlyName, setFriendlyName] = React.useState('');
  const [districtNumber, setDistrictNumber] = React.useState('');
  const [error, setError] = React.useState<string | null>(null);

  // Seeded only on open: a background refetch of the current user while the
  // dialog is up must not overwrite what is being typed.
  const userRef = React.useRef(user);
  userRef.current = user;
  React.useEffect(() => {
    if (!open) return;
    setFriendlyName(userRef.current?.friendlyName ?? '');
    setDistrictNumber(userRef.current?.homeDistrictNumber ?? '');
    setError(null);
  }, [open]);

  const { mutate, isPending } = useUpdateProfile({
    mutation: {
      onSuccess: updated => {
        // The response is the fresh user, so seed the cache with it — the
        // header name and home-district indicator update from this alone.
        queryClient.setQueryData(getGetLoginNameQueryKey(), updated);
        onOpenChange(false);
        toast({ description: t('profile.saved') });
      },
      onError: (err: unknown) => {
        const status = (err as { status?: number } | null)?.status;
        setError(
          status === 400
            ? t('profile.error_unknown_district', { number: districtNumber.trim() })
            : t('profile.error_save_failed'),
        );
      },
    },
  });

  const save = () => {
    setError(null);
    mutate({
      data: {
        friendlyName: friendlyName.trim(),
        homeDistrictNumber: districtNumber.trim(),
      },
    });
  };

  return (
    <Dialog open={open} onOpenChange={next => !isPending && onOpenChange(next)}>
      <DialogContent
        className="max-h-[85vh] overflow-y-auto max-w-md"
        data-testid="profile-dialog"
      >
        <DialogHeader>
          <DialogTitle>{t('profile.title')}</DialogTitle>
          <DialogDescription>{t('profile.description')}</DialogDescription>
        </DialogHeader>

        <div className="space-y-4">
          <div className="space-y-1.5">
            <Label className="text-muted-foreground">{t('profile.ad_login')}</Label>
            <p className="font-mono text-sm break-all" data-testid="profile-ad-login">
              {user?.activeDirectoryName ?? '—'}
            </p>
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="profile-friendly-name">{t('profile.preferred_name')}</Label>
            <Input
              id="profile-friendly-name"
              value={friendlyName}
              disabled={isPending}
              placeholder={t('profile.preferred_name_placeholder')}
              onChange={e => setFriendlyName(e.target.value)}
              data-testid="profile-friendly-name"
            />
            <p className="text-xs text-muted-foreground">{t('profile.preferred_name_hint')}</p>
          </div>

          <div className="space-y-1.5">
            <Label>{t('profile.home_district')}</Label>
            <HomeDistrictPicker
              value={districtNumber}
              districts={districts ?? []}
              disabled={isPending}
              onChange={setDistrictNumber}
            />
            <p className="text-xs text-muted-foreground">{t('profile.home_district_hint')}</p>
          </div>

          {/*
            Language and theme are deliberately NOT part of the Save button: they
            apply and persist the moment they are clicked, exactly as they did in
            the header. Routing them through Save would mean Cancel had to undo a
            theme the user can already see applied behind the dialog.
          */}
          <div className="space-y-3 rounded-md border bg-muted/30 p-3">
            <p className="text-sm font-medium">{t('profile.preferences')}</p>

            <div className="flex items-center justify-between gap-3">
              <Label className="font-normal">{t('profile.language')}</Label>
              <div className="flex items-center gap-1" role="group" aria-label={t('profile.language')}>
                {LANGUAGES.map(({ code, label }) => (
                  <Button
                    key={code}
                    type="button"
                    size="sm"
                    variant={language === code ? 'default' : 'outline'}
                    aria-pressed={language === code}
                    className="h-7 w-11 px-0 text-xs"
                    onClick={() => setLanguage(code)}
                    data-testid={`profile-language-${code}`}
                  >
                    {label}
                  </Button>
                ))}
              </div>
            </div>

            <div className="flex items-center justify-between gap-3">
              <Label className="font-normal">{t('profile.theme')}</Label>
              <div className="flex items-center gap-1" role="group" aria-label={t('profile.theme')}>
                <Button
                  type="button"
                  size="sm"
                  variant={theme === 'dark' ? 'outline' : 'default'}
                  aria-pressed={theme !== 'dark'}
                  className="h-7 gap-1.5 px-2.5 text-xs"
                  onClick={() => setTheme('light')}
                  data-testid="profile-theme-light"
                >
                  <Sun className="h-3.5 w-3.5" />
                  {t('profile.theme_light')}
                </Button>
                <Button
                  type="button"
                  size="sm"
                  variant={theme === 'dark' ? 'default' : 'outline'}
                  aria-pressed={theme === 'dark'}
                  className="h-7 gap-1.5 px-2.5 text-xs"
                  onClick={() => setTheme('dark')}
                  data-testid="profile-theme-dark"
                >
                  <Moon className="h-3.5 w-3.5" />
                  {t('profile.theme_dark')}
                </Button>
              </div>
            </div>

            <p className="text-xs text-muted-foreground">{t('profile.preferences_hint')}</p>
          </div>

          {error && (
            <p
              role="alert"
              data-testid="profile-error"
              className="flex items-start gap-2 rounded-md border border-destructive/40 bg-destructive/5 p-2.5 text-sm text-destructive"
            >
              <AlertTriangle className="h-4 w-4 shrink-0 mt-0.5" />
              {error}
            </p>
          )}
        </div>

        <DialogFooter>
          <Button variant="outline" disabled={isPending} onClick={() => onOpenChange(false)}>
            {t('district.cancel')}
          </Button>
          <Button disabled={isPending} onClick={save} data-testid="profile-save">
            {t('district.save')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
