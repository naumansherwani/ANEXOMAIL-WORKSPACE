// ANEXOMAIL — E24: account deletion, self-service side (Brain, port 3100)
//
// Sirf REQUEST / CANCEL / STATE. Asli delete (purge) yahan se kabhi nahi hota:
// public.account_purge() par kisi role ka execute nahi, sirf founder SQL Editor se
// chalata hai (docs/cursor-work/sql/E24_account_deletion.sql).
//
// Routes (mount: app.use("/api/account-deletion", accountDeletionRouter))
//   GET  /api/account-deletion/state     auth — scheduled? days_left? blockers?
//   POST /api/account-deletion/request   auth — { confirm_email } -> 7 din ka grace
//   POST /api/account-deletion/cancel    auth — grace ke andar wapas
//
// Truth Supabase mein: yeh file sirf RPC bulati hai; email match, blockers aur
// grace sab SQL decide karta hai.
import { Router } from "express";

import { admin as db } from "../lib/supa";

const router = Router();

const fail = (res: any, e: any) =>
  res.status(500).json({ error: "db_error", detail: String(e?.message || e) });

async function requireUser(req: any, res: any): Promise<string | null> {
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

router.get("/state", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  try {
    const { data, error } = await db.rpc("account_deletion_state", { _user: uid });
    if (error) throw error;
    res.json(data);
  } catch (e) {
    fail(res, e);
  }
});

router.post("/request", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  const confirmEmail = String(req.body?.confirm_email || "");
  try {
    const { data, error } = await db.rpc("account_deletion_request", {
      _user: uid,
      _confirm_email: confirmEmail,
    });
    if (error) throw error;
    if (data && data.ok === false) {
      const status = data.error === "blocked" ? 409 : data.error === "user_not_found" ? 404 : 400;
      return res.status(status).json(data);
    }
    res.json(data);
  } catch (e) {
    fail(res, e);
  }
});

router.post("/cancel", async (req, res) => {
  const uid = await requireUser(req, res);
  if (!uid) return;
  try {
    const { data, error } = await db.rpc("account_deletion_cancel", { _user: uid });
    if (error) throw error;
    res.json(data);
  } catch (e) {
    fail(res, e);
  }
});

export default router;
export { router as accountDeletionRouter };
