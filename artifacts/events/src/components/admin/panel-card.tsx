import React from 'react';
import { useI18n } from '@/i18n';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import { LoadError } from '@/components/load-error';
import { RotateCcw } from 'lucide-react';

/**
 * One panel of the administration page: a titled card that says up front where
 * its contents come from -- the server, or only this browser -- and reserves
 * the same space for loading and failure that the district grid does.
 *
 * `dirty` + `onReset` put an undo next to the panel that has unsaved local
 * edits, so nothing local is ever stranded without a way back.
 */
export function PanelCard({
  title,
  hint,
  localOnly,
  dirty,
  onReset,
  isLoading,
  isError,
  onRetry,
  children,
  testId,
}: {
  title: string;
  hint?: string;
  localOnly?: boolean;
  dirty?: boolean;
  onReset?: () => void;
  isLoading?: boolean;
  isError?: boolean;
  onRetry?: () => void;
  children: React.ReactNode;
  testId?: string;
}) {
  const { t } = useI18n();

  return (
    <Card className="flex h-full flex-col shadow-sm" data-testid={testId}>
      <CardHeader className="flex-row items-center justify-between gap-2 space-y-0 py-2.5">
        <div className="min-w-0">
          <CardTitle className="flex items-center gap-2 text-sm">
            <span className="truncate">{title}</span>
            {localOnly && (
              <span className="shrink-0 rounded bg-amber-100 px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-amber-900 dark:bg-amber-500/20 dark:text-amber-200">
                {t('admin.local_badge')}
              </span>
            )}
          </CardTitle>
          {hint && <p className="mt-0.5 text-xs text-muted-foreground">{hint}</p>}
        </div>
        {dirty && onReset && (
          <Button type="button" size="sm" variant="ghost" className="h-7 shrink-0 gap-1.5 text-xs" onClick={onReset}>
            <RotateCcw className="h-3.5 w-3.5" />
            {t('admin.discard_local')}
          </Button>
        )}
      </CardHeader>
      <CardContent className="flex-1 pt-0">
        {isLoading ? (
          <div className="space-y-2">
            {[1, 2, 3].map(i => <Skeleton key={i} className="h-8 w-full" />)}
          </div>
        ) : isError ? (
          // A failed request must never read as an empty list.
          <LoadError onRetry={onRetry ?? (() => {})} />
        ) : (
          children
        )}
      </CardContent>
    </Card>
  );
}
