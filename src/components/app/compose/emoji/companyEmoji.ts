// QC1e D4A (20 Nov 2026, AWAM ONLY): data layer of the company emoji pack. Talks to the Rust door `emoji.pack.*` (emoji_glue.rs) through the same
// rpc client as everything else (kernel first, then fetch). No vendor, no third-party host: pictures come back as base64 inside the answer and are
// shown as data: URLs (img-src 'self' data:). Every picture is immutable (its id is its sha-256), so it is fetched once and cached for the session.
import { rpc } from "@/lib/rpc";
import { NO_QUOTA, type CompanyItem, type Quota } from "./company_emoji_pure";

export type Pack = { items: CompanyItem[]; quota: Quota; canManage: boolean; role: string; available: boolean };
export const EMPTY_PACK: Pack = { items: [], quota: NO_QUOTA, canManage: false, role: "", available: false };

const TTL = 60_000;
let cache: { at: number; p: Promise<Pack> } | null = null;
const subs = new Set<(p: Pack) => void>();

type ListReply = { items?: CompanyItem[]; quota?: Quota; role?: string; can_manage?: boolean };

/** The pack of the caller's company. Any failure (engine without the module yet, no workspace, offline) = an empty, "not available" pack: the picker simply shows no Company tab. */
export function loadPack(force = false): Promise<Pack> {
  if (!force && cache && Date.now() - cache.at < TTL) return cache.p;
  const p = rpc<ListReply>("emoji.pack.list", {})
    .then((r): Pack => ({ items: r.items ?? [], quota: r.quota ?? NO_QUOTA, canManage: !!r.can_manage, role: r.role ?? "", available: true }))
    .catch((): Pack => EMPTY_PACK);
  cache = { at: Date.now(), p };
  void p.then((v) => subs.forEach((f) => f(v)));
  return p;
}
export function onPack(f: (p: Pack) => void): () => void { subs.add(f); return () => { subs.delete(f); }; }
export function invalidatePack(): Promise<Pack> { return loadPack(true); }

const imgs = new Map<string, Promise<string>>();
/** data: URL of one picture. Keyed by sha-256: the same picture is never fetched twice. */
export function imageUrl(code: string, sha: string): Promise<string> {
  let p = imgs.get(sha);
  if (!p) {
    p = rpc<{ data_b64?: string; mime?: string }>("emoji.pack.get", { code }).then((r) => {
      if (!r.data_b64) throw new Error("no image");
      return `data:${r.mime ?? "image/webp"};base64,${r.data_b64}`;
    });
    p.catch(() => imgs.delete(sha));
    imgs.set(sha, p);
  }
  return p;
}

export function fileToBase64(f: Blob): Promise<string> {
  return new Promise((ok, no) => {
    const r = new FileReader();
    r.onerror = () => no(new Error("The picture could not be read."));
    r.onload = () => { const s = String(r.result ?? ""); ok(s.slice(s.indexOf(",") + 1)); };
    r.readAsDataURL(f);
  });
}

export async function addEmoji(a: { code: string; alt: string; file: Blob }): Promise<void> {
  await rpc("emoji.pack.add", { code: a.code, alt: a.alt, image_b64: await fileToBase64(a.file) });
  await invalidatePack();
}
export async function removeEmoji(code: string): Promise<void> { await rpc("emoji.pack.remove", { code }); await invalidatePack(); }
export async function setEmojiAlt(code: string, alt: string): Promise<void> { await rpc("emoji.pack.alt", { code, alt }); await invalidatePack(); }
