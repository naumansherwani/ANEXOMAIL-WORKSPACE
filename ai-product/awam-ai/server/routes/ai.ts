import { Router } from "express";
import { admin } from "../lib/supa";

export const ai = Router();

const FOUNDER = new Set([
  "naumansherwani.founder@anexomail.com",
  "naumansherwani.founder@nexatect.com",
]);

const RATE_PER_1K = 0.0025; // GBP per 1k tokens (blended) — display only
const GUARD_WORDS = [
  "refund", "invoice", "payment", "bank", "wire", "salary",
  "contract", "legal", "lawsuit", "nda", "terminate", "cancel", "delete all",
];

/* ============================================================ LEO MEMORY
   Real long-term memory (Supabase #4 · leo_memory_vectors).
   Layers: working (session) · episodic (har msg) · semantic (recall).
   Cap: agent_memory_config.leo = 3,000,000 → leo_memory_prune().
   Embedding optional: OPENAI_API_KEY ho to vector(1536), warna
   keyword+recency recall (honest fallback, koi mock nahi).
   ==================================================================== */

const EMBED_MODEL = "text-embedding-3-small"; // 1536 dims (schema lock)
let writeCounter = 0;

async function embed(text: string): Promise<number[] | null> {
  const key = process.env.OPENAI_API_KEY || "";
  if (!key || !text.trim()) return null;
  try {
    const r = await fetch("https://api.openai.com/v1/embeddings", {
      method: "POST",
      headers: { "content-type": "application/json", authorization: `Bearer ${key}` },
      body: JSON.stringify({ model: EMBED_MODEL, input: text.slice(0, 8000) }),
    });
    const j: any = await r.json().catch(() => ({}));
    const v = j?.data?.[0]?.embedding;
    return Array.isArray(v) && v.length === 1536 ? v : null;
  } catch (e: any) {
    console.error("[leo-memory:embed]", e?.message || e);
    return null;
  }
}

async function remember(input: {
  user_id: string;
  session_id?: string | null;
  thread_id?: string | null;
  role: "user" | "assistant" | "system" | "tool";
  content: string;
  layer?: "working" | "episodic" | "semantic";
  importance?: number;
  pinned?: boolean;
  metadata?: Record<string, any>;
}) {
  const content = String(input.content || "").trim();
  if (!content) return null;
  const embedding = await embed(content);
  const { data, error } = await admin.from("leo_memory_vectors").insert({
    agent: "leo",
    user_id: input.user_id,
    session_id: input.session_id || null,
    thread_id: input.thread_id || null,
    layer: input.layer || "episodic",
    role: input.role,
    content,
    embedding,
    importance: typeof input.importance === "number" ? input.importance : 0.5,
    pinned: !!input.pinned,
    metadata: input.metadata || {},
  }).select("id").single();
  if (error) console.error("[leo-memory:remember]", error.message);

  // 3M cap enforcement — har 200 writes pe ek prune (RAM safe, DB side)
  if (++writeCounter % 200 === 0) {
    const { error: pe } = await admin.rpc("leo_memory_prune");
    if (pe) console.error("[leo-memory:prune]", pe.message);
  }
  return data?.id || null;
}

async function recall(user_id: string, query: string, limit = 12) {
  const vec = await embed(query);
  if (vec) {
    const { data, error } = await admin.rpc("leo_recall", {
      p_user_id: user_id,
      p_embedding: vec,
      p_limit: limit,
    });
    if (!error && Array.isArray(data) && data.length) {
      // access_count bump — jo yaad aata hai woh zinda rehta hai
      const ids = data.map((m: any) => m.id);
      void admin.from("leo_memory_vectors")
        .update({ updated_at: new Date().toISOString() }).in("id", ids);
      return data.map((m: any) => ({
        content: m.content, layer: m.layer, score: m.score, created_at: m.created_at,
      }));
    }
    if (error) console.error("[leo-memory:recall]", error.message);
  }
  // fallback: pinned + keyword + recency
  const words = query.toLowerCase().split(/\s+/).filter((w) => w.length > 4).slice(0, 3);
  const or = words.map((w) => `content.ilike.%${w}%`).join(",");
  const q = admin.from("leo_memory_vectors")
    .select("content, layer, created_at")
    .eq("user_id", user_id)
    .order("pinned", { ascending: false })
    .order("created_at", { ascending: false })
    .limit(limit);
  const { data } = or ? await q.or(or) : await q;
  return (data || []).map((m: any) => ({ ...m, score: null }));
}

async function memoryStats(user_id: string) {
  const { count } = await admin.from("leo_memory_vectors")
    .select("id", { count: "exact", head: true })
    .eq("user_id", user_id).eq("agent", "leo");
  const { data: cfg } = await admin.from("agent_memory_config")
    .select("max_memories").eq("agent", "leo").maybeSingle();
  return { stored: count || 0, cap: cfg?.max_memories || 3000000 };
}

async function ctx(req: any) {
  const h = String(req.headers["authorization"] || "");
  const token = h.startsWith("Bearer ") ? h.slice(7) : "";
  if (!token) return { user: null as any, founder: false };
  const { data } = await admin.auth.getUser(token);
  const user = data?.user || null;
  if (!user) return { user: null as any, founder: false };
  const email = String(user.email || "").toLowerCase();
  return { user, founder: FOUNDER.has(email) };
}

function guard(handler: (req: any, res: any, c: any) => Promise<any>) {
  return async (req: any, res: any) => {
    try {
      const c = await ctx(req);
      if (!c.user) return res.status(401).json({ error: "unauthorized" });
      return await handler(req, res, c);
    } catch (e: any) {
      console.error("[ai]", e?.message || e);
      return res.status(500).json({ error: "ai_failed" });
    }
  };
}

const num = (v: any) => Number(v ?? 0);

/* ------------------------------------------------------------- sessions */
ai.get("/ai/sessions", guard(async (_req, res, c) => {
  const { data } = await admin
    .from("ai_sessions").select("*").eq("user_id", c.user.id)
    .order("created_at", { ascending: false }).limit(100);
  const ids = (data || []).map((s: any) => s.id);
  const turns = ids.length
    ? (await admin.from("ai_turns").select("session_id").in("session_id", ids)).data || []
    : [];
  const costs = (await admin.from("ai_credits_ledger").select("turn_id, cost").eq("user_id", c.user.id)).data || [];
  const totalCost = costs.reduce((a: number, r: any) => a + num(r.cost), 0);
  const sessions = (data || []).map((s: any) => ({
    id: s.id,
    title: s.title,
    model: s.model,
    created_at: s.created_at,
    updated_at: s.updated_at,
    turns: turns.filter((t: any) => t.session_id === s.id).length,
    cost: (data || []).length === 1 ? totalCost : 0,
    currency: "GBP",
  }));
  res.json({ sessions });
}));

ai.post("/ai/sessions", guard(async (req, res, c) => {
  const b = req.body || {};
  const { data, error } = await admin.from("ai_sessions").insert({
    user_id: c.user.id,
    title: b.title || "New session",
    model: b.model || modelFor("leo"),
  }).select("*").single();
  if (error) return res.status(400).json({ error: error.message });
  res.json({ session: { ...data, turns: 0, cost: 0, currency: "GBP" } });
}));

ai.get("/ai/sessions/:id", guard(async (req, res, c) => {
  const sid = String(req.params.id);
  const { data: turns } = await admin
    .from("ai_turns").select("*").eq("user_id", c.user.id).eq("session_id", sid)
    .order("created_at", { ascending: true });
  const tids = (turns || []).map((t: any) => t.id);
  const receipts = tids.length
    ? (await admin.from("ai_receipts").select("*").in("turn_id", tids)).data || []
    : [];
  const guards = tids.length
    ? (await admin.from("ai_guardrail_events").select("*").in("turn_id", tids)).data || []
    : [];
  res.json({
    turns: (turns || []).map((t: any) => ({
      id: t.id,
      parent_turn_id: t.parent_turn_id,
      role: t.role,
      content: t.content,
      model: t.model,
      agent: t.agent,
      created_at: t.created_at,
      receipt: receipts.find((r: any) => r.turn_id === t.id)
        ? shapeReceipt(receipts.find((r: any) => r.turn_id === t.id))
        : null,
      guardrail: guards.find((g: any) => g.turn_id === t.id) || null,
    })),
  });
}));

function shapeReceipt(r: any) {
  return {
    id: r.id,
    turn_id: r.turn_id,
    model: r.model,
    input_tokens: r.input_tokens || 0,
    output_tokens: r.output_tokens || 0,
    cost: num(r.cost),
    currency: r.currency || "GBP",
    ttft_ms: r.ttft_ms,
    latency_ms: r.latency_ms,
    sources: Array.isArray(r.sources) ? r.sources : [],
    escalated_to: r.escalated_to,
    sherlock_verdict: r.sherlock_verdict,
    created_at: r.created_at,
  };
}

/* -------------------------------------------------------------- credits */
ai.get("/ai/credits", guard(async (_req, res, c) => {
  const { data } = await admin
    .from("ai_credits_ledger").select("cost, created_at").eq("user_id", c.user.id);
  const rows = data || [];
  const now = new Date();
  const day = now.toISOString().slice(0, 10);
  const month = now.toISOString().slice(0, 7);
  const spent_today = rows.filter((r: any) => String(r.created_at).startsWith(day))
    .reduce((a: number, r: any) => a + num(r.cost), 0);
  const spent_month = rows.filter((r: any) => String(r.created_at).startsWith(month))
    .reduce((a: number, r: any) => a + num(r.cost), 0);
  res.json({
    unlimited: c.founder,
    balance: 0,
    spent_today,
    spent_month,
    currency: "GBP",
    rate_per_1k: RATE_PER_1K,
  });
}));

ai.get("/ai/receipts", guard(async (_req, res, c) => {
  const { data } = await admin.from("ai_receipts").select("*")
    .eq("user_id", c.user.id).order("created_at", { ascending: false }).limit(200);
  res.json({ receipts: (data || []).map(shapeReceipt) });
}));

/* --------------------------------------------------------------- memory */
ai.get("/ai/memory", guard(async (_req, res, c) => {
  const { data } = await admin.from("ai_memory").select("*")
    .eq("user_id", c.user.id).order("created_at", { ascending: false }).limit(200);
  res.json({ items: data || [] });
}));

ai.delete("/ai/memory/:id", guard(async (req, res, c) => {
  const { error } = await admin.from("ai_memory").delete()
    .eq("user_id", c.user.id).eq("id", String(req.params.id));
  if (error) return res.status(400).json({ error: error.message });
  res.json({ ok: true, deleted: true });
}));

/* ---------------------------------------------------- LEO brain memory */
ai.get("/ai/leo/memory", guard(async (_req, res, c) => {
  const stats = await memoryStats(c.user.id);
  const { data } = await admin.from("leo_memory_vectors")
    .select("id, layer, role, content, summary, importance, pinned, created_at")
    .eq("user_id", c.user.id)
    .order("pinned", { ascending: false })
    .order("created_at", { ascending: false }).limit(100);
  res.json({
    agent: "leo",
    cap: stats.cap,
    stored: stats.stored,
    embeddings: Boolean(process.env.OPENAI_API_KEY),
    items: data || [],
  });
}));

ai.post("/ai/leo/memory/recall", guard(async (req, res, c) => {
  const q = String(req.body?.query || "").trim();
  if (!q) return res.status(400).json({ error: "query_required" });
  res.json({ memories: await recall(c.user.id, q, Number(req.body?.limit) || 12) });
}));

ai.post("/ai/leo/memory/:id/pin", guard(async (req, res, c) => {
  const pinned = req.body?.pinned !== false;
  const { data, error } = await admin.from("leo_memory_vectors")
    .update({ pinned, updated_at: new Date().toISOString() })
    .eq("user_id", c.user.id).eq("id", String(req.params.id)).select("*").single();
  if (error) return res.status(400).json({ error: error.message });
  res.json({ memory: data });
}));

ai.delete("/ai/leo/memory/:id", guard(async (req, res, c) => {
  const { error } = await admin.from("leo_memory_vectors").delete()
    .eq("user_id", c.user.id).eq("id", String(req.params.id)).eq("pinned", false);
  if (error) return res.status(400).json({ error: error.message });
  res.json({ ok: true, deleted: true });
}));

ai.post("/ai/leo/memory/prune", guard(async (_req, res, c) => {
  if (!c.founder) return res.status(403).json({ error: "founder_only" });
  const { data, error } = await admin.rpc("leo_memory_prune");
  if (error) return res.status(400).json({ error: error.message });
  res.json({ pruned: data ?? 0, cap: (await memoryStats(c.user.id)).cap });
}));

/* -------------------------------------------------------------- prompts */
ai.get("/ai/prompts", guard(async (_req, res, c) => {
  const { data } = await admin.from("ai_prompts").select("*")
    .eq("user_id", c.user.id).order("created_at", { ascending: false }).limit(200);
  res.json({ prompts: data || [] });
}));

ai.get("/ai/prompts/:id/versions", guard(async (req, res, c) => {
  const { data } = await admin.from("ai_prompt_versions").select("*")
    .eq("user_id", c.user.id).eq("prompt_id", String(req.params.id))
    .order("version", { ascending: false });
  res.json({ versions: (data || []).map((v: any) => ({
    ...v, variables: Array.isArray(v.variables) ? v.variables : [],
  })) });
}));

ai.post("/ai/prompts/:id/versions", guard(async (req, res, c) => {
  const pid = String(req.params.id);
  const b = req.body || {};
  const { data: p } = await admin.from("ai_prompts").select("*")
    .eq("user_id", c.user.id).eq("id", pid).maybeSingle();
  if (!p) return res.status(404).json({ error: "prompt_not_found" });
  const version = (p.latest_version || 0) + 1;
  const { data, error } = await admin.from("ai_prompt_versions").insert({
    prompt_id: pid, user_id: c.user.id, version,
    body: String(b.body || ""),
    variables: Array.isArray(b.variables) ? b.variables : [],
    note: b.note || null,
  }).select("*").single();
  if (error) return res.status(400).json({ error: error.message });
  await admin.from("ai_prompts").update({ latest_version: version, updated_at: new Date().toISOString() }).eq("id", pid);
  res.json({ version: data });
}));

ai.post("/ai/prompts/:id/fork", guard(async (req, res, c) => {
  const pid = String(req.params.id);
  const { data: p } = await admin.from("ai_prompts").select("*")
    .eq("user_id", c.user.id).eq("id", pid).maybeSingle();
  if (!p) return res.status(404).json({ error: "prompt_not_found" });
  const { data: latest } = await admin.from("ai_prompt_versions").select("*")
    .eq("prompt_id", pid).order("version", { ascending: false }).limit(1);
  const { data: fork, error } = await admin.from("ai_prompts").insert({
    user_id: c.user.id,
    name: (req.body?.name || `${p.name} (fork)`),
    description: p.description,
    latest_version: 1,
    forked_from: pid,
  }).select("*").single();
  if (error) return res.status(400).json({ error: error.message });
  if (latest?.[0]) {
    await admin.from("ai_prompt_versions").insert({
      prompt_id: fork.id, user_id: c.user.id, version: 1,
      body: latest[0].body, variables: latest[0].variables, note: "forked",
    });
  }
  res.json({ prompt: fork });
}));

/* ---------------------------------------------------------------- arena */
ai.get("/ai/arena", guard(async (_req, res, c) => {
  const { data } = await admin.from("ai_arena_runs").select("*")
    .eq("user_id", c.user.id).order("created_at", { ascending: false }).limit(50);
  res.json({ runs: (data || []).map((r: any) => ({
    ...r, entries: Array.isArray(r.entries) ? r.entries : [],
  })) });
}));

ai.post("/ai/arena", guard(async (req, res, c) => {
  const question = String(req.body?.question || "").trim();
  if (!question) return res.status(400).json({ error: "question_required" });
  const agents: string[] = Array.isArray(req.body?.agents) && req.body.agents.length
    ? req.body.agents : ["leo", "jimmy", "sherlock"];
  const entries: any[] = [];
  for (const agent of agents) {
    const t0 = Date.now();
    const out = await callModel([{ role: "user", content: question }], modelFor(agent));
    entries.push({
      agent,
      model: out.model,
      answer: out.text,
      latency_ms: Date.now() - t0,
      cost: out.cost,
      sherlock_score: null,
    });
    await logCost(c.user.id, null, out, c.founder);
  }
  const winner = entries[0]?.agent ?? null;
  const { data, error } = await admin.from("ai_arena_runs").insert({
    user_id: c.user.id, question, winner, entries,
  }).select("*").single();
  if (error) return res.status(400).json({ error: error.message });
  res.json({ run: { ...data, entries } });
}));

/* ------------------------------------------------------------ guardrail */
ai.get("/ai/guardrail", guard(async (_req, res, c) => {
  const { data } = await admin.from("ai_guardrail_events").select("*")
    .eq("user_id", c.user.id).order("created_at", { ascending: false }).limit(100);
  res.json({ events: data || [] });
}));

ai.post("/ai/guardrail/:id", guard(async (req, res, c) => {
  const decision = req.body?.decision === "release" ? "released" : "refused";
  const { data, error } = await admin.from("ai_guardrail_events")
    .update({ state: decision }).eq("user_id", c.user.id).eq("id", String(req.params.id))
    .select("*").single();
  if (error) return res.status(400).json({ error: error.message });
  res.json({ event: data });
}));

/* ----------------------------------------------------------- model call */
function modelFor(agent: string) {
  if (agent === "jimmy") return process.env.JIMMY_MODEL || "deepseek/deepseek-chat";
  if (agent === "sherlock") return process.env.SHERLOCK_MODEL || "deepseek/deepseek-r1";
  return process.env.LEO_MODEL || "deepseek/deepseek-chat";
}

const approxTokens = (s: string) => Math.max(1, Math.ceil(s.length / 4));

type Msg = { role: "system" | "user" | "assistant"; content: string };

async function callModel(messages: Msg[], model: string) {
  const key = process.env.OPENROUTER_API_KEY || "";
  const joined = messages.map((m) => m.content).join("\n");
  if (!key) return { model, text: "", cost: 0, input_tokens: 0, output_tokens: 0, error: "no_key" };
  const r = await fetch("https://openrouter.ai/api/v1/chat/completions", {
    method: "POST",
    headers: { "content-type": "application/json", authorization: `Bearer ${key}` },
    body: JSON.stringify({ model, messages }),
  });
  const j: any = await r.json().catch(() => ({}));
  const text = j?.choices?.[0]?.message?.content || "";
  if (!text && j?.error) return { model, text: "", cost: 0, input_tokens: 0, output_tokens: 0, error: String(j.error?.message || "model_error") };
  const it = j?.usage?.prompt_tokens ?? approxTokens(joined);
  const ot = j?.usage?.completion_tokens ?? approxTokens(text);
  return { model, text, input_tokens: it, output_tokens: ot, cost: ((it + ot) / 1000) * RATE_PER_1K };
}

async function logCost(user_id: string, turn_id: string | null, out: any, founder: boolean) {
  await admin.from("ai_credits_ledger").insert({
    user_id, turn_id, model: out.model,
    tokens: (out.input_tokens || 0) + (out.output_tokens || 0),
    cost: out.cost || 0, currency: "GBP", charged: !founder,
  });
}

/* ------------------------------------------------------------ LEO brain */
const LEO_SYSTEM = `Tum LEO ho — ANEXOMAIL Workspace ka AI (NEXATECT Global Ltd).
Founder: Muhammad Nauman Sherwani. Tum Jimmy John (Supreme Commander) ko report karte ho.
Rules:
- Language auto-detect karo (Roman Urdu / English) — user ki language mein jawab do.
- Tumhari memory permanent hai (3,000,000 messages). Jo yaad hai use karo, dobara mat pucho.
- Paisa, legal, cancel, delete jaisi baat par khud action mat lo — founder approval chahiye.
- Kabhi jhooth/mock data nahi. Nahi pata to saaf kaho.
- Escalation: mushkil/strategic sawal par Jimmy ko escalate karne ki tajweez do.`;

/* ----------------------------------------------------------------- chat */
ai.post("/ai/chat", guard(async (req, res, c) => {
  const b = req.body || {};
  const session_id = String(b.session_id || "");
  const message = String(b.message || "").trim();
  if (!session_id || !message) return res.status(400).json({ error: "session_and_message_required" });

  res.status(200);
  res.setHeader("content-type", "text/event-stream");
  res.setHeader("cache-control", "no-cache, no-transform");
  res.setHeader("connection", "keep-alive");
  const send = (o: any) => res.write(`data: ${JSON.stringify(o)}\n\n`);

  const { data: userTurn } = await admin.from("ai_turns").insert({
    session_id, user_id: c.user.id, role: "user", content: message,
    parent_turn_id: b.parent_turn_id || null,
  }).select("*").single();

  // 1) EPISODIC WRITE — har user msg permanent memory mein
  await remember({
    user_id: c.user.id, session_id, role: "user", content: message,
    layer: "episodic", importance: 0.5,
    metadata: { turn_id: userTurn?.id || null },
  });

  const hit = GUARD_WORDS.find((w) => message.toLowerCase().includes(w));
  if (hit) {
    const { data: ev } = await admin.from("ai_guardrail_events").insert({
      user_id: c.user.id, turn_id: userTurn?.id || null, keyword: hit,
      reason: `"${hit}" money/legal/cancel category mein hai — LEO ne rok diya, founder decision chahiye.`,
      state: "paused",
    }).select("*").single();
    await remember({
      user_id: c.user.id, session_id, role: "system",
      content: `Guardrail paused: "${hit}" — ${message}`,
      layer: "semantic", importance: 0.9, pinned: true,
      metadata: { guardrail: true, keyword: hit },
    });
    send({ type: "guardrail", event: ev });
    send({ type: "done", turn: { id: userTurn?.id, parent_turn_id: null, role: "assistant", content: "", model: null, agent: "leo", created_at: new Date().toISOString(), receipt: null, guardrail: ev } });
    return res.end();
  }

  // 2) SEMANTIC RECALL — reply se pehle purani yaad nikalo
  const memories = await recall(c.user.id, message, 12);

  // 3) WORKING MEMORY — isi session ke last 10 turns
  const { data: recent } = await admin.from("ai_turns")
    .select("role, content").eq("user_id", c.user.id).eq("session_id", session_id)
    .order("created_at", { ascending: false }).limit(10);
  const history = (recent || []).reverse()
    .map((t: any) => ({ role: t.role === "assistant" ? "assistant" : "user", content: String(t.content || "") })) as Msg[];

  const messages: Msg[] = [{ role: "system", content: LEO_SYSTEM }];
  if (memories.length) {
    messages.push({
      role: "system",
      content: "LONG-TERM MEMORY (Leo ki apni yaad, sirf relevant use karo):\n" +
        memories.map((m: any, i: number) => `${i + 1}. [${m.layer}] ${String(m.content).slice(0, 500)}`).join("\n"),
    });
    send({ type: "memory", used: memories.length });
  }
  messages.push(...history);

  const model = String(b.model || modelFor("leo"));
  const t0 = Date.now();
  const out = await callModel(messages, model);
  if (out.error === "no_key") {
    send({ type: "error", message: "AI key server par set nahi hai (OPENROUTER_API_KEY)." });
    return res.end();
  }
  if (out.error) {
    send({ type: "error", message: `Model error: ${out.error}` });
    return res.end();
  }
  send({ type: "ttft", ms: Date.now() - t0 });
  for (const chunk of out.text.match(/[\s\S]{1,60}/g) || []) send({ type: "delta", text: chunk });

  const { data: aTurn } = await admin.from("ai_turns").insert({
    session_id, user_id: c.user.id, role: "assistant", content: out.text,
    model: out.model, agent: "leo", parent_turn_id: userTurn?.id || null,
  }).select("*").single();

  // 4) EPISODIC WRITE — Leo ka apna jawab bhi yaad rehta hai
  await remember({
    user_id: c.user.id, session_id, role: "assistant", content: out.text,
    layer: "episodic", importance: 0.6,
    metadata: { turn_id: aTurn?.id || null, model: out.model },
  });

  const { data: receipt } = await admin.from("ai_receipts").insert({
    turn_id: aTurn?.id, user_id: c.user.id, model: out.model,
    input_tokens: out.input_tokens, output_tokens: out.output_tokens,
    cost: out.cost, currency: "GBP", latency_ms: Date.now() - t0,
    ttft_ms: null, sources: memories.slice(0, 5).map((m: any) => ({
      title: String(m.content).slice(0, 60), ref: "leo_memory", kind: m.layer,
    })),
  }).select("*").single();

  await logCost(c.user.id, aTurn?.id || null, out, c.founder);
  await admin.from("ai_sessions").update({ updated_at: new Date().toISOString() }).eq("id", session_id);

  send({
    type: "done",
    turn: {
      id: aTurn?.id, parent_turn_id: userTurn?.id || null, role: "assistant",
      content: out.text, model: out.model, agent: "leo",
      created_at: aTurn?.created_at, receipt: receipt ? shapeReceipt(receipt) : null,
      guardrail: null,
    },
  });
  res.end();
}));
