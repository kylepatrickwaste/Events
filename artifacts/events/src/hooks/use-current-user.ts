import { useGetLoginName, getGetLoginNameQueryKey } from '@workspace/api-client-react';

/**
 * The signed-in user as resolved by the API (appsettings overlay off IIS,
 * Windows Authentication on the real servers).
 *
 * Identity is decoration on every screen that uses it — the header name, the
 * home-district shortcut — so a failure here must degrade instantly rather than
 * hold up the page: no retries, and callers should read `undefined` as "no
 * identity" instead of "still loading". Shared so those options can't drift
 * between call sites.
 */
export function useCurrentUser() {
  return useGetLoginName({
    query: {
      queryKey: getGetLoginNameQueryKey(),
      retry: false,
      staleTime: 5 * 60_000,
      refetchOnWindowFocus: false,
    },
  });
}
