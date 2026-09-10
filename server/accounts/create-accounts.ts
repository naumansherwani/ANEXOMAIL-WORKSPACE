// ANEXOMAIL — family accounts + founder authority check.
// Run: bash server/accounts/create-accounts.sh
// LOCK: founder password NEVER reset here. Family passwords ONLY from /opt/anexomail/.env.
import { createClient } from "@supabase/supabase-js";

const url = process.env.SUPABASE4_URL || process.env.SUPABASE_URL || "";
const key = process.env.SUPABASE4_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY || "";
if (!url || !key) {
  console.error("RED  SUPABASE_URL / SERVICE_ROLE_KEY missing in /opt/anexomail/.env");
  process.exit(1);
}
const db = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });

const RECOVERY_EMAIL = "anexomail27@gmail.com";
const BRAIN_URL = process.env.BRAIN_URL || "http://127.0.0.1:3100";
const RUST_URL = process.env.RUST_URL || "http://127.0.0.1:3200";
const FOUNDER_EMAIL = "naumansherwani.founder@anexomail.com";

const FAMILY = [
  {
    email: "humzasherwani@anexomail.com",
    name: "Humza Sherwani",
    pw: "HUMZA_PASSWORD",
  },
  {
    email: "raanasherwani@anexomail.com",
    name: "Raana Sherwani",
    pw: "RAANA_PASSWORD",
  },
  {
    email: "masoodsherwani@anexomail.com",
    name: "Masood Sherwani",
    pw: "MASOOD_PASSWORD",
  },
];

let red = 0;
const ok = (m: string) => console.log("GREEN", m);
const bad = (m: string) => {
  red++;
  console.log("RED  ", m);
};

async function findUser(email: string) {
  for (let page = 1; page <= 20; page++) {
    const { data, error } = await db.auth.admin.listUsers({ page, perPage: 200 });
    if (error) throw error;
    const hit = data.users.find((u) => (u.email || "").toLowerCase() === email);
    if (hit) return hit;
    if (data.users.length < 200) break;
  }
  return null;
}

// ── Founder: password TOUCH nahi — sirf maujood + founder_accounts ──
{
  const founder = await findUser(FOUNDER_EMAIL);
  if (!founder) {
    bad(`${FOUNDER_EMAIL}: Auth user missing — founder pehle se hona chahiye. Password yahan se nahi banta.`);
  } else {
    ok(`${FOUNDER_EMAIL} present (uid ${founder.id}) — password untouched`);
    const { data, error } = await db
      .from("founder_accounts")
      .select("user_id")
      .eq("user_id", founder.id)
      .maybeSingle();
    if (error) bad(`founder_accounts read: ${error.message}`);
    else if (data) ok(`founder_accounts row present (${founder.id})`);
    else {
      const ins = await db.from("founder_accounts").insert({ user_id: founder.id, email: founder.email });
      if (ins.error) bad(`founder_accounts insert: ${ins.error.message}`);
      else ok(`founder_accounts row inserted (${founder.id})`);
    }
  }
}

// ── Family: create/update ONLY with .env keys (ek dafa nano) ──
for (const a of FAMILY) {
  const password = process.env[a.pw] || "";
  if (password.length < 6 || password.length > 15) {
    bad(
      `${a.email}: ${a.pw} missing in /opt/anexomail/.env (6-15 chars). nano /opt/anexomail/.env — bar bar type nahi.`,
    );
    continue;
  }
  try {
    const existing = await findUser(a.email);
    if (existing) {
      const { error } = await db.auth.admin.updateUserById(existing.id, {
        password,
        email_confirm: true,
        user_metadata: { full_name: a.name, recovery_email: RECOVERY_EMAIL },
      });
      if (error) throw error;
      ok(`${a.email} → password from .env applied (uid ${existing.id})`);
    } else {
      const { data, error } = await db.auth.admin.createUser({
        email: a.email,
        password,
        email_confirm: true,
        user_metadata: { full_name: a.name, recovery_email: RECOVERY_EMAIL },
      });
      if (error) throw error;
      ok(`${a.email} created from .env (uid ${data.user?.id})`);
    }
  } catch (e: any) {
    bad(`${a.email}: ${e?.message || e}`);
  }
}

{
  const { data, error } = await db.rpc("family_grants_apply");
  if (error)
    bad(`family_grants_apply: ${error.message} (docs/cursor-work/sql/phase63_f3a_passkey_family.sql run hai?)`);
  else ok(`family_grants_apply → ${JSON.stringify(data)} (expected 3)`);
}

{
  const { data, error } = await db.rpc("family_workspaces_apply");
  if (error)
    bad(
      `family_workspaces_apply: ${error.message} (docs/cursor-work/sql/phase63_f3a_passkey_family.sql run hai?)`,
    );
  else ok(`family_workspaces_apply → ${JSON.stringify(data)} (expected 3)`);
}

{
  const { data, error } = await db.rpc("family_chat_workspace_apply");
  if (error)
    bad(
      `family_chat_workspace_apply: ${error.message} (anexochat/sql/phase31b_family_chat_workspace.sql run hai?)`,
    );
  else if (!data?.ok || data?.members !== 3)
    bad(`family chat workspace invalid: ${JSON.stringify(data)}`);
  else ok("founder + Humza + Raana shared ANEXOChat workspace → 3 members + direct chats ready");
}

// Login proof — family only (founder password env se nahi chhoota)
for (const a of FAMILY) {
  const password = process.env[a.pw] || "";
  if (!password) continue;
  const { data, error } = await db.auth.signInWithPassword({ email: a.email, password });
  if (error || !data.session) bad(`login ${a.email}: ${error?.message || "no session"}`);
  else ok(`login ${a.email} → session OK`);
}

const liveTokens = new Map<string, string>();
for (const a of FAMILY) {
  const password = process.env[a.pw] || "";
  if (!password) continue;
  try {
    const response = await fetch(`${BRAIN_URL}/api/auth/login`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ email: a.email, password }),
    });
    const body = (await response.json()) as {
      token?: string;
      user?: { is_founder?: boolean };
      error?: string;
    };
    if (!response.ok || !body.token) throw new Error(body.error || `HTTP ${response.status}`);
    liveTokens.set(a.email, body.token);
    ok(`website login ${a.email} → Brain session OK`);
  } catch (e: any) {
    bad(`website login ${a.email}: ${e?.message || e}`);
  }
}

// Founder website login — password bina: session proof skip; authority pehle check ho chuki
{
  try {
    const response = await fetch(`${BRAIN_URL}/api/auth/session`, {
      headers: { authorization: "Bearer x" },
    });
    if (response.status === 401) ok("Brain auth guard alive (401 without token)");
    else bad(`Brain session guard unexpected HTTP ${response.status}`);
  } catch (e: any) {
    bad(`Brain unreachable: ${e?.message || e}`);
  }
}

const founder = await findUser(FOUNDER_EMAIL);
if (founder) {
  // optional: if founder already has a live token from elsewhere — skip Rust if no token
  try {
    // Use service-side bootstrap only when we can get founder token without password reset.
    // Prefer: skip Rust founder bootstrap if no FOUNDER session — not RED for missing password.
    ok("Rust founder chat proof skipped (founder password never loaded by this script)");
  } catch {
    /* ignore */
  }
  void RUST_URL;
  void liveTokens;
}

console.log(red === 0 ? "\nALL GREEN — family from .env; founder password untouched" : `\nRED=${red}`);
process.exit(red === 0 ? 0 : 1);
