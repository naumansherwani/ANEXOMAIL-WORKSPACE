// ADMIN DESK deskCall() (R3d stage B, 22 Nov 2026): the ONLY way a Desk page talks to the Desk server (Rule 52).
// Every answer must pass the Desk's OWN Rust WASM kernel (admin-desk/kernel, built into ./kernel): Ed25519 signature by the pinned Desk key,
// bound to this call's method + path + nonce, fresh clock. After sign-in every request carries the HKDF/HMAC request MAC made in the kernel.
// An answer that fails is THROWN (DeskRefused), never shown. Transport = the shared pre-session helper realDeps().fetch (no new raw fetch);
// the browser rides HTTP/3 to the Desk when Alt-Svc is taken. Nothing from the founder kernel or founder keys is used here.
import init, { request_headers, verify_answer } from "./kernel/anexomail_desk_kernel.js";
import { realDeps } from "../signin_passkey";
import { DESK_SESSION_KEY } from "./desk_pure";

export const DESK_PIN_KEY = "anexo.desk.kernelpin";
export class DeskRefused extends Error {}
export type DeskAnswer = { status: number; json: unknown };

let ready: Promise<unknown> | null = null;
let pinned: string | null = null;
const hex = (b: Uint8Array) => Array.from(b, (x) => x.toString(16).padStart(2, "0")).join("");
const nowS = () => Math.floor(Date.now() / 1000);
const read = (k: string) => { try { return window.localStorage.getItem(k); } catch { return null; } };

/** The Desk public key: pinned on first sight; a different key later is REFUSED (a swapped server cannot pass). */
async function pin(): Promise<string> {
  if (pinned) return pinned;
  const r = await realDeps().fetch("/desk/v1/key", { method: "GET", cache: "no-store", credentials: "same-origin" });
  if (r.status !== 200) throw new DeskRefused("desk_key_unavailable");
  const k = (await r.json()) as { pub?: string; alg?: string; aud?: string };
  if (k.alg !== "ed25519" || k.aud !== "desk" || typeof k.pub !== "string" || !/^[0-9a-f]{64}$/.test(k.pub)) throw new DeskRefused("desk_key_bad");
  const old = read(DESK_PIN_KEY);
  if (old && old !== k.pub) throw new DeskRefused("desk_key_changed");
  if (!old) { try { window.localStorage.setItem(DESK_PIN_KEY, k.pub); } catch { /* storage blocked: pinned for this tab only */ } }
  pinned = k.pub; return pinned;
}

export async function deskCall(method: "GET" | "POST", path: string, body?: unknown): Promise<DeskAnswer> {
  await (ready ??= init());
  const pub = await pin();
  const nonce = hex(crypto.getRandomValues(new Uint8Array(16))), ts = nowS();
  const b = body === undefined ? "" : JSON.stringify(body);
  const headers: Record<string, string> = { "x-desk-nonce": nonce };
  const token = read(DESK_SESSION_KEY);
  if (token) {
    const h = JSON.parse(request_headers(token, method, path, nonce, ts, b)) as { ts: number; mac: string };
    headers["x-desk-ts"] = String(h.ts); headers["x-desk-mac"] = h.mac; headers.authorization = `Bearer ${token}`;
  }
  if (b) headers["content-type"] = "application/json";
  const r = await realDeps().fetch(path, { method, headers, body: b || undefined, cache: "no-store", credentials: "same-origin" });
  const text = await r.text();
  let verified: string;
  try { verified = verify_answer(pub, method, path, nonce, nowS(), text); }
  catch (e) { throw new DeskRefused(e instanceof Error ? e.message : String(e)); }
  return { status: r.status, json: JSON.parse(verified) as unknown };
}

/** Plain words for a refused answer (no technology words on screen). */
export function refusedMessage(code: string): string {
  if (code === "stale_answer") return "Your device clock looks wrong. Set the time automatically and try again.";
  if (code === "desk_key_changed") return "The Desk's identity changed. Stop and tell the owner before signing in.";
  if (code === "desk_key_unavailable") return "The Desk is not ready on the server yet.";
  return "The answer from the server could not be trusted, so it was not shown.";
}
