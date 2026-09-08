import { Router } from "express";
import { createClient } from "@supabase/supabase-js";

const URL = process.env.SUPABASE4_URL || process.env.SUPABASE_URL || "";
const KEY = process.env.SUPABASE4_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY || "";
const db = URL && KEY ? createClient(URL, KEY, { auth: { persistSession: false, autoRefreshToken: false } }) : null;
export const workspaceRouter = Router();

async function userId(req: any, res: any) {
  if (!db) { res.status(503).json({ error: "account_service_not_configured" }); return null; }
  const raw = String(req.headers.authorization || "");
  const token = raw.startsWith("Bearer ") ? raw.slice(7) : "";
  const { data, error } = token ? await db.auth.getUser(token) : { data: { user: null }, error: null };
  if (error || !data.user) { res.status(401).json({ error: "unauthorized" }); return null; }
  return data.user.id;
}

workspaceRouter.post("/organisations", async (req, res) => {
  const uid = await userId(req, res); if (!uid) return;
  const name = String(req.body?.name || "").trim();
  const domain = req.body?.domain ? String(req.body.domain).trim().toLowerCase() : null;
  if (name.length < 2) return res.status(400).json({ error: "Organisation name is required." });
  const base = name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "").slice(0, 40) || "workspace";
  const slug = `${base}-${uid.slice(0, 8)}`;
  const { data, error } = await db.from("account_organisations").insert({ name, slug, domain, created_by: uid }).select("id,name,slug,domain").single();
  if (error) return res.status(500).json({ error: error.message });
  const { error: accountMemberError } = await db.from("account_org_members").upsert({ org_id: data.id, user_id: uid, role: "owner" }, { onConflict: "org_id,user_id" });
  if (accountMemberError) return res.status(500).json({ error: "workspace_membership_failed" });
  const { data: authUser } = await db.auth.admin.getUserById(uid);
  const email = authUser.user?.email || null;
  const { error: legacyOrgError } = await db.from("orgs").upsert({ id: data.id, name }, { onConflict: "id" });
  if (legacyOrgError) return res.status(500).json({ error: "operational_workspace_failed" });
  const { error: legacyMemberError } = await db.from("org_members").upsert(
    { org_id: data.id, user_id: uid, email, role: "owner", status: "active" },
    { onConflict: "org_id,user_id" },
  );
  if (legacyMemberError) return res.status(500).json({ error: "operational_membership_failed" });
  res.status(201).json(data);
});

workspaceRouter.post("/invitations", async (req, res) => {
  const uid = await userId(req, res); if (!uid) return;
  const emails = Array.isArray(req.body?.emails) ? req.body.emails.filter((v: unknown) => typeof v === "string") : [];
  if (!emails.length) return res.status(400).json({ error: "At least one email is required." });
  const { data: membership } = await db!.from("account_org_members").select("org_id,role").eq("user_id", uid).in("role", ["owner", "admin"]).limit(1).maybeSingle();
  if (!membership) return res.status(403).json({ error: "organisation_admin_required" });
  const invited: string[] = [];
  for (const raw of emails) {
    const email = String(raw).trim().toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) continue;
    const { error } = await db!.auth.admin.inviteUserByEmail(email, { redirectTo: "https://anexomail.com/auth/callback", data: { organisation_id: membership.org_id, role: "member" } });
    if (!error) invited.push(email);
  }
  if (!invited.length) return res.status(502).json({ error: "invitations_not_sent" });
  res.json({ invited });
});