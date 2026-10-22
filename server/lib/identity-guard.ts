/**
 * Identity vault runtime (Bun fallback; Rust primary in Auth Phase A): check at sign-up, register after, keep the local
 * mirror fresh, retry the outbox, sweep payment customers, tell the founder's overview how it is doing.
 * Raw values never leave this process: only one-way HMACs go to the database (identity_signup_check / identity_register_signals).
 */
import { decide, isNotInstalled, Mirror, Outbox, signalsRaw, type Feed, type GuardDecision, type RawIdentity, type Signal } from "./identity-mirror";
import { admin } from "./supa";
import { runNotices, type NoticeRow } from "./identity-notice";

export { fingerprintFrom, type RawIdentityInput } from "./identity-mirror";

/** Same pepper rule as server/routes/auth.ts vaultKey() and HASHING.md (DEVICE_VAULT_KEY; fallback derived from the service key). */
export function vaultKey(): string {
  const k = process.env.DEVICE_VAULT_KEY || "";
  if (k) return k;
  const base = process.env.SUPABASE4_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY || "";
  return base ? `anexomail-vault:${base.slice(-32)}` : "anexomail-vault-unconfigured";
}

export const mirror = new Mirror();
export const outbox = new Outbox(process.env.IDENTITY_OUTBOX || "/var/lib/anexomail/identity-outbox.jsonl");

const failures: number[] = [];
let lastClosedAt = 0;
const noteFailure = () => {
  failures.push(Date.now());
  while (failures.length && failures[0]! < Date.now() - 3_600_000) failures.shift();
};

function withTimeout<T>(p: PromiseLike<T>, ms = 8000): Promise<T> {
  return Promise.race([Promise.resolve(p), new Promise<T>((_, rej) => setTimeout(() => rej(new Error("timeout")), ms))]);
}

/** Sign-up policy question. E70 `identity_signup_decide(signals, domain)`; if only the older E66-E69 SQL is installed, fall back to
 *  `identity_signup_check` (no hold / disposable then — the older database never answers them). Domain is not secret and not hashed. */
async function askDecide(signals: Signal[], domain: string | null) {
  const first = await withTimeout(admin.rpc("identity_signup_decide", { p_signals: signals, p_domain: domain }));
  if (first.error && isNotInstalled(first.error)) return withTimeout(admin.rpc("identity_signup_check", { p_signals: signals }));
  return first;
}

export async function check(raw: RawIdentity): Promise<GuardDecision> {
  const signals = signalsRaw(raw, vaultKey());
  if (!signals.length) return { kind: "allow", via: "database" };
  const mirrorDeny = mirror.deny(signals);
  if (mirrorDeny.length) return decide({ mirrorReady: mirror.ready, mirrorDeny, db: { ok: false, notInstalled: false } });
  let db: Parameters<typeof decide>[0]["db"];
  try {
    // the disposable-inbox rule is about the address a person can be reached at: the RECOVERY inbox (the @anexomail.com login is ours, never disposable)
    const domain = String(raw.recovery ?? "").split("@")[1]?.trim().toLowerCase() || null;
    const { data, error } = await askDecide(signals, domain);
    db = error ? { ok: false, notInstalled: isNotInstalled(error) } : { ok: true, value: data ?? {} };
    if (error && !isNotInstalled(error)) noteFailure();
  } catch (err) {
    noteFailure();
    db = { ok: false, notInstalled: false };
    console.error("[identity.check]", (err as Error).message);
  }
  const d = decide({ mirrorReady: mirror.ready, mirrorDeny, db });
  if (d.kind === "closed") lastClosedAt = Date.now();
  if (d.kind === "allow" && d.via === "not_installed") console.warn("[identity] vault SQL not installed yet — guard is out of the way (run sql-run.sh)");
  return d;
}

export type RegisterResult = {
  /** The account is waiting for a human decision (GoTrue refuses its sign-in until then). */
  pending: boolean;
  /** The database could not be reached: hashes are in the outbox and registered later. */
  deferred: boolean;
  decision: string | null;
};

/** After the account exists. Anything that fails is kept (hashes only) and retried — nobody ends up unregistered.
 *  The result tells the route whether to hand out a session at all (pending => never). */
export async function register(account: string, raw: RawIdentity): Promise<RegisterResult> {
  const signals = signalsRaw(raw, vaultKey());
  if (!signals.length) return { pending: false, deferred: false, decision: null };
  try {
    const data = await send(account, signals);
    return { pending: data?.pending === true, deferred: false, decision: typeof data?.decision === "string" ? data.decision : null };
  } catch (notInstalled) {
    if (notInstalled === "not_installed") return { pending: false, deferred: false, decision: null };
    outbox.add(account, signals);
    return { pending: false, deferred: true, decision: null };
  }
}

async function send(account: string, signals: Signal[]): Promise<{ pending?: boolean; decision?: string } | null> {
  try {
    const { data, error } = await withTimeout(admin.rpc("identity_register_signals", { p_account: account, p_signals: signals }));
    if (error) {
      if (isNotInstalled(error)) throw "not_installed";
      // account vanished before the retry (FK) = nothing left to register
      if (/foreign key|23503/i.test(`${error.code} ${error.message}`)) return null;
      noteFailure();
      throw "failed";
    }
    return (data ?? null) as { pending?: boolean; decision?: string } | null;
  } catch (e) {
    if (e === "not_installed" || e === "failed") throw e;
    noteFailure();
    throw "failed";
  }
}

export async function drainOutbox(): Promise<number> {
  const items = outbox.list();
  if (!items.length) return 0;
  const left = [];
  for (const it of items) {
    try {
      await send(it.account, it.signals);
    } catch (e) {
      if (e !== "not_installed") left.push({ ...it, tries: it.tries + 1 });
      else left.push(it);
    }
  }
  outbox.save(left);
  return items.length - left.length;
}

export async function syncMirror(forceFull = false): Promise<void> {
  const full = forceFull || !mirror.ready;
  let more = true;
  let guard = 0;
  while (more && guard++ < 50) {
    const args = full && guard === 1 ? { p_since: null, p_since_id: 0, p_limit: 5000 } : { p_since: mirror.cursorT ?? "-infinity", p_since_id: mirror.cursorId, p_limit: 5000 };
    const { data, error } = await withTimeout(admin.rpc("identity_ban_feed", args));
    if (error) {
      if (!isNotInstalled(error)) noteFailure();
      return;
    }
    const feed = data as Feed;
    mirror.apply(feed);
    // a full load is one page of active rows; further pages (rare) continue incrementally from its cursor
    more = Boolean(feed.more) && Boolean(feed.cursor_t);
    if (full && guard === 1 && !feed.more) break;
  }
}

export async function sweepPayments(): Promise<number> {
  const { data: after } = await withTimeout(admin.rpc("identity_cursor_get", { p_name: "payment" }));
  const { data, error } = await withTimeout(admin.rpc("identity_payment_pending", { p_after: after ?? "epoch", p_limit: 200 }));
  if (error || !Array.isArray(data) || !data.length) return 0;
  let n = 0;
  let upto = String(after ?? "epoch");
  for (const row of data as { user_id: string; ref: string; at: string }[]) {
    const { error: e2 } = await withTimeout(admin.rpc("identity_register_payment", { p_account: row.user_id, p_ref: `polar:${row.ref}`, p_key: vaultKey() }));
    if (e2) break; // stop at the first failure so the cursor never skips a row
    n++;
    upto = row.at;
  }
  if (n) await withTimeout(admin.rpc("identity_cursor_set", { p_name: "payment", p_ts: upto }));
  return n;
}

/** Expiry of finite signals/bans, old audit, and un-decided holds (E70: hold_expire_days => rejected, account stays locked). */
export async function purge(): Promise<void> {
  const { error } = await withTimeout(admin.rpc("identity_vault_purge"), 30_000);
  if (error && !isNotInstalled(error)) noteFailure();
  // E71: old probation counters (40 days). Not installed yet => ignored.
  await withTimeout(admin.rpc("identity_probation_sweep"), 30_000).catch(() => undefined);
}

/** E71: tell people their sign-up was approved (outbox in SQL: retries, never repeats; rejections are never announced). */
export async function sendNotices(): Promise<{ sent: number; failed: number }> {
  const { sendMail } = await import("../mail/sendmail");
  return runNotices({
    pending: async (limit) => {
      const { data, error } = await withTimeout(admin.rpc("identity_notice_pending", { p_limit: limit }));
      if (error) {
        if (!isNotInstalled(error)) noteFailure();
        return [];
      }
      return (Array.isArray(data) ? data : []) as NoticeRow[];
    },
    send: async (m) => {
      const r = await sendMail({ from: "noreply@anexomail.com", fromName: "ANEXOMAIL", to: [m.to], subject: m.subject, text: m.text });
      return !!r.ok;
    },
    done: async (account, ok) => {
      await withTimeout(admin.rpc("identity_notice_done", { p_account: account, p_ok: ok }));
    },
  });
}

export async function reportHealth(): Promise<void> {
  const mode = Date.now() - lastClosedAt < 300_000 ? "closed" : mirror.ready ? "mirror" : "db_only";
  await withTimeout(
    admin.rpc("identity_health_report", {
      p_source: "bun",
      p_outbox: outbox.size,
      p_failures: failures.length,
      p_mirror_size: mirror.size,
      p_mirror_age: mirror.ageSeconds(),
      p_mode: mode,
    }),
  );
}

let started = false;
export function startIdentityWorkers(): void {
  if (started || process.env.IDENTITY_WORKERS === "0") return;
  started = true;
  const safe = (name: string, fn: () => Promise<unknown>) => () => void fn().catch((e) => console.error(`[identity.${name}]`, (e as Error)?.message ?? e));
  safe("sync", () => syncMirror(true))();
  setInterval(safe("sync", () => syncMirror(false)), 30_000);
  setInterval(safe("resync", () => syncMirror(true)), 3_600_000);
  setInterval(safe("outbox", drainOutbox), 30_000);
  setInterval(safe("payments", sweepPayments), 300_000);
  setInterval(safe("health", reportHealth), 60_000);
  setInterval(safe("purge", purge), 6 * 3_600_000);
  setInterval(safe("notices", sendNotices), 60_000);
  setTimeout(safe("purge", purge), 5 * 60_000);
  setTimeout(safe("health", reportHealth), 15_000);
}
