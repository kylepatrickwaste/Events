import React, { createContext, useContext, useEffect, useMemo, useRef } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { useHealthCheck, getHealthCheckQueryKey } from '@workspace/api-client-react';

/** How often to re-check the API while it is answering. */
const POLL_INTERVAL_MS = 20_000;
/** How often to re-check while we believe it is down, so recovery is noticed fast. */
const DOWN_POLL_INTERVAL_MS = 5_000;

export interface ServerStatus {
  /** False once a health check has actually failed (network error or non-OK response). */
  isReachable: boolean;
  /** True while a health check request is in flight. */
  isChecking: boolean;
  /** Build number reported by whichever API the client is pointed at. */
  buildNumber?: string;
  /** Run a health check immediately. */
  retry: () => void;
}

const ServerStatusContext = createContext<ServerStatus | undefined>(undefined);

/**
 * Single source of truth for "can we reach the API".  The app has no backend of
 * its own and no local data, so `/api/healthz` answering is the only honest
 * signal that anything on screen can be trusted.
 */
export function ServerStatusProvider({ children }: { children: React.ReactNode }) {
  const { data, isError, isFetching, refetch } = useHealthCheck({
    query: {
      queryKey: getHealthCheckQueryKey(),
      // A network failure or non-OK response must read as "down" rather than
      // "no data yet", so don't let retries or a stale window hide it.
      retry: false,
      staleTime: 0,
      refetchOnWindowFocus: true,
      refetchOnReconnect: true,
      refetchInterval: (query) =>
        query.state.status === 'error' ? DOWN_POLL_INTERVAL_MS : POLL_INTERVAL_MS,
    },
  });

  // Queries that failed while the server was down stay failed until something
  // asks again, so the page would keep showing an error after the dialog closed.
  // Refetch everything on the down -> up transition.
  const queryClient = useQueryClient();
  const wasDown = useRef(false);
  useEffect(() => {
    if (isError) {
      wasDown.current = true;
    } else if (wasDown.current) {
      wasDown.current = false;
      void queryClient.invalidateQueries();
    }
  }, [isError, queryClient]);

  const value = useMemo<ServerStatus>(
    () => ({
      // Optimistic until proven otherwise: the very first check is still in
      // flight on load, and we don't want a dialog flashing before it lands.
      isReachable: !isError,
      isChecking: isFetching,
      buildNumber: data?.buildNumber,
      retry: () => {
        void refetch();
      },
    }),
    [isError, isFetching, data?.buildNumber, refetch],
  );

  return <ServerStatusContext.Provider value={value}>{children}</ServerStatusContext.Provider>;
}

export function useServerStatus(): ServerStatus {
  const context = useContext(ServerStatusContext);
  if (!context) {
    throw new Error('useServerStatus must be used within a ServerStatusProvider');
  }
  return context;
}
