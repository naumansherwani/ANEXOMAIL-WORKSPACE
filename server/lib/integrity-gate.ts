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
 *
 * E70/E71: ek HOLD (sign-up review ka intezar) ya rejected account ke liye sirf /health, /auth/logout, /public/* khula hai — uska token
 * kuch padh nahi sakta (profile bhi nahi). E71: probation wale naye account ki had (mail send / bulk import) yahin lagti hai, lekin SIRF
 * jab token asli saabit ho (GoTrue getUser): jhoota sub kisi aur ki daily had kha nahi sakta.
 */
import type { NextFunction, Request, Response } from "express";
import { probationMessage, probationRule, probationTake } from "./probation";

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

/** Pure: HOLD / rejected account ke liye kya khula hai (path `/api` ke baad wala hissa) — logout aur health, bas. */
export function allowedWhenHeld(path: string): boolean {
  const p = String(path || "").split("?")[0];
  return p === "/health" || p === "/auth/logout" || p === "/public" || p.startsWith("/public/");
}

const cache = new Map<string, { blocked: boolean; held: boolean; at: number }>();
const TTL_MS = 30_000;

async function stateOf(sub: string, now = Date.now()): Promise<{ blocked: boolean; held: boolean }> {
  const hit = cache.get(sub);
  if (hit && now - hit.at < TTL_MS) return hit;
  let blocked = false;
  let held = false;
  try {
    const { admin: supa } = await import("./supa"); // lazy: pure helpers testable bina supabase package ke
    const { data, error } = await supa.from("account_integrity").select("state").eq("user_id", sub).maybeSingle();
    if (!error) blocked = data?.state === "blocked" || data?.state === "purged";
    // E70: a sign-up held for review (or rejected) is locked at GoTrue too; this closes the last window — a token issued just before the hold.
    if (!blocked) {
      const hs = await supa.from("identity_account_state").select("state").eq("account_id", sub).maybeSingle();
      if (!hs.error) held = hs.data?.state === "pending" || hs.data?.state === "rejected";
    }
  } catch {
    blocked = false;
    held = false;
  }
  if (cache.size > 5000) cache.clear();
  const v = { blocked, held, at: now };
  cache.set(sub, v);
  return v;
}

export async function isBlocked(sub: string, now = Date.now()): Promise<boolean> {
  const v = await stateOf(sub, now);
  return v.blocked || v.held;
}

// ---- E71: token asli hai? (sirf probation wali kam-yaab calls ke liye; 60s cache) ----
const verified = new Map<string, { sub: string | null; at: number }>();
async function verifiedSub(authorization: string | undefined, claimed: string, now = Date.now()): Promise<string | null> {
  const token = String(authorization || "").replace(/^Bearer\s+/i, "").trim();
  if (!token) return null;
  const hit = verified.get(token);
  if (hit && now - hit.at < 60_000) return hit.sub;
  let sub: string | null = null;
  try {
    const { admin: supa } = await import("./supa");
    const { data, error } = await supa.auth.getUser(token);
    sub = !error && data?.user?.id ? String(data.user.id).toLowerCase() : null;
  } catch {
    sub = null;
  }
  if (verified.size > 2000) verified.clear();
  verified.set(token, { sub, at: now });
  return sub === claimed ? sub : null;
}

export async function integrityGate(req: Request, res: Response, next: NextFunction) {
  try {
    const sub = jwtSub(req.headers.authorization);
    if (!sub) return next();
    const st = await stateOf(sub);
    if (st.held && !allowedWhenHeld(req.path)) {
      // E70: a sign-up waiting for review (or rejected). Neutral wording — never says why.
      return res.status(403).json({
        error: "account_pending",
        code: "account_pending",
        message: "This account can't be used right now. If you recently signed up, it may be waiting for review.",
      });
    }
    if (st.blocked && !allowedWhenBlocked(req.path)) {
      return res.status(403).json({
        error: "account_blocked",
        message: "This account is blocked. You can still download your data until the export window ends.",
      });
    }
    if (st.blocked || st.held) return next();
    // E71: probation (new, unpaid accounts): mail send / bulk import have hard limits, counted in SQL.
    const rule = probationRule(req.method, req.path, req.body);
    if (rule && (await verifiedSub(req.headers.authorization, sub)) === sub) {
      const v = await probationTake(sub, rule);
      if (!v.ok) {
        return res.status(403).json({ error: "probation_limit", code: v.reason || "probation", message: probationMessage(v) });
      }
    }
  } catch {
    /* fail-open */
  }
  return next();
}

/** test ke liye */
export function _clearCache() {
  cache.clear();
  verified.clear();
}
