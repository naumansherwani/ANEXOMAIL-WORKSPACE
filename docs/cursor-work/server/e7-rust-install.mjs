// E7 (#7) Rust installer — /opt/anexomail-rust/src/main.rs: mail.identities
import fs from "fs";
import crypto from "crypto";
import { spawnSync } from "child_process";
const SIM = process.env.SIM === "1";
const ROOT = SIM ? "/tmp/e7sim/rust/" : "/opt/anexomail-rust/src/";
const EXPECT = {"main.rs": "30a92a32af445408"};
const EDITS = [["        \"mail.thread\" => {\n", "        \"mail.identities\" => mail_identities(&me.org_id, &me.email).await,\n        \"mail.thread\" => {\n"], ["async fn mail_domains_list(org: &str) -> Result<Value, String> {\n", "/// #7 \u2014 Compose \"Send from\": is user ke liye jaiz From addresses. Qaida Bun `lib/identity.ts` jaisa:\n/// org ke mailboxes / mail_accounts / org_addresses (alias nahi, inactive nahi) + apna @anexomail.com login.\n/// Default = apna login (warna pehla). Naya code Rust-first; Bun fallback nahi.\nasync fn mail_identities(org: &str, own_email: &str) -> Result<Value, String> {\n    let mut found: std::collections::BTreeMap<String, &'static str> = std::collections::BTreeMap::new();\n    let sources: [(String, &str); 3] = [\n        (format!(\"mailboxes?select=address,box_type,active&org_id=eq.{org}\"), \"box_type\"),\n        (format!(\"mail_accounts?select=address&org_id=eq.{org}\"), \"\"),\n        (format!(\"org_addresses?select=address,kind,active&org_id=eq.{org}\"), \"kind\"),\n    ];\n    for (path, kind_col) in sources.iter() {\n        let rows = sb_select(path).await.unwrap_or(json!([]));\n        for r in rows.as_array().cloned().unwrap_or_default() {\n            let addr = r\n                .get(\"address\")\n                .and_then(|v| v.as_str())\n                .unwrap_or(\"\")\n                .trim()\n                .to_lowercase();\n            if addr.is_empty() || !addr.contains('@') {\n                continue;\n            }\n            if r.get(\"active\").and_then(|v| v.as_bool()) == Some(false) {\n                continue;\n            }\n            let kind = if kind_col.is_empty() {\n                \"mailbox\"\n            } else {\n                r.get(*kind_col).and_then(|v| v.as_str()).unwrap_or(\"mailbox\")\n            };\n            if kind == \"alias\" {\n                continue;\n            }\n            found.insert(addr, if kind == \"shared\" { \"shared\" } else { \"mailbox\" });\n        }\n    }\n    let own = own_email.trim().to_lowercase();\n    if own.ends_with(\"@anexomail.com\") {\n        found.entry(own.clone()).or_insert(\"mailbox\");\n    }\n    let mut list: Vec<Value> = Vec::new();\n    if found.contains_key(&own) {\n        list.push(json!({ \"address\": own, \"kind\": \"login\" }));\n    }\n    for (addr, kind) in found.iter() {\n        if *addr == own {\n            continue;\n        }\n        list.push(json!({ \"address\": addr, \"kind\": kind }));\n    }\n    let default = list\n        .first()\n        .and_then(|v| v.get(\"address\"))\n        .cloned()\n        .unwrap_or(Value::Null);\n    Ok(json!({ \"identities\": list, \"default\": default }))\n}\n\nasync fn mail_domains_list(org: &str) -> Result<Value, String> {\n"]];
const sha = (f) => crypto.createHash("sha256").update(fs.readFileSync(ROOT + f)).digest("hex").slice(0, 16);
let src = fs.readFileSync(ROOT + "main.rs", "utf8");
if (src.includes("async fn mail_identities")) { console.log("ALREADY PATCHED - kuch nahi badla"); process.exit(0); }
if (sha("main.rs") !== EXPECT["main.rs"]) { console.log("STOP: main.rs live sha " + sha("main.rs") + " != expected " + EXPECT["main.rs"] + " - kuch nahi badla, yeh line mujhe bhejo"); process.exit(2); }
for (const [o, n] of EDITS) {
  const c = src.split(o).length - 1;
  if (c !== 1) { console.log("STOP: anchor " + c + " baar mila - kuch nahi badla"); process.exit(3); }
  src = src.replace(o, () => n);
}
const bak = ROOT + "main.rs.bak.e7." + Date.now();
fs.copyFileSync(ROOT + "main.rs", bak);
fs.writeFileSync(ROOT + "main.rs", src);
console.log("main.rs patched, backup: " + bak);
if (SIM) process.exit(0);
console.log("--- cargo build --release (kuch minute lagte hain) ---");
const b = spawnSync("cargo", ["build", "--release"], { cwd: "/opt/anexomail-rust", stdio: "inherit" });
if (b.status !== 0) { fs.copyFileSync(bak, ROOT + "main.rs"); console.log("BUILD FAIL - main.rs wapas purani, purani binary chal rahi hai. Upar ka error mujhe bhejo."); process.exit(4); }
spawnSync("pm2", ["restart", "anexomail-rust", "--update-env"], { stdio: "ignore" });
spawnSync("pm2", ["save"], { stdio: "ignore" });
spawnSync("sleep", ["3"]);
const h = spawnSync("curl", ["-s", "-o", "/dev/null", "-w", "rust /rpc/health %{http_code}\n", "--max-time", "5", "http://127.0.0.1:3200/rpc/health"], { stdio: "inherit" });
