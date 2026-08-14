import React from 'react';
import { Link } from 'wouter';
import { useI18n, Language } from '@/i18n';
import { useTheme } from '@/components/theme-provider';
import logoUrl from '@assets/Waste_Connections_Logo_Symbol_-_2_Color-_12-10-09_-_transparen_1786045458506.png';
import { Moon, Sun } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { TruckDrive } from './TruckDrive';

export function Header() {
  const { t, language, setLanguage } = useI18n();
  const { theme, setTheme } = useTheme();
  const titleRef = React.useRef<HTMLAnchorElement>(null);
  const langRef = React.useRef<HTMLDivElement>(null);

  return (
    <header className="sticky top-0 z-50 w-full border-b bg-background shadow-sm">
      <TruckDrive startRef={titleRef} endRef={langRef} />
      <div className="container flex h-14 items-center justify-between">
        <Link href="/" ref={titleRef} className="flex items-center gap-2 mr-6 hover:opacity-90 transition-opacity">
          <img src={logoUrl} alt="Waste Connections" className="h-8 w-auto object-contain" />
          <span className="font-bold hidden sm:inline-block text-primary">
            {t('app.title')}
          </span>
        </Link>
        <div className="flex flex-1 items-center justify-end space-x-4">
          <div ref={langRef} className="flex items-center space-x-1 text-sm text-muted-foreground">
            <button 
              onClick={() => setLanguage('en')}
              className={`hover:text-foreground transition-colors ${language === 'en' ? 'text-foreground font-semibold' : ''}`}
            >
              EN
            </button>
            <span>|</span>
            <button 
              onClick={() => setLanguage('es')}
              className={`hover:text-foreground transition-colors ${language === 'es' ? 'text-foreground font-semibold' : ''}`}
            >
              ES
            </button>
            <span>|</span>
            <button 
              onClick={() => setLanguage('fr')}
              className={`hover:text-foreground transition-colors ${language === 'fr' ? 'text-foreground font-semibold' : ''}`}
            >
              FR
            </button>
          </div>
          <Button
            variant="ghost"
            size="icon"
            onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}
            className="text-muted-foreground hover:text-foreground"
          >
            <Sun className="h-5 w-5 rotate-0 scale-100 transition-all dark:-rotate-90 dark:scale-0" />
            <Moon className="absolute h-5 w-5 rotate-90 scale-0 transition-all dark:rotate-0 dark:scale-100" />
            <span className="sr-only">Toggle theme</span>
          </Button>
        </div>
      </div>
    </header>
  );
}

export function Footer() {
  const { t, setLanguage, language } = useI18n();

  return (
    <footer className="border-t bg-muted/40 py-6 mt-auto">
      <div className="container flex flex-col sm:flex-row items-center justify-between gap-4">
        <div className="text-sm text-muted-foreground">
          © 2026 Waste Connections
        </div>
        <div className="flex items-center space-x-3 text-sm text-muted-foreground">
          <button 
            onClick={() => setLanguage('en')}
            className={`hover:text-foreground transition-colors ${language === 'en' ? 'text-foreground font-semibold' : ''}`}
          >
            {t('nav.english')}
          </button>
          <span>|</span>
          <button 
            onClick={() => setLanguage('es')}
            className={`hover:text-foreground transition-colors ${language === 'es' ? 'text-foreground font-semibold' : ''}`}
          >
            {t('nav.spanish')}
          </button>
          <span>|</span>
          <button 
            onClick={() => setLanguage('fr')}
            className={`hover:text-foreground transition-colors ${language === 'fr' ? 'text-foreground font-semibold' : ''}`}
          >
            {t('nav.french')}
          </button>
        </div>
      </div>
    </footer>
  );
}

export function Shell({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-[100dvh] flex flex-col bg-background">
      <Header />
      <main className="flex-1">
        {children}
      </main>
      <Footer />
    </div>
  );
}
