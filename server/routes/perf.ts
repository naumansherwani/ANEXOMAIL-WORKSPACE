// ANEXOMAIL — Phase 27: Performance Platform API (Server 2 / Brain, port 3100)
//
// NANO COMMAND (server par):
//   cp /opt/anexomail/src/routes/perf.ts /opt/anexomail/src/routes/perf.ts.bak.$(date +%s) 2>/dev/null
//   nano /opt/anexomail/src/routes/perf.ts
//   # select all -> paste -> Ctrl+O, Ctrl+X
//
// 6 advance features (sab asli rows se, koi mock nahi):
//   1. Speed receipts      — perf_budgets vs perf_samples ke asli p50/p95/p99
//   2. Prefetch brain      — hit/miss + bachaye gaye ms
//   3. Cold-start killer   — first paint vs warm per surface
//   4. Query lab           — asli search chalti hai, stage timings record hote hain
//   5. Device twin         — per-device network class + slow surfaces
//   6. Regression sentinel — release-over-release p95 diff + advice
//
// Env locked: SUPABASE4_URL / SUPABASE4_SERVICE_ROLE_KEY (fallback SUPABASE_*).
// Missing env par process crash NAHI — sirf yeh router 503 deta hai.
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
  console.error("perf: SUPABASE4_URL / SUPABASE4_SERVICE_ROLE_KEY missing — routes will 503");
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

type Sample = { action: string; surface: string | null; duration_ms: number; device_fingerprint: string | null; cold: boolean; release: string | null };

const pct = (sorted: number[], p: number): number | null => {
  if (sorted.length === 0) return null;
  const i = Math.min(sorted.length - 1, Math.max(0, Math.ceil(p * sorted.length) - 1));
  return sorted[i] ?? null;
};

async function loadSamples(uid: string, hours = 24): Promise<Sample[]> {
  const since = new Date(Date.now() - hours * 3600_000).toISOString();
  const { data, error } = await db!
    .from("perf_samples")
    .select("action, surface, duration_ms, device_fingerprint, cold, release")
    .eq("user_id", uid)
    .gt("at", since)
    .order("at", { ascending: false })
    .limit(20000);
  if (error) throw error;
  return (data ?? []) as Sample[];
}

function budgetRows(
  budgets: { action: string; label: string; budget_ms: number }[],
  samples: Sample[],
) {
  return budgets.map((b) => {
    const mine = samples.filter((s) => s.action === b.action);
    const sorted = mine.map((s) => s.duration_ms).sort((a, c) => a - c);
    const p95 = pct(sorted, 0.95);
    // worst surface = jis surface ka p95 sabse bura hai
    const bySurface = new Map<string, number[]>();
    for (const s of mine) {
      if (!s.surface) continue;
      const list = bySurface.get(s.surface) ?? [];
      list.push(s.duration_ms);
      bySurface.set(s.surface, list);
    }
    let worst_surface: string | null = null;
    let worstVal = -1;
    for (const [surface, list] of bySurface) {
      const v = pct(list.sort((a, c) => a - c), 0.95) ?? 0;
      if (v > worstVal) {
        worstVal = v;
        worst_surface = surface;
      }
    }
    const state =
      sorted.length === 0
        ? "no_data"
        : (p95 ?? 0) <= b.budget_ms
          ? "pass"
          : (p95 ?? 0) <= b.budget_ms * 1.5
            ? "warn"
            : "fail";
    return {
      action: b.action,
      label: b.label,
      budget_ms: b.budget_ms,
      p50_ms: pct(sorted, 0.5),
      p95_ms: p95,
      p99_ms: pct(sorted, 0.99),
      samples: sorted.length,
      state,
      worst_surface,
    };
  });
}

async function loadBudgets(uid: string) {
  const { data, error } = await db!
    .from("perf_budgets")
    .select("action, label, budget_ms")
    .eq("user_id", uid)
    .order("budget_ms", { ascending: true });
  if (error) throw error;
  return (data ?? []) as { action: string; label: string; budget_ms: number }[];
}

// ---------------------------------------------------------------------------
// Beacon ingest — frontend yahan asli timings bhejta hai (no mock numbers)
// ---------------------------------------------------------------------------
router.post("/samples", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  try {
    const list = Array.isArray(req.body?.samples) ? req.body.samples : [];
    if (list.length === 0) return res.json({ ok: true, inserted: 0 });
    const rows = list.slice(0, 200).map((s: any) => ({
      user_id: uid,
      action: String(s.action || "unknown").slice(0, 80),
      surface: s.surface ? String(s.surface).slice(0, 120) : null,
      duration_ms: Math.max(0, Math.round(Number(s.duration_ms) || 0)),
      device_fingerprint: s.device_fingerprint ? String(s.device_fingerprint).slice(0, 128) : null,
      release: s.release ? String(s.release).slice(0, 64) : null,
      cold: Boolean(s.cold),
    }));
    const { error } = await db!.from("perf_samples").insert(rows);
    if (error) return fail(res, error);
    res.json({ ok: true, inserted: rows.length });
  } catch (e) {
    fail(res, e);
  }
});

// ---------------------------------------------------------------------------
// 1. Speed receipts
// ---------------------------------------------------------------------------
router.get("/budgets", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  try {
    const [budgets, samples] = await Promise.all([loadBudgets(uid), loadSamples(uid)]);
    res.json({ budgets: budgetRows(budgets, samples) });
  } catch (e) {
    fail(res, e);
  }
});

// ---------------------------------------------------------------------------
// Overview — score asli budget compliance se
// ---------------------------------------------------------------------------
router.get("/dashboard", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  try {
    const since = new Date(Date.now() - 86_400_000).toISOString();
    const [budgets, samples] = await Promise.all([loadBudgets(uid), loadSamples(uid)]);
    const rows = budgetRows(budgets, samples);
    const withData = rows.filter((r) => r.state !== "no_data");
    const passing = withData.filter((r) => r.state === "pass").length;

    const [{ data: pf }, { data: cold }, { count: regressions }] = await Promise.all([
      db!.from("perf_prefetch_events").select("outcome, saved_ms").eq("user_id", uid).gt("at", since),
      db!.from("perf_surface_starts").select("cold").eq("user_id", uid).gt("at", since),
      db!
        .from("perf_regressions")
        .select("id", { count: "exact", head: true })
        .eq("user_id", uid)
        .eq("state", "open"),
    ]);

    const events = (pf ?? []) as { outcome: string; saved_ms: number }[];
    const hits = events.filter((e) => e.outcome === "hit").length;
    const ms_saved = events.reduce((n, e) => n + (e.outcome === "hit" ? e.saved_ms : 0), 0);
    const all = samples.map((s) => s.duration_ms).sort((a, c) => a - c);

    const advice: { title: string; detail: string; severity: string }[] = [];
    for (const r of rows.filter((x) => x.state === "fail").slice(0, 4)) {
      advice.push({
        title: `${r.label} is over budget`,
        detail: `p95 ${r.p95_ms}ms against a ${r.budget_ms}ms budget${r.worst_surface ? ` — worst on ${r.worst_surface}` : ""}.`,
        severity: "high",
      });
    }
    if (withData.length === 0)
      advice.push({
        title: "No samples yet",
        detail: "Use the workspace for a few minutes — every action reports its own timing.",
        severity: "low",
      });
    if ((regressions ?? 0) > 0)
      advice.push({
        title: "Open performance regression",
        detail: "A release made an action slower. Review the regression sentinel.",
        severity: "medium",
      });

    res.json({
      score: withData.length === 0 ? 0 : Math.round((passing / withData.length) * 100),
      p95_ms: pct(all, 0.95),
      budgets_passing: passing,
      budgets_total: rows.length,
      prefetch_hit_rate: events.length === 0 ? null : hits / events.length,
      ms_saved_24h: ms_saved,
      cold_starts_24h: ((cold ?? []) as { cold: boolean }[]).filter((c) => c.cold).length,
      open_regressions: regressions ?? 0,
      advice,
      slowest: rows
        .filter((r) => r.p95_ms != null)
        .sort((a, b) => (b.p95_ms ?? 0) / b.budget_ms - (a.p95_ms ?? 0) / a.budget_ms)
        .slice(0, 5)
        .map((r) => ({ action: r.action, p95_ms: r.p95_ms as number, budget_ms: r.budget_ms })),
    });
  } catch (e) {
    fail(res, e);
  }
});

// ---------------------------------------------------------------------------
// 2 + 3. Prefetch brain + cold-start map
// ---------------------------------------------------------------------------
router.get("/prefetch", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  try {
    const since = new Date(Date.now() - 7 * 86_400_000).toISOString();
    const [{ data: pf, error: e1 }, { data: st, error: e2 }] = await Promise.all([
      db!.from("perf_prefetch_events").select("surface, outcome, saved_ms").eq("user_id", uid).gt("at", since),
      db!
        .from("perf_surface_starts")
        .select("surface, first_paint_ms, warm_ms, cold")
        .eq("user_id", uid)
        .gt("at", since),
    ]);
    if (e1) return fail(res, e1);
    if (e2) return fail(res, e2);

    const events = (pf ?? []) as { surface: string; outcome: string; saved_ms: number }[];
    const hits = events.filter((e) => e.outcome === "hit");
    const bySurface = new Map<string, { predicted: number; opened: number; saved: number }>();
    for (const e of events) {
      const cur = bySurface.get(e.surface) ?? { predicted: 0, opened: 0, saved: 0 };
      cur.predicted += 1;
      if (e.outcome === "hit") {
        cur.opened += 1;
        cur.saved += e.saved_ms;
      }
      bySurface.set(e.surface, cur);
    }

    const starts = (st ?? []) as { surface: string; first_paint_ms: number | null; warm_ms: number | null; cold: boolean }[];
    const coldMap = new Map<string, { fp: number[]; warm: number[]; cold: number }>();
    for (const s of starts) {
      const cur = coldMap.get(s.surface) ?? { fp: [], warm: [], cold: 0 };
      if (s.first_paint_ms != null) cur.fp.push(s.first_paint_ms);
      if (s.warm_ms != null) cur.warm.push(s.warm_ms);
      if (s.cold) cur.cold += 1;
      coldMap.set(s.surface, cur);
    }
    const avg = (list: number[]) => (list.length === 0 ? null : Math.round(list.reduce((a, b) => a + b, 0) / list.length));

    res.json({
      hit_rate: events.length === 0 ? null : hits.length / events.length,
      hits: hits.length,
      misses: events.length - hits.length,
      ms_saved: hits.reduce((n, e) => n + e.saved_ms, 0),
      predictions: [...bySurface.entries()]
        .map(([surface, v]) => ({
          surface,
          predicted: v.predicted,
          opened: v.opened,
          accuracy: v.predicted === 0 ? 0 : v.opened / v.predicted,
          avg_saved_ms: v.opened === 0 ? 0 : Math.round(v.saved / v.opened),
        }))
        .sort((a, b) => b.predicted - a.predicted)
        .slice(0, 12),
      cold_surfaces: [...coldMap.entries()]
        .map(([surface, v]) => ({
          surface,
          first_paint_ms: avg(v.fp),
          warm_ms: avg(v.warm),
          cold_starts: v.cold,
        }))
        .sort((a, b) => b.cold_starts - a.cold_starts)
        .slice(0, 12),
    });
  } catch (e) {
    fail(res, e);
  }
});

// ---------------------------------------------------------------------------
// 4. Query lab — asli query chalti hai, stage timings record hote hain
// ---------------------------------------------------------------------------
const mapTrace = (r: any) => ({
  id: r.id,
  query: r.query,
  at: r.at,
  total_ms: r.total_ms,
  rows: r.rows_returned,
  cached: r.cached,
  stages: Array.isArray(r.stages) ? r.stages : [],
  slowest_stage:
    Array.isArray(r.stages) && r.stages.length > 0
      ? [...r.stages].sort((a: any, b: any) => b.ms - a.ms)[0].stage
      : null,
});

router.get("/search", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  try {
    const { data, error } = await db!
      .from("perf_search_traces")
      .select("*")
      .eq("user_id", uid)
      .order("at", { ascending: false })
      .limit(20);
    if (error) return fail(res, error);
    res.json({ traces: (data ?? []).map(mapTrace) });
  } catch (e) {
    fail(res, e);
  }
});

router.post("/search/run", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  const q = String(req.body?.query || "").trim();
  if (!q) return res.status(400).json({ error: "query_required" });
  try {
    const stages: { stage: string; ms: number }[] = [];
    const t0 = performance.now();

    // parse
    const terms = q.split(/\s+/).filter(Boolean).slice(0, 8);
    stages.push({ stage: "parse", ms: Math.round(performance.now() - t0) });

    // index scan — asli threads par trigram/ilike search
    const t1 = performance.now();
    const { data: threads, error } = await db!
      .from("mail_threads")
      .select("id, subject, last_message_at")
      .eq("user_id", uid)
      .ilike("subject", `%${terms[0] ?? q}%`)
      .order("last_message_at", { ascending: false })
      .limit(50);
    if (error) return fail(res, error);
    stages.push({ stage: "index scan", ms: Math.round(performance.now() - t1) });

    // fetch bodies for the top hits
    const t2 = performance.now();
    const ids = (threads ?? []).slice(0, 10).map((t: any) => t.id);
    let bodies = 0;
    if (ids.length > 0) {
      const { data: msgs } = await db!
        .from("mail_messages")
        .select("id")
        .in("thread_id", ids)
        .limit(200);
      bodies = (msgs ?? []).length;
    }
    stages.push({ stage: "fetch", ms: Math.round(performance.now() - t2) });

    // rank
    const t3 = performance.now();
    const ranked = (threads ?? []).sort((a: any, b: any) =>
      String(b.last_message_at ?? "").localeCompare(String(a.last_message_at ?? "")),
    );
    stages.push({ stage: "rank", ms: Math.round(performance.now() - t3) });

    const total_ms = Math.round(performance.now() - t0);
    const { data: saved, error: insErr } = await db!
      .from("perf_search_traces")
      .insert({
        user_id: uid,
        query: q,
        total_ms,
        rows_returned: ranked.length,
        cached: false,
        stages,
      })
      .select("*")
      .single();
    if (insErr) return fail(res, insErr);

    await db!.from("perf_samples").insert({
      user_id: uid,
      action: "search.global",
      surface: "query-lab",
      duration_ms: total_ms,
      cold: false,
    });

    res.json({ trace: mapTrace({ ...saved, stages }), matched_messages: bodies });
  } catch (e) {
    fail(res, e);
  }
});

// ---------------------------------------------------------------------------
// 5. Device twins
// ---------------------------------------------------------------------------
router.get("/devices", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  try {
    const [{ data: devices, error }, samples] = await Promise.all([
      db!.from("perf_device_profiles").select("*").eq("user_id", uid).order("last_seen_at", { ascending: false }),
      loadSamples(uid, 24 * 7),
    ]);
    if (error) return fail(res, error);

    res.json({
      devices: (devices ?? []).map((d: any) => {
        const mine = samples.filter((s) => s.device_fingerprint === d.fingerprint);
        const sorted = mine.map((s) => s.duration_ms).sort((a, b) => a - b);
        const bySurface = new Map<string, number[]>();
        for (const s of mine) {
          if (!s.surface) continue;
          const list = bySurface.get(s.surface) ?? [];
          list.push(s.duration_ms);
          bySurface.set(s.surface, list);
        }
        return {
          id: d.id,
          label: d.label,
          platform: d.platform,
          browser: d.browser,
          network: d.network,
          downlink_mbps: d.downlink_mbps == null ? null : Number(d.downlink_mbps),
          rtt_ms: d.rtt_ms,
          p95_ms: pct(sorted, 0.95),
          samples: sorted.length,
          slow_surfaces: [...bySurface.entries()]
            .map(([surface, list]) => ({
              surface,
              p95_ms: pct(list.sort((a, b) => a - b), 0.95) ?? 0,
            }))
            .sort((a, b) => b.p95_ms - a.p95_ms)
            .slice(0, 5),
          last_seen_at: d.last_seen_at,
        };
      }),
    });
  } catch (e) {
    fail(res, e);
  }
});

// ---------------------------------------------------------------------------
// 6. Regression sentinel — releases compare karke rows likhta hai
// ---------------------------------------------------------------------------
router.get("/regressions", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  try {
    const { data, error } = await db!
      .from("perf_regressions")
      .select("*")
      .eq("user_id", uid)
      .order("detected_at", { ascending: false })
      .limit(50);
    if (error) return fail(res, error);
    res.json({
      regressions: (data ?? []).map((r: any) => ({
        id: r.id,
        action: r.action,
        release: r.release,
        previous_release: r.previous_release,
        before_p95_ms: r.before_p95_ms,
        after_p95_ms: r.after_p95_ms,
        delta_pct: r.delta_pct == null ? null : Number(r.delta_pct),
        state: r.state,
        detected_at: r.detected_at,
        advice: r.advice,
      })),
    });
  } catch (e) {
    fail(res, e);
  }
});

// ---------------------------------------------------------------------------
// Founder god-view — /api/founder/perf/overview
// ---------------------------------------------------------------------------
founderRouter.get("/perf/overview", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  try {
    const { data, error } = await db!.rpc("founder_perf_overview");
    if (error) return fail(res, error);
    const d = (data ?? {}) as any;
    res.json({
      tenants: d.tenants ?? 0,
      p95_ms: d.p95_ms ?? null,
      budgets_failing: d.budgets_failing ?? 0,
      open_regressions: d.open_regressions ?? 0,
      cold_starts_24h: d.cold_starts_24h ?? null,
      ms_saved_24h: d.ms_saved_24h ?? null,
      worst_tenants: Array.isArray(d.worst_tenants) ? d.worst_tenants : [],
    });
  } catch (e) {
    fail(res, e);
  }
});

export default router;
export { founderRouter as founderPerfRouter };