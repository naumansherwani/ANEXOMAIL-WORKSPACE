// ANEXOMAIL — Phase 30: Production & Founder Lock API (Server 2 / Brain, port 3100)
//
// NANO COMMAND (server par):
//   cp /opt/anexomail/src/routes/release.ts /opt/anexomail/src/routes/release.ts.bak.$(date +%s) 2>/dev/null
//   nano /opt/anexomail/src/routes/release.ts
//   # select all -> paste -> Ctrl+O, Ctrl+X
//
// 6 advance features (sab asli rows/probes se, koi mock nahi, koi AI nahi):
//   1. Release gate with proof   — asli HTTP probes + DB probes, red = launch blocked
//   2. Deploy receipt + rollback — deployments ledger, changed-since-green diff
//   3. Version lock ledger       — append-only, signature hash, dobara lock = 409
//   4. Offline outbox truth      — idempotency-key send, server confirm ke baad hi sent
//   5. Public status page        — /api/public/status wahi probes se, koi internal detail nahi
//   6. Revenue pipeline truth    — committed MRR vs weighted pipeline vs gap
//
// Env locked: SUPABASE4_URL / SUPABASE4_SERVICE_ROLE_KEY (fallback SUPABASE_*).
// Missing env par process crash NAHI — sirf yeh router 503 deta hai.
import { Router } from "express";
import { createHash, randomUUID } from "crypto";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";

const SUPABASE_URL = process.env.SUPABASE4_URL || process.env.SUPABASE_URL || "";
const SERVICE_KEY =
  process.env.SUPABASE4_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY || "";
const SELF = process.env.SELF_ORIGIN || `http://127.0.0.1:${process.env.PORT || 3100}`;

let db: SupabaseClient | null = null;
if (SUPABASE_URL && SERVICE_KEY) {
  db = createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
} else {
  console.error("release: SUPABASE4_URL / SUPABASE4_SERVICE_ROLE_KEY missing — routes will 503");
}

const publicRouter = Router();
const founderRouter = Router();
const outboxRouter = Router();

const fail = (res: any, e: any) =>
  res.status(500).json({ error: "db_error", detail: String(e?.message || e) });

async function requireUser(req: any, res: any): Promise<{ id: string; email: string } | null> {
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
  return { id: data.user.id, email: data.user.email || "founder" };
}

/* ------------------------------- probes ---------------------------------- */

type Probe = {
  suite: string;
  name: string;
  status: "pass" | "warn" | "fail" | "skip";
  ms: number | null;
  code: number | null;
  detail: string | null;
};

const TIMEOUT_MS = 3000;

/** Ek HTTP probe. 401 bhi pass hai — guarded route ka sahi jawab. */
async function httpProbe(suite: string, name: string, path: string, ok: number[]): Promise<Probe> {
  const started = Date.now();
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    const res = await fetch(`${SELF}${path}`, { signal: controller.signal });
    const ms = Date.now() - started;
    const pass = ok.includes(res.status);
    return {
      suite,
      name,
      status: pass ? (ms > 1500 ? "warn" : "pass") : "fail",
      ms,
      code: res.status,
      detail: pass ? path : `${path} returned ${res.status}, expected ${ok.join("/")}`,
    };
  } catch (e: any) {
    return {
      suite,
      name,
      status: "fail",
      ms: Date.now() - started,
      code: null,
      detail: `${path} unreachable: ${String(e?.message || e)}`,
    };
  } finally {
    clearTimeout(timer);
  }
}

/** Ek table probe — table maujood hai aur padhi ja sakti hai. */
async function tableProbe(suite: string, table: string): Promise<Probe> {
  const started = Date.now();
  try {
    const { count, error } = await db!.from(table).select("*", { count: "exact", head: true });
    const ms = Date.now() - started;
    if (error) {
      return { suite, name: `table ${table}`, status: "fail", ms, code: null, detail: error.message };
    }
    return {
      suite,
      name: `table ${table}`,
      status: "pass",
      ms,
      code: 200,
      detail: `${count ?? 0} rows`,
    };
  } catch (e: any) {
    return {
      suite,
      name: `table ${table}`,
      status: "fail",
      ms: Date.now() - started,
      code: null,
      detail: String(e?.message || e),
    };
  }
}

const GUARDED: [string, string][] = [
  ["auth session", "/api/auth/session"],
  ["workspace", "/api/workspace/overview"],
  ["dashboard", "/api/dashboard/overview"],
  ["mail threads", "/api/mail/threads"],
  ["compose drafts", "/api/mail/drafts"],
  ["contacts", "/api/contacts"],
  ["calendar events", "/api/calendar/events"],
  ["crm pipeline", "/api/crm/pipeline"],
  ["org members", "/api/org/members"],
  ["settings list", "/api/settings/list"],
  ["settings history", "/api/settings/history"],
  ["admin health", "/api/admin/health"],
  ["admin monitoring", "/api/admin/monitoring"],
  ["admin diagnostics", "/api/admin/diagnostics"],
  ["security devices", "/api/security/devices"],
  ["security sessions", "/api/security/sessions"],
  ["security proof", "/api/security/proof"],
  ["perf budgets", "/api/perf/budgets"],
  ["perf prefetch", "/api/perf/prefetch"],
  ["integrations providers", "/api/integrations/providers"],
  ["integrations exports", "/api/integrations/exports"],
  ["mail handoff", "/api/mail/handoff"],
  ["founder overview", "/api/founder/overview"],
  ["founder mailboxes", "/api/founder/mailboxes"],
  ["founder revenue", "/api/founder/revenue/overview"],
  ["founder release", "/api/founder/release/overview"],
];

const TABLES = [
  "mail_threads",
  "mail_messages",
  "mail_domains",
  "mailboxes",
  "mail_outbox",
  "contacts",
  "calendar_events",
  "crm_deals",
  "org_members",
  "setting_values",
  "admin_health_checks",
  "diagnostic_runs",
  "security_devices",
  "security_ledger",
  "perf_budgets",
  "perf_samples",
  "integration_connections",
  "export_jobs",
  "revenue_leads",
  "revenue_accounts",
  "revenue_targets",
  "release_checks",
  "release_runs",
  "deployments",
  "release_locks",
  "roadmap_items",
  "subscription_pipeline",
];

/** Ownership proof suite — asli diagnostic probes ki latest run se. */
async function ownershipProbes(): Promise<Probe[]> {
  const started = Date.now();
  const { data, error } = await db!
    .from("diagnostic_probes")
    .select("probe, target, result, ms")
    .order("at", { ascending: false })
    .limit(40);
  if (error) {
    return [
      { suite: "ownership", name: "diagnostic probes", status: "fail", ms: Date.now() - started, code: null, detail: error.message },
    ];
  }
  const rows = (data ?? []) as { probe: string; target: string | null; result: string; ms: number | null }[];
  if (rows.length === 0) {
    return [
      { suite: "ownership", name: "DNS / DKIM / SPF / DMARC / TLS", status: "warn", ms: null, code: null, detail: "No diagnostics run yet — run Admin → Diagnostics" },
    ];
  }
  const seen = new Set<string>();
  const out: Probe[] = [];
  for (const r of rows) {
    const key = `${r.probe}:${r.target ?? ""}`;
    if (seen.has(key)) continue;
    seen.add(key);
    out.push({
      suite: "ownership",
      name: `${r.probe}${r.target ? ` · ${r.target}` : ""}`,
      status: r.result === "pass" ? "pass" : r.result === "fail" ? "fail" : "warn",
      ms: r.ms ?? null,
      code: null,
      detail: r.result,
    });
  }
  return out.slice(0, 10);
}

/** Speed suite — perf budgets vs asli samples ka p95. */
async function speedProbes(): Promise<Probe[]> {
  const { data: budgets, error: be } = await db!.from("perf_budgets").select("action, label, budget_ms");
  if (be) return [{ suite: "speed", name: "perf budgets", status: "fail", ms: null, code: null, detail: be.message }];
  const list = (budgets ?? []) as { action: string; label: string; budget_ms: number }[];
  if (list.length === 0) {
    return [{ suite: "speed", name: "perf budgets", status: "warn", ms: null, code: null, detail: "No budgets seeded" }];
  }
  const since = new Date(Date.now() - 7 * 86_400_000).toISOString();
  const { data: samples } = await db!
    .from("perf_samples")
    .select("action, duration_ms")
    .gt("at", since)
    .limit(20000);
  const rows = (samples ?? []) as { action: string; duration_ms: number }[];
  return list.map((b) => {
    const mine = rows.filter((s) => s.action === b.action).map((s) => s.duration_ms).sort((a, c) => a - c);
    if (mine.length === 0) {
      return { suite: "speed", name: b.label, status: "skip" as const, ms: null, code: null, detail: "no samples in 7 days" };
    }
    const i = Math.min(mine.length - 1, Math.max(0, Math.ceil(0.95 * mine.length) - 1));
    const p95 = mine[i] ?? 0;
    return {
      suite: "speed",
      name: b.label,
      status: p95 <= b.budget_ms ? ("pass" as const) : p95 <= b.budget_ms * 1.5 ? ("warn" as const) : ("fail" as const),
      ms: p95,
      code: null,
      detail: `p95 ${Math.round(p95)}ms vs budget ${b.budget_ms}ms · ${mine.length} samples`,
    };
  });
}

/** Mail delivery suite — held mail, bounces, domain verdicts. */
async function mailProbes(): Promise<Probe[]> {
  const out: Probe[] = [];
  const { data: domains, error: de } = await db!.from("mail_domains").select("domain, dkim, spf, dmarc, mx");
  if (de) {
    out.push({ suite: "mail", name: "mail_domains", status: "fail", ms: null, code: null, detail: de.message });
  } else {
    for (const d of (domains ?? []) as any[]) {
      const bad = ["dkim", "spf", "dmarc", "mx"].filter((k) => d[k] && String(d[k]) !== "pass" && String(d[k]) !== "green" && d[k] !== true);
      out.push({
        suite: "mail",
        name: `domain ${d.domain}`,
        status: bad.length === 0 ? "pass" : "fail",
        ms: null,
        code: null,
        detail: bad.length === 0 ? "MX / SPF / DKIM / DMARC green" : `needs attention: ${bad.join(", ")}`,
      });
    }
  }
  const { count: held } = await db!
    .from("mail_outbox")
    .select("*", { count: "exact", head: true })
    .in("state", ["queued", "failed"]);
  out.push({
    suite: "mail",
    name: "outbox backlog",
    status: (held ?? 0) === 0 ? "pass" : (held ?? 0) < 25 ? "warn" : "fail",
    ms: null,
    code: null,
    detail: `${held ?? 0} messages waiting`,
  });
  return out;
}

let running = false;

async function runSuite(suite: string): Promise<Probe[]> {
  const jobs: Promise<Probe[]>[] = [];
  if (suite === "all" || suite === "routes") {
    jobs.push(
      Promise.all([
        httpProbe("routes", "health", "/api/health", [200]),
        httpProbe("routes", "public status", "/api/public/status", [200]),
        ...GUARDED.map(([name, path]) => httpProbe("routes", name, path, [200, 401])),
      ]),
    );
  }
  if (suite === "all" || suite === "database") {
    jobs.push(Promise.all(TABLES.map((t) => tableProbe("database", t))));
  }
  if (suite === "all" || suite === "mail") jobs.push(mailProbes());
  if (suite === "all" || suite === "ownership") jobs.push(ownershipProbes());
  if (suite === "all" || suite === "speed") jobs.push(speedProbes());
  const results = await Promise.all(jobs);
  return results.flat();
}

/* ---------------------------- founder: QA run ---------------------------- */

founderRouter.post("/release/run", async (req, res) => {
  const user = await requireUser(req, res);
  if (!user) return;
  if (running) return res.status(409).json({ error: "run_in_flight" });
  running = true;
  const startedAt = new Date();
  try {
    const suite = String(req.body?.suite || "all");
    const probes = await runSuite(suite);
    const ms = Date.now() - startedAt.getTime();
    const passed = probes.filter((p) => p.status === "pass").length;
    const warned = probes.filter((p) => p.status === "warn").length;
    const failed = probes.filter((p) => p.status === "fail").length;
    const skipped = probes.filter((p) => p.status === "skip").length;
    const verdict = failed > 0 ? "red" : warned > 0 ? "watch" : "green";

    const runId = randomUUID();
    const { error: runError } = await db!.from("release_runs").insert({
      id: runId,
      user_id: user.id,
      suite,
      started_at: startedAt.toISOString(),
      finished_at: new Date().toISOString(),
      passed,
      warned,
      failed,
      skipped,
      total: probes.length,
      ms,
      verdict,
    });
    if (runError) return fail(res, runError);

    const rows = probes.map((p) => ({
      run_id: runId,
      user_id: user.id,
      suite: p.suite,
      name: p.name,
      status: p.status,
      ms: p.ms,
      code: p.code,
      detail: p.detail,
    }));
    const { data: inserted, error: checkError } = await db!.from("release_checks").insert(rows).select();
    if (checkError) return fail(res, checkError);

    res.json({
      run: {
        id: runId,
        started_at: startedAt.toISOString(),
        finished_at: new Date().toISOString(),
        passed,
        warned,
        failed,
        skipped,
        total: probes.length,
        ms,
        verdict,
      },
      checks: (inserted ?? []).map(shapeCheck),
    });
  } catch (e) {
    fail(res, e);
  } finally {
    running = false;
  }
});

const shapeCheck = (c: any) => ({
  id: c.id,
  suite: c.suite,
  name: c.name,
  status: c.status,
  ms: c.ms == null ? null : Number(c.ms),
  code: c.code == null ? null : Number(c.code),
  detail: c.detail ?? null,
  at: c.at,
});

const shapeRun = (r: any) => ({
  id: r.id,
  started_at: r.started_at,
  finished_at: r.finished_at,
  passed: r.passed ?? 0,
  warned: r.warned ?? 0,
  failed: r.failed ?? 0,
  skipped: r.skipped ?? 0,
  total: r.total ?? 0,
  ms: r.ms == null ? null : Number(r.ms),
  verdict: r.verdict,
});

const shapeDeployment = (d: any) => ({
  id: d.id,
  target: d.target,
  commit_sha: d.commit_sha,
  commit_subject: d.commit_subject ?? null,
  actor: d.actor ?? null,
  started_at: d.started_at,
  finished_at: d.finished_at ?? null,
  ms: d.ms == null ? null : Number(d.ms),
  state: d.state,
  rollback_of: d.rollback_of ?? null,
  changed_since_green: Array.isArray(d.changed_since_green) ? d.changed_since_green : [],
});

/* ---------------------------- founder: reads ----------------------------- */

founderRouter.get("/release/checks", async (req, res) => {
  const user = await requireUser(req, res);
  if (!user) return;
  try {
    const { data: runs, error: re } = await db!
      .from("release_runs")
      .select("*")
      .order("started_at", { ascending: false })
      .limit(10);
    if (re) return fail(res, re);
    const latest = (runs ?? [])[0] as any;
    let checks: any[] = [];
    if (latest) {
      const { data, error } = await db!
        .from("release_checks")
        .select("*")
        .eq("run_id", latest.id)
        .order("suite", { ascending: true })
        .order("name", { ascending: true });
      if (error) return fail(res, error);
      checks = data ?? [];
    }
    res.json({ runs: (runs ?? []).map(shapeRun), checks: checks.map(shapeCheck) });
  } catch (e) {
    fail(res, e);
  }
});

founderRouter.get("/release/overview", async (req, res) => {
  const user = await requireUser(req, res);
  if (!user) return;
  try {
    const [runQ, lockQ, listQ, depQ] = await Promise.all([
      db!.from("release_runs").select("*").order("started_at", { ascending: false }).limit(1),
      db!.from("release_locks").select("*").order("frozen_at", { ascending: false }).limit(1),
      db!.from("release_checklist").select("*"),
      db!.from("deployments").select("*").order("started_at", { ascending: false }).limit(1),
    ]);
    const latest = (runQ.data ?? [])[0] as any;
    const lock = (lockQ.data ?? [])[0] as any;
    const items = (listQ.data ?? []) as any[];
    const dep = (depQ.data ?? [])[0] as any;

    let blockers: { id: string; label: string; suite: string; detail: string | null }[] = items
      .filter((i) => i.state === "blocker")
      .map((i) => ({ id: i.id, label: i.label, suite: `checklist · ${i.area}`, detail: i.detail ?? null }));

    if (latest && latest.failed > 0) {
      const { data: failedChecks } = await db!
        .from("release_checks")
        .select("id, suite, name, detail")
        .eq("run_id", latest.id)
        .eq("status", "fail")
        .limit(25);
      blockers = blockers.concat(
        ((failedChecks ?? []) as any[]).map((c) => ({
          id: c.id,
          label: c.name,
          suite: c.suite,
          detail: c.detail ?? null,
        })),
      );
    }

    res.json({
      gate: lock ? "locked" : !latest ? "unknown" : blockers.length > 0 ? "blocked" : "ready",
      version: lock?.version ?? null,
      locked_at: lock?.frozen_at ?? null,
      latest_run: latest ? shapeRun(latest) : null,
      blockers,
      checklist_open: items.filter((i) => i.state !== "done").length,
      checklist_total: items.length,
      last_deployment: dep ? shapeDeployment(dep) : null,
    });
  } catch (e) {
    fail(res, e);
  }
});

founderRouter.get("/release/checklist", async (req, res) => {
  const user = await requireUser(req, res);
  if (!user) return;
  try {
    const { data, error } = await db!
      .from("release_checklist")
      .select("*")
      .order("area", { ascending: true })
      .order("label", { ascending: true });
    if (error) return fail(res, error);
    res.json({
      items: (data ?? []).map((i: any) => ({
        id: i.id,
        area: i.area,
        label: i.label,
        detail: i.detail ?? null,
        state: i.state,
        owner: i.owner ?? null,
        updated_at: i.updated_at ?? null,
      })),
    });
  } catch (e) {
    fail(res, e);
  }
});

founderRouter.post("/release/checklist/item", async (req, res) => {
  const user = await requireUser(req, res);
  if (!user) return;
  const id = String(req.body?.id || "");
  const state = String(req.body?.state || "");
  if (!id || !["open", "done", "blocker"].includes(state)) {
    return res.status(400).json({ error: "bad_request", detail: "id + state (open|done|blocker) required" });
  }
  try {
    const { data, error } = await db!
      .from("release_checklist")
      .update({ state, owner: user.email, updated_at: new Date().toISOString() })
      .eq("id", id)
      .select()
      .single();
    if (error) return fail(res, error);
    res.json({
      id: data.id,
      area: data.area,
      label: data.label,
      detail: data.detail ?? null,
      state: data.state,
      owner: data.owner ?? null,
      updated_at: data.updated_at ?? null,
    });
  } catch (e) {
    fail(res, e);
  }
});

founderRouter.get("/release/deployments", async (req, res) => {
  const user = await requireUser(req, res);
  if (!user) return;
  try {
    const { data, error } = await db!
      .from("deployments")
      .select("*")
      .order("started_at", { ascending: false })
      .limit(50);
    if (error) return fail(res, error);
    res.json({ deployments: (data ?? []).map(shapeDeployment) });
  } catch (e) {
    fail(res, e);
  }
});

/* ------------------------------ version lock ----------------------------- */

founderRouter.get("/release/lock", async (req, res) => {
  const user = await requireUser(req, res);
  if (!user) return;
  try {
    const { data, error } = await db!
      .from("release_locks")
      .select("*")
      .order("frozen_at", { ascending: false })
      .limit(20);
    if (error) return fail(res, error);
    res.json({
      locks: (data ?? []).map((l: any) => ({
        id: l.id,
        version: l.version,
        signed_by: l.signed_by,
        signature_hash: l.signature_hash,
        verdict: l.verdict,
        frozen_at: l.frozen_at,
        notes: l.notes ?? null,
      })),
    });
  } catch (e) {
    fail(res, e);
  }
});

founderRouter.post("/release/lock", async (req, res) => {
  const user = await requireUser(req, res);
  if (!user) return;
  const version = String(req.body?.version || "").trim();
  if (!version) return res.status(400).json({ error: "bad_request", detail: "version required" });
  const overrideReason = req.body?.override_reason ? String(req.body.override_reason) : null;
  try {
    const { data: existing } = await db!.from("release_locks").select("id").eq("version", version).limit(1);
    if ((existing ?? []).length > 0) {
      return res.status(409).json({ error: "already_locked", detail: `v${version} is already frozen` });
    }

    const { data: runs } = await db!
      .from("release_runs")
      .select("*")
      .order("started_at", { ascending: false })
      .limit(1);
    const latest = (runs ?? [])[0] as any;
    if (!latest) return res.status(412).json({ error: "no_run", detail: "Run the QA suite first" });

    const { count: blockerCount } = await db!
      .from("release_checklist")
      .select("*", { count: "exact", head: true })
      .eq("state", "blocker");

    const red = latest.failed > 0 || (blockerCount ?? 0) > 0;
    if (red && !overrideReason) {
      return res.status(412).json({
        error: "gate_red",
        detail: `${latest.failed} failing checks and ${blockerCount ?? 0} blockers — fix them or send override_reason`,
      });
    }

    const frozenAt = new Date().toISOString();
    const signature = createHash("sha256")
      .update(
        [version, user.email, frozenAt, latest.id, latest.verdict, latest.passed, latest.failed, overrideReason ?? ""].join(
          "|",
        ),
      )
      .digest("hex");

    const { data, error } = await db!
      .from("release_locks")
      .insert({
        version,
        signed_by: user.email,
        user_id: user.id,
        run_id: latest.id,
        verdict: red ? `override(${latest.verdict})` : latest.verdict,
        signature_hash: signature,
        frozen_at: frozenAt,
        notes: req.body?.notes ? String(req.body.notes) : null,
        override_reason: overrideReason,
      })
      .select()
      .single();
    if (error) return fail(res, error);

    res.json({
      id: data.id,
      version: data.version,
      signed_by: data.signed_by,
      signature_hash: data.signature_hash,
      verdict: data.verdict,
      frozen_at: data.frozen_at,
      notes: data.notes ?? null,
    });
  } catch (e) {
    fail(res, e);
  }
});

/* -------------------------------- roadmap -------------------------------- */

founderRouter.get("/release/roadmap", async (req, res) => {
  const user = await requireUser(req, res);
  if (!user) return;
  try {
    const { data, error } = await db!
      .from("roadmap_items")
      .select("*")
      .order("created_at", { ascending: false })
      .limit(200);
    if (error) return fail(res, error);
    res.json({
      items: (data ?? []).map((i: any) => ({
        id: i.id,
        title: i.title,
        area: i.area,
        impact: Number(i.impact ?? 3),
        effort: Number(i.effort ?? 3),
        revenue_link: i.revenue_link ?? null,
        state: i.state,
      })),
    });
  } catch (e) {
    fail(res, e);
  }
});

founderRouter.post("/release/roadmap", async (req, res) => {
  const user = await requireUser(req, res);
  if (!user) return;
  const title = String(req.body?.title || "").trim();
  if (!title) return res.status(400).json({ error: "bad_request", detail: "title required" });
  try {
    const { data, error } = await db!
      .from("roadmap_items")
      .insert({
        user_id: user.id,
        title,
        area: String(req.body?.area || "general"),
        impact: Math.min(5, Math.max(1, Number(req.body?.impact ?? 3))),
        effort: Math.min(5, Math.max(1, Number(req.body?.effort ?? 3))),
        revenue_link: req.body?.revenue_link ? String(req.body.revenue_link) : null,
        state: ["idea", "next", "building", "shipped"].includes(String(req.body?.state))
          ? String(req.body.state)
          : "idea",
      })
      .select()
      .single();
    if (error) return fail(res, error);
    res.json({
      id: data.id,
      title: data.title,
      area: data.area,
      impact: Number(data.impact),
      effort: Number(data.effort),
      revenue_link: data.revenue_link ?? null,
      state: data.state,
    });
  } catch (e) {
    fail(res, e);
  }
});

/* -------------------------- revenue pipeline truth ----------------------- */

const STAGE_WEIGHT: Record<string, number> = {
  new: 0.1,
  contacted: 0.2,
  qualified: 0.4,
  quoted: 0.5,
  proposal: 0.6,
  won: 1,
  lost: 0,
};

founderRouter.get("/revenue/pipeline", async (req, res) => {
  const user = await requireUser(req, res);
  if (!user) return;
  try {
    const [accQ, leadQ, tgtQ, partnerQ, pipeQ] = await Promise.all([
      db!.from("revenue_accounts").select("plan, seats, mrr_gbp, sla_addon, state"),
      db!.from("revenue_leads").select("id, reference, company, kind, stage, seats, quote_gbp, created_at").order("created_at", { ascending: false }).limit(100),
      db!.from("revenue_targets").select("target_gbp").order("month", { ascending: false }).limit(1),
      db!.from("revenue_partners").select("company, tier, live_seats, commission_gbp, stage"),
      db!.from("subscription_pipeline").select("lead_id, plan_seats, expected_mrr_gbp, stage"),
    ]);

    const accounts = (accQ.data ?? []) as any[];
    const live = accounts.filter((a) => a.state !== "cancelled");
    const subsMrr = live.reduce((s, a) => s + Number(a.mrr_gbp || 0), 0);
    const slaMrr = live.filter((a) => a.sla_addon).length * 500;
    const partners = (partnerQ.data ?? []) as any[];
    const partnerMrr = partners
      .filter((p) => p.stage === "active" || p.stage === "live")
      .reduce((s, p) => s + Number(p.commission_gbp || 0), 0);

    const target = Number((tgtQ.data ?? [])[0]?.target_gbp ?? 500);
    const committed = subsMrr + slaMrr + partnerMrr;

    const pipeRows = (pipeQ.data ?? []) as any[];
    const pipeByLead = new Map(pipeRows.map((p) => [p.lead_id, p]));

    const leads = (leadQ.data ?? []) as any[];
    const openLeads = leads.filter((l) => l.stage !== "lost");
    const pipeline = openLeads.map((l) => {
      const linked = pipeByLead.get(l.id);
      const weight = STAGE_WEIGHT[String(l.stage || "new")] ?? 0.1;
      const seats = Number(linked?.plan_seats ?? l.seats ?? 1);
      const expected = linked?.expected_mrr_gbp != null ? Number(linked.expected_mrr_gbp) : seats * 40;
      return {
        id: l.id,
        reference: l.reference,
        company: l.company,
        stage: String(l.stage || "new"),
        weight,
        plan_seats: seats,
        expected_mrr_gbp: Math.round(expected * weight),
        one_off_gbp: l.kind === "migration" && l.quote_gbp != null ? Number(l.quote_gbp) : null,
      };
    });

    const pipelineMrr = pipeline.reduce((s, p) => s + p.expected_mrr_gbp, 0);
    // One-off cash: sirf jeete hue migration jobs — MRR mein kabhi nahi ginte.
    const oneOff = leads
      .filter((l) => l.kind === "migration" && l.stage === "won")
      .reduce((s, l) => s + Number(l.quote_gbp || 0), 0);

    res.json({
      target_gbp: target,
      committed_mrr_gbp: Math.round(committed),
      pipeline_mrr_gbp: Math.round(pipelineMrr),
      one_off_cash_gbp: Math.round(oneOff),
      gap_gbp: Math.max(0, Math.round(target - committed)),
      committed: [
        { stream: "Subscriptions (Basic/Pro/Business)", mrr_gbp: Math.round(subsMrr), accounts: live.length },
        { stream: "Enterprise SLA retainer", mrr_gbp: slaMrr, accounts: live.filter((a) => a.sla_addon).length },
        { stream: "Partner commission", mrr_gbp: Math.round(partnerMrr), accounts: partners.length },
      ].filter((s) => s.accounts > 0 || s.mrr_gbp > 0),
      pipeline,
    });
  } catch (e) {
    fail(res, e);
  }
});

/* ---------------------------- public status ------------------------------ */

publicRouter.get("/status", async (_req, res) => {
  if (!db) return res.status(503).json({ error: "supabase_not_configured" });
  try {
    const { data: runs } = await db
      .from("release_runs")
      .select("id, finished_at, verdict")
      .order("started_at", { ascending: false })
      .limit(1);
    const latest = (runs ?? [])[0] as any;

    const suites: { key: string; name: string; note: string }[] = [
      { key: "routes", name: "Workspace", note: "Sign-in, mail, calendar and admin surfaces" },
      { key: "database", name: "Storage", note: "Mail, contacts and settings storage" },
      { key: "mail", name: "Mail delivery", note: "Inbound and outbound mail" },
      { key: "ownership", name: "Domain authentication", note: "MX, SPF, DKIM and DMARC" },
      { key: "speed", name: "Performance", note: "Response times against our published budgets" },
    ];

    let components = suites.map((s) => ({ name: s.name, state: "operational" as const, note: s.note }));
    if (latest) {
      const { data: checks } = await db.from("release_checks").select("suite, status").eq("run_id", latest.id);
      const rows = (checks ?? []) as { suite: string; status: string }[];
      components = suites.map((s) => {
        const mine = rows.filter((c) => c.suite === s.key);
        const failed = mine.filter((c) => c.status === "fail").length;
        const warned = mine.filter((c) => c.status === "warn").length;
        return {
          name: s.name,
          state: failed > 0 ? ("down" as const) : warned > 0 ? ("degraded" as const) : ("operational" as const),
          note: s.note,
        };
      });
    }

    const worst = components.some((c) => c.state === "down")
      ? "down"
      : components.some((c) => c.state === "degraded")
        ? "degraded"
        : "operational";

    let lastIncident: { title: string; started_at: string; resolved_at: string | null } | null = null;
    const { data: incidents } = await db
      .from("incidents")
      .select("title, started_at, resolved_at")
      .order("started_at", { ascending: false })
      .limit(1);
    const inc = (incidents ?? [])[0] as any;
    if (inc) lastIncident = { title: inc.title, started_at: inc.started_at, resolved_at: inc.resolved_at ?? null };

    res.json({
      state: worst,
      updated_at: latest?.finished_at ?? new Date().toISOString(),
      components,
      last_incident: lastIncident,
    });
  } catch (e) {
    // Status page kabhi 500 na de — warna outage ke waqt hi ghayab ho jayega.
    res.json({
      state: "degraded",
      updated_at: new Date().toISOString(),
      components: [{ name: "Status feed", state: "degraded", note: "Health data temporarily unavailable" }],
      last_incident: null,
    });
  }
});

/* ---------------------------- offline outbox ----------------------------- */

outboxRouter.post("/outbox/send", async (req, res) => {
  const user = await requireUser(req, res);
  if (!user) return;
  const key = String(req.headers["idempotency-key"] || req.body?.idempotency_key || "");
  const to = String(req.body?.to || "").trim();
  const subject = String(req.body?.subject || "");
  const body = String(req.body?.body || "");
  if (!key || !to) {
    return res.status(400).json({ error: "bad_request", detail: "idempotency_key + to required" });
  }
  try {
    // Duplicate send guard — same key = same result, kabhi do mail nahi.
    const { data: existing } = await db!
      .from("mail_outbox")
      .select("id, state, sent_at")
      .eq("idempotency_key", key)
      .limit(1);
    const found = (existing ?? [])[0] as any;
    if (found) {
      return res.json({ id: found.id, state: found.state, sent_at: found.sent_at ?? null, duplicate: true });
    }

    const { data, error } = await db!
      .from("mail_outbox")
      .insert({
        user_id: user.id,
        idempotency_key: key,
        to_address: to,
        subject,
        body,
        thread_id: req.body?.thread_id ? String(req.body.thread_id) : null,
        state: "queued",
        attempts: 0,
      })
      .select()
      .single();
    if (error) return fail(res, error);

    // Hand-off to the mail pipeline. State "sent" sirf pipeline confirm par —
    // hum client ko jhoota "sent" kabhi nahi dete.
    res.json({ id: data.id, state: data.state, sent_at: data.sent_at ?? null, duplicate: false });
  } catch (e) {
    fail(res, e);
  }
});

export default publicRouter;
export { founderRouter as founderReleaseRouter, outboxRouter };
