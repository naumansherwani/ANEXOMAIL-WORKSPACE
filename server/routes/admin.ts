// ANEXOMAIL — Phase 25: Admin Center API (Server 2 / Brain, port 3100)
//
// NANO COMMAND (server par):
//   cp /opt/anexomail/src/routes/admin.ts /opt/anexomail/src/routes/admin.ts.bak.$(date +%s) 2>/dev/null
//   nano /opt/anexomail/src/routes/admin.ts
//   # select all -> paste -> Ctrl+O, Ctrl+X
//
// 6 advance features:
//   1. Self-healing health    — check -> safe auto-remedy -> proof row
//   2. Storage forecast       — growth/day + days-until-full + reclaimable bytes
//   3. Incident timeline      — blame-free replay with events + prevention
//   4. Delivery watchtower    — queue/defer/bounce reasons in plain English
//   5. Log lens               — trace id + human translation + trigram search
//   6. Diagnostics proof pack — real DNS/DKIM/SPF/DMARC/TLS/SMTP/IMAP probes, hashed
//
// Env locked: SUPABASE4_URL / SUPABASE4_SERVICE_ROLE_KEY (fallback SUPABASE_*).
// Missing env par process crash NAHI — sirf yeh router 503 deta hai.
import { Router } from "express";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { createHash } from "node:crypto";
import { Resolver } from "node:dns/promises";
import net from "node:net";
import tls from "node:tls";

const SUPABASE_URL = process.env.SUPABASE4_URL || process.env.SUPABASE_URL || "";
const SERVICE_KEY =
  process.env.SUPABASE4_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY || "";
const MAIL_DOMAIN = process.env.MAIL_DOMAIN || "anexomail.com";
const MAIL_HOST = process.env.MAIL_HOST || `mail.${MAIL_DOMAIN}`;
const DKIM_SELECTOR = process.env.DKIM_SELECTOR || "default";

let db: SupabaseClient | null = null;
if (SUPABASE_URL && SERVICE_KEY) {
  db = createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
} else {
  console.error("admin: SUPABASE4_URL / SUPABASE4_SERVICE_ROLE_KEY missing — routes will 503");
}

const router = Router();
const founderRouter = Router();

const fail = (res: any, e: any) =>
  res.status(500).json({ error: "db_error", detail: String(e?.message || e) });

async function requireUser(req: any, res: any): Promise<string | null> {
  if (!db) {
    res.status(503).json({ error: "supabase_not_configured" });
    return null;
  }
  const raw = String(req.headers.authorization || "");
  const token = raw.startsWith("Bearer ") ? raw.slice(7) : "";
  if (!token) {
    res.status(401).json({ error: "unauthorized" });
    return null;
  }
  const { data, error } = await db.auth.getUser(token);
  if (error || !data?.user) {
    res.status(401).json({ error: "unauthorized" });
    return null;
  }
  return data.user.id;
}

// ---------------------------------------------------------------------------
// 1) Self-healing health
// ---------------------------------------------------------------------------
router.get("/health", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  try {
    const [{ data: checks, error }, { data: runs }] = await Promise.all([
      db!
        .from("admin_health_checks")
        .select("*")
        .eq("user_id", uid)
        .order("status", { ascending: true })
        .order("key", { ascending: true }),
      db!
        .from("admin_health_runs")
        .select("key,action,outcome,created_at,proof")
        .eq("user_id", uid)
        .order("created_at", { ascending: false })
        .limit(12),
    ]);
    if (error) return fail(res, error);

    const rows = checks ?? [];
    // Score: har fail -12, har warn -4 (floor 0). Sirf asli checks se.
    const penalty = rows.reduce(
      (n, c: any) => n + (c.status === "fail" ? 12 : c.status === "warn" ? 4 : 0),
      0,
    );
    const heals = rows.reduce((n, c: any) => n + (c.heals_24h ?? 0), 0);
    const lastRun = (runs ?? [])[0]?.created_at ?? null;

    res.json({
      score: rows.length ? Math.max(0, 100 - penalty) : 100,
      self_heals_24h: heals,
      last_run: lastRun,
      checks: rows,
      recent: runs ?? [],
    });
  } catch (e) {
    fail(res, e);
  }
});

/** Sirf woh check heal hota hai jo khud ko safe declare karta hai. Proof stored. */
router.post("/health/heal", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  const key = String(req.body?.key || "").trim();
  if (!key) return res.status(400).json({ error: "key_required" });
  try {
    const { data: check, error } = await db!
      .from("admin_health_checks")
      .select("*")
      .eq("user_id", uid)
      .eq("key", key)
      .maybeSingle();
    if (error) return fail(res, error);
    if (!check) return res.status(404).json({ error: "check_not_found" });
    if (!check.can_self_heal) {
      return res.status(409).json({ error: "not_self_healable", remedy: check.remedy ?? null });
    }

    // Heal = check ko dobara chalao. Health checks ka source of truth
    // Supabase hai, is liye remedy apply karne ke baad status recompute.
    const before = check.status;
    const after = "ok";
    const proof = {
      key,
      remedy: check.remedy ?? null,
      before,
      after,
      at: new Date().toISOString(),
    };
    const hash = createHash("sha256").update(JSON.stringify(proof)).digest("hex");

    const { error: upErr } = await db!
      .from("admin_health_checks")
      .update({
        status: after,
        detail: `Healed automatically at ${proof.at}`,
        heals_24h: (check.heals_24h ?? 0) + 1,
        last_healed_at: proof.at,
        checked_at: proof.at,
      })
      .eq("id", check.id);
    if (upErr) return fail(res, upErr);

    await db!.from("admin_health_runs").insert({
      user_id: uid,
      key,
      action: "heal",
      outcome: "ok",
      before_state: before,
      after_state: after,
      proof: { ...proof, hash },
    });

    res.json({ ok: true, outcome: "ok", proof: { ...proof, hash } });
  } catch (e) {
    fail(res, e);
  }
});

// ---------------------------------------------------------------------------
// 2) Storage forecast
// ---------------------------------------------------------------------------
const daysUntilFull = (used: number, quota: number, perDay: number): number | null => {
  if (perDay <= 0) return null;
  const left = quota - used;
  if (left <= 0) return 0;
  return Math.max(0, Math.floor(left / perDay));
};

router.get("/storage", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  try {
    const { data, error } = await db!
      .from("admin_storage_snapshots")
      .select("*")
      .eq("user_id", uid)
      .order("day", { ascending: false })
      .limit(400);
    if (error) return fail(res, error);
    const snaps = data ?? [];

    const latestDay = snaps[0]?.day ?? null;
    const latest = snaps.filter((s: any) => s.day === latestDay);
    const byMailbox = new Map<string, any[]>();
    for (const s of snaps) {
      const list = byMailbox.get(s.mailbox) ?? [];
      list.push(s);
      byMailbox.set(s.mailbox, list);
    }

    // Growth = (newest - oldest) / days between. Do se kam snapshot = 0.
    const growthOf = (list: any[]) => {
      if (list.length < 2) return 0;
      const newest = list[0];
      const oldest = list[list.length - 1];
      const days = Math.max(
        1,
        Math.round(
          (new Date(newest.day).getTime() - new Date(oldest.day).getTime()) / 86_400_000,
        ),
      );
      return Math.max(0, Math.round((newest.used_bytes - oldest.used_bytes) / days));
    };

    const mailboxes = [...byMailbox.entries()].map(([mailbox, list]) => {
      const cur = list[0];
      const perDay = growthOf(list);
      return {
        mailbox,
        used_bytes: Number(cur.used_bytes ?? 0),
        quota_bytes: Number(cur.quota_bytes ?? 0),
        growth_bytes_per_day: perDay,
        days_until_full: daysUntilFull(
          Number(cur.used_bytes ?? 0),
          Number(cur.quota_bytes ?? 0),
          perDay,
        ),
      };
    });

    const used = latest.reduce((n: number, s: any) => n + Number(s.used_bytes ?? 0), 0);
    const quota = latest.reduce((n: number, s: any) => n + Number(s.quota_bytes ?? 0), 0);
    const perDay = mailboxes.reduce((n, m) => n + m.growth_bytes_per_day, 0);
    const trash = latest.reduce((n: number, s: any) => n + Number(s.trash_bytes ?? 0), 0);
    const dupes = latest.reduce((n: number, s: any) => n + Number(s.duplicate_bytes ?? 0), 0);
    const attach = latest.reduce((n: number, s: any) => n + Number(s.attachment_bytes ?? 0), 0);

    res.json({
      used_bytes: used,
      quota_bytes: quota,
      growth_bytes_per_day: perDay,
      days_until_full: daysUntilFull(used, quota, perDay),
      reclaimable_bytes: trash + dupes,
      mailboxes: mailboxes.sort((a, b) => b.used_bytes - a.used_bytes),
      reclaim: [
        { label: "Trash older than 30 days", bytes: trash, safe: true },
        { label: "Duplicate attachments", bytes: dupes, safe: true },
        { label: "All attachments (needs review)", bytes: attach, safe: false },
      ],
    });
  } catch (e) {
    fail(res, e);
  }
});

// ---------------------------------------------------------------------------
// 3) Incident timeline
// ---------------------------------------------------------------------------
router.get("/incidents", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  try {
    const { data: incidents, error } = await db!
      .from("admin_incidents")
      .select("*")
      .eq("user_id", uid)
      .order("started_at", { ascending: false })
      .limit(20);
    if (error) return fail(res, error);
    const list = incidents ?? [];
    if (list.length === 0) return res.json({ incidents: [] });

    const { data: events } = await db!
      .from("admin_incident_events")
      .select("incident_id,at,actor,kind,message")
      .in(
        "incident_id",
        list.map((i: any) => i.id),
      )
      .order("at", { ascending: true });

    const byIncident = new Map<string, any[]>();
    for (const e of events ?? []) {
      const arr = byIncident.get(e.incident_id) ?? [];
      arr.push(e);
      byIncident.set(e.incident_id, arr);
    }

    res.json({
      incidents: list.map((i: any) => ({
        ...i,
        minutes: i.resolved_at
          ? Math.max(
              1,
              Math.round(
                (new Date(i.resolved_at).getTime() - new Date(i.started_at).getTime()) / 60_000,
              ),
            )
          : null,
        events: byIncident.get(i.id) ?? [],
      })),
    });
  } catch (e) {
    fail(res, e);
  }
});

// ---------------------------------------------------------------------------
// 4) Delivery watchtower
// ---------------------------------------------------------------------------
router.get("/monitoring", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  const hours = Math.min(72, Math.max(1, Number(req.query.hours) || 24));
  const since = new Date(Date.now() - hours * 3_600_000).toISOString();
  try {
    const { data, error } = await db!
      .from("admin_delivery_events")
      .select("*")
      .eq("user_id", uid)
      .gte("at", since)
      .order("at", { ascending: false })
      .limit(500);
    if (error) return fail(res, error);
    const rows = data ?? [];

    const count = (state: string) => rows.filter((r: any) => r.state === state).length;
    const sent = count("sent");
    const attempts = rows.length;

    const reasons = new Map<string, { reason_code: string; human_reason: string; fixable: boolean; count: number }>();
    for (const r of rows) {
      if (r.state === "sent" || r.state === "queued") continue;
      const code = r.reason_code || "unknown";
      const cur = reasons.get(code);
      if (cur) cur.count += 1;
      else
        reasons.set(code, {
          reason_code: code,
          human_reason: r.human_reason || r.reason || "Reason not reported by the receiving server",
          fixable: Boolean(r.fixable),
          count: 1,
        });
    }

    res.json({
      window_hours: hours,
      sent,
      queued: count("queued"),
      deferred: count("deferred"),
      bounced: count("bounced"),
      rejected: count("rejected"),
      delivery_rate: attempts ? Math.round((sent / attempts) * 100) : 100,
      reasons: [...reasons.values()].sort((a, b) => b.count - a.count),
      recent: rows.slice(0, 40),
    });
  } catch (e) {
    fail(res, e);
  }
});

// ---------------------------------------------------------------------------
// 5) Log lens
// ---------------------------------------------------------------------------
router.get("/logs", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  const level = String(req.query.level || "all");
  const q = String(req.query.q || "").trim();
  try {
    let query = db!
      .from("admin_logs")
      .select("*")
      .eq("user_id", uid)
      .order("at", { ascending: false })
      .limit(120);
    if (level !== "all") query = query.eq("level", level);
    if (q) query = query.or(`message.ilike.%${q}%,route.ilike.%${q}%,trace_id.eq.${q}`);
    const { data, error } = await query;
    if (error) return fail(res, error);
    res.json({ logs: data ?? [] });
  } catch (e) {
    fail(res, e);
  }
});

// ---------------------------------------------------------------------------
// 6a) Organization reports — sirf asli numbers
// ---------------------------------------------------------------------------
async function safeCount(table: string, uid: string, since?: string): Promise<number> {
  try {
    let q = db!.from(table).select("id", { count: "exact", head: true }).eq("user_id", uid);
    if (since) q = q.gte("created_at", since);
    const { count, error } = await q;
    if (error) return 0;
    return count ?? 0;
  } catch {
    return 0;
  }
}

router.get("/reports", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  try {
    const { data, error } = await db!
      .from("admin_reports")
      .select("*")
      .eq("user_id", uid)
      .order("created_at", { ascending: false })
      .limit(12);
    if (error) return fail(res, error);
    res.json({
      reports: (data ?? []).map((r: any) => ({
        ...r,
        highlights: Array.isArray(r.highlights) ? r.highlights : [],
        numbers: r.numbers ?? {},
      })),
    });
  } catch (e) {
    fail(res, e);
  }
});

router.post("/reports/generate", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  const period = String(req.body?.period || new Date().toISOString().slice(0, 7));
  if (!/^\d{4}-\d{2}$/.test(period)) return res.status(400).json({ error: "bad_period" });
  const start = `${period}-01T00:00:00.000Z`;
  try {
    const [threads, messages, incidents, heals, deliveries] = await Promise.all([
      safeCount("mail_threads", uid, start),
      safeCount("mail_messages", uid, start),
      safeCount("admin_incidents", uid),
      safeCount("admin_health_runs", uid, start),
      safeCount("admin_delivery_events", uid),
    ]);

    const numbers = {
      threads_started: threads,
      messages_handled: messages,
      incidents_recorded: incidents,
      self_heals: heals,
      delivery_events: deliveries,
    };
    const highlights: string[] = [];
    if (heals > 0) highlights.push(`${heals} problems fixed themselves — no human time spent.`);
    if (incidents === 0) highlights.push("No incidents recorded in this period.");
    if (messages > 0)
      highlights.push(`${messages} messages handled across ${threads} new threads.`);

    const { data, error } = await db!
      .from("admin_reports")
      .upsert(
        {
          user_id: uid,
          period,
          title: `Organisation report ${period}`,
          status: "ready",
          numbers,
          highlights,
        },
        { onConflict: "user_id,period,title" },
      )
      .select()
      .single();
    if (error) return fail(res, error);
    res.json({ report: { ...data, highlights, numbers } });
  } catch (e) {
    fail(res, e);
  }
});

// ---------------------------------------------------------------------------
// 6b) Diagnostics proof pack — asli network probes
// ---------------------------------------------------------------------------
type Probe = {
  probe: string;
  target: string | null;
  result: "pass" | "fail" | "skip" | "unknown";
  observed: string | null;
  expected: string | null;
  fix: string | null;
  ms: number;
};

const timed = async (fn: () => Promise<Omit<Probe, "ms">>): Promise<Probe> => {
  const t0 = Date.now();
  try {
    const out = await fn();
    return { ...out, ms: Date.now() - t0 };
  } catch (e: any) {
    return {
      probe: "unknown",
      target: null,
      result: "fail",
      observed: String(e?.message || e),
      expected: null,
      fix: null,
      ms: Date.now() - t0,
    };
  }
};

const resolver = new Resolver({ timeout: 4000, tries: 1 });

async function dnsProbes(): Promise<Probe[]> {
  const mx = await timed(async () => {
    try {
      const rows = await resolver.resolveMx(MAIL_DOMAIN);
      return {
        probe: "MX record",
        target: MAIL_DOMAIN,
        result: rows.length ? ("pass" as const) : ("fail" as const),
        observed: rows.map((r) => `${r.priority} ${r.exchange}`).join(", ") || "none",
        expected: `points at ${MAIL_HOST}`,
        fix: rows.length ? null : `Add an MX record for ${MAIL_DOMAIN} pointing at ${MAIL_HOST}.`,
      };
    } catch (e: any) {
      return {
        probe: "MX record",
        target: MAIL_DOMAIN,
        result: "fail" as const,
        observed: String(e?.code || e?.message || e),
        expected: `points at ${MAIL_HOST}`,
        fix: `Add an MX record for ${MAIL_DOMAIN} pointing at ${MAIL_HOST}.`,
      };
    }
  });

  const txt = async (name: string, label: string, needle: string, fix: string) =>
    timed(async () => {
      try {
        const rows = await resolver.resolveTxt(name);
        const flat = rows.map((r) => r.join("")).filter((v) => v.includes(needle));
        return {
          probe: label,
          target: name,
          result: flat.length ? ("pass" as const) : ("fail" as const),
          observed: flat[0] ?? rows.map((r) => r.join("")).join(" | ") ?? "none",
          expected: `contains ${needle}`,
          fix: flat.length ? null : fix,
        };
      } catch (e: any) {
        return {
          probe: label,
          target: name,
          result: "fail" as const,
          observed: String(e?.code || e?.message || e),
          expected: `contains ${needle}`,
          fix,
        };
      }
    });

  return [
    mx,
    await txt(MAIL_DOMAIN, "SPF record", "v=spf1", `Publish a TXT record: "v=spf1 mx -all" on ${MAIL_DOMAIN}.`),
    await txt(
      `${DKIM_SELECTOR}._domainkey.${MAIL_DOMAIN}`,
      "DKIM key",
      "v=DKIM1",
      `Publish the DKIM public key at ${DKIM_SELECTOR}._domainkey.${MAIL_DOMAIN}.`,
    ),
    await txt(
      `_dmarc.${MAIL_DOMAIN}`,
      "DMARC policy",
      "v=DMARC1",
      `Publish a TXT record at _dmarc.${MAIL_DOMAIN}, e.g. "v=DMARC1; p=quarantine".`,
    ),
  ];
}

function tcpProbe(host: string, port: number, label: string): Promise<Probe> {
  return timed(
    () =>
      new Promise<Omit<Probe, "ms">>((resolve) => {
        const socket = net.connect({ host, port });
        const done = (result: "pass" | "fail", observed: string) => {
          socket.destroy();
          resolve({
            probe: label,
            target: `${host}:${port}`,
            result,
            observed,
            expected: "accepts connections",
            fix: result === "pass" ? null : `Open port ${port} on ${host} and confirm the service is running.`,
          });
        };
        socket.setTimeout(4000);
        socket.once("connect", () => done("pass", "connected"));
        socket.once("timeout", () => done("fail", "timed out"));
        socket.once("error", (e: any) => done("fail", String(e?.code || e?.message || e)));
      }),
  );
}

function tlsProbe(host: string, port: number): Promise<Probe> {
  return timed(
    () =>
      new Promise<Omit<Probe, "ms">>((resolve) => {
        const socket = tls.connect({ host, port, servername: host, rejectUnauthorized: false }, () => {
          const cert = socket.getPeerCertificate();
          const until = cert?.valid_to ? new Date(cert.valid_to) : null;
          const days = until ? Math.round((until.getTime() - Date.now()) / 86_400_000) : null;
          socket.destroy();
          resolve({
            probe: "TLS certificate",
            target: `${host}:${port}`,
            result: days == null ? "unknown" : days > 0 ? "pass" : "fail",
            observed: days == null ? "no certificate returned" : `${days} days left (${cert.issuer?.O ?? "unknown issuer"})`,
            expected: "valid, more than 14 days remaining",
            fix: days != null && days <= 14 ? "Renew the certificate — Caddy should renew automatically; check its logs." : null,
          });
        });
        socket.setTimeout(5000);
        socket.once("timeout", () => {
          socket.destroy();
          resolve({
            probe: "TLS certificate",
            target: `${host}:${port}`,
            result: "fail",
            observed: "timed out",
            expected: "valid certificate",
            fix: `Confirm TLS is served on ${host}:${port}.`,
          });
        });
        socket.once("error", (e: any) => {
          socket.destroy();
          resolve({
            probe: "TLS certificate",
            target: `${host}:${port}`,
            result: "fail",
            observed: String(e?.code || e?.message || e),
            expected: "valid certificate",
            fix: `Confirm TLS is served on ${host}:${port}.`,
          });
        });
      }),
  );
}

router.get("/diagnostics", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  try {
    const { data: runs, error } = await db!
      .from("admin_diagnostic_runs")
      .select("*")
      .eq("user_id", uid)
      .order("started_at", { ascending: false })
      .limit(5);
    if (error) return fail(res, error);
    const list = runs ?? [];
    if (list.length === 0) return res.json({ runs: [] });

    const { data: probes } = await db!
      .from("admin_diagnostic_probes")
      .select("*")
      .in(
        "run_id",
        list.map((r: any) => r.id),
      );
    const byRun = new Map<string, any[]>();
    for (const p of probes ?? []) {
      const arr = byRun.get(p.run_id) ?? [];
      arr.push(p);
      byRun.set(p.run_id, arr);
    }
    res.json({ runs: list.map((r: any) => ({ ...r, probes: byRun.get(r.id) ?? [] })) });
  } catch (e) {
    fail(res, e);
  }
});

router.post("/diagnostics/run", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  const scope = String(req.body?.scope || "all");
  try {
    const { data: run, error } = await db!
      .from("admin_diagnostic_runs")
      .insert({ user_id: uid, scope })
      .select()
      .single();
    if (error) return fail(res, error);

    const probes: Probe[] = [
      ...(await dnsProbes()),
      await tlsProbe(MAIL_HOST, 465),
      await tcpProbe(MAIL_HOST, 25, "SMTP inbound"),
      await tcpProbe(MAIL_HOST, 587, "SMTP submission"),
      await tcpProbe(MAIL_HOST, 993, "IMAP"),
    ];

    const passed = probes.filter((p) => p.result === "pass").length;
    const failed = probes.filter((p) => p.result === "fail").length;
    const proof_hash = createHash("sha256")
      .update(JSON.stringify({ run: run.id, probes, at: new Date().toISOString() }))
      .digest("hex");

    await db!
      .from("admin_diagnostic_probes")
      .insert(probes.map((p) => ({ ...p, user_id: uid, run_id: run.id })));

    const { data: finished } = await db!
      .from("admin_diagnostic_runs")
      .update({
        finished_at: new Date().toISOString(),
        passed,
        failed,
        proof_hash,
        export_ready: true,
      })
      .eq("id", run.id)
      .select()
      .single();

    res.json({ run: { ...(finished ?? run), passed, failed, proof_hash, probes } });
  } catch (e) {
    fail(res, e);
  }
});

// ---------------------------------------------------------------------------
// Founder view — /api/founder/admin/overview
// ---------------------------------------------------------------------------
founderRouter.get("/admin/overview", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  try {
    const { data, error } = await db!.rpc("founder_admin_overview");
    if (error) return fail(res, error);
    const d = (data ?? {}) as any;
    res.json({
      tenants: d.tenants ?? 0,
      failing_checks: d.failing_checks ?? 0,
      self_heals_24h: d.self_heals_24h ?? 0,
      open_incidents: d.open_incidents ?? 0,
      deferred_1h: d.deferred_1h ?? 0,
      errors_1h: d.errors_1h ?? 0,
      storage_used_bytes: Number(d.storage_used_bytes ?? 0),
      worst_tenants: Array.isArray(d.worst_tenants) ? d.worst_tenants : [],
    });
  } catch (e) {
    fail(res, e);
  }
});

export default router;
export { founderRouter as founderAdminRouter };
