// #8 installer — Domains & addresses (D): sirf web (/opt/anexomail-web). Rust/Brain/DB nahi chhute.
// Generator: i8-build-installer.py (git HEAD -> anchor edits + naye files). Live sha nahi, EXACT anchor gate hai:
// har edit ka purana text live file mein ek hi baar milna chahiye, warna STOP aur kuch nahi badalta.
// Naye files (domains.ts, app.domains.tsx) backup ke baad likhe jate hain. routeTree.gen.ts build khud banata hai.
import fs from "fs";
import path from "path";
import { spawnSync } from "child_process";

const SIM = process.env.SIM === "1";
const WEB = (SIM ? "/tmp/i8sim" : "") + "/opt/anexomail-web/";
const EDITS = __EDITS__;
const NEWF = __NEWFILES__;

// ---- 1. preflight: sab kuch memory mein, disk par kuch nahi ----
const files = {}; // f -> final content
const existed = {}; // f -> bool
let todo = 0;
for (const e of EDITS) {
  if (!(e.f in files)) {
    files[e.f] = fs.readFileSync(WEB + e.f, "utf8");
    existed[e.f] = true;
  }
  const src = files[e.f];
  const c = src.split(e.old).length - 1;
  if (c === 1) {
    files[e.f] = src.replace(e.old, () => e.new);
    todo++;
  } else if (c === 0 && src.includes(e.new)) {
    // pehle se laga hua
  } else {
    console.log("STOP: anchor " + c + " baar mila in " + e.f + " - kuch nahi badla. Yeh line mujhe bhejo:");
    console.log(e.old.slice(0, 200));
    process.exit(3);
  }
}
for (const n of NEWF) {
  const have = fs.existsSync(WEB + n.f);
  existed[n.f] = have;
  if (have && fs.readFileSync(WEB + n.f, "utf8") === n.content) continue;
  files[n.f] = n.content;
  todo++;
}
if (todo === 0) {
  console.log("ALREADY PATCHED - kuch nahi badla");
  process.exit(0);
}

// ---- 2. backup + restore.sh ----
const bak = (SIM ? "/tmp/i8sim/bak-" : "/root/i8-bak-") + Date.now() + "/";
const restore = ["#!/bin/bash", "# #8 restore: purani files wapas (naye files hata do), phir web rebuild"];
for (const f of Object.keys(files)) {
  if (existed[f]) {
    const dst = bak + f;
    fs.mkdirSync(path.dirname(dst), { recursive: true });
    fs.copyFileSync(WEB + f, dst);
    restore.push(`cp '${dst}' '${WEB + f}'`);
  } else {
    restore.push(`rm -f '${WEB + f}'`);
  }
}
restore.push("cd /opt/anexomail-web && bun run build:bun && pm2 restart anexomail-web --update-env && pm2 save");
fs.mkdirSync(bak, { recursive: true });
fs.writeFileSync(bak + "restore.sh", restore.join("\n") + "\n", { mode: 0o755 });

const restoreAll = () => {
  for (const f of Object.keys(files)) {
    if (existed[f]) fs.copyFileSync(bak + f, WEB + f);
    else fs.rmSync(WEB + f, { force: true });
  }
};

// ---- 3. likho ----
for (const [f, content] of Object.entries(files)) {
  fs.mkdirSync(path.dirname(WEB + f), { recursive: true });
  fs.writeFileSync(WEB + f, content);
}
console.log("patched " + Object.keys(files).length + " files, " + todo + " edits. backup: " + bak);
if (SIM) process.exit(0);

// ---- 4. web build (fail = sab wapas + purani build dobara) ----
console.log("--- bun run build:bun (1-2 minute) ---");
const wb = spawnSync("bun", ["run", "build:bun"], { cwd: "/opt/anexomail-web", stdio: "inherit" });
if (wb.status !== 0) {
  restoreAll();
  spawnSync("bun", ["run", "build:bun"], { cwd: "/opt/anexomail-web", stdio: "ignore" });
  console.log("WEB BUILD FAIL - files wapas purani aur purani build dobara bani. Upar ka error mujhe bhejo.");
  process.exit(4);
}

// ---- 5. restart ----
spawnSync("pm2", ["restart", "anexomail-web", "--update-env"], { stdio: "ignore" });
spawnSync("pm2", ["save"], { stdio: "ignore" });
spawnSync("sleep", ["4"]);
spawnSync("curl", ["-s", "-o", "/dev/null", "-w", "web /health %{http_code}\n", "--max-time", "5", "http://127.0.0.1:3000/health"], { stdio: "inherit" });
const g = spawnSync("sh", ["-c", "grep -rl 'Connect a domain' /opt/anexomail-web/.output /opt/anexomail-web/dist 2>/dev/null | head -2"], { encoding: "utf8" });
console.log("build mein naya page: " + (g.stdout.trim() ? g.stdout.trim().replace(/\n/g, ", ") : "NAHI MILA (build dir alag ho sakti hai)"));
console.log("restore chahiye to: bash " + bak + "restore.sh");
