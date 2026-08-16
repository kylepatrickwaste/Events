import React from 'react';
import {
  useListUsers,
  useUpdateUser,
  getListUsersQueryKey,
  getGetLoginNameQueryKey,
  type AppUser,
} from '@workspace/api-client-react';
import { useQueryClient } from '@tanstack/react-query';
import { useI18n } from '@/i18n';
import { useCurrentUser } from '@/hooks/use-current-user';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Skeleton } from '@/components/ui/skeleton';
import { useToast } from '@/hooks/use-toast';
import { cn } from '@/lib/utils';
import { AlertTriangle, ChevronDown, ShieldCheck } from 'lucide-react';

const ADMIN = 'Admin';
const AGENT = 'Agent';

/**
 * One roster entry. Collapsed it is a single scannable line; expanded it is the
 * edit form. Only one row is open at a time — the list lives inside a dialog,
 * and several open forms would push Save off the bottom.
 */
function UserRow({ user, isSelf, expanded, onToggle, onSaved }: {
  user: AppUser;
  isSelf: boolean;
  expanded: boolean;
  onToggle: () => void;
  onSaved: () => void;
}) {
  const { t } = useI18n();
  const { toast } = useToast();

  const [friendlyName, setFriendlyName] = React.useState('');
  const [districtNumber, setDistrictNumber] = React.useState('');
  const [role, setRole] = React.useState<string>(AGENT);
  const [active, setActive] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  // Seeded only when the row opens. A background refetch of the roster while
  // somebody is typing must not overwrite the edit in progress, so the row is
  // read through a ref rather than listed as a dependency.
  const userRef = React.useRef(user);
  userRef.current = user;
  React.useEffect(() => {
    if (!expanded) return;
    const current = userRef.current;
    setFriendlyName(current.friendlyName ?? '');
    setDistrictNumber(current.homeDistrictNumber ?? '');
    setRole(current.role === ADMIN ? ADMIN : AGENT);
    setActive(current.active);
    setError(null);
  }, [expanded]);

  const { mutate, isPending } = useUpdateUser({
    mutation: {
      onSuccess: () => {
        onSaved();
        toast({ description: t('profile.user_saved') });
        onToggle();
      },
      onError: (err: unknown) => {
        const status = (err as { status?: number } | null)?.status;
        setError(
          status === 400
            ? t('profile.error_user_rejected')
            : t('profile.error_user_save_failed'),
        );
      },
    },
  });

  const save = () => {
    setError(null);
    mutate({
      id: user.id,
      data: {
        friendlyName: friendlyName.trim(),
        homeDistrictNumber: districtNumber.trim(),
        role,
        active,
      },
    });
  };

  const displayName = user.friendlyName?.trim() || user.activeDirectoryName;

  return (
    <li className="border-b last:border-b-0">
      <button
        type="button"
        onClick={onToggle}
        aria-expanded={expanded}
        className="flex w-full items-center gap-2 px-2.5 py-2 text-left hover:bg-muted/60 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-ring"
        data-testid={`admin-user-${user.id}`}
      >
        <ChevronDown
          className={cn('h-4 w-4 shrink-0 text-muted-foreground transition-transform', expanded && 'rotate-180')}
        />
        <span className="min-w-0 flex-1">
          <span className={cn('block truncate text-sm', !user.active && 'text-muted-foreground line-through')}>
            {displayName}
          </span>
          <span className="block truncate font-mono text-xs text-muted-foreground">
            {user.activeDirectoryName}
          </span>
        </span>
        {user.homeDistrictNumber ? (
          <span className="shrink-0 font-mono text-xs text-muted-foreground">
            {user.homeDistrictNumber}
          </span>
        ) : null}
        {user.role === ADMIN ? (
          <ShieldCheck className="h-4 w-4 shrink-0 text-primary" aria-label={t('profile.role_admin')} />
        ) : null}
      </button>

      {expanded && (
        <div className="space-y-3 border-t bg-muted/30 px-2.5 py-3">
          <div className="space-y-1.5">
            <Label htmlFor={`admin-name-${user.id}`} className="text-xs">
              {t('profile.preferred_name')}
            </Label>
            <Input
              id={`admin-name-${user.id}`}
              value={friendlyName}
              disabled={isPending}
              className="h-8"
              placeholder={t('profile.preferred_name_placeholder')}
              onChange={e => setFriendlyName(e.target.value)}
              data-testid={`admin-user-name-${user.id}`}
            />
          </div>

          <div className="space-y-1.5">
            <Label htmlFor={`admin-district-${user.id}`} className="text-xs">
              {t('profile.home_district')}
            </Label>
            <Input
              id={`admin-district-${user.id}`}
              value={districtNumber}
              disabled={isPending}
              className="h-8 font-mono"
              placeholder={t('profile.no_home_district')}
              onChange={e => setDistrictNumber(e.target.value)}
              data-testid={`admin-user-district-${user.id}`}
            />
          </div>

          <div className="flex items-center justify-between gap-3">
            <Label className="text-xs font-normal">{t('profile.role')}</Label>
            <div className="flex items-center gap-1" role="group" aria-label={t('profile.role')}>
              {[AGENT, ADMIN].map(value => (
                <Button
                  key={value}
                  type="button"
                  size="sm"
                  variant={role === value ? 'default' : 'outline'}
                  aria-pressed={role === value}
                  disabled={isPending || isSelf}
                  className="h-7 px-2.5 text-xs"
                  onClick={() => setRole(value)}
                  data-testid={`admin-user-role-${value.toLowerCase()}-${user.id}`}
                >
                  {value === ADMIN ? t('profile.role_admin') : t('profile.role_agent')}
                </Button>
              ))}
            </div>
          </div>

          <div className="flex items-center justify-between gap-3">
            <Label htmlFor={`admin-active-${user.id}`} className="text-xs font-normal">
              {t('profile.active_user')}
            </Label>
            <input
              id={`admin-active-${user.id}`}
              type="checkbox"
              checked={active}
              disabled={isPending || isSelf}
              onChange={e => setActive(e.target.checked)}
              className="h-4 w-4 accent-primary disabled:opacity-50"
              data-testid={`admin-user-active-${user.id}`}
            />
          </div>

          {/*
            Role and roster status are locked on your own row rather than left
            enabled and rejected by the API: demoting yourself removes the only
            screen that could undo it, so the safest place to say no is before
            the click.
          */}
          {isSelf && (
            <p className="text-xs text-muted-foreground">{t('profile.self_locked_hint')}</p>
          )}

          {error && (
            <p
              role="alert"
              className="flex items-start gap-2 rounded-md border border-destructive/40 bg-destructive/5 p-2 text-xs text-destructive"
              data-testid={`admin-user-error-${user.id}`}
            >
              <AlertTriangle className="mt-0.5 h-3.5 w-3.5 shrink-0" />
              {error}
            </p>
          )}

          <div className="flex justify-end gap-2">
            <Button
              type="button"
              variant="outline"
              size="sm"
              className="h-7 text-xs"
              disabled={isPending}
              onClick={onToggle}
            >
              {t('district.cancel')}
            </Button>
            <Button
              type="button"
              size="sm"
              className="h-7 text-xs"
              disabled={isPending}
              onClick={save}
              data-testid={`admin-user-save-${user.id}`}
            >
              {t('district.save')}
            </Button>
          </div>
        </div>
      )}
    </li>
  );
}

/**
 * The administrator's view of everyone who has ever signed in. Rows are created
 * by the API on first contact, so this is a record of real visitors rather than
 * a list somebody has to provision.
 */
export function AdminUserList({ enabled }: { enabled: boolean }) {
  const { t } = useI18n();
  const queryClient = useQueryClient();
  const { data: me } = useCurrentUser();
  const [expandedId, setExpandedId] = React.useState<number | null>(null);

  const { data: users, isLoading, isError } = useListUsers({
    query: { enabled, queryKey: getListUsersQueryKey() },
  });

  const onSaved = React.useCallback(() => {
    queryClient.invalidateQueries({ queryKey: getListUsersQueryKey() });
    // An administrator can rename themselves from this list too, and the header
    // reads its name from the current-user query, not from here.
    queryClient.invalidateQueries({ queryKey: getGetLoginNameQueryKey() });
  }, [queryClient]);

  if (isLoading) {
    return (
      <div className="space-y-2" data-testid="admin-users-loading">
        <Skeleton className="h-9 w-full" />
        <Skeleton className="h-9 w-full" />
        <Skeleton className="h-9 w-full" />
      </div>
    );
  }

  if (isError) {
    return (
      <p
        role="alert"
        className="flex items-start gap-2 rounded-md border border-destructive/40 bg-destructive/5 p-2 text-xs text-destructive"
        data-testid="admin-users-error"
      >
        <AlertTriangle className="mt-0.5 h-3.5 w-3.5 shrink-0" />
        {t('profile.users_load_failed')}
      </p>
    );
  }

  if (!users || users.length === 0) {
    return <p className="text-xs text-muted-foreground">{t('profile.users_empty')}</p>;
  }

  return (
    <ul
      className="max-h-64 overflow-y-auto rounded-md border bg-background"
      data-testid="admin-users-list"
    >
      {users.map(user => (
        <UserRow
          key={user.id}
          user={user}
          isSelf={user.activeDirectoryName === me?.activeDirectoryName}
          expanded={expandedId === user.id}
          onToggle={() => setExpandedId(current => (current === user.id ? null : user.id))}
          onSaved={onSaved}
        />
      ))}
    </ul>
  );
}
