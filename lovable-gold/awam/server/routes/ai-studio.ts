import { Router } from "express";
import { admin } from "../lib/supa";

export const aiStudio = Router();

/* ---------------- auth (bearer -> supabase user) ---------------- */
async function me(req: any) {
  const t = String(req.headers.authorization || "").replace(/^Bearer\s+/i, "");
  if (!t) return null;
  const { data } = await admin.auth.getUser(t);
  return data?.user || null;
}
function guard(fn: (req: any, res: any, uid: string, email: string) => Promise<any>) {
  return async (req: any, res: any) => {
    const u = await me(req);
    if (!u) return res.status(401).json({ error: "unauthorized" });
    try {
      await fn(req, res, u.id, String(u.email || ""));
    } catch (e: any) {
      console.error("[ai-studio]", e?.message || e);
      if (!res.headersSent) res.status(500).json({ error: "server_error", detail: String(e?.message || e) });
    }
  };
}

/* ---------------- model chain (OpenRouter only) ---------------- */
const MODELS = (process.env.LEO_MODEL_CHAIN ||
  "deepseek/deepseek-chat,google/gemma-2-9b-it:free")
  .split(",").map((s) => s.trim()).filter(Boolean);
const RATE_PER_1K = 0.0025; // GBP blended — display only

const SYSTEM: Record<string, string> = {
  rewrite: "Rewrite the text. Keep meaning identical. Return only the rewritten text.",
  grammar: "Fix grammar and spelling only. Never change meaning or tone. Return only corrected text.",
  translate: "Translate the text. Auto-detect source language. Return only the translation.",
  summarize: "Summarise the email thread. End with a 'Decisions:' list. Return plain text.",
  draft: "Write a first-draft email reply from the given context. Return only the email body.",
  tone: "Rewrite in the requested tone. Meaning stays locked. Return only the text.",
  meeting: "Extract meeting details. Return strict JSON: {title,start,end,attendees[],agenda[]} (ISO times).",
  tasks: "Extract commitments as tasks. Return strict JSON: {tasks:[{title,due,owner}]}.",
  template: "Turn this reply into a reusable template with {{placeholders}}. Return strict JSON: {name,subject,body}.",
};

async function runModel(tool: string, input: string, options: Record<string, string>) {
  const key = process.env.OPENROUTER_API_KEY || "";
  if (!key) throw new Error("OPENROUTER_API_KEY missing");
  const opt = Object.entries(options || {}).map(([k, v]) => `${k}=${v}`).join(", ");
  const started = Date.now();
  let lastErr = "";
  for (const model of MODELS) {
    try {
      const r = await fetch("https://openrouter.ai/api/v1/chat/completions", {
        method: "POST",
        headers: { "content-type": "application/json", authorization: `Bearer ${key}` },
        body: JSON.stringify({
          model,
          messages: [
            { role: "system", content: (SYSTEM[tool] || SYSTEM.rewrite) + (opt ? `\nOptions: ${opt}` : "") },
            { role: "user", content: String(input || "").slice(0, 24000) },
          ],
          temperature: tool === "grammar" ? 0 : 0.4,
          max_tokens: 1600,
        }),
      });
      const j: any = await r.json().catch(() => ({}));
      if (!r.ok) { lastErr = j?.error?.message || `http_${r.status}`; continue; }
      const out = j?.choices?.[0]?.message?.content || "";
      if (!out) { lastErr = "empty_completion"; continue; }
      const it = j?.usage?.prompt_tokens ?? 0;
      const ot = j?.usage?.completion_tokens ?? 0;
      return {
        output: String(out).trim(), model,
        input_tokens: it, output_tokens: ot,
        cost: Number((((it + ot) / 1000) * RATE_PER_1K).toFixed(6)),
        latency_ms: Date.now() - started,
      };
    } catch (e: any) { lastErr = e?.message || String(e); }
  }
  throw new Error(`all_models_failed: ${lastErr}`);
}

function shape(r: any) {
  return {
    id: r.id, tool: r.tool, input: r.input, output: r.output,
    options: r.options || {}, source_kind: r.source_kind, source_ref: r.source_ref,
    applied: !!r.applied, applied_to: r.applied_to, applied_ref: r.applied_ref,
    state: r.state, error: r.error,
    receipt: r.model ? {
      model: r.model, input_tokens: r.input_tokens, output_tokens: r.output_tokens,
      cost: Number(r.cost || 0), currency: r.currency || "GBP",
      ttft_ms: r.ttft_ms, latency_ms: r.latency_ms, sources: r.sources || [],
    } : null,
    guardrail: null,
    created_at: r.created_at,
  };
}

/* ---------------- reads ---------------- */
aiStudio.get("/ai/studio/runs", guard(async (req, res, uid) => {
  const tool = String(req.query.tool || "all");
  let q = admin.from("ai_studio_runs").select("*").eq("user_id", uid)
    .order("created_at", { ascending: false }).limit(60);
  if (tool && tool !== "all") q = q.eq("tool", tool);
  const { data, error } = await q;
  if (error) throw error;
  res.json({ runs: (data || []).map(shape) });
}));

aiStudio.get("/ai/studio/recipes", guard(async (_req, res, uid) => {
  const { data, error } = await admin.from("ai_studio_recipes").select("*")
    .eq("user_id", uid).order("created_at", { ascending: false });
  if (error) throw error;
  res.json({
    recipes: (data || []).map((r: any) => ({
      id: r.id, name: r.name, description: r.description,
      steps: r.steps || [], runs: r.runs || 0, last_run_at: r.last_run_at,
    })),
  });
}));

aiStudio.get("/ai/studio/batches", guard(async (_req, res, uid) => {
  const { data, error } = await admin.from("ai_studio_batches").select("*")
    .eq("user_id", uid).order("created_at", { ascending: false }).limit(30);
  if (error) throw error;
  res.json({
    batches: (data || []).map((b: any) => ({
      id: b.id, tool: b.tool, total: b.total || 0, done: b.done || 0,
      failed: b.failed || 0, cost: Number(b.cost || 0),
      currency: b.currency || "GBP", state: b.state, created_at: b.created_at,
    })),
  });
}));

/* targets = asli threads + drafts (koi dummy nahi) */
aiStudio.get("/ai/studio/targets", guard(async (_req, res, uid) => {
  const targets: any[] = [];
  const th = await admin.from("mail_threads").select("id,subject,updated_at")
    .eq("user_id", uid).order("updated_at", { ascending: false }).limit(25);
  for (const t of th.data || []) targets.push({ kind: "thread", ref: t.id, label: t.subject || "(no subject)" });
  const dr = await admin.from("mail_drafts").select("id,subject,updated_at")
    .eq("user_id", uid).order("updated_at", { ascending: false }).limit(15);
  for (const d of dr.data || []) targets.push({ kind: "draft", ref: d.id, label: d.subject || "(untitled draft)" });
  res.json({ targets });
}));

/* ---------------- run ---------------- */
async function resolveInput(uid: string, body: any): Promise<string> {
  if (body?.input && String(body.input).trim()) return String(body.input);
  if (body?.source_kind === "thread" && body?.source_ref) {
    const { data } = await admin.from("mail_messages")
      .select("from_email,subject,body_text,created_at")
      .eq("thread_id", body.source_ref).order("created_at", { ascending: true }).limit(30);
    return (data || []).map((m: any) => `From: ${m.from_email}\n${m.body_text || ""}`).join("\n\n---\n\n");
  }
  if (body?.source_kind === "draft" && body?.source_ref) {
    const { data } = await admin.from("mail_drafts").select("subject,body_text")
      .eq("id", body.source_ref).eq("user_id", uid).maybeSingle();
    return [data?.subject, data?.body_text].filter(Boolean).join("\n\n");
  }
  return "";
}

async function doRun(uid: string, body: any, extra: any = {}) {
  const tool = String(body?.tool || "rewrite");
  const options = body?.options || {};
  const input = await resolveInput(uid, body);
  if (!input.trim()) throw new Error("empty_input");

  let row: any = {
    user_id: uid, tool, input, options,
    source_kind: body?.source_kind || "free", source_ref: body?.source_ref || null,
    state: "done", ...extra,
  };
  try {
    const m = await runModel(tool, input, options);
    row = { ...row, ...m };
  } catch (e: any) {
    row = { ...row, state: "failed", error: String(e?.message || e), output: "" };
  }
  const { data, error } = await admin.from("ai_studio_runs").insert(row).select("*").single();
  if (error) throw error;
  return data;
}

aiStudio.post("/ai/studio/run", guard(async (req, res, uid) => {
  const run = await doRun(uid, req.body || {});
  res.json({ run: shape(run) });
}));

/* ---------------- apply = real write ---------------- */
aiStudio.post("/ai/studio/runs/:id/apply", guard(async (req, res, uid) => {
  const { data: run, error } = await admin.from("ai_studio_runs").select("*")
    .eq("id", req.params.id).eq("user_id", uid).maybeSingle();
  if (error) throw error;
  if (!run) return res.status(404).json({ error: "run_not_found" });
  if (run.state !== "done" || !run.output) return res.status(400).json({ error: "run_not_applicable" });

  const target = String(req.body?.target || "");
  let appliedTo = target;
  let appliedRef: string | null = null;
  const parse = () => { try { return JSON.parse(run.output.replace(/^```(json)?|```$/g, "").trim()); } catch { return null; } };

  if (run.tool === "meeting" || target === "calendar_events") {
    const j = parse();
    if (!j?.title) return res.status(400).json({ error: "model_output_not_structured" });
    const ins = await admin.from("calendar_events").insert({
      user_id: uid, title: j.title, starts_at: j.start || null, ends_at: j.end || null,
      agenda: Array.isArray(j.agenda) ? j.agenda.join("\n") : (j.agenda || null),
      source_kind: run.source_kind, source_ref: run.source_ref,
    }).select("id").single();
    if (ins.error) throw ins.error;
    appliedTo = "calendar_events"; appliedRef = ins.data.id;
  } else if (run.tool === "tasks" || target === "work_tasks") {
    const j = parse();
    const tasks = Array.isArray(j?.tasks) ? j.tasks : [];
    if (!tasks.length) return res.status(400).json({ error: "no_tasks_found" });
    const ins = await admin.from("work_tasks").insert(
      tasks.map((t: any) => ({
        user_id: uid, title: String(t.title || "").slice(0, 300),
        due_at: t.due || null, source_kind: run.source_kind, source_ref: run.source_ref,
      })),
    ).select("id");
    if (ins.error) throw ins.error;
    appliedTo = "work_tasks"; appliedRef = ins.data?.[0]?.id || null;
  } else if (run.tool === "template" || target === "mail_templates") {
    const j = parse() || { name: `Studio ${new Date().toISOString().slice(0, 10)}`, body: run.output };
    const ins = await admin.from("mail_templates").insert({
      user_id: uid, name: j.name, subject: j.subject || null, body_html: j.body || run.output,
    }).select("id").single();
    if (ins.error) throw ins.error;
    appliedTo = "mail_templates"; appliedRef = ins.data.id;
  } else {
    const ins = await admin.from("mail_drafts").insert({
      user_id: uid, subject: `Studio · ${run.tool}`, body_text: run.output,
      thread_id: run.source_kind === "thread" ? run.source_ref : null,
    }).select("id").single();
    if (ins.error) throw ins.error;
    appliedTo = "compose"; appliedRef = ins.data.id;
  }

  await admin.from("ai_studio_runs")
    .update({ applied: true, applied_to: appliedTo, applied_ref: appliedRef })
    .eq("id", run.id);
  res.json({ applied: true, applied_to: appliedTo, applied_ref: appliedRef });
}));

/* ---------------- batch ---------------- */
aiStudio.post("/ai/studio/batch", guard(async (req, res, uid) => {
  const tool = String(req.body?.tool || "rewrite");
  const options = req.body?.options || {};
  const targets = Array.isArray(req.body?.targets) ? req.body.targets.slice(0, 25) : [];
  if (!targets.length) return res.status(400).json({ error: "no_targets" });

  const b = await admin.from("ai_studio_batches").insert({
    user_id: uid, tool, total: targets.length, state: "running",
  }).select("*").single();
  if (b.error) throw b.error;

  let done = 0, failed = 0, cost = 0;
  for (const t of targets) {
    const r = await doRun(uid, { tool, options, source_kind: t.kind, source_ref: t.ref }, { batch_id: b.data.id })
      .catch(() => null);
    if (r && r.state === "done") { done++; cost += Number(r.cost || 0); } else failed++;
  }
  const up = await admin.from("ai_studio_batches").update({
    done, failed, cost: Number(cost.toFixed(6)),
    state: failed && !done ? "failed" : "done",
  }).eq("id", b.data.id).select("*").single();
  const x = up.data || b.data;
  res.json({
    batch: {
      id: x.id, tool: x.tool, total: x.total, done: x.done, failed: x.failed,
      cost: Number(x.cost || 0), currency: x.currency || "GBP", state: x.state, created_at: x.created_at,
    },
  });
}));

/* ---------------- recipes ---------------- */
aiStudio.post("/ai/studio/recipes", guard(async (req, res, uid) => {
  const name = String(req.body?.name || "").trim();
  if (!name) return res.status(400).json({ error: "name_required" });
  const { data, error } = await admin.from("ai_studio_recipes").insert({
    user_id: uid, name, description: req.body?.description || null,
    steps: Array.isArray(req.body?.steps) ? req.body.steps : [],
  }).select("*").single();
  if (error) throw error;
  res.json({
    recipe: { id: data.id, name: data.name, description: data.description, steps: data.steps || [], runs: 0, last_run_at: null },
  });
}));

aiStudio.post("/ai/studio/recipes/:id/run", guard(async (req, res, uid) => {
  const { data: recipe, error } = await admin.from("ai_studio_recipes").select("*")
    .eq("id", req.params.id).eq("user_id", uid).maybeSingle();
  if (error) throw error;
  if (!recipe) return res.status(404).json({ error: "recipe_not_found" });

  const rr = await admin.from("ai_studio_recipe_runs").insert({
    user_id: uid, recipe_id: recipe.id, state: "running",
  }).select("id").single();

  let carry = String(req.body?.input || "");
  const runs: any[] = [];
  for (const step of (recipe.steps || [])) {
    const r = await doRun(uid, { tool: step.tool, options: step.options || {}, input: carry }, { recipe_run_id: rr.data?.id || null });
    runs.push(shape(r));
    if (r.state !== "done") break;
    carry = r.output;
  }
  await admin.from("ai_studio_recipe_runs").update({ state: "done", output: carry }).eq("id", rr.data?.id || "");
  await admin.from("ai_studio_recipes")
    .update({ runs: (recipe.runs || 0) + 1, last_run_at: new Date().toISOString() })
    .eq("id", recipe.id);
  res.json({ output: carry, runs });
}));

export default aiStudio;
