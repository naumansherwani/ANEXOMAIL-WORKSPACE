// ANEXOMAIL — Phase 22: Integrations Platform API (Server 2 / Brain, port 3100)
// Repo copy: /opt/anexomail/src/routes/integrations.ts (nano overwrite)
//
// NO API / NO WEBHOOK RULE: koi public key, koi webhook endpoint nahi.
// NO MOCK: jo wired nahi, wo 501 { error: "not_implemented" } deta hai.
//
// CRASH FIX (Phase 22): is server par Supabase #4 ke env naam
// SUPABASE4_URL / SUPABASE4_SERVICE_ROLE_KEY hain. Pehle version SUPABASE_URL
// maang raha tha -> undefined -> createClient boot par throw -> poora Brain crash
// (port 3100 dead, curl 000). Ab dono naam chalte hain aur missing hone par
// process crash nahi karta: sirf yeh router 503 deta hai.
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
  console.error("integrations: SUPABASE4_URL / SUPABASE4_SERVICE_ROLE_KEY missing — routes will 503");
}

const router = Router();

const fail = (res: any, e: any) =>
  res.status(500).json({ error: "db_error", detail: String(e?.message || e) });

// ---- auth: har route Bearer token se guarded ----
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

// ---- 1. providers ----
router.get("/providers", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  const { data, error } = await db!
    .from("integration_providers")
    .select("id,label,kind,can_migrate,can_sync,can_send,notes,available")
    .order("sort_order", { ascending: true });
  if (error) return fail(res, error);
  res.json({ providers: data ?? [] });
});

// ---- 2. connections ----
router.get("/connections", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  const { data, error } = await db!
    .from("integration_connections")
    .select("id,provider,account,state,scopes,last_sync_at,synced_threads,error,created_at")
    .eq("user_id", uid)
    .order("created_at", { ascending: false });
  if (error) return fail(res, error);
  res.json({ connections: data ?? [] });
});

router.post("/connect", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  const { provider, account, host, port } = req.body || {};
  if (!provider) return res.status(400).json({ error: "provider_required" });

  const { data: p, error: pe } = await db!
    .from("integration_providers")
    .select("id,kind,available")
    .eq("id", provider)
    .maybeSingle();
  if (pe) return fail(res, pe);
  if (!p || !p.available) return res.status(400).json({ error: "provider_unavailable" });

  // OAuth flows (Google/Microsoft/Zoho) client credentials ke bagair start nahi hote.
  // Honest 501 — koi fake connection nahi.
  if (p.kind === "oauth") {
    return res
      .status(501)
      .json({ error: "not_implemented", detail: `${provider} oauth client pending` });
  }

  if (!account) return res.status(400).json({ error: "account_required" });
  const { data, error } = await db!
    .from("integration_connections")
    .upsert(
      {
        user_id: uid,
        provider,
        account,
        host: host ?? null,
        port: port ?? null,
        state: "needs_reauth", // credentials server vault se aayenge, request body se nahi
        updated_at: new Date().toISOString(),
      },
      { onConflict: "user_id,provider,account" },
    )
    .select("id,state")
    .single();
  if (error) return fail(res, error);
  res.json({ id: data.id, state: data.state, redirect_url: null });
});

router.post("/disconnect", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  const { id } = req.body || {};
  if (!id) return res.status(400).json({ error: "id_required" });
  const { error } = await db!
    .from("integration_connections")
    .delete()
    .eq("user_id", uid)
    .eq("id", id);
  if (error) return fail(res, error);
  res.json({ ok: true });
});

// ---- 3. migrations ----
const JOB_COLS =
  "id,provider,source_account,target_mailbox,state,mode,total,done,failed,eta_minutes,started_at,finished_at,last_error";

router.get("/migrations", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  const { data, error } = await db!
    .from("integration_migrations")
    .select(JOB_COLS)
    .eq("user_id", uid)
    .order("created_at", { ascending: false })
    .limit(50);
  if (error) return fail(res, error);
  res.json({ jobs: data ?? [] });
});

router.post("/migrations", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  const { connection_id, target_mailbox, mode } = req.body || {};
  if (!connection_id || !target_mailbox)
    return res.status(400).json({ error: "connection_and_target_required" });

  const { data: conn, error: ce } = await db!
    .from("integration_connections")
    .select("id,provider,account")
    .eq("user_id", uid)
    .eq("id", connection_id)
    .maybeSingle();
  if (ce) return fail(res, ce);
  if (!conn) return res.status(404).json({ error: "connection_not_found" });

  const { data, error } = await db!
    .from("integration_migrations")
    .insert({
      user_id: uid,
      connection_id: conn.id,
      provider: conn.provider,
      source_account: conn.account,
      target_mailbox,
      mode: mode === "mirror" ? "mirror" : "copy",
      state: "queued",
    })
    .select(JOB_COLS)
    .single();
  if (error) return fail(res, error);
  res.json(data);
});

router.post("/migrations/control", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  const { id, action } = req.body || {};
  const map: Record<string, any> = {
    pause: { state: "paused" },
    resume: { state: "queued" },
    retry: { state: "queued", last_error: null },
    cancel: {
      state: "failed",
      last_error: "cancelled by user",
      finished_at: new Date().toISOString(),
    },
  };
  if (!id || !map[action]) return res.status(400).json({ error: "bad_request" });
  const { data, error } = await db!
    .from("integration_migrations")
    .update(map[action])
    .eq("user_id", uid)
    .eq("id", id)
    .select(JOB_COLS)
    .maybeSingle();
  if (error) return fail(res, error);
  if (!data) return res.status(404).json({ error: "job_not_found" });
  res.json(data);
});

// ---- 4. delivery proof (ownership pillar) ----
router.get("/delivery/health", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  const domain = String(req.query.domain || "anexomail.com");
  const [checks, lists] = await Promise.all([
    db!.from("delivery_checks").select("key,state,detail,fix,checked_at").eq("domain", domain),
    db!.from("delivery_blocklists").select("name,listed").eq("domain", domain),
  ]);
  if (checks.error) return fail(res, checks.error);
  const rows = checks.data ?? [];
  const ok = rows.filter((r: any) => r.state === "ok").length;
  const score = rows.length ? Math.round((ok / rows.length) * 100) : 0;
  res.json({
    domain,
    score,
    checks: rows,
    blocklists: lists.data ?? [],
    reputation:
      rows.length === 0 ? "unknown" : score >= 90 ? "good" : score >= 70 ? "watch" : "poor",
  });
});

// ---- 5. exports (User Freedom: no lock-in) ----
router.get("/exports", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  const { data, error } = await db!
    .from("integration_exports")
    .select("id,scope,format,state,size_bytes,url,expires_at,created_at")
    .eq("user_id", uid)
    .order("created_at", { ascending: false })
    .limit(30);
  if (error) return fail(res, error);
  res.json({ jobs: data ?? [] });
});

router.post("/exports", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  const scope = String(req.body?.scope || "everything");
  const format = String(req.body?.format || "mbox");
  if (!["mail", "calendar", "contacts", "everything"].includes(scope))
    return res.status(400).json({ error: "bad_scope" });
  if (!["mbox", "eml", "ics", "csv", "json"].includes(format))
    return res.status(400).json({ error: "bad_format" });
  const { data, error } = await db!
    .from("integration_exports")
    .insert({ user_id: uid, scope, format, state: "queued" })
    .select("id,scope,format,state,size_bytes,url,expires_at,created_at")
    .single();
  if (error) return fail(res, error);
  res.json(data);
});

// ---- 6. Leo Actions (public API ki jagah) ----
const DEFAULT_ACTIONS = [
  {
    action_key: "triage_inbox",
    label: "Triage inbox",
    target: "mail_threads",
    description: "Leo sorts new threads by urgency and promises, no reply sent.",
    requires_approval: false,
  },
  {
    action_key: "draft_replies",
    label: "Draft replies",
    target: "leo_email_drafts",
    description: "Leo drafts replies for threads waiting on you. You approve before send.",
    requires_approval: true,
  },
  {
    action_key: "thread_to_meeting",
    label: "Thread to meeting",
    target: "calendar_events",
    description: "Turns an agreed thread into a calendar event with agenda.",
    requires_approval: true,
  },
  {
    action_key: "follow_up_chase",
    label: "Chase follow-ups",
    target: "mail_outbox",
    description: "Sends the follow-up you promised if no reply lands in time.",
    requires_approval: true,
  },
];

router.get("/leo-actions", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  const rows = DEFAULT_ACTIONS.map((a) => ({ user_id: uid, ...a }));
  const seed = await db!
    .from("leo_actions")
    .upsert(rows, { onConflict: "user_id,action_key", ignoreDuplicates: true });
  if (seed.error) return fail(res, seed.error);
  const { data, error } = await db!
    .from("leo_actions")
    .select("id,label,target,description,enabled,requires_approval,runs_30d")
    .eq("user_id", uid)
    .order("label", { ascending: true });
  if (error) return fail(res, error);
  res.json({ actions: data ?? [] });
});

router.post("/leo-actions/toggle", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  const { id, enabled } = req.body || {};
  if (!id || typeof enabled !== "boolean") return res.status(400).json({ error: "bad_request" });
  const { data, error } = await db!
    .from("leo_actions")
    .update({ enabled, updated_at: new Date().toISOString() })
    .eq("user_id", uid)
    .eq("id", id)
    .select("id,label,target,description,enabled,requires_approval,runs_30d")
    .maybeSingle();
  if (error) return fail(res, error);
  if (!data) return res.status(404).json({ error: "action_not_found" });
  res.json(data);
});

// ---- 7. founder founder view ----
export const founderIntegrationsRouter = Router();
founderIntegrationsRouter.get("/integrations/overview", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  const { data, error } = await db!.rpc("founder_integrations_overview");
  if (error) return fail(res, error);
  res.json(data);
});

export default router;