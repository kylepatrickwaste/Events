import React from 'react';
import { Button } from '@/components/ui/button';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { AlertTriangle, RefreshCw } from 'lucide-react';

/**
 * Shown in place of an empty state when a request failed, so "nothing here" and
 * "we never heard back" don't look the same.
 */
export function LoadError({ message, onRetry, className }: {
  message?: string;
  onRetry?: () => void;
  className?: string;
}) {
  const { t } = useI18n();

  return (
    <div
      data-testid="load-error"
      className={cn('py-10 px-4 text-center text-muted-foreground', className)}
    >
      <AlertTriangle className="h-10 w-10 mx-auto mb-3 text-destructive/60" />
      <p className="text-base text-foreground">{message ?? t('connection.load_failed')}</p>
      {onRetry && (
        <Button variant="outline" size="sm" className="mt-4" onClick={onRetry}>
          <RefreshCw className="h-4 w-4 mr-2" />
          {t('connection.retry')}
        </Button>
      )}
    </div>
  );
}
