/**
 * Identity vault — local MIRROR + durable OUTBOX + health (Bun side; Rust gets the same in Auth Phase A via vault_core.rs).
 *
 *  - HMAC/canonicalisation here is byte-for-byte the SQL in E68/E69 (parity vectors in the tests and in CHECK_E69), so the
 *    process can decide "is this a blocked identity?" WITHOUT the database.
 *  - Mirror = set of active strong-signal blocks, filled from identity_ban_feed (full at start + hourly, incremental every 30 s).
 *  - Outbox = hashes only (never raw values) of registrations that could not be written; retried until they land.
 *  - Fail-closed only when the vault IS installed but there is neither a mirror nor a working database. If the SQL is not
 *    installed yet (function missing) the guard stays out of the way and says so in the log.
 */
import { createHmac } from "node:crypto";
import { appendFileSync, existsSync, mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";

export type Signal = { kind: string; hmac: string };
const STRONG = new Set(["device_key", "email", "recovery", "payment"]);

export function canonEmail(raw: string | null | undefined): string | null {
  const v = String(raw ?? "");
  if (v.indexOf("@") < 1) return null;
  const local0 = v.split("@")[0]!.trim().toLowerCase();
  const domain = (v.split("@")[1] ?? "").trim().toLowerCase();
  const local = local0.split("+")[0]!;
  if (domain === "gmail.com" || domain === "googlemail.com") return `${local.replace(/\./g, "")}@gmail.com`;
  return `${local}@${domain}`;
}

export function hmacHex(kind: string, canon: string | null | undefined, key: string): string | null {
  if (canon == null || canon.trim() === "") return null;
  const k = createHmac("sha256", key || "no-pepper").update(`anexomail/identity/v1/${kind}`).digest();
  return createHmac("sha256", k).update(canon, "utf8").digest("hex");
}

/** Browser fingerprint groups, each already a client-side SHA-256 hex (64). Raw components never leave the browser. */
export type RawFingerprint = { hw?: string | null; gpu?: string | null; font?: string | null; gfx?: string | null; env?: string | null };
export const FP_GROUPS = ["hw", "gpu", "font", "gfx", "env"] as const;
export type RawIdentity = {
  email?: string | null;
  recovery?: string | null;
  deviceKey?: string | null;
  shape?: string | null;
  network?: string | null;
  fp?: RawFingerprint | null;
};

/** Same rule as SQL identity_fp_canon: a 64-hex digest or nothing (a broken client never blocks the other signals). */
export function fpCanon(v: string | null | undefined): string | null {
  const t = String(v ?? "").trim().toLowerCase();
  return /^[0-9a-f]{64}$/.test(t) ? t : null;
}

/** Same order and rules as SQL identity_signals_full_raw (E70). The five fp_* kinds (hw, gpu, font, gfx, env) are weak-tier: they never ban alone. */
export function signalsRaw(r: RawIdentity, key: string): Signal[] {
  const lower = (v: string | null | undefined) => (v == null ? null : v.trim().toLowerCase());
  const rows: [string, string | null][] = [
    ["email", canonEmail(r.email)],
    ["recovery", canonEmail(r.recovery)],
    ["device_key", lower(r.deviceKey)],
    ["device_shape", lower(r.shape)],
    ["network", lower(r.network)],
    ["fp_hw", fpCanon(r.fp?.hw)],
    ["fp_gpu", fpCanon(r.fp?.gpu)],
    ["fp_font", fpCanon(r.fp?.font)],
    ["fp_gfx", fpCanon(r.fp?.gfx)],
    ["fp_env", fpCanon(r.fp?.env)],
  ];
  const out: Signal[] = [];
  for (const [kind, canon] of rows) {
    const h = hmacHex(kind, canon, key);
    if (h) out.push({ kind, hmac: h });
  }
  return out;
}

export type RawIdentityInput = RawIdentity & { email: string; recovery: string; deviceKey: string | null; shape: string | null; network: string | null };

/** Request body `fingerprint` => up to five clean digests (junk, wrong type or length become null). Never trusts the shape of the input. */
export function fingerprintFrom(body: unknown): RawFingerprint | null {
  if (!body || typeof body !== "object") return null;
  const b = body as Record<string, unknown>;
  const out: RawFingerprint = {};
  let any = false;
  for (const g of FP_GROUPS) {
    const v = fpCanon(typeof b[g] === "string" ? (b[g] as string) : null);
    out[g] = v;
    if (v) any = true;
  }
  return any ? out : null;
}
import { admin } from "./supa";

/* ───────────────────────── mirror ───────────────────────── */
export type FeedRow = { k: string; h: string; a: boolean; e: number | null };
export type Feed = { rows: FeedRow[]; cursor_t: string | null; cursor_id: number; more: boolean; full: boolean };

export class Mirror {
  private set = new Map<string, number | null>(); // "kind:hex" -> expiry epoch seconds | null
  private loadedAt = 0;
  cursorT: string | null = null;
  cursorId = 0;

  get ready() {
    return this.loadedAt > 0;
  }
  get size() {
    return this.set.size;
  }
  ageSeconds(now = Date.now()) {
    return this.loadedAt ? Math.max(0, Math.round((now - this.loadedAt) / 1000)) : 0;
  }

  apply(feed: Feed, now = Date.now()) {
    if (feed.full) this.set.clear();
    for (const r of feed.rows ?? []) {
      if (!STRONG.has(r.k) || !/^[0-9a-f]{64}$/.test(r.h)) continue;
      const key = `${r.k}:${r.h}`;
      if (r.a) this.set.set(key, r.e ?? null);
      else this.set.delete(key);
    }
    if (feed.cursor_t) {
      this.cursorT = feed.cursor_t;
      this.cursorId = Number(feed.cursor_id) || 0;
    } else if (feed.full) {
      this.cursorT = null;
      this.cursorId = 0;
    }
    this.loadedAt = now;
  }

  /** Strong-signal deny only (the weak "review" logic needs counts and stays in the database). */
  deny(signals: Signal[], nowS = Math.floor(Date.now() / 1000)): string[] {
    const hit = new Set<string>();
    for (const s of signals) {
      if (!STRONG.has(s.kind)) continue;
      const key = `${s.kind}:${s.hmac}`;
      if (!this.set.has(key)) continue;
      const exp = this.set.get(key);
      if (exp != null && exp <= nowS) continue;
      hit.add(s.kind);
    }
    return [...hit].sort();
  }
}

/* ───────────────────────── outbox ───────────────────────── */
export type OutboxItem = { id: string; account: string; signals: Signal[]; at: number; tries: number };

export class Outbox {
  constructor(private path: string) {}
  private ensure() {
    const d = dirname(this.path);
    if (!existsSync(d)) mkdirSync(d, { recursive: true });
  }
  add(account: string, signals: Signal[], now = Date.now()) {
    this.ensure();
    const item: OutboxItem = { id: `${now}-${Math.random().toString(36).slice(2, 8)}`, account, signals, at: now, tries: 0 };
    appendFileSync(this.path, JSON.stringify(item) + "\n", { mode: 0o600 });
    return item.id;
  }
  list(): OutboxItem[] {
    if (!existsSync(this.path)) return [];
    const out: OutboxItem[] = [];
    for (const line of readFileSync(this.path, "utf8").split("\n")) {
      if (!line.trim()) continue;
      try {
        const it = JSON.parse(line) as OutboxItem;
        if (it?.account && Array.isArray(it.signals)) out.push(it);
      } catch {
        /* torn last line after a crash: skip */
      }
    }
    return out;
  }
  /** Rewrite atomically with what is left. */
  save(items: OutboxItem[]) {
    this.ensure();
    const tmp = `${this.path}.tmp`;
    writeFileSync(tmp, items.map((i) => JSON.stringify(i)).join("\n") + (items.length ? "\n" : ""), { mode: 0o600 });
    renameSync(tmp, this.path);
  }
  get size() {
    return this.list().length;
  }
}

/* ───────────────────────── guard (decision policy) ───────────────────────── */
export type GuardDecision =
  | { kind: "deny"; matched: string[]; appealable: boolean; reason?: string | null; via: "mirror" | "database" }
  | { kind: "hold"; reason: string; holdKind: "match" | "gate" | "manual"; via: "database" }
  | { kind: "allow"; review?: boolean; via: "database" | "mirror" | "not_installed" }
  | { kind: "closed" };

type DbValue = { decision?: string; matched?: string[]; appealable?: boolean; reason?: string | null; hold_kind?: string };

/** Pure policy so it can be tested: what to do with a database answer / error and the mirror.
 *  hold is decided by the database only (it needs counts and the gate switch); a mirror-only answer never holds — the
 *  registration that follows applies the hold in SQL, and the sign-in itself is refused by GoTrue until a human decides. */
export function decide(opts: {
  mirrorReady: boolean;
  mirrorDeny: string[];
  db: { ok: true; value: DbValue } | { ok: false; notInstalled: boolean };
}): GuardDecision {
  if (opts.mirrorDeny.length) return { kind: "deny", matched: opts.mirrorDeny, appealable: true, via: "mirror" };
  if (opts.db.ok) {
    const v = opts.db.value;
    if (v.decision === "deny") return { kind: "deny", matched: v.matched ?? [], appealable: v.appealable !== false, reason: v.reason ?? null, via: "database" };
    if (v.decision === "hold") {
      const hk = v.hold_kind === "gate" || v.hold_kind === "manual" ? v.hold_kind : "match";
      return { kind: "hold", reason: v.reason ?? "hold", holdKind: hk, via: "database" };
    }
    return { kind: "allow", review: v.decision === "review", via: "database" };
  }
  if (opts.db.notInstalled) return { kind: "allow", via: "not_installed" };
  return opts.mirrorReady ? { kind: "allow", via: "mirror" } : { kind: "closed" };
}

export function isNotInstalled(err: unknown): boolean {
  const e = err as { code?: string; message?: string } | null;
  return e?.code === "PGRST202" || e?.code === "42883" || /could not find the function|does not exist/i.test(e?.message ?? "");
}
