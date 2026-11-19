// QC1c F8-5: the network half. Step 1 asks the server to prepare the exact change (nothing is touched or changed yet); step 2 lets the Rust WASM kernel re-derive the digest, THEN the key is touched, and only the assertion is sent.
import { actionCheck } from "./kernel";
import { get, post } from "./api";
import { cleanExt, credToJson, friendly, prepareGet } from "./passkey_pure";
import { cleanDomain, parseBegun, parsePolicy, refusal, type Begun, type TlsPolicy } from "./tls_loosen_pure";

export const policyOf = async (box: string): Promise<TlsPolicy | null> => parsePolicy((await get(`/founder/v1/mail/tls/policy?box=${encodeURIComponent(box)}`)).data);
export async function prepare(box: string, domain: string, hours: number, reason: string): Promise<{ ok: true; begun: Begun } | { ok: false; error: string }> {
  const r = await post("/founder/v1/mail/tls/loosen/begin", { box, domain: cleanDomain(domain), hours, reason: reason.trim() });
  if (r.status !== 200) return { ok: false, error: refusal(r.status, r.body) };
  const b = parseBegun(r.body);
  return b ? { ok: true, begun: b } : { ok: false, error: "The server's answer was not understood, so nothing was changed." };
}
export async function confirm(b: Begun): Promise<{ ok: true } | { ok: false; error: string }> {
  if (typeof window === "undefined" || !window.PublicKeyCredential || !navigator.credentials) return { ok: false, error: "This browser has no passkey support." };
  const chk = await actionCheck({ action: b.action, target: b.target, params: b.params, nonce: b.nonce, hash: b.hash, challenge: String(b.options.challenge ?? "") });
  if (!chk) return { ok: false, error: "The security kernel could not run, so the key was not touched." };
  if (!chk.ok) return { ok: false, error: chk.problem ?? "The server's digest does not match this change, so the key was not touched." };
  let cred: PublicKeyCredential | null;
  try { cred = (await navigator.credentials.get({ publicKey: prepareGet(b.options as never) })) as PublicKeyCredential | null; } catch (e) { return { ok: false, error: friendly(e) }; }
  if (!cred) return { ok: false, error: "No key was used." };
  const j = credToJson(cred); j.clientExtensionResults = cleanExt(j.clientExtensionResults);
  const r = await post("/founder/v1/mail/tls/loosen/finish", { ceremony: b.ceremony, credential: j });
  return r.status === 200 && r.body?.ok === true ? { ok: true } : { ok: false, error: refusal(r.status, r.body) };
}
export async function tighten(box: string, domain: string): Promise<{ ok: boolean; error?: string }> {
  const r = await post("/founder/v1/mail/tls/tighten", { box, domain });
  return r.status === 200 && r.body?.ok === true ? { ok: true } : { ok: false, error: refusal(r.status, r.body) };
}
