/**
 * ANEXOMAIL — Coexistence RPC client (Phase 11+).
 *
 * Phase 1–10 ka Express/Bun API (REST, /api/*) zinda rehta hai — kuch rewrite nahi.
 * Phase 11+ ka Rust service tRPC-style JSON pe baat karta hai (/rpc/*).
 *
 * Rule: pehle Rust try karo, agar woh route abhi Rust mein nahi hai (404/501/502/503)
 * to wahi kaam legacy REST endpoint se ho jaye. Isse dono side-by-side chalte hain
 * aur migration bina downtime hoti hai.
 *
 * Config: sirf VITE_API_URL (same Caddy gateway origin). Koi secret frontend mein nahi.
 */

import { ApiError, api, sessionToken } from "./api";

const BASE = (import.meta.env['VITE_API_URL'] as string | undefined)?.replace(/\/$/, "") ?? "";

/** Rust service ka tRPC-compatible endpoint: POST {BASE}/rpc/{procedure} */
export async function rpc<T>(procedure: string, input?: unknown): Promise<T> {
  if (!BASE) throw new ApiError("API base URL is not configured (VITE_API_URL).", 0, "no_api_url");

  const headers = new Headers({ "content-type": "application/json" });
  const token = sessionToken.get();
  if (token) headers.set("authorization", `Bearer ${token}`);

  let res: Response;
  try {
    res = await fetch(`${BASE}/rpc/${procedure.replace(/^\//, "")}`, {
      method: "POST",
      headers,
      body: JSON.stringify({ input: input ?? null }),
    });
  } catch {
    throw new ApiError("Rust service reachable nahi hai.", 503, "rust_unreachable");
  }

  const text = await res.text();
  const json = text ? safeParse(text) : null;

  if (!res.ok) {
    const code = (json as { error?: { code?: string } } | null)?.error?.code;
    const message =
      (json as { error?: { message?: string } } | null)?.error?.message ?? `RPC ${procedure} failed`;
    throw new ApiError(message, res.status, code);
  }

  // tRPC shape { result: { data } } aur plain shape dono support.
  const shaped = json as { result?: { data?: T } } | null;
  return (shaped?.result?.data ?? (json as T)) as T;
}

/** Rust pe route na ho to legacy Express REST se same kaam. */
export async function rpcOrRest<T>(
  procedure: string,
  rest: { path: string; method?: string; body?: unknown },
  input?: unknown,
): Promise<T> {
  try {
    return await rpc<T>(procedure, input);
  } catch (e) {
    const err = e as ApiError;
    const fallbackable = [404, 501, 502, 503, 0].includes(err.status);
    if (!fallbackable) throw err;
    return api<T>(rest.path, {
      method: rest.method ?? (rest.body ? "POST" : "GET"),
      ...(rest.body ? { body: JSON.stringify(rest.body) } : {}),
    });
  }
}

/** Kaunsi side live hai — founder diagnostics ke liye (/pages). */
export async function stackHealth(): Promise<{
  legacy: "up" | "down";
  rust: "up" | "down";
}> {
  const ping = async (path: string) => {
    try {
      const r = await fetch(`${BASE}${path}`, { method: "GET" });
      return r.status > 0 ? ("up" as const) : ("down" as const);
    } catch {
      return "down" as const;
    }
  };
  const [legacy, rust] = await Promise.all([ping("/api/health"), ping("/rpc/health")]);
  return { legacy, rust };
}

function safeParse(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}
