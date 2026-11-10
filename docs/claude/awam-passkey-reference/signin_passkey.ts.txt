// G-MIX 2b / S6 (founder, 10 Nov 2026): "Continue with a passkey" on the sign-in page. Technology: browser WebAuthn Level 3 (navigator.credentials.get, user verification REQUIRED, discoverable credential:
// the page never names an account) + the Rust doors /founder/v1/auth/passkey/begin|finish (S2). No key, hash or signature is computed here: the browser's authenticator signs, the server verifies.
// Same helpers the Keys card uses (passkey_pure.ts). Pure decisions are tested; the runner takes its browser pieces as arguments so a test can stand in for them.
import { classifyLogin, type LoginOutcome } from "./signin_pure";
import { cleanExt, credToJson, prepareGet, type Json } from "./passkey_pure";

/** One sentence for every refusal of the passkey door (the server gives the same 401 for every cause, so the page must not guess which). */
export function passkeyOutcome(status: number, j: unknown): LoginOutcome {
  const o = classifyLogin(status, j);
  return o.kind === "invalid" ? { kind: "passkey_invalid" } : o;
}

/** What the browser threw while the sheet was open: cancelled / timed out is the common honest case; anything else is "not available" (never a wrong-password message). */
export function browserError(e: unknown): LoginOutcome {
  const n = (e as { name?: string })?.name;
  if (n === "NotAllowedError" || n === "AbortError") return { kind: "cancelled" };
  if (n === "NotSupportedError" || n === "SecurityError") return { kind: "unsupported" };
  return { kind: "busy" };
}

export type Deps = {
  fetch: (url: string, init: RequestInit) => Promise<Response>;
  get: ((o: CredentialRequestOptions) => Promise<Credential | null>) | null;
};
export const realDeps = (): Deps => ({
  fetch: (u, i) => window.fetch(u, i),
  get: typeof window !== "undefined" && window.PublicKeyCredential && navigator.credentials ? (o) => navigator.credentials.get(o) : null,
});

async function postJson(d: Deps, url: string, body: Json): Promise<{ status: number; json: unknown }> {
  const r = await d.fetch(url, { method: "POST", headers: { "content-type": "application/json" }, cache: "no-store", body: JSON.stringify(body) });
  let json: unknown = null; try { json = await r.json(); } catch { /* not json */ }
  return { status: r.status, json };
}

/** begin -> the browser's passkey sheet -> finish. `ticket` is set only when a correct password asked for the passkey as a second step. */
export async function runPasskey(ticket?: string, d: Deps = realDeps()): Promise<LoginOutcome> {
  if (!d.get) return { kind: "unsupported" };
  let b: { status: number; json: unknown };
  try { b = await postJson(d, "/founder/v1/auth/passkey/begin", ticket ? { ticket } : {}); } catch { return { kind: "offline" }; }
  const bj = (b.json && typeof b.json === "object" ? b.json : {}) as { ceremony?: unknown; options?: Json };
  if (b.status !== 200 || typeof bj.ceremony !== "string" || !bj.options || typeof bj.options.challenge !== "string") return passkeyOutcome(b.status === 200 ? 502 : b.status, b.json);
  let cred: PublicKeyCredential | null;
  try { cred = (await d.get({ publicKey: prepareGet(bj.options) })) as PublicKeyCredential | null; } catch (e) { return browserError(e); }
  if (!cred) return { kind: "no_key" };
  const j = credToJson(cred); j.clientExtensionResults = cleanExt(j.clientExtensionResults);
  let f: { status: number; json: unknown };
  try { f = await postJson(d, "/founder/v1/auth/passkey/finish", { ceremony: bj.ceremony, credential: j }); } catch { return { kind: "offline" }; }
  return passkeyOutcome(f.status, f.json);
}
