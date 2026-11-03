/**
 * One gate for the whole founder API (everything under /api/founder/*), pure and injectable so it can be tested.
 *
 * Why: every founder router in the Brain (movein, release, revenue, storage, perf, security, settings, integrations,
 * ai-credits, glitch, admin …) used its own `requireUser`, which only asks "is somebody signed in?". So any customer's
 * token could read the revenue pipeline, start a QA run, take the release lock or drive a move-in (mailbox, DNS,
 * rollback, invoice). This middleware is mounted ONCE, in front of all of them.
 */
import { isFounderEmail } from "./org-authz";

export type FounderGateDeps = {
  /** token → signed-in user (or null). */
  getUser: (token: string) => Promise<{ id: string; email?: string | null } | null>;
  /** extra founder identities beyond the email list (founder_accounts table). */
  isFounderAccount: (userId: string) => Promise<boolean>;
  /** lower-case founder emails (FOUNDER_EMAILS env, same default list routes/founder.ts uses). */
  emails: readonly string[];
};

export const bearerOf = (req: { headers?: Record<string, unknown> }): string => {
  const h = String(req.headers?.["authorization"] ?? "");
  return h.startsWith("Bearer ") ? h.slice(7).trim() : "";
};

export type FounderVerdict = "ok" | "unauthorized" | "founder_only";

export async function founderVerdict(token: string, d: FounderGateDeps): Promise<FounderVerdict> {
  if (!token) return "unauthorized";
  let user: Awaited<ReturnType<FounderGateDeps["getUser"]>> = null;
  try {
    user = await d.getUser(token);
  } catch {
    user = null;
  }
  if (!user) return "unauthorized";
  if (isFounderEmail(user.email, d.emails)) return "ok";
  try {
    if (await d.isFounderAccount(user.id)) return "ok";
  } catch {
    /* a lookup failure never turns a customer into a founder */
  }
  return "founder_only";
}

/** Express middleware: 401 without a session, 403 for every non-founder, otherwise next(). */
export const makeFounderGate =
  (d: FounderGateDeps) =>
  async (req: any, res: any, next: (err?: unknown) => void): Promise<void> => {
    if (req.method === "OPTIONS") return next(); // CORS preflight carries no Authorization header; it exposes nothing
    const v = await founderVerdict(bearerOf(req), d);
    if (v === "ok") return next();
    res.status(v === "unauthorized" ? 401 : 403).json({ error: v });
  };
