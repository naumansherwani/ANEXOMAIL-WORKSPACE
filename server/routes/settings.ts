// ANEXOMAIL — Phase 23: Settings Center API (Server 2 / Brain, port 3100)
// Repo copy: /opt/anexomail/src/routes/settings.ts (nano overwrite)
//
// 6 advance features: Time Machine · Explain (Leo cache) · Blast radius
//                     · Drift baseline · Scheduled change + auto-rollback · Dry-run simulate
// Env naam locked: SUPABASE4_URL / SUPABASE4_SERVICE_ROLE_KEY (fallback SUPABASE_*).
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
  console.error("settings: SUPABASE4_URL / SUPABASE4_SERVICE_ROLE_KEY missing — routes will 503");
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

const SCOPES = ["personal", "workspace", "appearance", "notifications", "privacy", "ai"];

/** table missing ho to 0 — poora endpoint nahi girta. */
async function safeCount(table: string): Promise<number> {
  try {
    const { count, error } = await db!.from(table).select("id", { count: "exact", head: true });
    if (error) return 0;
    return count ?? 0;
  } catch {
    return 0;
  }
}

function driftOf(def: any, value: string | null): "aligned" | "loose" | "risky" | null {
  if (def.recommended == null) return null;
  const current = value ?? def.default_value;
  if (String(current) === String(def.recommended)) return "aligned";
  // recommended `true` se hat kar off karna = risky, warna sirf loose.
  return String(def.recommended) === "true" ? "risky" : "loose";
}

async function defsFor(scope?: string) {
  let q = db!
    .from("setting_defs")
    .select("key,scope,label,help,kind,default_value,recommended,options,affects,reversible");
  if (scope) q = q.eq("scope", scope);
  return q;
}

async function valuesOf(uid: string) {
  const { data } = await db!
    .from("setting_values")
    .select("key,value,updated_at,updated_by")
    .eq("user_id", uid);
  const map = new Map<string, any>();
  for (const row of data ?? []) map.set(row.key, row);
  return map;
}

// ---- 1. list settings per scope ----
const listScope = async (req: any, res: any) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  const scope = String(req.params.scope);
  if (!SCOPES.includes(scope)) return res.status(404).json({ error: "unknown_scope" });

  const { data: defs, error } = await defsFor(scope);
  if (error) return fail(res, error);
  const vals = await valuesOf(uid);

  const settings = (defs ?? []).map((d: any) => {
    const v = vals.get(d.key);
    const value = v?.value ?? d.default_value ?? null;
    return {
      key: d.key,
      scope: d.scope,
      label: d.label,
      help: d.help,
      kind: d.kind,
      value,
      default_value: d.default_value ?? null,
      options: d.options ?? null,
      locked_by_policy: null,
      drift: driftOf(d, v?.value ?? null),
      updated_at: v?.updated_at ?? null,
      updated_by: v?.updated_by ?? null,
    };
  });
  res.json({ settings });
};

// frontend `/api/settings/:scope` maangta hai; specific routes neeche register hone
// se pehle define nahi kar sakte, is liye `/:scope` sab ke BAAD file ke aakhir mein hai.
router.get("/scoped/:scope", listScope);

// ---- 2. blast radius (save se PEHLE sach) ----
router.get("/blast-radius", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  const key = String(req.query.key || "");
  const { data: def, error } = await db!
    .from("setting_defs")
    .select("key,affects,reversible,risk_if_off,scope")
    .eq("key", key)
    .maybeSingle();
  if (error) return fail(res, error);
  if (!def) return res.status(404).json({ error: "unknown_setting" });

  const affects: string[] = def.affects ?? [];
  const members = affects.includes("members") ? await safeCount("org_members") : 0;
  const mailboxes = affects.includes("mailboxes") ? await safeCount("mailboxes") : 0;
  const automations = affects.includes("ai") || affects.includes("outbox") ? await safeCount("automation_rules") : 0;

  const weight = members + mailboxes + automations;
  const severity = !def.reversible || weight > 20 ? "high" : weight > 0 ? "medium" : "low";
  const breaks: string[] = [];
  if (!def.reversible) breaks.push("Yeh change wapas nahi ho sakta — permanent hai.");
  if (def.risk_if_off) breaks.push(def.risk_if_off);
  if (affects.includes("compose")) breaks.push("Compose ke send checks badal jayenge.");
  if (affects.includes("outbox")) breaks.push("Pehle se queued mail par asar hoga.");

  res.json({
    key,
    members_affected: members,
    mailboxes_affected: mailboxes,
    automations_affected: automations,
    severity,
    breaks,
    reversible: Boolean(def.reversible),
  });
});

// ---- 3. explain this setting (Leo cache, warna server fallback) ----
router.get("/explain", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  const key = String(req.query.key || "");
  const { data: cached } = await db!
    .from("setting_explanations")
    .select("key,plain,example,tradeoff,source")
    .eq("key", key)
    .maybeSingle();
  if (cached) return res.json(cached);

  const { data: def } = await db!
    .from("setting_defs")
    .select("key,label,help,recommended,risk_if_off,affects")
    .eq("key", key)
    .maybeSingle();
  if (!def) return res.status(404).json({ error: "unknown_setting" });

  res.json({
    key,
    plain: def.help,
    example:
      (def.affects ?? []).length > 0
        ? `Asar yahan hoga: ${(def.affects as string[]).join(", ")}.`
        : "Sirf tumhare account par asar hoga.",
    tradeoff: def.risk_if_off ?? null,
    source: "server",
  });
});

// ---- 4. dry-run simulate (koi write nahi) ----
router.post("/simulate", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  const { key, value } = req.body ?? {};
  if (!key) return res.status(400).json({ error: "key_required" });

  const { data: def } = await db!
    .from("setting_defs")
    .select("key,kind,options,recommended,reversible,risk_if_off,affects")
    .eq("key", key)
    .maybeSingle();
  if (!def) return res.status(404).json({ error: "unknown_setting" });

  const warnings: string[] = [];
  const str = String(value);
  if (def.kind === "toggle" && !["true", "false"].includes(str)) warnings.push("Toggle sirf true/false leta hai.");
  if (def.kind === "number" && Number.isNaN(Number(str))) warnings.push("Number chahiye.");
  if (def.kind === "choice" && Array.isArray(def.options)) {
    const allowed = (def.options as any[]).map((o) => String(o.value));
    if (!allowed.includes(str)) warnings.push(`Allowed: ${allowed.join(", ")}`);
  }
  if (def.recommended != null && String(def.recommended) !== str)
    warnings.push("Yeh recommended baseline se hat raha hai.");
  if (!def.reversible) warnings.push("Irreversible change — revert available nahi hoga.");

  let blast: any = null;
  try {
    const affects: string[] = def.affects ?? [];
    const members = affects.includes("members") ? await safeCount("org_members") : 0;
    const mailboxes = affects.includes("mailboxes") ? await safeCount("mailboxes") : 0;
    const automations = affects.includes("ai") || affects.includes("outbox") ? await safeCount("automation_rules") : 0;
    blast = {
      key,
      members_affected: members,
      mailboxes_affected: mailboxes,
      automations_affected: automations,
      severity: !def.reversible || members + mailboxes + automations > 20 ? "high" : "medium",
      breaks: def.risk_if_off ? [def.risk_if_off] : [],
      reversible: Boolean(def.reversible),
    };
  } catch {
    blast = null;
  }

  res.json({ ok: warnings.length === 0, warnings, blast });
});

// ---- 5. save (Time Machine version + blast snapshot) ----
async function writeSetting(uid: string, key: string, value: string, reason: string | null, by: string) {
  const { data: def } = await db!
    .from("setting_defs")
    .select("key,scope,label,help,kind,default_value,recommended,options,affects,reversible")
    .eq("key", key)
    .maybeSingle();
  if (!def) return { error: { message: "unknown_setting" } } as any;

  const { data: prev } = await db!
    .from("setting_values")
    .select("value")
    .eq("user_id", uid)
    .eq("key", key)
    .maybeSingle();

  const { data: saved, error } = await db!
    .from("setting_values")
    .upsert(
      { user_id: uid, key, value, updated_at: new Date().toISOString(), updated_by: by },
      { onConflict: "user_id,key" },
    )
    .select("key,value,updated_at,updated_by")
    .single();
  if (error) return { error } as any;

  await db!.from("setting_versions").insert({
    user_id: uid,
    key,
    from_value: prev?.value ?? null,
    to_value: value,
    changed_by: by,
    reason,
    blast: { affects: def.affects ?? [], reversible: def.reversible },
  });

  return {
    setting: {
      key: def.key,
      scope: def.scope,
      label: def.label,
      help: def.help,
      kind: def.kind,
      value: saved.value,
      default_value: def.default_value ?? null,
      options: def.options ?? null,
      locked_by_policy: null,
      drift: driftOf(def, saved.value),
      updated_at: saved.updated_at,
      updated_by: saved.updated_by,
    },
  } as any;
}

router.post("/save", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  const { key, value, reason } = req.body ?? {};
  if (!key) return res.status(400).json({ error: "key_required" });
  const out = await writeSetting(uid, String(key), String(value), reason ? String(reason) : null, "self");
  if (out.error) return out.error.message === "unknown_setting"
    ? res.status(404).json({ error: "unknown_setting" })
    : fail(res, out.error);
  res.json(out.setting);
});

// ---- 6. Time Machine: history + revert ----
router.get("/history", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  let q = db!
    .from("setting_versions")
    .select("id,key,from_value,to_value,changed_by,changed_at,reason,reverted")
    .eq("user_id", uid)
    .order("changed_at", { ascending: false })
    .limit(200);
  if (req.query.key) q = q.eq("key", String(req.query.key));
  const { data, error } = await q;
  if (error) return fail(res, error);
  res.json({ versions: data ?? [] });
});

router.post("/revert", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  const versionId = String(req.body?.version_id || "");
  if (!versionId) return res.status(400).json({ error: "version_id_required" });

  const { data: ver, error } = await db!
    .from("setting_versions")
    .select("id,key,from_value")
    .eq("user_id", uid)
    .eq("id", versionId)
    .maybeSingle();
  if (error) return fail(res, error);
  if (!ver) return res.status(404).json({ error: "unknown_version" });

  const out = await writeSetting(uid, ver.key, String(ver.from_value ?? ""), `revert of ${ver.id}`, "revert");
  if (out.error) return fail(res, out.error);
  await db!.from("setting_versions").update({ reverted: true }).eq("id", ver.id).eq("user_id", uid);
  res.json(out.setting);
});

// ---- 7. drift baseline ----
router.get("/drift", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  const { data: defs, error } = await defsFor();
  if (error) return fail(res, error);
  const vals = await valuesOf(uid);

  let aligned = 0;
  let loose = 0;
  let risky = 0;
  const items: any[] = [];
  for (const d of defs ?? []) {
    const drift = driftOf(d, vals.get(d.key)?.value ?? null);
    if (drift === "aligned") aligned += 1;
    else if (drift === "loose") {
      loose += 1;
      items.push({ key: d.key, label: d.label, drift, recommended: String(d.recommended) });
    } else if (drift === "risky") {
      risky += 1;
      items.push({ key: d.key, label: d.label, drift, recommended: String(d.recommended) });
    }
  }
  const scored = aligned + loose + risky;
  const score = scored === 0 ? 100 : Math.max(0, Math.round(((aligned + loose * 0.5) / scored) * 100));
  res.json({ score, aligned, loose, risky, items });
});

// ---- 8. scheduled change + auto-rollback ----
router.get("/scheduled", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  await runDueSchedules(uid);
  const { data, error } = await db!
    .from("setting_schedules")
    .select("id,key,to_value,apply_at,auto_rollback_minutes,state,requested_by")
    .eq("user_id", uid)
    .order("apply_at", { ascending: true })
    .limit(100);
  if (error) return fail(res, error);
  res.json({ changes: data ?? [] });
});

router.post("/schedule", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  const { key, to_value, apply_at, auto_rollback_minutes } = req.body ?? {};
  if (!key || to_value === undefined || !apply_at)
    return res.status(400).json({ error: "key_to_value_apply_at_required" });

  const { data, error } = await db!
    .from("setting_schedules")
    .insert({
      user_id: uid,
      key: String(key),
      to_value: String(to_value),
      apply_at: new Date(String(apply_at)).toISOString(),
      auto_rollback_minutes: auto_rollback_minutes ? Number(auto_rollback_minutes) : null,
      requested_by: "self",
    })
    .select("id,key,to_value,apply_at,auto_rollback_minutes,state,requested_by")
    .single();
  if (error) return fail(res, error);
  res.json(data);
});

router.post("/schedule/cancel", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  const id = String(req.body?.id || "");
  if (!id) return res.status(400).json({ error: "id_required" });
  const { data, error } = await db!
    .from("setting_schedules")
    .update({ state: "cancelled" })
    .eq("user_id", uid)
    .eq("id", id)
    .eq("state", "scheduled")
    .select("id,key,to_value,apply_at,auto_rollback_minutes,state,requested_by")
    .maybeSingle();
  if (error) return fail(res, error);
  if (!data) return res.status(404).json({ error: "not_scheduled" });
  res.json(data);
});

/**
 * SERVER BUDGET RULE: koi in-process cron nahi. Due schedules request ke waqt
 * apply hote hain (aur auto-rollback window guzar jaye to wapas).
 */
async function runDueSchedules(uid: string) {
  const now = new Date();
  const { data: due } = await db!
    .from("setting_schedules")
    .select("id,key,to_value,apply_at,auto_rollback_minutes,state,applied_at")
    .eq("user_id", uid)
    .in("state", ["scheduled", "applied"])
    .lte("apply_at", now.toISOString())
    .limit(20);

  for (const s of due ?? []) {
    if (s.state === "scheduled") {
      const out = await writeSetting(uid, s.key, String(s.to_value), `scheduled ${s.id}`, "schedule");
      if (!out.error) {
        await db!
          .from("setting_schedules")
          .update({ state: "applied", applied_at: now.toISOString() })
          .eq("id", s.id);
      }
      continue;
    }
    if (s.state === "applied" && s.auto_rollback_minutes && s.applied_at) {
      const deadline = new Date(new Date(s.applied_at).getTime() + s.auto_rollback_minutes * 60_000);
      if (now >= deadline) {
        const { data: ver } = await db!
          .from("setting_versions")
          .select("from_value")
          .eq("user_id", uid)
          .eq("key", s.key)
          .order("changed_at", { ascending: false })
          .limit(1)
          .maybeSingle();
        await writeSetting(uid, s.key, String(ver?.from_value ?? ""), `auto-rollback ${s.id}`, "auto-rollback");
        await db!
          .from("setting_schedules")
          .update({
            state: "rolled_back",
            rolled_back_at: now.toISOString(),
            rollback_reason: "auto-rollback window expired",
          })
          .eq("id", s.id);
      }
    }
  }
}

// ---- 9. founder founder view ----
founderRouter.get("/settings/overview", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  const since24 = new Date(Date.now() - 24 * 3600_000).toISOString();
  const since7 = new Date(Date.now() - 7 * 24 * 3600_000).toISOString();

  const [{ count: changes24h }, { count: reverts7d }, { count: pending }] = await Promise.all([
    db!.from("setting_versions").select("id", { count: "exact", head: true }).gte("changed_at", since24),
    db!
      .from("setting_versions")
      .select("id", { count: "exact", head: true })
      .eq("reverted", true)
      .gte("changed_at", since7),
    db!.from("setting_schedules").select("id", { count: "exact", head: true }).eq("state", "scheduled"),
  ]);

  const { data: recent } = await db!
    .from("setting_versions")
    .select("key,user_id")
    .gte("changed_at", since7)
    .limit(2000);

  const byKey = new Map<string, number>();
  const tenants = new Set<string>();
  for (const r of recent ?? []) {
    byKey.set(r.key, (byKey.get(r.key) ?? 0) + 1);
    if (r.user_id) tenants.add(r.user_id);
  }
  const most_changed = [...byKey.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 8)
    .map(([key, changes]) => ({ key, changes }));

  res.json({
    tenants: tenants.size,
    changes_24h: changes24h ?? 0,
    reverts_7d: reverts7d ?? 0,
    risky_tenants: [],
    most_changed,
    pending_scheduled: pending ?? 0,
  });
});

router.get("/:scope", listScope);

export default router;
export { founderRouter as founderSettingsRouter };
