/**
 * ANEXOMAIL — REAL TRANSLATION LAYER (Phase 31B)
 *
 * Sach: har zubaan ka apna bundle `src/i18n/<tag>.json` hai. Bundle apne
 * Hetzner server par Argos Translate (offline, koi bahar ka API nahi) se
 * banta hai — `server/i18n/translate.py`. Runtime par:
 *
 *   1. Choice `localStorage["ax.locale"]` mein, `<html lang/dir>` fauran set.
 *   2. Bundle dynamic import se aata hai (code-split) aur localStorage mein
 *      cache hota hai — doosri dafa switch instant, network ka intezar nahi.
 *   3. Jis string ka tarjuma maujood nahi, wahan asli English dikhti hai —
 *      kabhi khali ya dummy text nahi.
 */

import { useCallback, useEffect, useState } from "react";

import { DEFAULT_LOCALE, type Locale, type LocaleKey, STORAGE_KEY, findLocale } from "./locales";

const EVENT = "ax:locale";
const CACHE_PREFIX = "ax.i18n.";

type Bundle = Record<string, string>;

const files = import.meta.glob<{ default: Bundle }>("../i18n/*.json");
const memory = new Map<string, Bundle>();

function cacheKey(tag: string) {
  return `${CACHE_PREFIX}${tag}`;
}

function readCache(tag: string): Bundle | null {
  try {
    const raw = window.localStorage.getItem(cacheKey(tag));
    return raw ? (JSON.parse(raw) as Bundle) : null;
  } catch {
    return null;
  }
}

function writeCache(tag: string, bundle: Bundle) {
  try {
    window.localStorage.setItem(cacheKey(tag), JSON.stringify(bundle));
  } catch {
    /* storage bhara ya bandh — sirf memory cache chalegi */
  }
}

/** Bundle laao: memory → localStorage (instant) → dynamic import. */
async function loadBundle(tag: string): Promise<Bundle> {
  const cached = memory.get(tag);
  if (cached) return cached;

  const stored = typeof window === "undefined" ? null : readCache(tag);
  if (stored) memory.set(tag, stored);

  const path = `../i18n/${tag}.json`;
  const loader = files[path];
  if (!loader) {
    const empty = stored ?? {};
    memory.set(tag, empty);
    return empty;
  }
  try {
    const mod = await loader();
    const bundle = mod.default ?? {};
    memory.set(tag, bundle);
    if (typeof window !== "undefined") writeCache(tag, bundle);
    return bundle;
  } catch {
    const fallback = stored ?? {};
    memory.set(tag, fallback);
    return fallback;
  }
}

export function setLocale(locale: Locale) {
  try {
    window.localStorage.setItem(STORAGE_KEY, locale.tag);
  } catch {
    /* storage blocked — session ke liye phir bhi apply hoga */
  }
  // Bundle pehle se garam kar do, taake switch par jhatka na ho.
  void loadBundle(locale.tag);
  window.dispatchEvent(new CustomEvent<string>(EVENT, { detail: locale.tag }));
}

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

/**
 * `t("English source string")` — key wahi English text hai jo screen par likha
 * hai, is liye tarjuma na milne par bhi page sahi English dikhata hai.
 * Purane nav keys (LocaleKey) bhi chalte rehte hain.
 */
export function useLocale(): {
  locale: Locale;
  t: (key: string) => string;
  ready: boolean;
} {
  const [locale, setLocaleState] = useState<Locale>(DEFAULT_LOCALE);
  const [bundle, setBundle] = useState<Bundle>({});
  const [ready, setReady] = useState(false);

  useEffect(() => {
    let live = true;

    const apply = (next: Locale) => {
      setLocaleState(next);
      document.documentElement.lang = next.tag;
      document.documentElement.dir = next.dir;
      // Cache se fauran (light speed), phir file se pukhta.
      const instant = memory.get(next.tag) ?? readCache(next.tag);
      if (instant) {
        setBundle(instant);
        setReady(true);
      } else {
        setReady(next.tag === DEFAULT_LOCALE.tag);
      }
      void loadBundle(next.tag).then((b) => {
        if (!live) return;
        setBundle(b);
        setReady(true);
      });
    };

    apply(readStored());
    const onChange = (e: Event) => {
      const tag = (e as CustomEvent<string>).detail;
      apply(findLocale(tag) ?? DEFAULT_LOCALE);
    };
    window.addEventListener(EVENT, onChange);
    return () => {
      live = false;
      window.removeEventListener(EVENT, onChange);
    };
  }, []);

  const t = useCallback(
    (key: string) => {
      if (locale.tag === DEFAULT_LOCALE.tag) {
        return locale.t[key as LocaleKey] ?? key;
      }
      return bundle[key] ?? locale.t[key as LocaleKey] ?? DEFAULT_LOCALE.t[key as LocaleKey] ?? key;
    },
    [bundle, locale],
  );

  return { locale, t, ready };
}
