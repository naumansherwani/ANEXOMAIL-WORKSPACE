// E7 (#7) web installer — /opt/anexomail-web/src: Compose "Send from" selector
import fs from "fs";
import crypto from "crypto";
import { spawnSync } from "child_process";
const SIM = process.env.SIM === "1";
const ROOT = SIM ? "/tmp/e7sim/web/" : "/opt/anexomail-web/";
const EXPECT = {"src/components/app/compose/ComposeStudio.tsx": "86337c6e7eaf135a", "src/lib/mail.ts": "d669885b9d3415aa"};
const EDITS = [["src/lib/mail.ts", "export type FolderCounts = Record<string, { total: number; unread: number }>;\n", "export type SendIdentity = { address: string; kind: \"login\" | \"mailbox\" | \"shared\" };\n\n/** #7 \u2014 Compose \"Send from\": server (Rust mail.identities) ke jaiz From addresses. */\nexport function useIdentities(enabled = true) {\n  return useQuery<{ identities: SendIdentity[]; default: string | null }, ApiError>({\n    queryKey: [\"mail\", \"identities\"],\n    enabled,\n    queryFn: () =>\n      rpcOrRest<{ identities: SendIdentity[]; default: string | null }>(\n        \"mail.identities\",\n        { path: \"/api/mail/identities\" },\n        {},\n      ),\n    retry: false,\n    staleTime: 60_000,\n  });\n}\n\nexport type FolderCounts = Record<string, { total: number; unread: number }>;\n"], ["src/components/app/compose/ComposeStudio.tsx", "  useSignatures,\n", ""], ["src/components/app/compose/ComposeStudio.tsx", "import { useSendMail } from \"@/lib/mail\";\n", "import { useIdentities, useSendMail } from \"@/lib/mail\";\nimport { addressTone } from \"@/lib/mail-identity\";\n"], ["src/components/app/compose/ComposeStudio.tsx", "  const signatures = useSignatures();\n", "  const identities = useIdentities(identitiesOk);\n"], ["src/components/app/compose/ComposeStudio.tsx", "          {identitiesOk ? (\n          <select\n            aria-label=\"Send as\"\n            value={identity}\n            onChange={(e) => setIdentity(e.target.value)}\n            className=\"h-8 rounded-lg border border-border bg-card px-2 text-[11px] text-foreground\"\n          >\n            <option value=\"\">Send as \u2014 default identity</option>\n            {signatures.data?.signatures.map((sig) => (\n              <option key={sig.id} value={sig.identity}>\n                {sig.identity}\n              </option>\n            ))}\n          </select>\n          ) : null}\n", "          {identitiesOk && (identities.data?.identities.length ?? 0) > 0 ? (\n            <div className=\"flex items-center gap-1.5\">\n              <span\n                aria-hidden\n                className=\"h-2.5 w-2.5 shrink-0 rounded-full\"\n                style={{\n                  background:\n                    addressTone(identity || identities.data?.default)?.color ?? \"currentColor\",\n                }}\n              />\n              <select\n                aria-label=\"Send from\"\n                value={identity}\n                onChange={(e) => setIdentity(e.target.value)}\n                className=\"h-8 rounded-lg border border-border bg-card px-2 text-[11px] text-foreground\"\n              >\n                <option value=\"\">{`Send from \u2014 ${identities.data?.default ?? \"default\"}`}</option>\n                {identities.data?.identities.map((i) => (\n                  <option key={i.address} value={i.address}>\n                    {i.address}\n                  </option>\n                ))}\n              </select>\n            </div>\n          ) : null}\n"]];
const sha = (f) => crypto.createHash("sha256").update(fs.readFileSync(ROOT + f)).digest("hex").slice(0, 16);
if (fs.readFileSync(ROOT + "src/lib/mail.ts", "utf8").includes("useIdentities")) { console.log("ALREADY PATCHED - kuch nahi badla"); process.exit(0); }
for (const [f, h] of Object.entries(EXPECT)) {
  if (sha(f) !== h) { console.log("STOP: " + f + " live sha " + sha(f) + " != expected " + h + " - kuch nahi badla, yeh line mujhe bhejo"); process.exit(2); }
}
const out = {};
for (const f of Object.keys(EXPECT)) out[f] = fs.readFileSync(ROOT + f, "utf8");
for (const [f, o, n] of EDITS) {
  const c = out[f].split(o).length - 1;
  if (c !== 1) { console.log("STOP: anchor " + c + " baar mila in " + f + " - kuch nahi badla"); process.exit(3); }
  out[f] = out[f].replace(o, () => n);
}
const bak = (SIM ? "/tmp/e7sim/bak-" : "/root/e7-bak-") + Date.now() + "/";
for (const f of Object.keys(EXPECT)) { fs.mkdirSync(bak + f.substring(0, f.lastIndexOf("/")), { recursive: true }); fs.copyFileSync(ROOT + f, bak + f); }
for (const f of Object.keys(out)) fs.writeFileSync(ROOT + f, out[f]);
console.log("patched, backup: " + bak);
if (SIM) process.exit(0);
console.log("--- bun run build:bun ---");
const b = spawnSync("bun", ["run", "build:bun"], { cwd: "/opt/anexomail-web", stdio: "inherit" });
if (b.status !== 0) { for (const f of Object.keys(EXPECT)) fs.copyFileSync(bak + f, ROOT + f); console.log("BUILD FAIL - files wapas purani. Upar ka error mujhe bhejo."); process.exit(4); }
spawnSync("pm2", ["restart", "anexomail-web", "--update-env"], { stdio: "ignore" });
spawnSync("pm2", ["save"], { stdio: "ignore" });
spawnSync("sleep", ["3"]);
spawnSync("curl", ["-s", "-o", "/dev/null", "-w", "web /health %{http_code}\n", "--max-time", "5", "http://127.0.0.1:3000/health"], { stdio: "inherit" });
