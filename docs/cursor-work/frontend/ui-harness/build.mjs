// Sandbox-only UI harness: bundles the REAL page source with stubs for packages the sandbox lacks,
// compiles the REAL src/styles.css with Tailwind 4, so Playwright can screenshot it.
// Usage: node build.mjs <outDir>   (REPO / TOOLS env override the defaults)
import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";

const REPO = process.env.REPO || "/home/claude/anexomail-workspace";
const TOOLS = process.env.TOOLS || "/opt/npm-tools/node_modules";
const OUT = path.resolve(process.argv[2] || "./out");
const HERE = path.dirname(new URL(import.meta.url).pathname);
const require = createRequire(TOOLS + "/");
const esbuild = require("esbuild");
const { compile } = await import(TOOLS + "/tailwindcss/dist/lib.mjs");
fs.mkdirSync(OUT, { recursive: true });

// ---- lucide stand-ins (real 24x24 stroke paths for the common ones; circle for the rest)
const P = {
  Globe: '<circle cx="12" cy="12" r="10"/><path d="M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20"/><path d="M2 12h20"/>',
  Mail: '<rect width="20" height="16" x="2" y="4" rx="2"/><path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7"/>',
  Lock: '<rect width="18" height="11" x="3" y="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>',
  Copy: '<rect width="14" height="14" x="8" y="8" rx="2" ry="2"/><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"/>',
  CheckCircle2: '<circle cx="12" cy="12" r="10"/><path d="m9 12 2 2 4-4"/>',
  Check: '<path d="M20 6 9 17l-5-5"/>',
  Circle: '<circle cx="12" cy="12" r="10"/>',
  Clock: '<circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/>',
  ArrowRight: '<path d="M5 12h14"/><path d="m12 5 7 7-7 7"/>',
  AtSign: '<circle cx="12" cy="12" r="4"/><path d="M16 8v5a3 3 0 0 0 6 0v-1a10 10 0 1 0-4 8"/>',
  Loader2: '<path d="M21 12a9 9 0 1 1-6.219-8.56"/>',
  Plus: '<path d="M5 12h14"/><path d="M12 5v14"/>',
  RefreshCw: '<path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8"/><path d="M21 3v5h-5"/><path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16"/><path d="M8 16H3v5"/>',
  AlertTriangle: '<path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3"/><path d="M12 9v4"/><path d="M12 17h.01"/>',
  Mail: '<rect width="20" height="16" x="2" y="4" rx="2"/><path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7"/>',
  ShieldCheck: '<path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"/><path d="m9 12 2 2 4-4"/>',
  Trash2: '<path d="M3 6h18"/><path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6"/><path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2"/><line x1="10" x2="10" y1="11" y2="17"/><line x1="14" x2="14" y1="11" y2="17"/>',
  X: '<path d="M18 6 6 18"/><path d="m6 6 12 12"/>',
  MailPlus: '<path d="M22 13V6a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2v12c0 1.1.9 2 2 2h8"/><path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7"/><path d="M19 16v6"/><path d="M16 19h6"/>',
  Sparkles: '<path d="M9.937 15.5A2 2 0 0 0 8.5 14.063l-6.135-1.582a.5.5 0 0 1 0-.962L8.5 9.936A2 2 0 0 0 9.937 8.5l1.582-6.135a.5.5 0 0 1 .963 0L14.063 8.5A2 2 0 0 0 15.5 9.937l6.135 1.581a.5.5 0 0 1 0 .964L15.5 14.063a2 2 0 0 0-1.437 1.437l-1.582 6.135a.5.5 0 0 1-.963 0z"/>',
  Inbox: '<polyline points="22 12 16 12 14 15 10 15 8 12 2 12"/><path d="M5.45 5.11 2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z"/>',
  Send: '<path d="M14.536 21.686a.5.5 0 0 0 .937-.024l6.5-19a.496.496 0 0 0-.635-.635l-19 6.5a.5.5 0 0 0-.024.937l7.93 3.18a2 2 0 0 1 1.112 1.11z"/><path d="m21.854 2.147-10.94 10.939"/>',
};
const srcs = [path.join(REPO, "src/routes/app.domains.tsx"), path.join(REPO, "src/components/app/dashboard/SetupChecklist.tsx")];
const names = new Set();
for (const f of srcs) for (const m of fs.readFileSync(f, "utf8").matchAll(/import\s*\{([^}]+)\}\s*from\s*"lucide-react"/g))
  m[1].split(",").map((s) => s.trim()).filter(Boolean).forEach((n) => names.add(n.replace(/^type\s+/, "")));
let lucide = 'import * as React from "react";\nconst mk=(inner:string)=>(p:React.SVGProps<SVGSVGElement>)=><svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" {...p} dangerouslySetInnerHTML={{__html:inner}}/>;\n';
for (const n of names) lucide += `export const ${n}=mk(${JSON.stringify(P[n] || P.Circle)});\n`;
fs.writeFileSync(path.join(OUT, "lucide.tsx"), lucide);

// ---- JS bundle
const stub = (f) => path.join(HERE, "stubs", f);
const MAP = {
  "@/lib/domains": stub("domains.ts"),
  "@/lib/dashboard": stub("lib.ts"),
  "@/lib/i18n": stub("lib.ts"),
  "@/lib/notify": stub("lib.ts"),
  "@/lib/plan-surface": stub("lib.ts"),
  "@/components/app/org/OrgBits": stub("ui.tsx"),
  "@/components/state/StateBlock": stub("ui.tsx"),
  "@/components/ui/alert-dialog": stub("ui.tsx"),
  "lucide-react": path.join(OUT, "lucide.tsx"),
  "@tanstack/react-router": stub("router.ts"),
  "@radix-ui/react-slot": stub("radix-slot.tsx"),
};
const alias = {
  name: "alias",
  setup(b) {
    b.onResolve({ filter: /.*/ }, (a) => {
      if (MAP[a.path]) return { path: MAP[a.path] };
      if (a.path.startsWith("@/")) {
        const base = path.join(REPO, "src", a.path.slice(2));
        for (const ext of ["", ".ts", ".tsx", "/index.ts", "/index.tsx"]) if (fs.existsSync(base + ext) && fs.statSync(base + ext).isFile()) return { path: base + ext };
      }
    });
  },
};
await esbuild.build({
  entryPoints: [path.join(HERE, "entry.tsx")], bundle: true, outfile: path.join(OUT, "app.js"), format: "iife", platform: "browser",
  jsx: "automatic", nodePaths: [TOOLS], plugins: [alias], define: { "process.env.NODE_ENV": '"development"' }, logLevel: "warning", sourcemap: false,
});

// ---- CSS: the real src/styles.css through Tailwind 4's compiler
const read = (p) => fs.readFileSync(p, "utf8");
const loadStylesheet = async (id, base) => {
  if (id === "tailwindcss") return { path: TOOLS + "/tailwindcss/index.css", base: TOOLS + "/tailwindcss", content: read(TOOLS + "/tailwindcss/index.css") };
  if (id === "tw-animate-css") return { path: "tw-animate-css", base, content: read(path.join(HERE, "tw-animate-lite.css")) };
  const p = path.resolve(base, id);
  return { path: p, base: path.dirname(p), content: read(p) };
};
const compiler = await compile(read(path.join(REPO, "src/styles.css")), { base: path.join(REPO, "src"), loadStylesheet, loadModule: async () => { throw new Error("no plugins in harness"); } });
const files = [...srcs, path.join(REPO, "src/components/ui/button.tsx"), path.join(REPO, "src/components/ui/input.tsx"), path.join(HERE, "entry.tsx"), stub("ui.tsx")];
const cand = new Set();
// two tokenisers: one keeps ( ) , inside arbitrary values like grid-cols-[minmax(0,1fr)_...]; the other strips them
for (const f of files) for (const re of [/[\s"'`<>{}=;]+/, /[\s"'`<>{}()=;,]+/]) for (const t of read(f).split(re)) if (t) cand.add(t);
fs.writeFileSync(path.join(OUT, "app.css"), compiler.build([...cand]));
fs.writeFileSync(path.join(OUT, "index.html"), '<!doctype html><html lang="en" class="dark"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><link rel="stylesheet" href="app.css"></head><body><div id="root"></div><script src="app.js"></script></body></html>');
console.log("built ->", OUT, "| icons:", [...names].join(","), "| candidates:", cand.size);
