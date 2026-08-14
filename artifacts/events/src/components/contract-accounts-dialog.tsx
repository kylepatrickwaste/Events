import React from 'react';
import {
  useListDistrictAccountFlags,
  getListDistrictAccountFlagsQueryKey,
  useDeleteAccountFlag,
} from '@workspace/api-client-react';
import { useQueryClient } from '@tanstack/react-query';
import { useI18n } from '@/i18n';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import { useToast } from '@/hooks/use-toast';
import { FileX2, Undo2 } from 'lucide-react';

export function ContractAccountsDialog({ open, onOpenChange, districtId, onUnflagged }: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  districtId: number;
  onUnflagged: () => void;
}) {
  const { t, formatDate } = useI18n();
  const queryClient = useQueryClient();
  const { toast } = useToast();

  const { data: flags, isLoading } = useListDistrictAccountFlags(districtId, {
    query: { enabled: open && !!districtId, queryKey: getListDistrictAccountFlagsQueryKey(districtId) },
  });

  const deleteFlag = useDeleteAccountFlag();

  const handleRemove = (flagId: number, accountNumber: string) => {
    deleteFlag.mutate({ flagId }, {
      onSuccess: () => {
        queryClient.invalidateQueries({ queryKey: getListDistrictAccountFlagsQueryKey(districtId) });
        onUnflagged();
        toast({ description: t('contract_accounts.removed', { account: accountNumber }) });
      },
      onError: () => {
        toast({ variant: 'destructive', description: t('contract_accounts.remove_failed') });
      },
    });
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-2xl">
        <DialogHeader>
          <DialogTitle>{t('contract_accounts.title')}</DialogTitle>
          <DialogDescription>{t('contract_accounts.description')}</DialogDescription>
        </DialogHeader>

        {isLoading ? (
          <div className="space-y-3">
            {[1, 2, 3].map(i => <Skeleton key={i} className="h-14 w-full" />)}
          </div>
        ) : !flags || flags.length === 0 ? (
          <div className="py-10 text-center text-muted-foreground">
            <FileX2 className="h-10 w-10 mx-auto mb-3 opacity-20" />
            <p>{t('contract_accounts.empty')}</p>
          </div>
        ) : (
          <div className="border rounded-lg divide-y max-h-[50vh] overflow-y-auto">
            {flags.map(f => (
              <div key={f.id} className="flex items-center gap-4 p-3">
                <div className="flex-1 min-w-0">
                  <div className="font-mono font-medium">{f.accountNumber}</div>
                  <div className="text-xs text-muted-foreground">
                    {t('contract_accounts.flagged_by', { user: f.createdBy, date: formatDate(f.dateCreated) })}
                  </div>
                </div>
                <Button
                  size="sm"
                  variant="outline"
                  disabled={deleteFlag.isPending}
                  onClick={() => handleRemove(f.id, f.accountNumber)}
                >
                  <Undo2 className="h-4 w-4 mr-1.5" />
                  {t('contract_accounts.remove')}
                </Button>
              </div>
            ))}
          </div>
        )}
      </DialogContent>
    </Dialog>
  );
}
