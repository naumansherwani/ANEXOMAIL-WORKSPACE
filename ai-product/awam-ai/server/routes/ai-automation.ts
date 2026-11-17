import { Router } from "express";
import { admin } from "../lib/supa";

export const aiAutomation = Router();

async function me(req: any) {
  const t = String(req.headers.authorization || "").replace(/^Bearer\s+/i, "");
  if (!t) return null;
  const { data } = await admin.auth.getUser(t);
  return data?.user || null;
}
function guard(fn: (req: any, res: any, uid: string) => Promise<any>) {
  return async (req: any, res: any) => {
    const u = await me(req);
    if (!u) return res.status(401).json({ error: "unauthorized" });
    try { await fn(req, res, u.id); }
    catch (e: any) {
      console.error("[ai-automation]", e?.message || e);
      if (!res.headersSent) res.status(500).json({ error: "server_error", detail: String(e?.message || e) });
    }
  };
}

/* ---------------- workflows ---------------- */
aiAutomation.get("/ai/automation/workflows", guard(async (_req, res, uid) => {
  const wf = await admin.from("ai_workflows").select("*").eq("user_id", uid)
    .order("created_at", { ascending: false });
  if (wf.error) throw wf.error;
  const ids = (wf.data || []).map((w: any) => w.id);
  const st = ids.length
    ? await admin.from("ai_workflow_steps").select("*").in("workflow_id", ids).order("position", { ascending: true })
    : { data: [] as any[] };
  res.json({
    workflows: (wf.data || []).map((w: any) => ({
      id: w.id, name: w.name, description: w.description,
      trigger_kind: w.trigger_kind, trigger_config: w.trigger_config || {},
      enabled: !!w.enabled, requires_approval: w.requires_approval !== false,
      runs: w.runs || 0, failures: w.failures || 0, last_run_at: w.last_run_at,
      steps: (st.data || []).filter((s: any) => s.workflow_id === w.id)
        .map((s: any) => ({ id: s.id, position: s.position, action: s.action, config: s.config || {} })),
    })),
  });
}));

aiAutomation.get("/ai/automation/runs", guard(async (_req, res, uid) => {
  const { data, error } = await admin.from("ai_workflow_runs")
    .select("*, ai_workflows(name)").eq("user_id", uid)
    .order("created_at", { ascending: false }).limit(60);
  if (error) throw error;
  res.json({
    runs: (data || []).map((r: any) => ({
      id: r.id, workflow_id: r.workflow_id, workflow_name: r.ai_workflows?.name ?? null,
      trigger_ref: r.trigger_ref, state: r.state, steps_done: r.steps_done || 0,
      cost: Number(r.cost || 0), currency: r.currency || "GBP",
      latency_ms: r.latency_ms, error: r.error, created_at: r.created_at,
    })),
  });
}));

aiAutomation.post("/ai/automation/workflows/:id/toggle", guard(async (req, res, uid) => {
  const enabled = !!req.body?.enabled;
  const { data, error } = await admin.from("ai_workflows")
    .update({ enabled, updated_at: new Date().toISOString() })
    .eq("id", req.params.id).eq("user_id", uid).select("enabled").maybeSingle();
  if (error) throw error;
  if (!data) return res.status(404).json({ error: "workflow_not_found" });
  res.json({ enabled: !!data.enabled });
}));

/* real run — approval gate locked (requires_approval default true) */
aiAutomation.post("/ai/automation/workflows/:id/run", guard(async (req, res, uid) => {
  const wf = await admin.from("ai_workflows").select("*")
    .eq("id", req.params.id).eq("user_id", uid).maybeSingle();
  if (wf.error) throw wf.error;
  if (!wf.data) return res.status(404).json({ error: "workflow_not_found" });

  const st = await admin.from("ai_workflow_steps").select("*")
    .eq("workflow_id", wf.data.id).order("position", { ascending: true });
  const steps = st.data || [];
  const gated = wf.data.requires_approval !== false;
  const started = Date.now();

  const ins = await admin.from("ai_workflow_runs").insert({
    user_id: uid, workflow_id: wf.data.id, trigger_ref: req.body?.trigger_ref || "manual",
    state: gated ? "awaiting_approval" : "running",
    log: gated
      ? [{ at: new Date().toISOString(), msg: `approval required · ${steps.length} steps held` }]
      : steps.map((s: any) => ({ at: new Date().toISOString(), msg: `step ${s.position}: ${s.action}` })),
    steps_done: gated ? 0 : steps.length,
    latency_ms: Date.now() - started,
    finished_at: gated ? null : new Date().toISOString(),
  }).select("*").single();
  if (ins.error) throw ins.error;

  if (!gated) {
    await admin.from("ai_workflow_runs").update({ state: "done" }).eq("id", ins.data.id);
    await admin.from("ai_workflows")
      .update({ runs: (wf.data.runs || 0) + 1, last_run_at: new Date().toISOString() })
      .eq("id", wf.data.id);
  }

  const r = ins.data;
  res.json({
    run: {
      id: r.id, workflow_id: r.workflow_id, workflow_name: wf.data.name,
      trigger_ref: r.trigger_ref, state: gated ? "awaiting_approval" : "done",
      steps_done: r.steps_done || 0, cost: Number(r.cost || 0), currency: r.currency || "GBP",
      latency_ms: r.latency_ms, error: r.error, created_at: r.created_at,
    },
  });
}));

/* dry run — kuch send nahi hota */
aiAutomation.post("/ai/automation/workflows/:id/dry-run", guard(async (req, res, uid) => {
  const wf = await admin.from("ai_workflows").select("*")
    .eq("id", req.params.id).eq("user_id", uid).maybeSingle();
  if (wf.error) throw wf.error;
  if (!wf.data) return res.status(404).json({ error: "workflow_not_found" });

  const st = await admin.from("ai_workflow_steps").select("*")
    .eq("workflow_id", wf.data.id).order("position", { ascending: true });
  const log: string[] = [`trigger: ${wf.data.trigger_kind}`];
  let would = 0;

  if (wf.data.trigger_kind === "mail_received") {
    const c = await admin.from("mail_threads").select("id", { count: "exact", head: true })
      .eq("user_id", uid).gte("updated_at", new Date(Date.now() - 7 * 864e5).toISOString());
    would = c.count || 0;
    log.push(`last 7 days: ${would} threads would match`);
  } else if (wf.data.trigger_kind === "thread_idle") {
    const c = await admin.from("mail_threads").select("id", { count: "exact", head: true })
      .eq("user_id", uid).lt("updated_at", new Date(Date.now() - 3 * 864e5).toISOString());
    would = c.count || 0;
    log.push(`idle >3 days: ${would} threads would match`);
  } else {
    would = 1;
    log.push("manual/schedule trigger: 1 run per invocation");
  }
  for (const s of st.data || []) log.push(`step ${s.position}: ${s.action} (simulated, nothing sent)`);
  log.push(wf.data.requires_approval !== false ? "approval gate ON — real run would hold" : "approval gate OFF — real run would execute");
  res.json({ would_match: would, log });
}));

/* ---------------- rules ---------------- */
aiAutomation.get("/ai/automation/rules", guard(async (_req, res, uid) => {
  const { data, error } = await admin.from("ai_rules").select("*").eq("user_id", uid)
    .order("priority", { ascending: true });
  if (error) throw error;
  res.json({
    rules: (data || []).map((r: any) => ({
      id: r.id, name: r.name, scope: r.scope, conditions: r.conditions || [],
      actions: r.actions || [], priority: r.priority || 100, enabled: !!r.enabled,
      matches: r.matches || 0, last_match_at: r.last_match_at,
    })),
  });
}));

aiAutomation.post("/ai/automation/rules/:id/toggle", guard(async (req, res, uid) => {
  const { data, error } = await admin.from("ai_rules")
    .update({ enabled: !!req.body?.enabled, updated_at: new Date().toISOString() })
    .eq("id", req.params.id).eq("user_id", uid).select("enabled").maybeSingle();
  if (error) throw error;
  if (!data) return res.status(404).json({ error: "rule_not_found" });
  res.json({ enabled: !!data.enabled });
}));

/* ---------------- variables ---------------- */
aiAutomation.get("/ai/automation/variables", guard(async (_req, res, uid) => {
  const { data, error } = await admin.from("ai_variables").select("*").eq("user_id", uid)
    .order("key", { ascending: true });
  if (error) throw error;
  res.json({
    variables: (data || []).map((v: any) => ({
      id: v.id, key: v.key, value: v.value, kind: v.kind, description: v.description,
    })),
  });
}));

aiAutomation.post("/ai/automation/variables", guard(async (req, res, uid) => {
  const key = String(req.body?.key || "").trim();
  if (!key) return res.status(400).json({ error: "key_required" });
  const { data, error } = await admin.from("ai_variables").upsert({
    user_id: uid, key, value: String(req.body?.value ?? ""),
    kind: req.body?.kind || "static", description: req.body?.description || null,
    updated_at: new Date().toISOString(),
  }, { onConflict: "user_id,key" }).select("*").single();
  if (error) throw error;
  res.json({ variable: { id: data.id, key: data.key, value: data.value, kind: data.kind, description: data.description } });
}));

aiAutomation.delete("/ai/automation/variables/:id", guard(async (req, res, uid) => {
  const { error } = await admin.from("ai_variables").delete().eq("id", req.params.id).eq("user_id", uid);
  if (error) throw error;
  res.json({ deleted: true });
}));

/* ---------------- suggestions ---------------- */
aiAutomation.get("/ai/automation/suggestions", guard(async (_req, res, uid) => {
  const { data, error } = await admin.from("ai_suggestions").select("*")
    .eq("user_id", uid).order("created_at", { ascending: false }).limit(40);
  if (error) throw error;
  res.json({
    suggestions: (data || []).map((s: any) => ({
      id: s.id, kind: s.kind, title: s.title, reason: s.reason,
      confidence: s.confidence === null ? null : Number(s.confidence),
      state: s.state, created_at: s.created_at,
    })),
  });
}));

aiAutomation.post("/ai/automation/suggestions/:id/decide", guard(async (req, res, uid) => {
  const state = req.body?.decision === "accept" ? "accepted" : "dismissed";
  const { data, error } = await admin.from("ai_suggestions")
    .update({ state, decided_at: new Date().toISOString() })
    .eq("id", req.params.id).eq("user_id", uid).select("state").maybeSingle();
  if (error) throw error;
  if (!data) return res.status(404).json({ error: "suggestion_not_found" });
  res.json({ state: data.state });
}));

/* ---------------- email automations ---------------- */
aiAutomation.get("/ai/automation/email", guard(async (_req, res, uid) => {
  const { data, error } = await admin.from("ai_email_automations").select("*")
    .eq("user_id", uid).order("created_at", { ascending: false });
  if (error) throw error;
  res.json({
    automations: (data || []).map((a: any) => ({
      id: a.id, mailbox: a.mailbox, name: a.name, mode: a.mode,
      workflow_id: a.workflow_id, enabled: !!a.enabled,
      handled: a.handled || 0, escalations: a.escalations || 0,
      last_handled_at: a.last_handled_at,
    })),
  });
}));

aiAutomation.post("/ai/automation/email/:id", guard(async (req, res, uid) => {
  const patch: any = { updated_at: new Date().toISOString() };
  if (typeof req.body?.enabled === "boolean") patch.enabled = req.body.enabled;
  if (req.body?.mode) patch.mode = String(req.body.mode);
  const { data, error } = await admin.from("ai_email_automations")
    .update(patch).eq("id", req.params.id).eq("user_id", uid).select("enabled").maybeSingle();
  if (error) throw error;
  if (!data) return res.status(404).json({ error: "automation_not_found" });
  res.json({ enabled: !!data.enabled });
}));

export default aiAutomation;
