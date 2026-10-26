/**
 * ANEXOMAIL API client — Phase 5A.
 *
 * NO DUPLICATE rule: the frontend owns zero auth logic. Every credential,
 * token, passkey challenge and session lives in the backend (Rust/Bun on
 * Hetzner, which talks to Supabase). This file only speaks HTTP.
 *
 * The only config the frontend is allowed to know is VITE_API_URL.
 */

/**
 * SAME-ORIGIN DEFAULT: VITE_API_URL na ho to browser apne hi host par
 * `/api/*` maangta hai (Caddy us host par 127.0.0.1:3100 ko proxy karta hai).
 * Cross-origin base (anexomail.com) founderworkspace se CORS/preflight ki
 * wajah se fail hota tha — "Could not reach the workspace server".
 */
const BASE = (import.meta.env["VITE_API_URL"] as string | undefined)?.replace(/\/$/, "") ?? "";

const TOKEN_KEY = "anexo.session.token";
// Session refresh (21 Oct 2026): access token 1 ghanta chalta hai (Supabase JWT). Server login par refresh_token + expires_at deta hai;
// client expiry se pehle chupke se naya leta hai (`ensureFreshToken` + 401 par ek dafa retry) — user har ghante logout nahi hota.
const REFRESH_KEY = "anexo.session.refresh";
const EXPIRES_KEY = "anexo.session.expires";

export class ApiError extends Error {
  constructor(
    message: string,
    readonly status: number,
    readonly code?: string,
  ) {
    super(message);
    this.name = "ApiError";
  }

  /** Backend not wired yet for this endpoint — surfaced as an honest TODO state. */
  get isNotImplemented() {
    return this.status === 404 || this.status === 501;
  }
}

export const sessionToken = {
  get(): string | null {
    if (typeof window === "undefined") return null;
    return window.localStorage.getItem(TOKEN_KEY);
  },
  set(token: string) {
    if (typeof window === "undefined") return;
    window.localStorage.setItem(TOKEN_KEY, token);
  },
  clear() {
    if (typeof window === "undefined") return;
    window.localStorage.removeItem(TOKEN_KEY);
    window.localStorage.removeItem(REFRESH_KEY);
    window.localStorage.removeItem(EXPIRES_KEY);
  },
};

/** rpc() (Rust) jawabon se bhi refresh credentials rakhne ke liye (api() payload se khud rakhta hai). */
export function storeRefresh(refresh: unknown, expiresAt: unknown) {
  if (typeof window === "undefined" || typeof refresh !== "string" || !refresh) return;
  try {
    window.localStorage.setItem(REFRESH_KEY, refresh);
    if (typeof expiresAt === "number") window.localStorage.setItem(EXPIRES_KEY, String(expiresAt));
  } catch {
    /* private window: refresh nahi, purana 1-ghanta wala behavior */
  }
}
function readRefresh(): string | null {
  if (typeof window === "undefined") return null;
  try {
    return window.localStorage.getItem(REFRESH_KEY);
  } catch {
    return null;
  }
}
/** Access token ki expiry (unix seconds) — server ne di ho to, warna null. */
export function sessionExpiresAt(): number | null {
  if (typeof window === "undefined") return null;
  try {
    const v = Number(window.localStorage.getItem(EXPIRES_KEY));
    return Number.isFinite(v) && v > 0 ? v : null;
  } catch {
    return null;
  }
}

let refreshing: Promise<boolean> | null = null;
/** Ek hi refresh ek waqt (15 parallel 401 = ek call). true = naya token lag gaya. 401 par refresh token bhi saaf (asli logout). */
export function refreshSessionOnce(): Promise<boolean> {
  if (refreshing) return refreshing;
  const rt = readRefresh();
  if (!rt) return Promise.resolve(false);
  refreshing = (async () => {
    try {
      const res = await fetch(`${BASE}/api/auth/refresh`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ refresh_token: rt }),
        credentials: "omit",
      });
      if (res.ok) {
        const p = (await res.json()) as { token?: string; refresh_token?: string; expires_at?: number };
        if (p.token) {
          sessionToken.set(p.token);
          storeRefresh(p.refresh_token, p.expires_at);
          return true;
        }
        return false;
      }
      if (res.status === 401 || res.status === 400) {
        // refresh token asli taur par invalid/revoked — ab sign-out jaiz hai (access token ka normal 401 isay pakdega).
        try {
          window.localStorage.removeItem(REFRESH_KEY);
          window.localStorage.removeItem(EXPIRES_KEY);
        } catch {
          /* ignore */
        }
      }
      return false; // 429/5xx/network: temporary — kuch saaf nahi, agli koshish par dobara
    } catch {
      return false;
    } finally {
      refreshing = null;
    }
  })();
  return refreshing;
}

/** Expiry se 5 minute pehle (ya guzar chuki) ho to refresh. Timer / tab-wapsi / online par chalta hai. */
export async function ensureFreshToken(): Promise<void> {
  const exp = sessionExpiresAt();
  if (!sessionToken.get() || !readRefresh() || exp == null) return;
  if (exp - Math.floor(Date.now() / 1000) < 300) await refreshSessionOnce();
}

export async function api<T>(path: string, init?: RequestInit & { auth?: boolean }): Promise<T> {
  return send<T>(path, init, true);
}

async function send<T>(path: string, init: (RequestInit & { auth?: boolean }) | undefined, allowRefresh: boolean): Promise<T> {
  if (!BASE && typeof window === "undefined") {
    throw new ApiError("API base URL is not configured (VITE_API_URL).", 0, "no_api_url");
  }

  const headers = new Headers(init?.headers);
  if (init?.body && !headers.has("content-type")) {
    headers.set("content-type", "application/json");
  }
  const token = sessionToken.get();
  if (init?.auth !== false && token) {
    headers.set("authorization", `Bearer ${token}`);
  }

  // Rule 52 audit: har seedha REST call gina jata hai (anexoKernel.stats.fetch + fallbackProcs["METHOD /api/.."]="rest") — maqsad 0.
  try {
    (globalThis as { __anexoRest?: (p: string, m: string) => void }).__anexoRest?.(path, init?.method ?? "GET");
  } catch {
    /* diagnostics kabhi call nahi rokti */
  }
  let response: Response;
  try {
    response = await fetch(`${BASE}${path}`, { ...init, headers, credentials: "omit" });
  } catch {
    throw new ApiError("Could not reach the workspace server.", 0, "network");
  }

  const text = await response.text();
  const payload = text ? safeJson(text) : null;

  if (
    response.status === 401 &&
    allowRefresh &&
    init?.auth !== false &&
    token &&
    path !== "/api/auth/refresh" &&
    readRefresh() &&
    (await refreshSessionOnce())
  ) {
    return send<T>(path, init, false); // naya token ke saath ek dafa dobara
  }

  if (!response.ok) {
    const extracted = apiErrorFromPayload(payload, response.status);
    throw new ApiError(extracted.message, response.status, extracted.code);
  }

  if (payload && typeof payload === "object" && "refresh_token" in payload) {
    const p = payload as { refresh_token?: unknown; expires_at?: unknown };
    storeRefresh(p.refresh_token, p.expires_at);
  }
  return payload as T;
}

function apiErrorFromPayload(payload: unknown, status: number): { message: string; code?: string | undefined } {
  const fallback = `Request failed (${status}).`;
  if (!payload || typeof payload !== "object") return { message: fallback };
  const err = "error" in payload ? (payload as { error: unknown }).error : undefined;
  if (typeof err === "string" && err && err !== "[object Object]") {
    return {
      message: err,
      code:
        "code" in payload && (payload as { code: unknown }).code != null
          ? String((payload as { code: unknown }).code)
          : undefined,
    };
  }
  if (err && typeof err === "object") {
    const rec = err as { message?: unknown; code?: unknown };
    const message =
      typeof rec.message === "string" && rec.message
        ? rec.message
        : typeof rec.code === "string"
          ? rec.code
          : fallback;
    const code = typeof rec.code === "string" ? rec.code : undefined;
    return { message, code };
  }
  return { message: fallback };
}

function safeJson(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch {
    return { raw: text };
  }
}
