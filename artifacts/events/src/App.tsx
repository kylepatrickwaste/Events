import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { Toaster } from '@/components/ui/toaster';
import { TooltipProvider } from '@/components/ui/tooltip';
import { Route, Switch, Router as WouterRouter } from 'wouter';
import { I18nProvider } from '@/i18n';
import { ThemeProvider } from '@/components/theme-provider';
import { Shell } from '@/components/layout/Shell';
import { ServerStatusProvider } from '@/hooks/use-server-status';

import Home from '@/pages/home';
import DistrictWorkspace from '@/pages/district-workspace';
import EventDetail from '@/pages/event-detail';
import NotFound from '@/pages/not-found';

const queryClient = new QueryClient();

function Router() {
  return (
    <Shell>
      <Switch>
        <Route path="/" component={Home} />
        <Route path="/districts/:districtId" component={DistrictWorkspace} />
        <Route path="/districts/:districtId/events/:eventId" component={EventDetail} />
        <Route component={NotFound} />
      </Switch>
    </Shell>
  );
}

function App() {
  return (
    <ThemeProvider defaultTheme="light" storageKey="app-theme">
      <I18nProvider>
        <QueryClientProvider client={queryClient}>
          <ServerStatusProvider>
            <TooltipProvider>
              <WouterRouter base={import.meta.env.BASE_URL.replace(/\/$/, '')}>
                <Router />
              </WouterRouter>
              <Toaster />
            </TooltipProvider>
          </ServerStatusProvider>
        </QueryClientProvider>
      </I18nProvider>
    </ThemeProvider>
  );
}

export default App;
