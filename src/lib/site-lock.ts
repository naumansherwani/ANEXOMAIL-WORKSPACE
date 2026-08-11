/**
 * PRE-LAUNCH LOCK (locked rule) — poori website awam ke liye band hai.
 *
 * Lock IP se nahi, KEY se khulta hai — founder duniya ke kisi bhi corner se,
 * kisi bhi device/network se site khol sakta hai. Awam ko sirf "Not open yet"
 * screen milti hai, koi route nahi. founderworkspace.anexomail.com bhi isi gate
 * ke peeche hai, so awam ko founder surface bhi nazar nahi aata.
 *
 * Frontend .env (server par):
 *   VITE_SITE_LOCK=true            # on | true | 1 = lock active
 *   VITE_UNLOCK_KEY=<lamba secret> # key kabhi hardcode nahi
 *
 * Kholna:  https://anexomail.com/?unlock=<VITE_UNLOCK_KEY>   -> localStorage set -> /
 * Band:    https://anexomail.com/?unlock=off                 -> localStorage clear
 */

const STORE_KEY = "site_unlocked";

function unlockKey(): string {
  const env = import.meta.env as Record<string, string | undefined>;
  return String(env["VITE_UNLOCK_KEY"] ?? env["VITE_FOUNDER_KEY"] ?? "").trim();
}

/** Lock sirf tab active hai jab VITE_SITE_LOCK on/true/1 ho aur key mojood ho. */
export function siteLockEnabled(): boolean {
  const env = import.meta.env as Record<string, string | undefined>;
  const flag = String(env["VITE_SITE_LOCK"] ?? "").trim().toLowerCase();
  return (flag === "on" || flag === "true" || flag === "1") && unlockKey().length > 0;
}

function isUnlocked(): boolean {
  try {
    return window.localStorage.getItem(STORE_KEY) === "true";
  } catch {
    return false;
  }
}

/**
 * Client-side check. `?unlock=<key>` device ko unlock karta hai aur phir `/` par
 * bhej deta hai (key URL mein nahi rehti, share hone par leak na ho).
 * `?unlock=off` lock wapas laga deta hai.
 */
export function resolveSiteAccess(): boolean {
  if (typeof window === "undefined") return false;
  if (!siteLockEnabled()) return true;

  let param: string | null = null;
  try {
    param = new URL(window.location.href).searchParams.get("unlock");
  } catch {
    param = null;
  }

  if (param !== null) {
    try {
      if (param === unlockKey()) {
        window.localStorage.setItem(STORE_KEY, "true");
        window.location.replace("/");
        return true;
      }
      if (param === "off" || param === "0") {
        window.localStorage.removeItem(STORE_KEY);
        window.location.replace("/");
        return false;
      }
    } catch {
      /* storage blocked — locked rehta hai */
    }
  }

  return isUnlocked();
}
