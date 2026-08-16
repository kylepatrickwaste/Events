import React from 'react';
import { AlertDialog, AlertDialogContent, AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogTitle } from '@/components/ui/alert-dialog';
import { Button } from '@/components/ui/button';
import { useI18n } from '@/i18n';
import { useServerStatus } from '@/hooks/use-server-status';
import { RefreshCw, ServerCrash } from 'lucide-react';

/**
 * Blocking popup shown whenever the API cannot be reached.  Nothing in this app
 * works without the server, so the dialog deliberately has no dismiss button —
 * it closes itself as soon as a health check succeeds.
 */
export function ApiUnreachableDialog() {
  const { t } = useI18n();
  const { isReachable, isChecking, retry } = useServerStatus();

  return (
    <AlertDialog open={!isReachable}>
      <AlertDialogContent
        data-testid="dialog-api-unreachable"
        onEscapeKeyDown={e => e.preventDefault()}
      >
        <AlertDialogHeader>
          <div className="mx-auto sm:mx-0 mb-1 flex h-10 w-10 items-center justify-center rounded-full bg-destructive/10">
            <ServerCrash className="h-5 w-5 text-destructive" />
          </div>
          <AlertDialogTitle>{t('connection.unreachable_title')}</AlertDialogTitle>
          <AlertDialogDescription>{t('connection.unreachable_description')}</AlertDialogDescription>
        </AlertDialogHeader>
        <p className="text-sm text-muted-foreground">{t('connection.unreachable_hint')}</p>
        <AlertDialogFooter>
          <Button onClick={retry} disabled={isChecking} data-testid="button-retry-connection">
            <RefreshCw className={`mr-2 h-4 w-4 ${isChecking ? 'animate-spin' : ''}`} />
            {isChecking ? t('connection.checking') : t('connection.retry')}
          </Button>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );
}
