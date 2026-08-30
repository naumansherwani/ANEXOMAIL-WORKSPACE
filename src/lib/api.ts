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
const BASE = (import.meta.env['VITE_API_URL'] as string | undefined)?.replace(/\/$/, "") ?? "";

const TOKEN_KEY = "anexo.session.token";

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
  },
};

export async function api<T>(
  path: string,
  init?: RequestInit & { auth?: boolean },
): Promise<T> {
  if (!BASE) {
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

  let response: Response;
  try {
    response = await fetch(`${BASE}${path}`, { ...init, headers, credentials: "omit" });
  } catch {
    throw new ApiError("Could not reach the workspace server.", 0, "network");
  }

  const text = await response.text();
  const payload = text ? safeJson(text) : null;

  if (!response.ok) {
    const message =
      (payload && typeof payload === "object" && "error" in payload
        ? String((payload as { error: unknown }).error)
        : null) ?? `Request failed (${response.status}).`;
    const code =
      payload && typeof payload === "object" && "code" in payload
        ? String((payload as { code: unknown }).code)
        : undefined;
    throw new ApiError(message, response.status, code);
  }

  return payload as T;
}

function safeJson(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch {
    return { raw: text };
  }
}