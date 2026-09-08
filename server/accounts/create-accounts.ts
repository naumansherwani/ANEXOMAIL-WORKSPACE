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

const ACCOUNTS = [
  { email: "naumansherwani.founder@anexomail.com", name: "Muhammad Nauman Sherwani", pw: "FOUNDER_MAIL_PASSWORD", founder: true },
  { email: "humzasherwani@anexomail.com", name: "Humza Sherwani", pw: "HUMZA_PASSWORD", founder: false },
  { email: "raanasherwani@anexomail.com", name: "Raana Sherwani", pw: "RAANA_PASSWORD", founder: false },
];

let red = 0;
const ok = (m: string) => console.log("GREEN", m);
const bad = (m: string) => { red++; console.log("RED  ", m); };

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
  if (password.length < 8) { bad(`${a.email}: ${a.pw} env khali/8 se chhota — skip`); continue; }
  try {
    const existing = await findUser(a.email);
    if (existing) {
      const { error } = await db.auth.admin.updateUserById(existing.id, {
        password, email_confirm: true, user_metadata: { full_name: a.name },
      });
      if (error) throw error;
      ok(`${a.email} pehle se tha → password reset + confirmed (uid ${existing.id})`);
    } else {
      const { data, error } = await db.auth.admin.createUser({
        email: a.email, password, email_confirm: true, user_metadata: { full_name: a.name },
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
    const { data, error } = await db.from("founder_accounts").select("user_id").eq("user_id", founder.id).maybeSingle();
    if (error) bad(`founder_accounts read: ${error.message}`);
    else if (data) ok(`founder_accounts row present (${founder.id})`);
    else {
      const ins = await db.from("founder_accounts").insert({ user_id: founder.id, email: founder.email });
      if (ins.error) bad(`founder_accounts insert: ${ins.error.message} — SQL editor se manually daalo`);
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

// Login proof (service key nahi — asli signInWithPassword, anon-less admin client bhi chalta hai)
for (const a of ACCOUNTS) {
  const password = process.env[a.pw] || "";
  if (!password) continue;
  const { data, error } = await db.auth.signInWithPassword({ email: a.email, password });
  if (error || !data.session) bad(`login ${a.email}: ${error?.message || "no session"}`);
  else ok(`login ${a.email} → session OK`);
}

console.log(red === 0 ? "\nALL GREEN — ab browser /auth se login karo" : `\nRED=${red}`);
process.exit(red === 0 ? 0 : 1);
