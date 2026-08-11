/**
 * PRE-LAUNCH LOCK (locked rule) — poori website awam ke liye band hai.
 *
 * Lock ek secret key se khulta hai, IP se nahi — is liye founder duniya ke kisi
 * bhi corner se, kisi bhi device/network se site khol sakta hai, jabke awam ko
 * sirf "not open yet" screen milti hai. founderworkspace.anexomail.com bhi isi
 * gate ke peeche hai, so awam ko founder surface bhi nazar nahi aata.
 *
 * Server par set karo (frontend .env):
 *   VITE_SITE_LOCK=on
 *   VITE_FOUNDER_KEY=<lamba random secret>
 *
 * Kholne ka tareeqa (ek hi baar per device):
 *   https://anexomail.com/?unlock=<VITE_FOUNDER_KEY>
 *   https://founderworkspace.anexomail.com/?unlock=<VITE_FOUNDER_KEY>
 * Band karne ka tareeqa: ?unlock=off
 */

const STORE_KEY = "ax.site.unlock";

function expectedKey(): string {
  return String(import.meta.env["VITE_FOUNDER_KEY"] ?? "").trim();
}

/** Lock sirf tab active hai jab VITE_SITE_LOCK=on aur key mojood ho. */
export function siteLockEnabled(): boolean {
  const on = String(import.meta.env["VITE_SITE_LOCK"] ?? "").trim().toLowerCase();
  return (on === "on" || on === "true" || on === "1") && expectedKey().length > 0;
}

function stored(): string | null {
  try {
    return window.localStorage.getItem(STORE_KEY);
  } catch {
    return null;
  }
}

/**
 * Client-side check. `?unlock=<key>` aaye to key device par yaad rakhi jaati hai
 * aur URL se saaf kar di jaati hai, taake link share hone par bhi na dikhe.
 */
export function resolveSiteAccess(): boolean {
  if (typeof window === "undefined") return false;
  if (!siteLockEnabled()) return true;

  const key = expectedKey();
  let unlocked = stored() === key;

  try {
    const url = new URL(window.location.href);
    const param = url.searchParams.get("unlock");
    if (param !== null) {
      if (param === "off" || param === "0") {
        window.localStorage.removeItem(STORE_KEY);
        unlocked = false;
      } else if (param === key) {
        window.localStorage.setItem(STORE_KEY, key);
        unlocked = true;
      }
      url.searchParams.delete("unlock");
      window.history.replaceState({}, "", url.pathname + url.search + url.hash);
    }
  } catch {
    /* ignore */
  }

  return unlocked;
}
