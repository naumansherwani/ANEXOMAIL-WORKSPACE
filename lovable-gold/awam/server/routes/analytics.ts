/**
 * Analytics Center — Bun FALLBACK (/api/analytics/*, /api/founder/analytics/overview).
 * Rust (analytics_glue.rs, `/rpc/analytics.*`) PRIMARY hai; yeh route tab chalta hai jab Rust 404/501/502/503 de.
 * Package gate yahan bhi SERVER par (lib/analytics-gate.ts). Hisaab SQL E89 ke service_role-only functions mein.
 */
import { Router } from "express";
import { admin } from "../lib/supa";
import { resolvePlan } from "../lib/plan";
import { isFounderEmail, parseFounderEmails } from "../lib/org-authz";
import { ANALYTICS_NEED, analyticsDenial, canSeeTeam, cleanAddresses, cleanTz } from "../lib/analytics-gate";

export const analyticsRouter = Router();
export const founderAnalyticsRouter = Router();

const FOUNDERS = parseFounderEmails(
  process.env.FOUNDER_EMAILS,
  "naumansherwani.founder@anexomail.com,naumansherwani.founder@nexatect.com",
);

const hits = new Map<string, number[]>();
function allowed(user: string): boolean {
  const now = Date.now();
  const q = (hits.get(user) || []).filter((t) => now - t < 60_000);
  if (q.length >= 30) { hits.set(user, q); return false; }
  q.push(now); hits.set(user, q);
  if (hits.size > 5000) for (const [k, v] of hits) if (!v.some((t) => now - t < 60_000)) hits.delete(k);
  return true;
}

async function who(req: any) {
  const h = String(req.headers["authorization"] || "");
  const token = h.startsWith("Bearer ") ? h.slice(7) : "";
  if (!token) return null;
  const { data } = await admin.auth.getUser(token);
  const user = data?.user;
  return user ? { id: user.id, email: String(user.email || "").toLowerCase() } : null;
}

function sqlError(res: any, e: any) {
  const m = String(e?.message || e?.code || e || "");
  if (/PGRST202|Could not find the function|42883/.test(m)) return res.status(501).json({ error: "analytics_sql_missing" });
  console.error("[analytics]", m);
  return res.status(500).json({ error: "db_error" });
}

analyticsRouter.get("/analytics/:report", async (req, res) => {
  try {
    const report = String(req.params.report);
    const need = ANALYTICS_NEED[report];
    if (!need) return res.status(404).json({ error: "unknown_report" });
    const me = await who(req);
    if (!me) return res.status(401).json({ error: "unauthorized" });
    const plan = await resolvePlan(me.id, me.email);
    const denial = analyticsDenial(need, plan);
    if (denial) return res.status(403).json({ error: { code: "feature_not_available", message: denial } });
    if (!allowed(me.id)) return res.status(429).json({ error: "too_many_requests" });

    const m = await admin.from("org_members").select("org_id,role").eq("user_id", me.id).limit(1).maybeSingle();
    const org = (m.data as any)?.org_id as string | undefined;
    if (!org) return res.status(501).json({ error: "not_implemented_for_account" });

    let out: { data: any; error: any };
    if (report === "team") {
      if (!canSeeTeam((m.data as any)?.role)) return res.status(403).json({ error: { code: "owner_or_admin_only", message: "The team report is for workspace owners and admins." } });
      out = await admin.rpc("analytics_team", { p_user: me.id, p_org: org });
    } else if (report === "promise-sla") {
      out = await admin.rpc("analytics_promise_sla", { p_user: me.id, p_org: org, p_email: me.email });
    } else {
      const rows: string[] = [];
      for (const t of ["mailboxes", "mail_accounts"]) {
        const r = await admin.from(t).select("address").eq("org_id", org).limit(500);
        for (const x of (r.data as any[]) || []) if (x?.address) rows.push(String(x.address));
      }
      const addrs = cleanAddresses(rows, me.email);
      const fn = ({
        "response-debt": "analytics_response_debt",
        "thread-economics": "analytics_thread_economics",
        "deep-work": "analytics_deep_work",
        "attention-leaks": "analytics_attention_leaks",
        forecast: "analytics_forecast",
      } as Record<string, string>)[report]!;
      const args: Record<string, unknown> = { p_user: me.id, p_addresses: addrs };
      if (report === "deep-work") args.p_tz = cleanTz(req.query.tz);
      out = await admin.rpc(fn, args);
    }
    if (out.error) return sqlError(res, out.error);
    return res.json(out.data);
  } catch (e) {
    return sqlError(res, e);
  }
});

founderAnalyticsRouter.get("/analytics/overview", async (req, res) => {
  try {
    const me = await who(req);
    if (!me) return res.status(401).json({ error: "unauthorized" });
    const f = await admin.from("founder_accounts").select("user_id").eq("user_id", me.id).maybeSingle();
    if (!isFounderEmail(me.email, FOUNDERS) && !f.data) return res.status(403).json({ error: "founder_only" });
    const out = await admin.rpc("founder_analytics_overview");
    if (out.error) return sqlError(res, out.error);
    return res.json(out.data);
  } catch (e) {
    return sqlError(res, e);
  }
});

// Fallback (Rust primary: billing.revenueTruth). Flat per-company price — Rule 51. SQL: E90 founder_revenue_truth().
founderAnalyticsRouter.get("/billing/revenue", async (req, res) => {
  try {
    const me = await who(req);
    if (!me) return res.status(401).json({ error: "unauthorized" });
    const f = await admin.from("founder_accounts").select("user_id").eq("user_id", me.id).maybeSingle();
    if (!isFounderEmail(me.email, FOUNDERS) && !f.data) return res.status(403).json({ error: "founder_only" });
    const out = await admin.rpc("founder_revenue_truth");
    if (out.error) return sqlError(res, out.error);
    return res.json(out.data);
  } catch (e) {
    return sqlError(res, e);
  }
});
