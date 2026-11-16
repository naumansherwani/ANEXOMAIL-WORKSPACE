// Q1d-1a a4: the DKIM panel's doors (E175, a3). Same signed path as every mail door: kernel-signed requests, kernel-verified answers. No key material ever comes here.
import { get, post } from "./api";
import { prove } from "./passkey";
import type { Health } from "./dkim_pure";

const q = (b: string) => encodeURIComponent(b);
export async function dkimHealth(box: string): Promise<Health | null> { const r = (await get(`/founder/v1/mail/dkim/health?box=${q(box)}`)).data; return r?.connected ? (r.health as Health) : null; }
export async function dkimCheck(box: string, key: string): Promise<{ ok: true; result: string } | { ok: false; error: string }> {
  const r = await post("/founder/v1/mail/dkim/check", { box, key });
  return r.status === 200 && r.body?.ok ? { ok: true, result: r.body.check?.result ?? "lookup_error" } : { ok: false, error: r.body?.error || `HTTP ${r.status}` };
}
export async function dkimProof(box: string, receiver: string, authres: string): Promise<{ ok: true; results: { verdict: string; domain: string; selector: string | null; aligned: boolean; key_known: boolean }[] } | { ok: false; error: string }> {
  const r = await post("/founder/v1/mail/dkim/proof", { box, receiver, authres });
  return r.status === 200 && r.body?.ok ? { ok: true, results: r.body.proof?.results ?? [] } : { ok: false, error: r.body?.error || `HTTP ${r.status}` };
}
/** Turn a one-way policy switch ON. Needs a touch on this exact mailbox (action mail.key). */
export async function dkimPolicy(box: string, change: { oversign?: boolean; dual?: boolean; dns_match?: boolean }): Promise<{ ok: true } | { ok: false; error: string }> {
  const body = { box, ...change }; let r = await post("/founder/v1/mail/dkim/policy", body);
  if (r.status === 200 && r.body?.needs_touch) {
    const want = `dkimpolicy:${box}`;
    if (r.body.action !== "mail.key" || r.body.target !== want) return { ok: false, error: "The server asked for a touch on something else. Nothing was changed." };
    const p = await prove({ action: "mail.key", target: want }); if (!p.ok) return { ok: false, error: p.error };
    r = await post("/founder/v1/mail/dkim/policy", { ...body, grant: p.result?.grant, nonce: p.nonce });
  }
  return r.status === 200 && r.body?.ok ? { ok: true } : { ok: false, error: r.body?.error || `HTTP ${r.status}` };
}

/** AUDIT-Q1d G1: the three DKIM evidence hash chains re-checked on the server (null = door not available). */
export async function dkimChain(): Promise<{ checked: number; broken: number } | null> { const r = (await get("/founder/v1/mail/dkim/chain")).data; return r?.connected && r.chain && typeof r.chain.checked === "number" ? { checked: r.chain.checked, broken: r.chain.broken } : null; }
