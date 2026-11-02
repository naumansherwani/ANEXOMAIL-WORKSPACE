// G4 (E120): the Dashboard "Ledger seal" gauge, as PURE functions (unit tested with bun). Two jobs:
//  1) the browser PINS the newest seal it has seen {id, upto_seq, root, cp_hash}. A server that is rolled back to an old backup, or whose history was
//     rewritten, can no longer look "fine": the pinned seal will be missing or different. (Same idea as a Certificate Transparency monitor.)
//  2) one honest sentence + state for the gauge, built only from what the server and the kernel really said. Nothing is invented.
export type Seal = { id: number; upto_seq: number; root: string; cp_hash: string };
export type PinState = "new" | "same" | "advanced" | "rollback" | "rewritten" | "unchecked";
export type PinVerdict = { state: PinState; text: string };
export type Gauge = { state: "ok" | "warn" | "fail" | "unknown"; text: string; chip?: string };
export type Proof = { n: number; ok: number } | "failed" | null;

const HEX64 = /^[0-9a-f]{64}$/;
const KEY = "anexo.founder.sealpin.v1";

/** A seal is only used if every field has the exact shape the database guarantees. Anything else is ignored, never trusted. */
export function asSeal(v: any): Seal | null {
  if (!v || typeof v !== "object") return null;
  const id = Number(v.id), upto = Number(v.upto_seq);
  if (!Number.isSafeInteger(id) || id < 1 || !Number.isSafeInteger(upto) || upto < 1) return null;
  if (typeof v.root !== "string" || !HEX64.test(v.root) || typeof v.cp_hash !== "string" || !HEX64.test(v.cp_hash)) return null;
  return { id, upto_seq: upto, root: v.root, cp_hash: v.cp_hash };
}

const same = (a: Seal, b: Seal) => a.id === b.id && a.upto_seq === b.upto_seq && a.root === b.root && a.cp_hash === b.cp_hash;

/**
 * pin       = the seal this browser remembered (null = first visit)
 * current   = the newest seal the server shows now (null = the server shows none)
 * pinnedNow = what the server says seal #pin.id is NOW (only needed when the server moved ahead; null/"error" = could not ask)
 */
export function judgePin(pin: Seal | null, current: Seal | null, pinnedNow: Seal | null | "error"): PinVerdict {
  if (!pin) return { state: "new", text: current ? "first seal remembered in this browser" : "" };
  if (!current) return { state: "rollback", text: `this browser saw seal #${pin.id}, the server now shows none: history was rolled back` };
  if (current.id < pin.id || current.upto_seq < pin.upto_seq) return { state: "rollback", text: `this browser saw seal #${pin.id}, the server now stops at #${current.id}: history was rolled back` };
  if (current.id === pin.id) return same(pin, current) ? { state: "same", text: `seal #${pin.id} matches what this browser remembered` }
    : { state: "rewritten", text: `seal #${pin.id} is different from what this browser remembered: history was rewritten` };
  if (pinnedNow === "error" || pinnedNow === null) return { state: "unchecked", text: `could not re-check the remembered seal #${pin.id} just now` };
  return same(pin, pinnedNow) ? { state: "advanced", text: `seal #${pin.id} still matches, ${current.id - pin.id} newer seal${current.id - pin.id === 1 ? "" : "s"} since` }
    : { state: "rewritten", text: `seal #${pin.id} is different from what this browser remembered: history was rewritten` };
}

/**
 * G5a: when the server moved ahead of the pinned seal, a kernel-checked RFC 9162 consistency proof is STRONGER than comparing the old seal:
 * it proves the new ledger contains the old one unchanged. ext = "ok" (kernel accepted) | "bad" (kernel refused) | "na" (route/proof unavailable).
 * A refused proof is always a rewrite. An accepted proof also settles a seal we could not re-ask ("unchecked"). "na" changes nothing.
 */
export function withExtension(v: PinVerdict, ext: "ok" | "bad" | "na" | "absent", pin: Seal | null, current: Seal | null): PinVerdict {
  if (ext === "bad") return { state: "rewritten", text: `the ledger now at seal #${current?.id ?? "?"} does not extend seal #${pin?.id ?? "?"} that this browser remembered (consistency proof refused): history was rewritten` };
  if (ext === "ok" && (v.state === "advanced" || v.state === "unchecked") && pin && current)
    return { state: "advanced", text: `seal #${pin.id} still holds and the kernel proved the ledger up to entry ${current.upto_seq} extends it unchanged (RFC 9162)` };
  // "na" = the proof route exists but gave no usable answer, or the kernel could not run: the server moved ahead WITHOUT a proof, so the remembered seal
  // is NOT moved forward (a forked server must not be able to skip the very check it should pass). "absent" = E121 is not installed yet: old behaviour.
  if (ext === "na" && v.state === "advanced" && pin && current)
    return { state: "unchecked", text: `seal #${pin.id} still matches, but no consistency proof could be checked just now, so the remembered seal was not moved` };
  return v;
}

export function loadPin(): Seal | null {
  try { const raw = localStorage.getItem(KEY); return raw ? asSeal(JSON.parse(raw)) : null; } catch { return null; }
}
export function savePin(s: Seal): void {
  try { localStorage.setItem(KEY, JSON.stringify(s)); } catch { /* private window: the check simply starts again next time */ }
}
/** Move the pin forward only for a verdict that proves the old seal is intact (never after a rollback / rewrite: that would hide it). */
export function shouldAdvancePin(v: PinVerdict): boolean { return v.state === "new" || v.state === "advanced"; }

export function fmtAge(s: number): string {
  if (!Number.isFinite(s) || s < 0) return "just now";
  if (s < 90) return "just now";
  if (s < 5400) return `${Math.round(s / 60)} min ago`;
  if (s < 172800) return `${Math.round(s / 3600)} h ago`;
  return `${Math.round(s / 86400)} days ago`;
}

// ---- G5b: the signed checkpoint (C2SP) ----------------------------------------------------------------------------------------------------------
// The server delivers the newest signed note + the audit-log public keys. The KERNEL checks the Ed25519 signature and that the note's size/root are the ones we expect;
// this file only (1) shapes the answer, (2) remembers the audit-log key in this browser (TOFU: first sight is trusted, a later change is a loud warning), (3) writes the sentence.
export type LogKey = { id: number; name: string; pub_hex: string; key_id_hex: string; status: string };
export type SignedView = { note: string; cp_id: number; size: number; root: string; origin: string; key: LogKey; keys: LogKey[]; level: string; unsigned: number; recheckOk: boolean | null };
export type KeyVerdict = { state: "new" | "same" | "rotated" | "replaced"; text: string };
export type SignedVerdict = { state: "ok" | "warn" | "fail" | "none"; text: string; keyState?: KeyVerdict["state"] };
const KEYPIN = "anexo.founder.logkeypin.v1";
const HEX8 = /^[0-9a-f]{8}$/;

export function asLogKey(v: any): LogKey | null {
  if (!v || typeof v !== "object") return null;
  const id = Number(v.id);
  if (!Number.isSafeInteger(id) || id < 1 || typeof v.name !== "string" || v.name.length < 3 || v.name.length > 200 || /[\s+]/.test(v.name)) return null;
  if (typeof v.pub_hex !== "string" || !HEX64.test(v.pub_hex) || typeof v.key_id_hex !== "string" || !HEX8.test(v.key_id_hex)) return null;
  return { id, name: v.name, pub_hex: v.pub_hex, key_id_hex: v.key_id_hex, status: v.status === "retired" ? "retired" : "active" };
}

/** `d` = the signed data of GET /founder/v1/audit/signed. null = nothing usable (E123 not installed, or no seal signed yet): no claim is made then. */
export function asSignedView(d: any): SignedView | null {
  if (!d || d.connected === false || !d.signed || d.signed.found !== true) return null;
  const s = d.signed, cp = Number(s.cp_id), size = Number(s.size);
  if (!Number.isSafeInteger(cp) || cp < 1 || !Number.isSafeInteger(size) || size < 1 || typeof s.root !== "string" || !HEX64.test(s.root)) return null;
  if (typeof s.note !== "string" || s.note.length < 100 || s.note.length > 4096 || typeof s.origin !== "string") return null;
  const keys = (Array.isArray(s.keys) ? s.keys : []).map(asLogKey).filter((k: LogKey | null): k is LogKey => !!k);
  const key = keys.find((k: LogKey) => k.id === Number(s.key_id));
  if (!key || key.name !== s.origin) return null;
  const p = d.pulse ?? {}, rc = d.db_recheck;
  return { note: s.note, cp_id: cp, size, root: s.root, origin: s.origin, key, keys, level: typeof p.level === "string" ? p.level : "ok", unsigned: Number(p.unsigned) || 0, recheckOk: rc && typeof rc.ok === "boolean" ? rc.ok : null };
}

export function loadKeyPin(): { name: string; pub_hex: string } | null {
  try { const o = JSON.parse(localStorage.getItem(KEYPIN) ?? "null"); return o && typeof o.name === "string" && HEX64.test(o.pub_hex) ? { name: o.name, pub_hex: o.pub_hex } : null; } catch { return null; }
}
export function saveKeyPin(k: { name: string; pub_hex: string }): void {
  try { localStorage.setItem(KEYPIN, JSON.stringify({ name: k.name, pub_hex: k.pub_hex })); } catch { /* private window: first-sight trust starts again next time */ }
}
/** TOFU for the audit-log key. First sight = remembered. Same key = fine. A different key is NEVER accepted silently: "rotated" (the old key is still listed by the server as retired) is a warning, "replaced" (the old key is not even listed) is a failure. */
export function judgeKey(pin: { name: string; pub_hex: string } | null, k: LogKey, keys: LogKey[]): KeyVerdict {
  if (!pin) return { state: "new", text: "the audit-log key was remembered in this browser" };
  if (pin.name === k.name && pin.pub_hex === k.pub_hex) return { state: "same", text: "the audit-log key is the one this browser remembered" };
  if (keys.some((x) => x.pub_hex === pin.pub_hex && x.status === "retired")) return { state: "rotated", text: "the audit-log key was changed since this browser first saw it (the old key is listed as retired); check it, then trust the new key" };
  return { state: "replaced", text: "the audit-log key is NOT the one this browser remembered and the old key is not in the server's list: possible key substitution" };
}

/**
 * kernel = what the WASM kernel said about THIS note under THIS key: "ok" | "bad" | "na" (could not run).
 * mkSeal = the newest seal the server shows on the Dashboard. The signed note may be one seal behind (the signer runs about once a minute): that is information, not an alarm.
 */
export function judgeSigned(view: SignedView | null, kernel: "ok" | "bad" | "na", keyV: KeyVerdict | null, mkSeal: Seal | null): SignedVerdict {
  if (!view) return { state: "none", text: "" };
  if (kernel === "bad") return { state: "fail", text: `the signature on seal #${view.cp_id} did NOT verify in this browser (kernel refused it)` };
  if (kernel === "na") return { state: "warn", text: `could not check the signature on seal #${view.cp_id} just now` };
  if (keyV?.state === "replaced") return { state: "fail", text: keyV.text, keyState: "replaced" };
  if (mkSeal && mkSeal.id === view.cp_id && (mkSeal.root !== view.root || mkSeal.upto_seq !== view.size)) return { state: "fail", text: `the signed note for seal #${view.cp_id} says a different root than the seal shown: they disagree` };
  if (view.recheckOk === false) return { state: "fail", text: "the database re-check of the stored signed notes found a problem" };
  const parts = [`seal #${view.cp_id} is signed by the audit-log key (Ed25519, checked by the kernel in this browser)`];
  let state: SignedVerdict["state"] = "ok";
  if (keyV?.state === "rotated") { state = "warn"; parts.push(keyV.text); }
  if (mkSeal && mkSeal.id > view.cp_id) parts.push(`the newer seal #${mkSeal.id} is not signed yet`);
  if (view.level === "fail") { state = "fail"; parts.push("seals have waited far too long for a signature"); }
  else if (view.level === "warn" && state === "ok") { state = "warn"; parts.push("seals are waiting for a signature"); }
  return { state, text: parts.join("; "), keyState: keyV?.state };
}

/** The gauge. `mk` is the signed answer of GET /founder/v1/audit/merkle. `fmtTime` shows a server time in the founder's city. */
export function ledgerGauge(mk: any, proof: Proof, pin: PinVerdict | null, fmtTime: (ms: number) => string, signed: SignedVerdict | null = null): Gauge {
  if (!mk) return { state: "fail", text: "Not answering" };
  if (mk.connected === false) return { state: "unknown", text: mk.note || "Install the E107 SQL step" };
  const p = mk.pulse ?? {}, lc = p.last_checkpoint, fc = p.full_check;
  let state: Gauge["state"] = p.level === "fail" ? "fail" : p.level === "warn" ? "warn" : "ok";
  const bump = (to: "warn" | "fail") => { if (to === "fail" || state === "ok") state = to; };
  const parts: string[] = [];
  parts.push(lc ? `${p.rows} entries, sealed up to entry ${lc.upto_seq} at ${fmtTime(lc.created_ms)}, ${p.lag_rows} since`
                : `${p.rows ?? 0} entries, the first seal comes at ${p.every_rows ?? "?"} new entries`);
  // the checker: E120 not installed -> say nothing invented; installed -> the real result and its age
  if (p.checker === undefined) { /* E120 not installed yet: older answer, no claim about a full check */ }
  else if (p.checker === "never") { bump("warn"); parts.push("no full ledger check has run yet"); }
  else if (fc) {
    if (!fc.chain_ok || !fc.cp_ok) { bump("fail"); parts.push(!fc.chain_ok ? `full check ${fmtAge(fc.age_s)}: chain broken at entry ${fc.chain_bad_seq}` : `full check ${fmtAge(fc.age_s)}: seal ${fc.cp_bad_id} does not match`); }
    else if (p.checker === "stale") { bump("warn"); parts.push(`last full check ${fmtAge(fc.age_s)} (the checker may be stalled)`); }
    else parts.push(`full check ${fmtAge(fc.age_s)}: ${fc.rows} entries intact`);
  }
  if (p.sealer_stalled) { bump("warn"); parts.push("a seal is due but the automatic sealer has not made it"); }
  if (proof === "failed") { bump("warn"); parts.push("browser proof unavailable just now"); }
  else if (proof) { if (proof.ok < proof.n) { bump("fail"); parts.push(`${proof.n - proof.ok} of ${proof.n} entries FAILED the proof in this browser`); } else parts.push(`${proof.ok} of ${proof.n} entries proven in this browser`); }
  if (pin) {
    if (pin.state === "rollback" || pin.state === "rewritten") { bump("fail"); parts.push(pin.text.toUpperCase().slice(0, 1) + pin.text.slice(1)); }
    else if (pin.text && pin.state !== "new") parts.push(pin.text);
  }
  if (signed && signed.state !== "none" && signed.text) { if (signed.state === "fail") bump("fail"); else if (signed.state === "warn") bump("warn"); parts.push(signed.text.charAt(0).toUpperCase() + signed.text.slice(1)); }
  return { state, text: parts.join(". "), chip: lc ? `#${lc.id}` : undefined };
}
