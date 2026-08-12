// ANEXOMAIL — Phase 28: Revenue Engine API (Server 2 / Brain, port 3100)
//
// NANO COMMAND (server par):
//   cp /opt/anexomail/src/routes/revenue.ts /opt/anexomail/src/routes/revenue.ts.bak.$(date +%s) 2>/dev/null
//   nano /opt/anexomail/src/routes/revenue.ts
//   # select all -> paste -> Ctrl+O, Ctrl+X
//
// 4 money roads (AI ke bina):
//   1. Core subscriptions  — revenue_accounts se asli MRR
//   2. Migration service   — revenue_jobs, £500–£2,000 one-off
//   3. White-label partner — revenue_partners, 20/25/30% recurring
//   4. Enterprise SLA      — £700/mo add-on flag
//
// Public lead endpoint: POST /api/public/revenue/lead  (koi auth nahi, rate-limited by IP)
// Founder god-view:     GET  /api/founder/revenue/overview  (Bearer required)
//
// Env locked: SUPABASE4_URL / SUPABASE4_SERVICE_ROLE_KEY (fallback SUPABASE_*).
import { Router } from "express";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";

const SUPABASE_URL = process.env.SUPABASE4_URL || process.env.SUPABASE_URL || "";
const SERVICE_KEY =
  process.env.SUPABASE4_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY || "";

let db: SupabaseClient | null = null;
if (SUPABASE_URL && SERVICE_KEY) {
  db = createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
} else {
  console.error("revenue: SUPABASE4_URL / SUPABASE4_SERVICE_ROLE_KEY missing — routes will 503");
}

const PLAN_PRICE: Record<string, number> = { basic: 20, pro: 40, business: 85 };
const SLA_PRICE = 700;

const publicRouter = Router();
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

// -------- naive in-memory IP throttle: 5 leads / 10 min per IP --------
const hits = new Map<string, number[]>();
function throttled(ip: string): boolean {
  const now = Date.now();
  const win = (hits.get(ip) || []).filter((t) => now - t < 10 * 60_000);
  if (win.length >= 5) {
    hits.set(ip, win);
    return true;
  }
  win.push(now);
  hits.set(ip, win);
  if (hits.size > 5000) hits.clear();
  return false;
}

function reference(kind: string): string {
  const p =
    kind === "migration" ? "MIG" : kind === "partner" ? "PTR" : kind === "sla" ? "SLA" : "LED";
  const n = Math.random().toString(36).slice(2, 6).toUpperCase();
  const d = new Date();
  return `${p}-${d.getUTCFullYear()}${String(d.getUTCMonth() + 1).padStart(2, "0")}-${n}`;
}

/** POST /api/public/revenue/lead — public, writes a real lead row. */
publicRouter.post("/revenue/lead", async (req: any, res) => {
  if (!db) return res.status(503).json({ error: "supabase_not_configured" });
  const ip = String(req.headers["x-forwarded-for"] || req.ip || "")
    .split(",")[0]
    .trim();
  if (throttled(ip)) return res.status(429).json({ error: "too_many_requests" });

  const b = req.body || {};
  const kind = String(b.kind || "");
  if (!["migration", "partner", "sla", "plan"].includes(kind)) {
    return res.status(400).json({ error: "bad_kind" });
  }
  const company = String(b.company || "")
    .trim()
    .slice(0, 200);
  const email = String(b.email || "")
    .trim()
    .slice(0, 200);
  if (!company || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    return res.status(400).json({ error: "company_and_valid_email_required" });
  }

  const row = {
    reference: reference(kind),
    kind,
    company,
    email,
    contact_name: b.name ? String(b.name).slice(0, 200) : null,
    domain: b.domain ? String(b.domain).slice(0, 200) : null,
    seats: Number.isFinite(Number(b.seats)) ? Math.round(Number(b.seats)) : null,
    quote_gbp: Number.isFinite(Number(b.quote_gbp)) ? Number(b.quote_gbp) : null,
    message: b.message ? String(b.message).slice(0, 2000) : null,
    detail: typeof b.detail === "object" && b.detail ? b.detail : {},
    source_ip: ip || null,
    user_agent: String(req.headers["user-agent"] || "").slice(0, 300) || null,
  };

  const { data, error } = await db
    .from("revenue_leads")
    .insert(row)
    .select("id, reference, kind, created_at")
    .single();
  if (error) return fail(res, error);

  // Migration lead = quoted job, straight into the pipeline (real row, no mock).
  if (kind === "migration" && row.quote_gbp) {
    await db.from("revenue_jobs").insert({
      lead_id: data.id,
      kind: "migration",
      company,
      amount_gbp: row.quote_gbp,
      deposit_gbp: Math.round(row.quote_gbp * 0.5),
      stage: "quoted",
    });
  }
  if (kind === "partner") {
    await db.from("revenue_partners").insert({
      company,
      email,
      tier: ["reseller", "gold", "platinum"].includes(String(b?.detail?.tier))
        ? String(b.detail.tier)
        : "reseller",
      commission_rate:
        Number(b?.detail?.rate) > 0 && Number(b?.detail?.rate) <= 0.3 ? Number(b.detail.rate) : 0.2,
      stage: "applied",
    });
  }

  return res.json(data);
});

/** GET /api/founder/revenue/overview — real MRR, streams, leads, gap maths. */
founderRouter.get("/revenue/overview", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  try {
    const month = new Date();
    month.setUTCDate(1);
    const monthStart = new Date(
      Date.UTC(month.getUTCFullYear(), month.getUTCMonth(), 1),
    ).toISOString();

    const [targetQ, accQ, jobQ, leadQ, partnerQ] = await Promise.all([
      db!
        .from("revenue_targets")
        .select("target_gbp, month")
        .order("month", { ascending: false })
        .limit(1),
      db!.from("revenue_accounts").select("plan, seats, mrr_gbp, sla_addon, status"),
      db!.from("revenue_jobs").select("amount_gbp, stage, created_at"),
      db!
        .from("revenue_leads")
        .select("id, reference, kind, company, email, quote_gbp, stage, created_at")
        .in("stage", ["new", "contacted", "quoted"])
        .order("created_at", { ascending: false })
        .limit(25),
      db!.from("revenue_partners").select("id, company, tier, live_seats, commission_rate, stage"),
    ]);

    const target = Number(targetQ.data?.[0]?.target_gbp ?? 500);
    const accounts = (accQ.data || []).filter((a: any) => a.status === "active");

    let subMrr = 0;
    let slaMrr = 0;
    let slaCount = 0;
    for (const a of accounts) {
      const price = PLAN_PRICE[String(a.plan)] ?? 0;
      subMrr +=
        Number(a.mrr_gbp) > 0 ? Number(a.mrr_gbp) : price * Math.max(1, Number(a.seats) || 1);
      if (a.sla_addon) {
        slaMrr += SLA_PRICE;
        slaCount += 1;
      }
    }

    const partners = (partnerQ.data || []).map((p: any) => ({
      id: p.id,
      company: p.company,
      tier: p.tier,
      live_seats: Number(p.live_seats) || 0,
      // Partner ka apna billing minus commission = humara net share.
      commission_gbp: Math.round(
        (Number(p.live_seats) || 0) * PLAN_PRICE.pro * Number(p.commission_rate || 0.2),
      ),
      stage: p.stage,
    }));
    const partnerSeats = partners
      .filter((p) => p.stage === "live")
      .reduce((s, p) => s + p.live_seats, 0);
    const partnerGross = partnerSeats * PLAN_PRICE.pro;
    const partnerNet = Math.round(
      partners
        .filter((p) => p.stage === "live")
        .reduce((s, p) => s + p.live_seats * PLAN_PRICE.pro * (1 - Number(0.2)), 0),
    );

    const jobsThisMonth = (jobQ.data || []).filter(
      (j: any) =>
        j.created_at >= monthStart &&
        ["booked", "running", "delivered", "invoiced", "paid"].includes(j.stage),
    );
    const oneOff = jobsThisMonth.reduce((s: number, j: any) => s + Number(j.amount_gbp || 0), 0);

    const mrr = Math.round(subMrr + slaMrr + partnerNet);
    const streams = [
      {
        stream: "Core subscriptions",
        mrr_gbp: Math.round(subMrr),
        one_off_gbp: 0,
        accounts: accounts.length,
      },
      {
        stream: "Migration service",
        mrr_gbp: 0,
        one_off_gbp: Math.round(oneOff),
        accounts: jobsThisMonth.length,
      },
      {
        stream: "White-label partners",
        mrr_gbp: partnerNet,
        one_off_gbp: 0,
        accounts: partners.filter((p) => p.stage === "live").length,
      },
      { stream: "Enterprise SLA", mrr_gbp: slaMrr, one_off_gbp: 0, accounts: slaCount },
    ];

    const remaining = Math.max(0, target - mrr);
    const seatsNeeded = Math.ceil(remaining / PLAN_PRICE.pro);

    return res.json({
      target_gbp: target,
      mrr_gbp: mrr,
      arr_gbp: mrr * 12,
      one_off_gbp: Math.round(oneOff),
      target_progress: target > 0 ? Math.min(1, mrr / target) : 0,
      streams,
      leads: (leadQ.data || []).map((l: any) => ({
        ...l,
        quote_gbp: l.quote_gbp == null ? null : Number(l.quote_gbp),
      })),
      partners,
      gap: {
        seats_needed: seatsNeeded,
        plan: "Pro (£40)",
        note:
          remaining === 0
            ? "Target already covered — next £ goes to growth, not survival."
            : `Or ${Math.ceil(remaining / PLAN_PRICE.business)} Business seats, or ${Math.ceil(remaining / SLA_PRICE)} Priority Support retainer${remaining > SLA_PRICE ? "s" : ""}. One £1,000 migration covers ${Math.floor(1000 / Math.max(1, target))} month${target <= 1000 ? "s" : ""} of the target while recurring builds. Partner gross tracked: £${partnerGross}.`,
      },
    });
  } catch (e) {
    return fail(res, e);
  }
});

export default publicRouter;
export { founderRouter as founderRevenueRouter };
