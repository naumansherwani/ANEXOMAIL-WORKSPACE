/**
 * SQL overlay + preference for the 28 awam locales.
 * Missing row stays English. Never invents a string.
 * Path: Claude stack — Rust /rpc/locale.* PRIMARY, Bun /api/locale/* fallback.
 */
import { rpcOrRest } from "./rpc";
import { findLocale, STORAGE_KEY } from "./locales";

type Bundle = Record<string, string>;

const sqlMemory = new Map<string, Bundle>();
/* single-flight: concurrent callers share ONE request (LCP: page load fired locale.bundle x3, locale.pref x3) */
const bundleInflight = new Map<string, Promise<Bundle>>();
let prefInflight: Promise<string | null> | null = null;

export function loadSqlBundle(tag: string): Promise<Bundle> {
  const hit = sqlMemory.get(tag);
  if (hit) return Promise.resolve(hit);
  const live = bundleInflight.get(tag);
  if (live) return live;
  const p = fetchSqlBundle(tag).finally(() => bundleInflight.delete(tag));
  bundleInflight.set(tag, p);
  return p;
}

async function fetchSqlBundle(tag: string): Promise<Bundle> {
  try {
    const res = await rpcOrRest<{ tag: string; bundle: Bundle }>(
      "locale.bundle",
      { path: `/api/locale/bundle?tag=${encodeURIComponent(tag)}` },
      { tag },
    );
    const bundle = res.bundle && typeof res.bundle === "object" ? res.bundle : {};
    sqlMemory.set(tag, bundle);
    return bundle;
  } catch {
    sqlMemory.set(tag, {});
    return {};
  }
}

export async function persistLocalePref(tag: string) {
  try {
    await rpcOrRest(
      "locale.pref.set",
      { path: "/api/locale/pref", method: "PUT", body: { tag } },
      { tag },
    );
  } catch {
    /* SQL not run yet, or signed out — localStorage still holds the choice */
  }
}

export function hydrateLocalePref(): Promise<string | null> {
  if (prefInflight) return prefInflight;
  const p = fetchLocalePref().finally(() => {
    prefInflight = null;
  });
  prefInflight = p;
  return p;
}

async function fetchLocalePref(): Promise<string | null> {
  try {
    if (typeof window !== "undefined") {
      const local = window.localStorage.getItem(STORAGE_KEY);
      if (local && findLocale(local)) {
        /* local wins for this device; SQL still updated on next pick */
      }
    }
    const res = await rpcOrRest<{ tag: string | null }>("locale.pref", {
      path: "/api/locale/pref",
    });
    return res.tag && findLocale(res.tag) ? res.tag : null;
  } catch {
    return null;
  }
}
