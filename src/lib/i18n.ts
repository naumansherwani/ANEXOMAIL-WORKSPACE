/**
 * ANEXOMAIL — locale state (no provider, no external i18n dependency).
 *
 * Choice localStorage mein rehti hai, aur `<html lang>`/`dir` usi waqt update
 * hota hai. SSR-safe: pehla render hamesha default locale par hota hai, phir
 * hydration ke baad user ki choice lagti hai (hydration mismatch nahi).
 */

import { useEffect, useState } from "react";

import {
  DEFAULT_LOCALE,
  type Locale,
  type LocaleKey,
  STORAGE_KEY,
  findLocale,
} from "./locales";

const EVENT = "ax:locale";

function readStored(): Locale {
  if (typeof window === "undefined") return DEFAULT_LOCALE;
  try {
    return (
      findLocale(window.localStorage.getItem(STORAGE_KEY)) ??
      findLocale(window.navigator.language) ??
      DEFAULT_LOCALE
    );
  } catch {
    return DEFAULT_LOCALE;
  }
}

export function setLocale(locale: Locale) {
  try {
    window.localStorage.setItem(STORAGE_KEY, locale.tag);
  } catch {
    /* storage blocked — session ke liye phir bhi apply hoga */
  }
  window.dispatchEvent(new CustomEvent<string>(EVENT, { detail: locale.tag }));
}

export function useLocale(): { locale: Locale; t: (key: LocaleKey) => string } {
  const [locale, setLocaleState] = useState<Locale>(DEFAULT_LOCALE);

  useEffect(() => {
    const apply = (next: Locale) => {
      setLocaleState(next);
      document.documentElement.lang = next.tag;
      document.documentElement.dir = next.dir;
    };
    apply(readStored());
    const onChange = (e: Event) => {
      const tag = (e as CustomEvent<string>).detail;
      apply(findLocale(tag) ?? DEFAULT_LOCALE);
    };
    window.addEventListener(EVENT, onChange);
    return () => window.removeEventListener(EVENT, onChange);
  }, []);

  return { locale, t: (key) => locale.t[key] ?? DEFAULT_LOCALE.t[key] };
}
