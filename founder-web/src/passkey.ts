// J3/J4 — founder passkeys in the browser (WebAuthn Level 3). Technology: browser WebAuthn + Signal API; every decision is made by the server (Rust + E139 SQL) and, for a protected action, the digest is re-derived by the WASM kernel (action@1) BEFORE the key is touched.
import { actionCheck, type ActionReport } from "./kernel";
import { get, post } from "./api";
import { cleanExt, credToJson, friendly, prepareCreate, prepareGet, toB64u, type Json } from "./passkey_pure";
export { b64u, cleanExt, credToJson, friendly, prepareCreate, prepareGet, toB64u } from "./passkey_pure";

export const supported = () => typeof window !== "undefined" && !!window.PublicKeyCredential && !!navigator.credentials;

type Opts = { ceremony: string; options: Json; nonce?: string; hash?: string };
async function begin(body: Json): Promise<Opts> {
  const r = await post("/founder/v1/passkey/options", body);
  if (r.status !== 200) throw new Error(r.body?.error || `HTTP ${r.status}`);
  return r.body as Opts;
}

export type ActionSpec = { action: string; target: string; params?: Record<string, string>; purpose?: "action" | "t3_begin" | "t3_approve" | "t3_execute"; request?: string; nonce?: string };
export type Proved = { ok: true; result: any; decision: string; risk: number; nonce: string } | { ok: false; error: string; decision?: string };

/** Sign in or approve ONE named action with a key. For an action the kernel re-derives the digest first: if the server's digest or challenge is not the digest of exactly what was asked, the key is never touched. */
export async function prove(spec?: ActionSpec): Promise<Proved> {
  if (!supported()) return { ok: false, error: "This browser has no passkey support." };
  const o = await begin(spec ? { purpose: spec.purpose ?? "action", action: spec.action, target: spec.target, params: spec.params ?? {}, request: spec.request, nonce: spec.nonce } : { purpose: "signin" });
  if (spec) {
    const chk: ActionReport | undefined = await actionCheck({ action: spec.action, target: spec.target, params: spec.params ?? {}, nonce: o.nonce ?? "", hash: o.hash, challenge: o.options.challenge });
    if (!chk) return { ok: false, error: "The security kernel could not run, so the key was not touched." };
    if (!chk.ok) return { ok: false, error: chk.problem ?? "The server's digest does not match this action." };
  }
  let cred: PublicKeyCredential | null;
  try { cred = (await navigator.credentials.get({ publicKey: prepareGet(o.options) })) as PublicKeyCredential | null; } catch (e) { return { ok: false, error: friendly(e) }; }
  if (!cred) return { ok: false, error: "No key was used." };
  const j = credToJson(cred); j.clientExtensionResults = cleanExt(j.clientExtensionResults);
  const r = await post("/founder/v1/passkey/verify", { ceremony: o.ceremony, credential: j });
  if (r.status !== 200) return { ok: false, error: r.body?.error || `HTTP ${r.status}`, decision: r.body?.decision };
  return { ok: true, result: r.body.result, decision: r.body.decision, risk: r.body.risk, nonce: o.nonce ?? "" };
}

export type Registered = { ok: true; recovery_codes?: string[]; via: string } | { ok: false; error: string };
/** Add a key. The first key needs nothing else; later keys are a protected action ("passkey.add" for the NEW credential id), proved with an existing key. */
export async function register(label: string, kind: "key" | "phone" = "key"): Promise<Registered> {
  if (!supported()) return { ok: false, error: "This browser has no passkey support." };
  const o = await begin({ purpose: "register", label, kind });
  let cred: PublicKeyCredential | null;
  try { cred = (await navigator.credentials.create({ publicKey: prepareCreate(o.options) })) as PublicKeyCredential | null; } catch (e) { return { ok: false, error: friendly(e) }; }
  if (!cred) return { ok: false, error: "No key was created." };
  const j = credToJson(cred); j.clientExtensionResults = cleanExt(j.clientExtensionResults);
  const r = await post("/founder/v1/passkey/verify", { ceremony: o.ceremony, credential: j });
  if (r.status !== 200) return { ok: false, error: r.body?.error || `HTTP ${r.status}` };
  if (r.body.needs_stepup) {
    const p = await prove({ action: r.body.action, target: r.body.target, params: r.body.params, purpose: "action" });
    if (!p.ok) return { ok: false, error: p.error };
    const f = await post("/founder/v1/passkey/finish", { ceremony: r.body.ceremony, grant: p.result.grant });
    if (f.status !== 200) return { ok: false, error: f.body?.error || `HTTP ${f.status}` };
    return { ok: true, via: f.body.via };
  }
  return { ok: true, via: r.body.via, recovery_codes: r.body.recovery_codes?.codes ?? r.body.recovery_codes ?? undefined };
}

/** WebAuthn Level 3 Signal API: tell the passkey provider which keys are still valid / were revoked, so a revoked key disappears from the picker. Feature-detected; every call is acknowledged to the server either way. */
export async function runSignals(signals: Json[]): Promise<{ done: number; unsupported: number }> {
  const P = (window as any).PublicKeyCredential;
  let done = 0, unsupported = 0;
  for (const s of signals) {
    const fn = s.kind === "all_accepted" ? P?.signalAllAcceptedCredentials : s.kind === "unknown_credential" ? P?.signalUnknownCredential : null;
    if (typeof fn !== "function") { unsupported++; continue; }
    try {
      if (s.kind === "all_accepted") await P.signalAllAcceptedCredentials({ rpId: s.payload.rpId, userId: toB64u(s.payload.userId), allAcceptedCredentialIds: s.payload.credentialIds });
      else await P.signalUnknownCredential({ rpId: s.payload.rpId, credentialId: s.payload.credentialId });
      await post("/founder/v1/chairman/signal_ack", { p_id: s.id }); done++;
    } catch { unsupported++; }
  }
  return { done, unsupported };
}

export type KeysView = { available: boolean; keys: any[]; webauthn: any; signals: any[]; protocol: any; post_quantum: any; hardware?: any };
export const loadKeys = async (): Promise<KeysView> => (await get<KeysView>("/founder/v1/passkey/list")).data;
export const door = (name: string, body: Json) => post(`/founder/v1/chairman/${name}`, body);
