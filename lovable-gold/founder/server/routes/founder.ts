import { Router } from "express";
import { admin } from "../lib/supa";

export const founder = Router();

/* ------------------------------------------------------------ founder gate */
const FOUNDER_EMAILS = (process.env.FOUNDER_EMAILS ||
  "naumansherwani.founder@anexomail.com,naumansherwani.founder@nexatect.com")
  .split(",")
  .map((s) => s.trim().toLowerCase())
  .filter(Boolean);

async function ctx(req: any) {
  const h = String(req.headers["authorization"] || "");
  const token = h.startsWith("Bearer ") ? h.slice(7) : "";
  if (!token) return { user: null as any, isFounder: false };
  const { data } = await admin.auth.getUser(token);
  const user = data?.user || null;
  if (!user) return { user: null as any, isFounder: false };

  const email = String(user.email || "").toLowerCase();
  let isFounder = FOUNDER_EMAILS.includes(email);
  if (!isFounder) {
    try {
      const r = await admin.from("founder_accounts").select("user_id").eq("user_id", user.id).limit(1);
      isFounder = Boolean(r.data?.length);
    } catch {}
  }
  return { user, isFounder };
}

/** founder-only guard: 401 without a session, 403 for non-founders. */
function guard(handler: (req: any, res: any, c: any) => Promise<any>) {
  return async (req: any, res: any) => {
    try {
      const c = await ctx(req);
      if (!c.user) return res.status(401).json({ error: "unauthorized" });
      if (!c.isFounder) return res.status(403).json({ error: "founder_only" });
      return await handler(req, res, c);
    } catch (e: any) {
      console.error("[founder]", e?.message || e);
      return res.status(500).json({ error: "founder_failed" });
    }
  };
}

/** read that never explodes when a table/column is absent */
async function safe<T>(fn: () => Promise<{ data: any; error: any }>, fallback: T): Promise<T> {
  try {
    const { data, error } = await fn();
    if (error) return fallback;
    return (data as T) ?? fallback;
  } catch {
    return fallback;
  }
}

const WORKSPACE_HOST = process.env.FOUNDER_WORKSPACE_HOST || "founderworkspace.anexomail.com";

type MailboxRow = {
  address: string;
  display_name: string | null;
  kind: string | null;
  domain: string | null;
  provisioned: boolean | null;
  agent: string | null;
  aliases: string[] | null;
};

async function mailboxRows(): Promise<MailboxRow[]> {
  return safe<MailboxRow[]>(
    () =>
      admin
        .from("mailboxes")
        .select("address, display_name, kind, domain, provisioned, agent, aliases")
        .order("kind", { ascending: true })
        .order("address", { ascending: true }),
    [],
  );
}

async function domainRows(): Promise<Record<string, boolean>> {
  const rows = await safe<any[]>(
    () => admin.from("mail_domains").select("domain, spf_ok, dkim_ok, dmarc_ok"),
    [],
  );
  const map: Record<string, boolean> = {};
  for (const r of rows) {
    map[String(r.domain)] = Boolean(r.spf_ok) && Boolean(r.dkim_ok) && Boolean(r.dmarc_ok);
  }
  return map;
}

/** message counts per address — one read, aggregated in memory (column-name tolerant) */
async function messageStats(): Promise<Record<string, { total: number; last: string | null }>> {
  const shapes = [
    "to_address, created_at",
    "recipient, created_at",
    "to_addr, created_at",
    "mailbox, created_at",
  ];
  let rows: any[] = [];
  for (const cols of shapes) {
    rows = await safe<any[]>(
      () => admin.from("mail_messages").select(cols).order("created_at", { ascending: false }).limit(5000),
      [],
    );
    if (rows.length) break;
  }
  const out: Record<string, { total: number; last: string | null }> = {};
  for (const r of rows) {
    const addr = String(r.to_address ?? r.recipient ?? r.to_addr ?? r.mailbox ?? "").toLowerCase();
    if (!addr) continue;
    const at = r.created_at ? String(r.created_at) : null;
    const cur = out[addr] || { total: 0, last: null };
    cur.total += 1;
    if (at && (!cur.last || at > cur.last)) cur.last = at;
    out[addr] = cur;
  }
  return out;
}

async function draftRows(): Promise<any[]> {
  return safe<any[]>(
    () =>
      admin
        .from("leo_email_drafts")
        .select("id, agent, from_address, to_address, subject, body, confidence, state, escalated_to, created_at")
        .order("created_at", { ascending: false })
        .limit(200),
    [],
  );
}

/* --------------------------------------------------------------- overview */
founder.get(
  "/founder/overview",
  guard(async (_req, res) => {
    const [boxes, dns] = await Promise.all([mailboxRows(), domainRows()]);

    const byDomain = new Map<string, number>();
    for (const b of boxes) {
      const d = String(b.domain || "anexomail.com");
      byDomain.set(d, (byDomain.get(d) || 0) + 1);
    }

    return res.json({
      founder_addresses: boxes.filter((b) => b.kind === "founder").map((b) => b.address),
      domains: [...byDomain.entries()].map(([domain, mailboxes]) => ({
        domain,
        dns_ok: dns[domain] === true,
        mailboxes,
      })),
      workspace_host: WORKSPACE_HOST,
      mailboxes_total: boxes.length,
      mailboxes_provisioned: boxes.filter((b) => b.provisioned === true).length,
    });
  }),
);

/* -------------------------------------------------------------- mailboxes */
founder.get(
  "/founder/mailboxes",
  guard(async (_req, res) => {
    const [boxes, dns, stats] = await Promise.all([mailboxRows(), domainRows(), messageStats()]);

    return res.json({
      mailboxes: boxes.map((b) => {
        const domain = String(b.domain || "anexomail.com");
        const s = stats[b.address.toLowerCase()] || { total: 0, last: null };
        const kind = ["founder", "agent", "industry", "support", "system"].includes(String(b.kind))
          ? String(b.kind)
          : "founder";
        return {
          address: b.address,
          display_name: b.display_name ?? null,
          kind,
          domain,
          provisioned: b.provisioned === true,
          dns_ok: dns[domain] === true,
          agent: b.agent ?? null,
          aliases: Array.isArray(b.aliases) ? b.aliases : [],
          messages_total: s.total,
          last_message_at: s.last,
        };
      }),
    });
  }),
);

/* -------------------------------------------------------------- ai agents */
founder.get(
  "/founder/ai-agents",
  guard(async (_req, res) => {
    const [agents, boxes, drafts] = await Promise.all([
      safe<any[]>(
        () => admin.from("ai_agents").select("id, name, role, address, reports_to, model, status").order("name"),
        [],
      ),
      mailboxRows(),
      draftRows(),
    ]);

    const provisioned = new Set(
      boxes.filter((b) => b.provisioned === true).map((b) => b.address.toLowerCase()),
    );

    const agg = new Map<string, { pending: number; sent: number; esc: number; secs: number[] }>();
    for (const d of drafts) {
      const key = String(d.agent || "Leo");
      const cur = agg.get(key) || { pending: 0, sent: 0, esc: 0, secs: [] as number[] };
      if (d.state === "draft" || d.state === "held") cur.pending += 1;
      if (d.state === "sent") cur.sent += 1;
      if (d.state === "escalated") cur.esc += 1;
      agg.set(key, cur);
    }

    return res.json({
      agents: agents.map((a) => {
        const st = agg.get(String(a.name)) || { pending: 0, sent: 0, esc: 0, secs: [] as number[] };
        const live = provisioned.has(String(a.address).toLowerCase());
        return {
          id: String(a.id),
          name: String(a.name),
          role: String(a.role || ""),
          address: String(a.address),
          reports_to: a.reports_to ?? null,
          status: live ? "live" : a.status === "offline" ? "offline" : "provisioning",
          model: a.model ?? null,
          drafts_pending: st.pending,
          replies_sent: st.sent,
          avg_reply_seconds: null,
          escalations: st.esc,
        };
      }),
    });
  }),
);

/* ---------------------------------------------------------------- ai mail */
founder.get(
  "/founder/ai-mail",
  guard(async (req, res) => {
    const want = String(req.query.state || "all");
    const rows = await draftRows();
    const filtered = want === "all" ? rows : rows.filter((r) => String(r.state) === want);

    return res.json({
      items: filtered.map((r) => ({
        id: String(r.id),
        agent: String(r.agent || "Leo"),
        from_address: String(r.from_address || ""),
        to_address: String(r.to_address || ""),
        subject: String(r.subject || ""),
        preview: String(r.body || "").replace(/\s+/g, " ").slice(0, 220),
        confidence: r.confidence === null || r.confidence === undefined ? null : Number(r.confidence),
        state: ["draft", "sent", "escalated", "held"].includes(String(r.state)) ? String(r.state) : "draft",
        escalated_to: r.escalated_to ?? null,
        created_at: String(r.created_at),
      })),
    });
  }),
);

/* ------------------------------------------------------------- provisioning */
founder.post(
  "/founder/mailboxes/provision",
  guard(async (req, res) => {
    const wanted: string[] = Array.isArray(req.body?.addresses)
      ? req.body.addresses.map((a: any) => String(a).toLowerCase().trim()).filter(Boolean)
      : [];

    const boxes = await mailboxRows();
    const targets = wanted.length
      ? boxes.filter((b) => wanted.includes(b.address.toLowerCase()))
      : boxes.filter((b) => b.provisioned !== true);

    if (!targets.length) return res.json({ created: [] });

    const { error } = await admin
      .from("mailboxes")
      .update({ provision_requested_at: new Date().toISOString() })
      .in(
        "address",
        targets.map((t) => t.address),
      );
    if (error) return res.status(500).json({ error: "provision_request_failed" });

    // Postfix/Dovecot creation is done by the mail sync job; `provisioned`
    // flips to true only when the mailbox really exists on the server.
    return res.json({ created: targets.map((t) => t.address) });
  }),
);

/* ------------------------------------------------------------ draft approve */
founder.post(
  "/founder/ai-mail/approve",
  guard(async (req, res, c) => {
    const id = String(req.body?.id || "");
    if (!id) return res.status(400).json({ error: "id_required" });

    const rows = await safe<any[]>(
      () =>
        admin
          .from("leo_email_drafts")
          .select("id, from_address, to_address, subject, body, state")
          .eq("id", id)
          .limit(1),
      [],
    );
    const draft = rows[0];
    if (!draft) return res.status(404).json({ error: "draft_not_found" });
    if (draft.state === "sent") return res.json({ sent: true });

    const queued = await admin.from("mail_outbox").insert({
      from_address: draft.from_address,
      to_address: draft.to_address,
      subject: draft.subject,
      body: draft.body,
      source: "leo_email_drafts",
      source_id: draft.id,
      state: "queued",
    });
    if (queued.error) return res.status(500).json({ error: "queue_failed" });

    await admin
      .from("leo_email_drafts")
      .update({ state: "sent", approved_at: new Date().toISOString(), approved_by: c.user.id })
      .eq("id", id);

    return res.json({ sent: true });
  }),
);
