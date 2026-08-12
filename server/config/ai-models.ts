// nano /opt/anexomail/src/config/ai-models.ts
// ╔══════════════════════════════════════════════════════════════╗
// ║  NEXATECT™ — ANEXOMAIL AI MODEL REGISTRY (Server 2)         ║
// ║  Leo + Industries — Ek jagah update karo                    ║
// ╚══════════════════════════════════════════════════════════════╝

// ─── API ENDPOINTS ───────────────────────────────────────────
export const ENDPOINTS = {
  openrouter: "https://openrouter.ai/api/v1/chat/completions",
  deepinfra: "https://api.deepinfra.com/v1/openai/chat/completions",
};

// ─── API KEYS (env se) ────────────────────────────────────────
export const KEYS = {
  or2: () => process.env.OPENROUTER_API_KEY_2 || "",
  or3: () => process.env.OPENROUTER_API_KEY_3 || "",
  di2: () => process.env.DEEPINFRA_API_KEY_2 || "",
};

// ─── MODEL REGISTRY ───────────────────────────────────────────
export const MODELS = {
  // ── LEO (ANEXOMAIL — Primary AI) ─────────────────────────
  leo: {
    primary: { model: process.env.LEO_MODEL || "claude-haiku-4-5", provider: "deepinfra", key: "di2" },
    fallback: { model: "deepseek-ai/DeepSeek-V4-Flash", provider: "deepinfra", key: "di2" },
    free: { model: "meta-llama/llama-3.3-70b-instruct:free", provider: "openrouter", key: "or3" },
  },
};

// ─── CREDIT COSTS (internal billing unit — provider cost se alag) ──
export const CREDITS = {
  standard: 0.5, // 2 requests = 1 credit
  advanced: 2,
  vision: 3,
  bulk: 5,
};

// ─── RATE LIMITS ──────────────────────────────────────────────
export const LIMITS = {
  free: { daily: 5, monthly: 50 },
  basic: { daily: 50, monthly: 1000 },
  pro: { daily: 200, monthly: 5000 },
  premium: { daily: -1, monthly: -1 },
  founder: { daily: -1, monthly: -1 },
};

// ─── HELPER ───────────────────────────────────────────────────
export function getModelConfig(agent: keyof typeof MODELS, tier: string = "primary") {
  const agentModels = MODELS[agent] as any;
  const config = agentModels?.[tier] || agentModels?.primary;
  if (!config) throw new Error(`Model not found: ${agent}.${tier}`);
  return {
    model: config.model,
    endpoint: ENDPOINTS[config.provider as keyof typeof ENDPOINTS],
    apiKey: KEYS[config.key as keyof typeof KEYS](),
    provider: config.provider,
  };
}

export default MODELS;
