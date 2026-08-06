import React, { createContext, useContext, useEffect, useState } from 'react';

export type Language = 'en' | 'es' | 'fr';

interface I18nContextType {
  language: Language;
  setLanguage: (lang: Language) => void;
  t: (key: string, variables?: Record<string, string | number>) => string;
  formatCurrency: (amount: number) => string;
  formatDate: (dateStr: string, options?: Intl.DateTimeFormatOptions) => string;
}

const I18nContext = createContext<I18nContextType | undefined>(undefined);

import en from './en.json';
import es from './es.json';
import fr from './fr.json';

const translations: Record<Language, unknown> = { en, es, fr };

export function I18nProvider({ children }: { children: React.ReactNode }) {
  const [language, setLanguageState] = useState<Language>('en');

  useEffect(() => {
    const saved = localStorage.getItem('app-language') as Language;
    if (saved && ['en', 'es', 'fr'].includes(saved)) {
      setLanguageState(saved);
    }
  }, []);

  const setLanguage = (lang: Language) => {
    setLanguageState(lang);
    localStorage.setItem('app-language', lang);
  };

  const t = (key: string, variables?: Record<string, string | number>) => {
    const keys = key.split('.');
    let template: any = translations[language];
    
    for (const k of keys) {
      if (template && typeof template === 'object') {
        template = template[k];
      } else {
        template = undefined;
        break;
      }
    }

    if (template === undefined || typeof template !== 'string') {
      // fallback to english
      let enTemplate: any = en;
      for (const k of keys) {
        if (enTemplate && typeof enTemplate === 'object') {
          enTemplate = enTemplate[k];
        } else {
          enTemplate = undefined;
          break;
        }
      }
      template = typeof enTemplate === 'string' ? enTemplate : key;
    }

    let result = template as string;
    if (variables) {
      for (const [k, v] of Object.entries(variables)) {
        result = result.replace(new RegExp(`{{\\s*${k}\\s*}}`, 'g'), String(v));
      }
    }
    return result;
  };

  const formatCurrency = (amount: number) => {
    const locale = language === 'en' ? 'en-US' : language === 'es' ? 'es-MX' : 'fr-FR';
    return new Intl.NumberFormat(locale, { style: 'currency', currency: 'USD' }).format(amount);
  };

  const formatDate = (dateStr: string, options?: Intl.DateTimeFormatOptions) => {
    if (!dateStr) return '';
    const date = new Date(dateStr);
    const locale = language === 'en' ? 'en-US' : language === 'es' ? 'es-MX' : 'fr-FR';
    return new Intl.DateTimeFormat(locale, {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
      hour: 'numeric',
      minute: '2-digit',
      ...options
    }).format(date);
  };

  return (
    <I18nContext.Provider value={{ language, setLanguage, t, formatCurrency, formatDate }}>
      {children}
    </I18nContext.Provider>
  );
}

export function useI18n() {
  const context = useContext(I18nContext);
  if (!context) {
    throw new Error('useI18n must be used within an I18nProvider');
  }
  return context;
}
