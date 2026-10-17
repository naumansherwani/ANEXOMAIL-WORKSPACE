// Prints, from the REAL src/lib/plan-surface.ts, what each package sees (rail + denial text) — no guessing.
// Run: TOOLS=/opt/npm-tools/node_modules node docs/cursor-work/founder/tools/plan-surface-matrix.mjs > docs/cursor-work/founder/plan-surface-matrix.md
import { createRequire } from "node:module";
import { pathToFileURL } from "node:url";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
const tools = process.env.TOOLS || "/opt/npm-tools/node_modules";
const esbuild = createRequire(tools + "/")("esbuild");
const dir = mkdtempSync(join(tmpdir(), "psm-"));
const out = join(dir, "ps.mjs");
await esbuild.build({ entryPoints: ["src/lib/plan-surface.ts"], bundle: true, format: "esm", outfile: out, loader: { ".ts": "ts" }, logLevel: "silent" });
const ps = await import(pathToFileURL(out).href);

const RAIL = [["/app", "Dashboard"], ["/app/mail/inbox", "Mail"], ["/app/people", "People"], ["/app/calendar", "Calendar"], ["/app/work", "Work"], ["/app/crm", "CRM"], ["/app/org", "Org"], ["/app/domains", "Domains"], ["/app/safety", "Safety"], ["/app/chat", "ANEXOChat"]];
const FEAT = [["Pro mail tools", ps.showProMailTools], ["Multiple identities", ps.showMultipleIdentities], ["Full video", ps.showFullVideo], ["CRM collab", ps.showCrmCollab], ["CRM activity ledger", ps.showCrmLedger], ["CRM risk", ps.showCrmRisk], ["CRM graph", ps.showCrmGraph], ["Work business record", ps.showWorkBusinessRecord]];
const plans = ["basic", "pro", "business", "business_pro"];
const kinds = ["personal", "business"];
const host = { publicMailHost: true, aiHost: false, founderHost: false };

console.log("# Package surface matrix (generated from `src/lib/plan-surface.ts`)\n");
console.log("Regenerate: `TOOLS=/opt/npm-tools/node_modules node docs/cursor-work/founder/tools/plan-surface-matrix.mjs > docs/cursor-work/founder/plan-surface-matrix.md`. Rule 5: this is what the CODE says; it is not proof of what a live account sees.\n");
console.log("`personal` is what Basic and Pro buyers get by default; `business` is what Business / Business Pro buyers get. A cell is ✔ when the rail item shows.\n");
const cols = plans.flatMap((p) => kinds.map((k) => [p, k]));
console.log("| Rail item | " + cols.map(([p, k]) => `${p} · ${k}`).join(" | ") + " |");
console.log("|---|" + cols.map(() => "---").join("|") + "|");
for (const [to, label] of RAIL) console.log(`| ${label} | ` + cols.map(([p, k]) => (ps.railItemVisible(to, { ...host, plan: p, kind: k, founder: false }) ? "✔" : "—")).join(" | ") + " |");
for (const [label, fn] of FEAT) console.log(`| _${label}_ | ` + cols.map(([p, k]) => (fn(p, null, k) ? "✔" : "—")).join(" | ") + " |");
console.log("\n## Package names the user sees\n");
console.log("| plan · kind | copy name |\n|---|---|");
for (const [p, k] of cols) console.log(`| ${p} · ${k} | ${ps.packageCopyName(p, k)} |`);
console.log("\n## What a locked page says (denial copy), per package\n");
for (const [p, k] of cols) {
  const rows = [];
  for (const [to, label] of RAIL) {
    if (to === "/app" || to.startsWith("/app/mail") || to === "/app/people" || to === "/app/calendar") continue;
    const d = ps.surfaceDenial(to === "/app/crm" ? "/app/crm" : to, { ...host, plan: p, kind: k, founder: false });
    if (d) rows.push(`- **${label}** → “${d.title}”`);
  }
  console.log(`**${p} · ${k}** (${ps.packageCopyName(p, k)})\n${rows.join("\n") || "- nothing locked"}\n`);
}
console.log("## Plain-reading checks\n");
const odd = [];
for (const k of kinds) {
  if (ps.showCrmGraph("pro", null, k) && !ps.showCrmCollab("pro", null, k)) odd.push(`graph without collab for pro · ${k}`);
}
if (ps.railItemVisible("/app/crm", { ...host, plan: "basic", kind: "business", founder: false }) === false && ps.railItemVisible("/app/domains", { ...host, plan: "basic", kind: "business", founder: false })) odd.push("Basic · business sees Domains but not Work/CRM (a Basic company account gets the domain tool without the tools that use it)");
if (ps.showOrg("business", null, "personal")) odd.push("Org visible on a personal account");
console.log(odd.length ? odd.map((x) => "- " + x).join("\n") : "- none found by these rules");
