/**
 * ANEXOMAIL — REAL TRANSLATION LAYER (Phase 31B)
 *
 * Awam on anexomail.com / ai.anexomail.com: original locale files (not Argos widget).
 * Founder host + family testers stay English. Missing string = English.
 *
 * Runtime:
 *   1. Choice `localStorage["ax.locale"]` mein, `<html lang/dir>` fauran set.
 *   2. Bundle dynamic import se aata hai (code-split) aur localStorage mein
 *      cache hota hai — doosri dafa switch instant, network ka intezar nahi.
 *   3. Jis string ka tarjuma maujood nahi, wahan asli English dikhti hai —
 *      kabhi khali ya dummy text nahi.
 */

import { useCallback, useEffect, useState } from "react";

import { useAuth } from "./auth";
import { CRM_I18N } from "./crm-i18n";
import { hydrateLocalePref, loadSqlBundle, persistLocalePref } from "./locale-sync";
import { DEFAULT_LOCALE, type Locale, type LocaleKey, STORAGE_KEY, findLocale } from "./locales";
import { publicLocaleAllowed } from "./public-locale";
import { SITE_I18N_REST } from "./site-i18n-rest";
import { WORKSPACE_I18N } from "./workspace-i18n";

const EVENT = "ax:locale";
const CACHE_PREFIX = "ax.i18n.v4.";

/**
 * Landing display typography is locked English in EVERY locale.
 * The hero is built from English word-order fragments ("The Workspace" /
 * "Built Around" / "Email."); translating the fragments one by one breaks
 * RTL languages into fake-looking half-sentences ("کے گرد بنایا" akela).
 * Landing layout is no-touch, so these keys are pinned here — full sentences,
 * buttons, nav and workspace chrome still translate normally.
 */
const DISPLAY_ENGLISH = new Set([
  "The Workspace",
  "Built Around",
  "Email.",
  "Private Email.",
  "Intelligent Workspace.",
  "One Platform.",
]);

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
  void persistLocalePref(locale.tag);
  window.dispatchEvent(new CustomEvent<string>(EVENT, { detail: locale.tag }));
}

function readStored(): Locale {
  if (typeof window === "undefined") return DEFAULT_LOCALE;
  try {
    return findLocale(window.localStorage.getItem(STORAGE_KEY)) ?? DEFAULT_LOCALE;
  } catch {
    return DEFAULT_LOCALE;
  }
}

function pinEnglish() {
  if (typeof document === "undefined") return;
  document.documentElement.lang = DEFAULT_LOCALE.tag;
  document.documentElement.dir = "ltr";
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
  const { session } = useAuth();
  const allowed = publicLocaleAllowed(session);
  const [locale, setLocaleState] = useState<Locale>(DEFAULT_LOCALE);
  const [bundle, setBundle] = useState<Bundle>({});
  const [overlay, setOverlay] = useState<Bundle>({});
  const [ready, setReady] = useState(false);

  useEffect(() => {
    if (!allowed) {
      setLocaleState(DEFAULT_LOCALE);
      setBundle({});
      setOverlay({});
      setReady(true);
      pinEnglish();
      return;
    }

    let live = true;

    const apply = (next: Locale) => {
      setLocaleState(next);
      document.documentElement.lang = next.tag;
      document.documentElement.dir = next.dir;
      const instant = memory.get(next.tag) ?? readCache(next.tag);
      if (instant) {
        setBundle(instant);
        setReady(true);
      } else {
        setReady(next.tag === DEFAULT_LOCALE.tag);
      }
      void Promise.all([loadBundle(next.tag), loadSqlBundle(next.tag)]).then(([b, sql]) => {
        if (!live) return;
        setBundle(b);
        setOverlay(sql);
        setReady(true);
      });
    };

    apply(readStored());
    void hydrateLocalePref().then((tag) => {
      if (!live || !tag) return;
      let hasLocal = false;
      try {
        hasLocal = Boolean(window.localStorage.getItem(STORAGE_KEY));
      } catch {
        hasLocal = false;
      }
      if (!hasLocal) apply(findLocale(tag) ?? DEFAULT_LOCALE);
    });
    const onChange = (e: Event) => {
      const tag = (e as CustomEvent<string>).detail;
      apply(findLocale(tag) ?? DEFAULT_LOCALE);
    };
    window.addEventListener(EVENT, onChange);
    return () => {
      live = false;
      window.removeEventListener(EVENT, onChange);
    };
  }, [allowed]);

  const t = useCallback(
    (key: string) => {
      if (DISPLAY_ENGLISH.has(key)) return key;
      if (!allowed || locale.tag === DEFAULT_LOCALE.tag) {
        return locale.t[key as LocaleKey] ?? key;
      }
      const chrome =
        overlay[key] ??
        bundle[key] ??
        WORKSPACE_I18N[locale.tag]?.[key] ??
        CRM_I18N[locale.tag]?.[key] ??
        SITE_I18N_REST[locale.tag]?.[key];
      return chrome ?? locale.t[key as LocaleKey] ?? DEFAULT_LOCALE.t[key as LocaleKey] ?? key;
    },
    [allowed, bundle, locale, overlay],
  );

  return { locale: allowed ? locale : DEFAULT_LOCALE, t, ready };
}
