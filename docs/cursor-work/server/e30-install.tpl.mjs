// E30 installer — dashboard ka sach: Rust :3200 (PRIMARY) + Brain (fallback) + web.
// Generator: e30-build-installer.py (git HEAD -> anchor edits). Live sha nahi, EXACT anchor gate hai:
// har edit ka purana text live file mein ek hi baar milna chahiye, warna STOP aur kuch nahi badalta.
// SQL (E30_dashboard_truth.sql) is script se PEHLE chalti hai (wrapper block). Dobara chalane se kuch nahi badalta.
import fs from "fs";
import path from "path";
import { spawnSync } from "child_process";

const SIM = process.env.SIM === "1";
const BASE = SIM ? "/tmp/e30sim" : "";
const ROOTS = {
  rust: BASE + "/opt/anexomail-rust/src/",
  brain: BASE + "/opt/anexomail/src/",
  web: BASE + "/opt/anexomail-web/",
};
const EDITS = __EDITS__;

// ---- 1. preflight: sab kuch memory mein, disk par kuch nahi ----
const files = {};
let todo = 0;
for (const e of EDITS) {
  const key = e.area + "|" + e.f;
  if (!(key in files)) files[key] = fs.readFileSync(ROOTS[e.area] + e.f, "utf8");
  const src = files[key];
  const c = src.split(e.old).length - 1;
  if (c === 1) {
    files[key] = src.replace(e.old, () => e.new);
    todo++;
  } else if (c === 0 && src.includes(e.new)) {
    // pehle se laga hua
  } else {
    console.log("STOP: anchor " + c + " baar mila in " + e.area + "/" + e.f + " - kuch nahi badla. Yeh line mujhe bhejo:");
    console.log(e.old.slice(0, 200));
    process.exit(3);
  }
}
if (todo === 0) {
  console.log("ALREADY PATCHED - kuch nahi badla");
  process.exit(0);
}

// ---- 2. backup + restore.sh ----
const bak = (SIM ? BASE + "/bak-" : "/root/e30-bak-") + Date.now() + "/";
const restore = ["#!/bin/bash", "# E30 restore: purani files wapas, phir rebuild"];
for (const key of Object.keys(files)) {
  const [area, f] = key.split("|");
  const dst = bak + area + "/" + f;
  fs.mkdirSync(path.dirname(dst), { recursive: true });
  fs.copyFileSync(ROOTS[area] + f, dst);
  restore.push(`cp '${dst}' '${ROOTS[area] + f}'`);
}
restore.push("cd /opt/anexomail-rust && cargo build --release && pm2 restart anexomail-rust --update-env");
restore.push("cd /opt/anexomail-web && bun run build:bun && pm2 restart anexomail-web --update-env");
restore.push("pm2 restart anexomail-leo --update-env && pm2 save");
fs.writeFileSync(bak + "restore.sh", restore.join("\n") + "\n", { mode: 0o755 });

const restoreArea = (areas) => {
  for (const key of Object.keys(files)) {
    const [area, f] = key.split("|");
    if (areas.includes(area)) fs.copyFileSync(bak + area + "/" + f, ROOTS[area] + f);
  }
};

// ---- 3. likho ----
for (const [key, content] of Object.entries(files)) {
  const [area, f] = key.split("|");
  fs.writeFileSync(ROOTS[area] + f, content);
}
console.log("patched " + Object.keys(files).length + " files, " + todo + " edits. backup: " + bak);
if (SIM) process.exit(0);

// ---- 4. Rust build (fail = sab wapas) ----
console.log("--- cargo build --release (1-2 minute) ---");
const cb = spawnSync("cargo", ["build", "--release"], { cwd: "/opt/anexomail-rust", stdio: "inherit" });
if (cb.status !== 0) {
  restoreArea(["rust", "brain", "web"]);
  console.log("RUST BUILD FAIL - sab files wapas purani, purani binary chal rahi hai. Upar ka error mujhe bhejo.");
  process.exit(4);
}

// ---- 5. web build (fail = web files wapas; Rust/Brain naye rahte hain, purane web ke saath bhi theek) ----
console.log("--- bun run build:bun ---");
const wb = spawnSync("bun", ["run", "build:bun"], { cwd: "/opt/anexomail-web", stdio: "inherit" });
if (wb.status !== 0) {
  restoreArea(["web"]);
  console.log("WEB BUILD FAIL - web files wapas purani (Rust/Brain naye). Upar ka error mujhe bhejo.");
}

// ---- 6. restart ----
for (const app of ["anexomail-rust", "anexomail-leo", "anexomail-web"]) {
  spawnSync("pm2", ["restart", app, "--update-env"], { stdio: "ignore" });
}
spawnSync("pm2", ["save"], { stdio: "ignore" });
spawnSync("sleep", ["4"]);
const H = (label, url) =>
  spawnSync("curl", ["-s", "-o", "/dev/null", "-w", label + " %{http_code}\n", "--max-time", "5", url], { stdio: "inherit" });
H("rust /rpc/health", "http://127.0.0.1:3200/rpc/health");
H("brain /api/dashboard/summary (401 = theek, auth chahiye)", "http://127.0.0.1:3100/api/dashboard/summary");
H("web /health", "http://127.0.0.1:3000/health");
console.log("restore chahiye to: bash " + bak + "restore.sh");
