/**
 * Two-step sign-in (TOTP) ka pending challenge store — password sahi hone ke BAAD, code se pehle.
 * Session (AAL1) server ke andar rehti hai, browser ko sirf ek anjaan `challenge_id` milta hai: 5 minute, 5 koshishein, ek dafa.
 * (Bun ek process hai — memory kaafi; restart par user dobara password dalta hai, koi nuqsan nahi.)
 */
import { randomBytes } from "node:crypto";

export type Pending = { userId: string; factorId: string; accessToken: string; refreshToken: string };
type Entry = Pending & { exp: number; tries: number };

const TTL_MS = 5 * 60_000;
const MAX_TRIES = 5;
const MAX_ENTRIES = 5000;
const store = new Map<string, Entry>();

export function createChallenge(p: Pending, now = Date.now()): string {
  if (store.size >= MAX_ENTRIES) for (const [k, v] of store) if (v.exp <= now) store.delete(k);
  if (store.size >= MAX_ENTRIES) store.delete(store.keys().next().value as string);
  const id = randomBytes(24).toString("base64url");
  store.set(id, { ...p, exp: now + TTL_MS, tries: 0 });
  return id;
}

export type Peek = { ok: true; pending: Pending } | { ok: false; reason: "expired" | "locked" };

/** Code check se PEHLE: har call ek koshish ginti hai; 5 ke baad challenge jal jata hai. */
export function peekChallenge(id: string, now = Date.now()): Peek {
  const e = store.get(id);
  if (!e || e.exp <= now) {
    store.delete(id);
    return { ok: false, reason: "expired" };
  }
  e.tries += 1;
  if (e.tries > MAX_TRIES) {
    store.delete(id);
    return { ok: false, reason: "locked" };
  }
  return { ok: true, pending: e };
}

/** Code sahi nikla — challenge dobara kabhi nahi chalega. */
export const consumeChallenge = (id: string) => void store.delete(id);

/** 6 ankon ka code (spaces ke saath bhi). */
export const cleanCode = (c: unknown): string | null => {
  const x = String(c ?? "").replace(/\s+/g, "");
  return /^\d{6}$/.test(x) ? x : null;
};
