/**
 * ANEXOMAIL — Phase 7/8: Mail Core + LEO delivery pipeline
 * Source of truth: Supabase 4 (mail_threads / mail_messages / mail_labels /
 * mail_attachments). Postfix delivery hook DB mein sync karta hai.
 * Real data only — koi mock nahi.
 */
import { Router } from "express";
import nodemailer from "nodemailer";
import { admin as supa } from "../lib/supa";
import { leoSupportPipeline } from "../lib/leo-brain";

export const mailRouter = Router();

type Ctx = { userId: string; orgId: string };

async function ctx(req: any, res: any): Promise<Ctx | null> {
  const bearer = (req.headers.authorization || "").replace(/^Bearer\s+/i, "");
  const token = bearer || req.cookies?.ax_session || "";
  if (!token) { res.status(401).json({ error: "unauthenticated" }); return null; }
  const { data, error } = await supa.auth.getUser(token);
  if (error || !data?.user) { res.status(401).json({ error: "unauthenticated" }); return null; }
  const userId = data.user.id;
  const requested = (req.header("x-org-id") || req.query.org_id || "") as string;
  const { data: rows } = await supa.from("org_members").select("org_id").eq("user_id", userId);
  const ids = (rows || []).map((r: any) => r.org_id);
  if (!ids.length) { res.status(409).json({ error: "no_workspace" }); return null; }
  const orgId = requested && ids.includes(requested) ? requested : ids[0];
  return { userId, orgId };
}

const list = (v: any): string[] =>
  Array.isArray(v) ? v.filter(Boolean)
  : typeof v === "string" ? v.split(",").map((s) => s.trim()).filter(Boolean)
  : [];

async function labelsFor(threadIds: string[]) {
  const map = new Map<string, string[]>();
  if (!threadIds.length) return map;
  const { data } = await supa
    .from("mail_thread_labels")
    .select("thread_id, mail_labels(id,name)")
    .in("thread_id", threadIds);
  for (const row of (data || []) as any[]) {
    const arr = map.get(row.thread_id) || [];
    if (row.mail_labels?.name) arr.push(row.mail_labels.name);
    map.set(row.thread_id, arr);
  }
  return map;
}

function threadItem(t: any, labels: string[]) {
  return {
    id: t.id,
    subject: t.subject || "",
    snippet: t.snippet ?? null,
    from_name: t.from_name ?? null,
    from_address: t.from_address || "",
    account_id: t.account_id ?? null,
    account_address: t.mail_accounts?.address ?? null,
    message_count: t.message_count ?? 0,
    unread: !!t.unread,
    starred: !!t.starred,
    has_attachments: !!t.has_attachments,
    status: t.status || "open",
    assignee: t.assignee ?? null,
    labels,
    category: t.category ?? null,
    snoozed_until: t.snoozed_until ?? null,
    last_message_at: t.last_message_at || t.created_at,
  };
}

async function queryThreads(c: Ctx, req: any) {
  const folder = String(req.query.folder || "inbox");
  const account = req.query.account ? String(req.query.account) : null;
  const category = req.query.category ? String(req.query.category) : null;
  const label = req.query.label ? String(req.query.label) : null;
  const q = req.query.q ? String(req.query.q).trim() : "";

  let threadIds: string[] | null = null;
  if (label) {
    const { data: lab } = await supa
      .from("mail_labels").select("id").eq("org_id", c.orgId)
      .or(`id.eq.${label},name.eq.${label}`).limit(1).maybeSingle();
    const { data: links } = await supa
      .from("mail_thread_labels").select("thread_id").eq("label_id", lab?.id || label);
    threadIds = (links || []).map((r: any) => r.thread_id);
    if (!threadIds.length) return { threads: [] };
  }

  let sel = supa
    .from("mail_threads")
    .select("*, mail_accounts(address)")
    .eq("org_id", c.orgId)
    .eq("folder", folder)
    .order("last_message_at", { ascending: false })
    .limit(100);

  if (account) sel = sel.eq("account_id", account);
  if (category) sel = sel.eq("category", category);
  if (threadIds) sel = sel.in("id", threadIds);
  if (q) sel = sel.or(`subject.ilike.%${q}%,snippet.ilike.%${q}%,from_address.ilike.%${q}%`);

  const { data, error } = await sel;
  if (error) throw error;
  const rows = (data || []) as any[];
  const lmap = await labelsFor(rows.map((r) => r.id));
  return { threads: rows.map((r) => threadItem(r, lmap.get(r.id) || [])) };
}

mailRouter.get("/threads", async (req, res) => {
  const c = await ctx(req, res); if (!c) return;
  try { res.json(await queryThreads(c, req)); }
  catch (e: any) { res.status(500).json({ error: e.message }); }
});

mailRouter.get("/search", async (req, res) => {
  const c = await ctx(req, res); if (!c) return;
  try { res.json(await queryThreads(c, req)); }
  catch (e: any) { res.status(500).json({ error: e.message }); }
});

mailRouter.get("/accounts", async (req, res) => {
  const c = await ctx(req, res); if (!c) return;
  const { data, error } = await supa
    .from("mailboxes").select("id,address,kind").eq("org_id", c.orgId).order("address");
  if (error) return res.status(500).json({ error: error.message });
  res.json({ accounts: data || [] });
});

mailRouter.get("/labels", async (req, res) => {
  const c = await ctx(req, res); if (!c) return;
  const { data, error } = await supa
    .from("mail_labels").select("id,name,colour").eq("org_id", c.orgId).order("name");
  if (error) return res.status(500).json({ error: error.message });
  res.json({ labels: data || [] });
});

mailRouter.get("/thread/:id", async (req, res) => {
  const c = await ctx(req, res); if (!c) return;
  const { data: t, error } = await supa
    .from("mail_threads").select("*, mail_accounts(address)")
    .eq("org_id", c.orgId).eq("id", req.params.id).maybeSingle();
  if (error) return res.status(500).json({ error: error.message });
  if (!t) return res.status(404).json({ error: "not_found" });

  const { data: msgs } = await supa
    .from("mail_messages")
    .select("*, mail_attachments(id,filename,mime_type,size_bytes,storage_path)")
    .eq("thread_id", t.id).order("sent_at", { ascending: true });

  const lmap = await labelsFor([t.id]);
  if (t.unread) await supa.from("mail_threads").update({ unread: false }).eq("id", t.id);

  res.json({
    id: t.id,
    subject: t.subject || "",
    status: t.status || "open",
    assignee: t.assignee ?? null,
    labels: lmap.get(t.id) || [],
    snoozed_until: t.snoozed_until ?? null,
    account_address: (t as any).mail_accounts?.address ?? null,
    messages: ((msgs || []) as any[]).map((m) => ({
      id: m.id,
      direction: m.direction,
      from_name: m.from_name ?? null,
      from_address: m.from_address,
      to: list(m.to_addrs),
      cc: list(m.cc_addrs),
      subject: m.subject ?? null,
      body_text: m.body_text ?? null,
      body_html: m.body_html ?? null,
      sent_at: m.sent_at,
      scheduled_at: m.scheduled_at ?? null,
      attachments: (m.mail_attachments || []).map((a: any) => ({
        id: a.id, filename: a.filename, mime_type: a.mime_type,
        size_bytes: a.size_bytes ?? 0, url: a.storage_path ?? null,
      })),
    })),
  });
});

const smtp = nodemailer.createTransport({
  host: process.env.SMTP_HOST || "127.0.0.1",
  port: Number(process.env.SMTP_PORT || 25),
  secure: false,
  tls: { rejectUnauthorized: false },
});

mailRouter.post("/send", async (req, res) => {
  const c = await ctx(req, res); if (!c) return;
  const b = req.body || {};
  const to = list(b.to), cc = list(b.cc), bcc = list(b.bcc);
  if (!to.length) return res.status(400).json({ error: "to_required" });

  const { data: acc } = await supa
    .from("mailboxes").select("id,address").eq("org_id", c.orgId).order("address").limit(1).maybeSingle();
  if (!acc) return res.status(409).json({ error: "no_mail_account" });

  const scheduled = b.send_at ? new Date(b.send_at) : null;
  const now = new Date();
  const isScheduled = !!scheduled && scheduled.getTime() > now.getTime();

  let threadId: string | null = b.thread_id || null;
  if (!threadId) {
    const { data: t, error } = await supa.from("mail_threads").insert({
      org_id: c.orgId, account_id: acc.id, subject: b.subject || "(no subject)",
      snippet: String(b.body || "").slice(0, 180), from_name: null, from_address: acc.address,
      folder: "sent", status: "open", unread: false, message_count: 0,
      last_message_at: (scheduled || now).toISOString(),
    }).select("id").single();
    if (error) return res.status(500).json({ error: error.message });
    threadId = t.id;
  }

  const { data: msg, error: mErr } = await supa.from("mail_messages").insert({
    org_id: c.orgId, thread_id: threadId, direction: "out",
    from_address: acc.address, to_addrs: to, cc_addrs: cc, bcc_addrs: bcc,
    subject: b.subject || null, body_text: b.body || null,
    sent_at: (scheduled || now).toISOString(),
    scheduled_at: isScheduled ? scheduled!.toISOString() : null,
  }).select("id").single();
  if (mErr) return res.status(500).json({ error: mErr.message });

  if (isScheduled) return res.json({ ok: true, scheduled_at: scheduled!.toISOString(), thread_id: threadId, message_id: msg.id });

  try {
    await smtp.sendMail({
      from: acc.address, to, cc, bcc,
      subject: b.subject || "(no subject)", text: b.body || "",
    });
  } catch (e: any) {
    return res.status(502).json({ error: "smtp_failed", detail: e.message });
  }
  res.json({ ok: true, thread_id: threadId, message_id: msg.id });
});

async function ownThread(c: Ctx, id: string) {
  const { data } = await supa.from("mail_threads").select("id").eq("org_id", c.orgId).eq("id", id).maybeSingle();
  return !!data;
}

mailRouter.post("/thread/:id/status", async (req, res) => {
  const c = await ctx(req, res); if (!c) return;
  if (!(await ownThread(c, req.params.id))) return res.status(404).json({ error: "not_found" });
  const { error } = await supa.from("mail_threads").update({ status: req.body?.status }).eq("id", req.params.id);
  if (error) return res.status(400).json({ error: error.message });
  res.json({ ok: true });
});

mailRouter.post("/thread/:id/snooze", async (req, res) => {
  const c = await ctx(req, res); if (!c) return;
  if (!(await ownThread(c, req.params.id))) return res.status(404).json({ error: "not_found" });
  const until = req.body?.until ? new Date(req.body.until).toISOString() : null;
  const patch: any = { snoozed_until: until };
  if (until) patch.folder = "snoozed";
  const { error } = await supa.from("mail_threads").update(patch).eq("id", req.params.id);
  if (error) return res.status(400).json({ error: error.message });
  res.json({ ok: true });
});

mailRouter.post("/thread/:id/move", async (req, res) => {
  const c = await ctx(req, res); if (!c) return;
  if (!(await ownThread(c, req.params.id))) return res.status(404).json({ error: "not_found" });
  const { error } = await supa.from("mail_threads").update({ folder: req.body?.folder }).eq("id", req.params.id);
  if (error) return res.status(400).json({ error: error.message });
  res.json({ ok: true });
});

mailRouter.post("/thread/:id/labels", async (req, res) => {
  const c = await ctx(req, res); if (!c) return;
  if (!(await ownThread(c, req.params.id))) return res.status(404).json({ error: "not_found" });
  const add = list(req.body?.add), remove = list(req.body?.remove);

  for (const name of add) {
    let { data: lab } = await supa.from("mail_labels").select("id")
      .eq("org_id", c.orgId).or(`id.eq.${name},name.eq.${name}`).limit(1).maybeSingle();
    if (!lab) {
      const { data: created } = await supa.from("mail_labels")
        .insert({ org_id: c.orgId, name }).select("id").single();
      lab = created as any;
    }
    if (lab) await supa.from("mail_thread_labels")
      .upsert({ thread_id: req.params.id, label_id: lab.id }, { onConflict: "thread_id,label_id" });
  }
  for (const name of remove) {
    const { data: lab } = await supa.from("mail_labels").select("id")
      .eq("org_id", c.orgId).or(`id.eq.${name},name.eq.${name}`).limit(1).maybeSingle();
    if (lab) await supa.from("mail_thread_labels").delete()
      .eq("thread_id", req.params.id).eq("label_id", lab.id);
  }
  res.json({ ok: true });
});

/** Postfix delivery hook — incoming mail -> Supabase -> LEO pipeline. */
mailRouter.post("/deliver", async (req, res) => {
  const secret = process.env.MAIL_HOOK_SECRET || "";
  if (!secret || req.header("x-mail-hook-secret") !== secret)
    return res.status(401).json({ error: "unauthorized" });

  const b = req.body || {};
  const rcpt = String(b.to || "").toLowerCase();
  if (!rcpt) return res.status(400).json({ error: "to_required" });

  const { data: acc } = await supa.from("mailboxes")
    .select("*").eq("address", rcpt).maybeSingle();
  if (!acc) return res.status(404).json({ error: "unknown_recipient" });

  const subject = b.subject || "(no subject)";
  const from = String(b.from || "").toLowerCase();
  const now = new Date().toISOString();

  let threadId: string | null = null;
  if (b.in_reply_to) {
    const { data: prev } = await supa.from("mail_messages")
      .select("thread_id").eq("message_id_header", b.in_reply_to).maybeSingle();
    threadId = prev?.thread_id ?? null;
  }
  if (!threadId) {
    const { data: t, error } = await supa.from("mail_threads").insert({
      org_id: acc.org_id ?? "dbd5aef3-8d6d-415f-9b5b-8d32f0adce3a", account_id: acc.id, subject,
      snippet: String(b.text || "").slice(0, 180),
      from_name: b.from_name ?? null, from_address: from,
      folder: "inbox", status: "open", unread: true, message_count: 0,
      category: "primary", last_message_at: now,
    }).select("id").single();
    if (error) return res.status(500).json({ error: error.message });
    threadId = t.id;
  } else {
    await supa.from("mail_threads")
      .update({ unread: true, folder: "inbox", last_message_at: now, snippet: String(b.text || "").slice(0, 180) })
      .eq("id", threadId);
  }

  const { data: inserted, error: mErr } = await supa.from("mail_messages").insert({
    org_id: acc.org_id ?? "dbd5aef3-8d6d-415f-9b5b-8d32f0adce3a", thread_id: threadId, direction: "in",
    from_name: b.from_name ?? null, from_address: from,
    to_addresses: [rcpt], cc_addresses: list(b.cc),
    subject, body_text: b.text ?? null, body_html: b.html ?? null,
    message_id: b.message_id ?? null, sent_at: b.date || now,
  }).select("id").single();
  if (mErr) return res.status(500).json({ error: mErr.message });

  // ---- LEO pipeline (no tickets, no queue). Never blocks delivery. ----
  let leo: any = { ran: false };
  try {
    const autoReply = acc.auto_reply !== false;
    const isBot = /auto-(generated|replied|submitted)/i.test(String(b.auto_submitted || b.headers?.["auto-submitted"] || ""))
      || /(mailer-daemon|no-?reply|postmaster)@/i.test(from);
    if (autoReply && !isBot && from && from !== rcpt) {
      leo = await leoSupportPipeline({
        orgId: acc.org_id,
        account: acc,
        threadId,
        messageId: inserted.id,
        from,
        fromName: b.from_name ?? null,
        to: rcpt,
        subject,
        text: b.text ?? "",
        html: b.html ?? null,
      });
      leo = { ran: true, ...(leo || {}) };
    } else {
      leo = { ran: false, reason: isBot ? "loop_guard" : "auto_reply_off" };
    }
  } catch (e: any) {
    leo = { ran: false, error: e?.message || String(e) };
    console.error("[leo] pipeline failed:", e);
  }

  res.json({ ok: true, thread_id: threadId, message_id: inserted.id, leo });
});
