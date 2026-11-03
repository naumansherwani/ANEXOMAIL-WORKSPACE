/**
 * ANEXOMAIL — login-loop fix (founder 21 Oct 2026): Supabase auth.getUser(token) har request par network call hai.
 * Login ke foran baad dashboard 15 parallel calls karta hai; Supabase ka koi bhi temporary error / 429 / timeout
 * "401 unauthorized" ban kar client ko sign-out kar deta tha (dashboard -> login -> loading loop).
 *
 * Yeh module GoTrueClient.getUser ko ek jagah (poore process mein, har client par) mazboot karta hai:
 *   1) kamyab verify 20 s cache (token -> user): 15 calls = 1 Supabase call,
 *   2) ek hi token ki parallel calls ek hi in-flight request share karti hain,
 *   3) SIRF temporary error (network / 429 / 5xx) par 2 baar retry; asli "invalid token" (401/403) foran wapas.
 * Logout par forgetAuthToken(token) cache saaf karta hai. Koi secret/token log nahi hota.
 */
import { createClient } from "@supabase/supabase-js";

const TTL_MS = 20_000;
const MAX_CACHE = 4000;
let installed = false;
const cache = new Map<string, { exp: number; value: any }>();
const inflight = new Map<string, Promise<any>>();

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

/** true = Supabase ka temporary masla (token ghalat NAHI). */
export function isTransientAuthError(err: any): boolean {
  if (!err) return false;
  const st = Number(err.status ?? err.code);
  if (st === 401 || st === 403 || st === 400 || st === 422) return false;
  if (!st || st === 429 || st >= 500) return true;
  return /fetch|network|timeout|ECONN|socket/i.test(String(err.message || ""));
}

export function forgetAuthToken(token: string) {
  cache.delete(token);
}

export function hardenSupabaseAuth() {
  if (installed) return;
  installed = true;
  const probe = createClient("https://placeholder.supabase.co", "placeholder", {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const proto: any = Object.getPrototypeOf(probe.auth);
  const orig = proto?.getUser;
  if (typeof orig !== "function") {
    console.warn("[auth-harden] getUser not found — skipped");
    return;
  }
  proto.getUser = function (this: any, jwt?: string) {
    if (!jwt) return orig.call(this, jwt);
    const now = Date.now();
    const hit = cache.get(jwt);
    if (hit && hit.exp > now) return Promise.resolve(hit.value);
    const running = inflight.get(jwt);
    if (running) return running;
    const p = (async () => {
      let last: any = null;
      for (let i = 0; i < 3; i++) {
        const r: any = await orig.call(this, jwt).catch((e: any) => ({ data: { user: null }, error: e }));
        if (!r?.error && r?.data?.user) {
          if (cache.size >= MAX_CACHE) {
            for (const [k, v] of cache) if (v.exp < Date.now()) cache.delete(k);
            if (cache.size >= MAX_CACHE) cache.clear();
          }
          cache.set(jwt, { exp: Date.now() + TTL_MS, value: r });
          return r;
        }
        last = r;
        if (!isTransientAuthError(r?.error)) return r; // asli invalid token
        await sleep(150 * (i + 1));
      }
      return last;
    })().finally(() => inflight.delete(jwt));
    inflight.set(jwt, p);
    return p;
  };
}
