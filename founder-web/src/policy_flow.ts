import { actionCheck } from "./kernel";
import { post } from "./api";
import { cleanExt, credToJson, friendly, prepareGet } from "./passkey_pure";
import { bodyOf, parseBegun, refusalText, type Begun, type Draft } from "./policy_change";

export type Step1 = { ok: true; begun: Begun } | { ok: false; error: string };
/** Step 1: ask the server to prepare the change. Nothing is touched or changed yet; the server may refuse here (lock-out, rate limit, no change). */
export async function prepare(d: Draft, reason: string): Promise<Step1> {
  const r = await post("/founder/v1/sessions/policy/begin", bodyOf(d, reason));
  if (r.status !== 200) return { ok: false, error: refusalText(r.status, r.body) };
  const b = parseBegun(r.body);
  return b ? { ok: true, begun: b } : { ok: false, error: "The server's answer was not understood, so nothing was changed." };
}
export type Step2 = { ok: true } | { ok: false; error: string };
/** Step 2: the kernel re-derives the digest, then the key is touched, then only the assertion is sent. */
export async function confirm(b: Begun): Promise<Step2> {
  if (typeof window === "undefined" || !window.PublicKeyCredential || !navigator.credentials) return { ok: false, error: "This browser has no passkey support." };
  const chk = await actionCheck({ action: b.action, target: b.target, params: b.params, nonce: b.nonce, hash: b.hash, challenge: String(b.options.challenge ?? "") });
  if (!chk) return { ok: false, error: "The security kernel could not run, so the key was not touched." };
  if (!chk.ok) return { ok: false, error: chk.problem ?? "The server's digest does not match this change, so the key was not touched." };
  let cred: PublicKeyCredential | null;
  try { cred = (await navigator.credentials.get({ publicKey: prepareGet(b.options as never) })) as PublicKeyCredential | null; } catch (e) { return { ok: false, error: friendly(e) }; }
  if (!cred) return { ok: false, error: "No key was used." };
  const j = credToJson(cred); j.clientExtensionResults = cleanExt(j.clientExtensionResults);
  const r = await post("/founder/v1/sessions/policy/finish", { ceremony: b.ceremony, credential: j });
  return r.status === 200 && r.body?.ok === true ? { ok: true } : { ok: false, error: refusalText(r.status, r.body) };
}
