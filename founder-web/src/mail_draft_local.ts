// QC7b (20 Nov 2026): the draft is ALSO sealed in the browser. Sealing uses only the device PUBLIC key (kernel kemopen@1 seal: ML-KEM-768 + X25519 + HKDF + AES-256-GCM, browser random values), so autosave
// never asks for a key touch. The sealed copy lives in IndexedDB; it opens only after the founder touches his key (mail_keys.unlockDeviceKey) and only in the kernel. Plain text never touches storage.
import { kemOpen, kemSeal } from "./kernel";
import { keyHistory, loadWrapped, openMaterial, unlockDeviceKey } from "./mail_keys";
import { decodeDraft, draftAad, encodeDraft, pendingOf, slotOf, type DraftBody, type LocalRec } from "./mail_draft_local_pure";
const DB = "anexomail-drafts", STORE = "sealed";
const idb = <T,>(f: (s: IDBObjectStore) => IDBRequest<T>, mode: IDBTransactionMode): Promise<T | undefined> => new Promise((res) => {
  try {
    const o = indexedDB.open(DB, 1); o.onupgradeneeded = () => o.result.createObjectStore(STORE);
    o.onerror = () => res(undefined);
    o.onsuccess = () => { const r = f(o.result.transaction(STORE, mode).objectStore(STORE)); r.onsuccess = () => res(r.result); r.onerror = () => res(undefined); };
  } catch { res(undefined); }
});
const k = (box: string, slot: string) => `${box.toLowerCase()}:${slot}`;
/** The active device key of this mailbox that THIS device holds (public half is stored beside the wrapped record). null = no key made here yet: then only the server copy exists, and the bar says so. */
async function activeKey(box: string): Promise<{ key_id: string; pub: string } | null> {
  const h = await keyHistory(box); const a = h?.keys.find((x) => x.status === "active"); if (!a) return null;
  const rec = await loadWrapped(box, a.key_id); return rec ? { key_id: a.key_id, pub: rec.pub } : null;
}
/** Seal the draft into this browser. Never throws; false = nothing was stored (no key here yet, kernel could not run). */
export async function sealLocal(box: string, serverId: string | null | undefined, d: DraftBody, synced: boolean): Promise<boolean> {
  try {
    const key = await activeKey(box); if (!key) return false;
    const slot = slotOf(serverId), s = await kemSeal({ pub: key.pub, key_id: key.key_id, aad: draftAad(box, slot), plain: encodeDraft(d) });
    if (!s || !s.ok) return false;
    const rec: LocalRec = { box: box.toLowerCase(), slot, key_id: key.key_id, wrap: s.wrap, nonce: s.nonce, sealed: s.sealed, saved_ms: Date.now(), ...(serverId ? { server_id: serverId } : {}), synced };
    return (await idb((st) => st.put(rec, k(box, slot)), "readwrite")) !== undefined;
  } catch { return false; }
}
/** The server accepted the draft: mark the copy synced (kept, sealed, until the draft is sent or discarded), and drop the "new" slot it replaced. */
export async function markSynced(box: string, serverId: string, d: DraftBody): Promise<void> { await forget(box, "new"); await sealLocal(box, serverId, d, true); }
export async function forget(box: string, slot: string): Promise<void> { await idb((st) => st.delete(k(box, slot)), "readwrite"); }
/** Sent or discarded: nothing of this draft stays on the device. */
export async function forgetDraft(box: string, serverId: string | null | undefined): Promise<void> { await forget(box, slotOf(serverId)); await forget(box, "new"); }
export async function pending(box: string): Promise<LocalRec | null> {
  const all = (await idb((st) => st.getAll(), "readonly")) as LocalRec[] | undefined; return pendingOf(all ?? [], box);
}
/** Restore: one key touch, then the kernel opens the copy. null + reason on any failure; the copy is left untouched. */
export async function restore(rec: LocalRec): Promise<{ ok: true; draft: DraftBody } | { ok: false; error: string }> {
  const u = await unlockDeviceKey(rec.box, rec.key_id); if (!u.ok) return u;
  const m = openMaterial(rec.box, rec.key_id); const w = await loadWrapped(rec.box, rec.key_id);
  if (!m || !w) return { ok: false, error: "The device key is not available." };
  const o = await kemOpen({ dk: m.dk, x: m.x, pub: w.pub, key_id: rec.key_id, wrap: rec.wrap, nonce: rec.nonce, aad: draftAad(rec.box, rec.slot), sealed: rec.sealed });
  if (!o || !o.ok) return { ok: false, error: o && !o.ok ? o.reason : "The kernel could not open the draft." };
  const d = decodeDraft(o.plain); return d ? { ok: true, draft: d } : { ok: false, error: "The sealed draft was damaged." };
}
