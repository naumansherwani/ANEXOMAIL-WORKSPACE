/**
 * Probation (E71) — a brand-new account (first `probation_days`, not paid, not the founder) has hard limits:
 *   send        20 recipients per message, 50 messages per day
 *   invite / public link / bulk import: closed
 * The SQL function identity_probation_take() is the single source of truth and keeps an atomic counter; this file only
 * (1) recognises which API calls count, (2) asks SQL, (3) words the refusal. Rust asks the same SQL function (export_glue.rs).
 *
 * Fail-open on purpose: if the database cannot answer, mail is NOT blocked for everyone (an outage must not lock the product).
 * The reverse never happens: this code cannot turn a "deny" from SQL into an "allow".
 */
export type ProbationKind = "send" | "invite" | "public_link" | "bulk";
export type ProbationRule = { kind: ProbationKind; recipients: number };
export type ProbationVerdict = { ok: boolean; reason?: string; limit?: number; until?: string | null };

const ADDR = /[^\s,;<>"']+@[^\s,;<>"']+/g;

/** Distinct recipient addresses across to / cc / bcc (arrays or "a@x.com, b@y.com" strings). Case-insensitive, deduplicated. */
export function countRecipients(body: unknown): number {
  const b = (body && typeof body === "object" ? body : {}) as Record<string, unknown>;
  const seen = new Set<string>();
  for (const k of ["to", "cc", "bcc"]) {
    const v = b[k];
    const parts: string[] = Array.isArray(v) ? v.map((x) => (typeof x === "string" ? x : "")) : typeof v === "string" ? [v] : [];
    for (const p of parts) for (const m of p.match(ADDR) || []) seen.add(m.toLowerCase());
  }
  return seen.size;
}

/** Which API calls are probation-relevant. `path` is the part after /api (what Express gives the gate). */
export function probationRule(method: string, path: string, body: unknown): ProbationRule | null {
  if (String(method).toUpperCase() !== "POST") return null;
  const p = String(path || "").split("?")[0]!.replace(/\/+$/, "");
  if (p === "/mail/send" || p === "/mail/schedule" || p === "/mail/outbox/send") return { kind: "send", recipients: Math.max(1, countRecipients(body)) };
  if (p === "/contacts/import" || p === "/crm/leads/import") return { kind: "bulk", recipients: 0 };
  return null;
}

/** The refusal text: tells the person what is limited and until when — never mentions fingerprints, holds or the vault. */
export function probationMessage(v: ProbationVerdict): string {
  const until = v.until ? ` These limits end on ${String(v.until).slice(0, 10)}, or as soon as you subscribe to a plan.` : " These limits end when your account is a few days old, or as soon as you subscribe to a plan.";
  switch (v.reason) {
    case "probation_recipients": return `New accounts can send to up to ${v.limit ?? 20} people per message.${until}`;
    case "probation_daily": return `New accounts can send up to ${v.limit ?? 50} messages per day. You can send more tomorrow.${until}`;
    case "probation_invites": return `Invitations are not available on a brand-new account yet.${until}`;
    case "probation_links": return `Public links are not available on a brand-new account yet.${until}`;
    case "probation_bulk": return `Bulk imports are not available on a brand-new account yet.${until}`;
    default: return `This is not available on a brand-new account yet.${until}`;
  }
}

type Rpc = (fn: string, args: Record<string, unknown>) => PromiseLike<{ data: unknown; error: { message?: string } | null }>;

/** Ask SQL. Any failure (no function yet, DB down, timeout) => ok (fail-open). A SQL "deny" is always honoured. */
export async function probationTake(account: string, rule: ProbationRule, rpc?: Rpc): Promise<ProbationVerdict> {
  try {
    const call: Rpc = rpc ?? (async (fn, args) => (await import("./supa")).admin.rpc(fn, args) as never);
    const { data, error } = await Promise.race([
      call("identity_probation_take", { p_account: account, p_kind: rule.kind, p_recipients: rule.recipients }),
      new Promise<never>((_, rej) => setTimeout(() => rej(new Error("timeout")), 3000)),
    ]);
    if (error || !data || typeof data !== "object") return { ok: true };
    const d = data as Record<string, unknown>;
    if (d.ok === false) return { ok: false, reason: String(d.reason || "probation"), limit: typeof d.limit === "number" ? d.limit : undefined, until: typeof d.until === "string" ? d.until : null };
    return { ok: true };
  } catch {
    return { ok: true };
  }
}
