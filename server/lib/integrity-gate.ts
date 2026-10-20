/**
 * ANEXOMAIL — blocked account guard (Blueprint G37), Brain side.
 *
 * Rust (/rpc/*) ka guard `export_glue::blocked` hai; yeh Brain ke /api/* ke liye wohi usool:
 * jis account ki halat `blocked` ya `purged` hai (insaan ne block kiya, warning ke baad — engine kabhi khud block nahi karta, E18)
 * uski har /api call 403 `account_blocked`, siwaye export / apna delete / login-logout. Export Rust mein hai (/rpc + /file).
 *
 * Token ka `sub` bina signature verify padha jata hai: jhoota sub sirf "us user ki halat" dikhata hai, access nahi deta
 * (asli verify har router apna karta hai). Token na ho => guzar jao (public routes, webhooks). DB/cache mein masla => guzar jao
 * (fail-open): outage mein sab ko lock nahi karte.
 */
import type { NextFunction, Request, Response } from "express";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Pure: "Bearer <jwt>" ya jwt -> uuid sub, warna null. */
export function jwtSub(authorization: string | undefined | null): string | null {
  const raw = String(authorization || "").replace(/^Bearer\s+/i, "").trim();
  const part = raw.split(".")[1];
  if (!part) return null;
  try {
    const sub = JSON.parse(Buffer.from(part, "base64url").toString("utf8"))?.sub;
    return typeof sub === "string" && UUID.test(sub) ? sub.toLowerCase() : null;
  } catch {
    return null;
  }
}

/** Pure: blocked account ke liye kya khula hai (path `/api` ke baad wala hissa). */
export function allowedWhenBlocked(path: string): boolean {
  const p = String(path || "").split("?")[0];
  return (
    p === "/health" ||
    p === "/auth" || p.startsWith("/auth/") ||
    p === "/account-deletion" || p.startsWith("/account-deletion/") ||
    p === "/public" || p.startsWith("/public/")
  );
}

const cache = new Map<string, { blocked: boolean; at: number }>();
const TTL_MS = 30_000;

export async function isBlocked(sub: string, now = Date.now()): Promise<boolean> {
  const hit = cache.get(sub);
  if (hit && now - hit.at < TTL_MS) return hit.blocked;
  let blocked = false;
  try {
    const { admin: supa } = await import("./supa"); // lazy: pure helpers testable bina supabase package ke
    const { data, error } = await supa.from("account_integrity").select("state").eq("user_id", sub).maybeSingle();
    if (!error) blocked = data?.state === "blocked" || data?.state === "purged";
  } catch {
    blocked = false;
  }
  if (cache.size > 5000) cache.clear();
  cache.set(sub, { blocked, at: now });
  return blocked;
}

export async function integrityGate(req: Request, res: Response, next: NextFunction) {
  try {
    const sub = jwtSub(req.headers.authorization);
    if (!sub || allowedWhenBlocked(req.path)) return next();
    if (await isBlocked(sub)) {
      return res.status(403).json({
        error: "account_blocked",
        message: "This account is blocked. You can still download your data until the export window ends.",
      });
    }
  } catch {
    /* fail-open */
  }
  return next();
}

/** test ke liye */
export function _clearCache() {
  cache.clear();
}
