// ANEXOMAIL — teen founder/family accounts Supabase Auth mein banao (idempotent).
// Run: bash server/accounts/create-accounts.sh   (passwords env se, kabhi print nahi)
import { createClient } from "@supabase/supabase-js";

const url = process.env.SUPABASE4_URL || process.env.SUPABASE_URL || "";
const key = process.env.SUPABASE4_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY || "";
if (!url || !key) {
  console.error("RED  SUPABASE_URL / SERVICE_ROLE_KEY env missing (source /opt/anexomail/.env)");
  process.exit(1);
}
const db = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });

const RECOVERY_EMAIL = "anexomail27@gmail.com";
const BRAIN_URL = process.env.BRAIN_URL || "http://127.0.0.1:3100";
const RUST_URL = process.env.RUST_URL || "http://127.0.0.1:3200";

const ACCOUNTS = [
  {
    email: "naumansherwani.founder@anexomail.com",
    name: "Muhammad Nauman Sherwani",
    pw: "FOUNDER_MAIL_PASSWORD",
    founder: true,
  },
  {
    email: "humzasherwani@anexomail.com",
    name: "Humza Sherwani",
    pw: "HUMZA_PASSWORD",
    founder: false,
  },
  {
    email: "raanasherwani@anexomail.com",
    name: "Raana Sherwani",
    pw: "RAANA_PASSWORD",
    founder: false,
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

for (const a of ACCOUNTS) {
  const password = process.env[a.pw] || "";
  if (password.length < 6 || password.length > 15) {
    bad(`${a.email}: ${a.pw} env 6-15 characters ka hona chahiye — skip`);
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
      ok(`${a.email} pehle se tha → password reset + confirmed (uid ${existing.id})`);
    } else {
      const { data, error } = await db.auth.admin.createUser({
        email: a.email,
        password,
        email_confirm: true,
        user_metadata: { full_name: a.name, recovery_email: RECOVERY_EMAIL },
      });
      if (error) throw error;
      ok(`${a.email} created + confirmed (uid ${data.user?.id})`);
    }
  } catch (e: any) {
    bad(`${a.email}: ${e?.message || e}`);
  }
}

// Founder authority row
{
  const founder = await findUser(ACCOUNTS[0].email);
  if (founder) {
    const { data, error } = await db
      .from("founder_accounts")
      .select("user_id")
      .eq("user_id", founder.id)
      .maybeSingle();
    if (error) bad(`founder_accounts read: ${error.message}`);
    else if (data) ok(`founder_accounts row present (${founder.id})`);
    else {
      const ins = await db
        .from("founder_accounts")
        .insert({ user_id: founder.id, email: founder.email });
      if (ins.error)
        bad(`founder_accounts insert: ${ins.error.message} — SQL editor se manually daalo`);
      else ok(`founder_accounts row inserted (${founder.id})`);
    }
  }
}

// Family entitlement (phase56)
{
  const { data, error } = await db.rpc("family_grants_apply");
  if (error) bad(`family_grants_apply: ${error.message} (sql/phase56_mailbox_final.sql run hai?)`);
  else ok(`family_grants_apply → ${JSON.stringify(data)} (expected 2)`);
}

// Founder + family ek hi real chat workspace mein; direct conversations pehle se ready.
{
  const { data, error } = await db.rpc("family_chat_workspace_apply");
  if (error)
    bad(
      `family_chat_workspace_apply: ${error.message} (sql/phase60_family_chat_workspace.sql run hai?)`,
    );
  else if (!data?.ok || data?.members !== 3)
    bad(`family chat workspace invalid: ${JSON.stringify(data)}`);
  else ok("founder + Humza + Raana shared ANEXOChat workspace → 3 members + direct chats ready");
}

// Login proof (service key nahi — asli signInWithPassword, anon-less admin client bhi chalta hai)
for (const a of ACCOUNTS) {
  const password = process.env[a.pw] || "";
  if (!password) continue;
  const { data, error } = await db.auth.signInWithPassword({ email: a.email, password });
  if (error || !data.session) bad(`login ${a.email}: ${error?.message || "no session"}`);
  else ok(`login ${a.email} → session OK`);
}

// Website ka asli login endpoint bhi lazmi hai. Direct Auth green aur Brain red ho
// to script ALL GREEN nahi bolti.
const liveTokens = new Map<string, string>();
for (const a of ACCOUNTS) {
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
    if (a.founder && body.user?.is_founder !== true) throw new Error("founder authority missing");
    liveTokens.set(a.email, body.token);
    ok(`website login ${a.email} → Brain session OK`);
  } catch (e: any) {
    bad(`website login ${a.email}: ${e?.message || e}`);
  }
}

// Rust PRIMARY par founder ko dono family members aur dono direct conversations nazar aani chahiye.
const founderToken = liveTokens.get(ACCOUNTS[0].email);
if (founderToken) {
  try {
    const headers = { authorization: `Bearer ${founderToken}`, "content-type": "application/json" };
    const bootstrapResponse = await fetch(`${RUST_URL}/rpc/chat.bootstrap`, {
      method: "POST",
      headers,
      body: "{}",
    });
    const bootstrap = (await bootstrapResponse.json()) as {
      members?: { user_id: string }[];
      error?: unknown;
    };
    if (!bootstrapResponse.ok || (bootstrap.members?.length || 0) < 3) {
      throw new Error(`bootstrap members=${bootstrap.members?.length || 0}`);
    }
    const conversationsResponse = await fetch(`${RUST_URL}/rpc/chat.conversations`, {
      method: "POST",
      headers,
      body: "{}",
    });
    const conversations = (await conversationsResponse.json()) as { conversations?: unknown[] };
    if (!conversationsResponse.ok || (conversations.conversations?.length || 0) < 2) {
      throw new Error(`direct conversations=${conversations.conversations?.length || 0}`);
    }
    ok("Rust ANEXOChat founder bootstrap → 3 members + 2 direct conversations visible");
  } catch (e: any) {
    bad(`Rust ANEXOChat live proof: ${e?.message || e}`);
  }
}

console.log(red === 0 ? "\nALL GREEN — website login + shared ANEXOChat ready" : `\nRED=${red}`);
process.exit(red === 0 ? 0 : 1);
