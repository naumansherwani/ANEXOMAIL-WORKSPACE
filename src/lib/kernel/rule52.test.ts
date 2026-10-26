/**
 * RULE 52 GUARD (AGENTS.md) — har jumle ka ek test. Yeh tootay to Rule 52 toota. Docs: docs/cursor-work/RULE-52-PROOF.md
 * Sirf repo files padhta hai (koi network nahi); live saboot (browser + server) RULE-52-PROOF.md mein hai.
 */
import { createHash } from "node:crypto";
import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, test } from "bun:test";

import { KERNEL_PIN } from "./pin.gen";

const root = join(import.meta.dir, "../../..");
const read = (p: string) => readFileSync(join(root, p), "utf8");
const walk = (d: string, out: string[] = []): string[] => {
  for (const n of readdirSync(join(root, d))) {
    const rel = `${d}/${n}`;
    if (statSync(join(root, rel)).isDirectory()) walk(rel, out);
    else out.push(rel);
  }
  return out;
};

describe("Rule 52 — ek kernel, builtin, poori website", () => {
  test("[1] kernel Rust hai, async Tokio, wasm cdylib, browser mein quinn/wtransport nahi", () => {
    const c = read("web-wasm/Cargo.toml");
    expect(c).toMatch(/crate-type\s*=\s*\["cdylib"/);
    expect(c).toMatch(/^tokio\s*=/m);
    expect(c).not.toMatch(/quinn|wtransport/);
    expect(read("web-wasm/src/exec.rs")).toMatch(/LocalSet|tokio/);
  });

  test("[1b] founder ke alfaaz: Rust, async, tRPC, WebTransport, Tokio -> WASM kernel (rule text + code dono)", () => {
    const rule = read("AGENTS.md");
    expect(rule).toMatch(/Rust, async, tRPC, WebTransport, async, Tokio/);
    expect(read("src/lib/rpc.ts")).toMatch(/tRPC/); // tRPC-style { result: { data } } envelope
    expect(read("src/lib/rpc-contract.ts")).toMatch(/tRPC/); // typed procedures
    expect(read("web-wasm/Cargo.toml")).toMatch(/Tokio/i);
    expect(read("web-wasm/src/rpc.rs")).toMatch(/WebTransport|wt\/rpc/);
    expect(read("server/rust/wtrpc_glue.rs")).toMatch(/Tokio|tokio/);
  });

  test("[1b] founder ke alfaz: Rust + async + Tokio + WebTransport + tRPC-style contract (AGENTS.md mein verbatim)", () => {
    const a = read("AGENTS.md");
    expect(a).toMatch(/tRPC, WebTransport, async, Tokio/);
    expect(read("src/lib/rpc-contract.ts")).toMatch(/tRPC/);
    expect(read("web-wasm/src/rpc.rs")).toMatch(/\/wt\/rpc/);
  });

  test("[2] version ek: Cargo == lib.rs VERSION == pin == wasm file ka naam", () => {
    const cargo = /^version\s*=\s*"([^"]+)"/m.exec(read("web-wasm/Cargo.toml"))![1]!;
    const v = /VERSION: \(u32, u32, u32\) = \((\d+), (\d+), (\d+)\)/.exec(read("web-wasm/src/lib.rs"))!;
    expect(`${v[1]}.${v[2]}.${v[3]}`).toBe(cargo);
    expect(KERNEL_PIN.version).toBe(cargo);
    expect(KERNEL_PIN.url).toBe(`/kernel/anexo-kernel-${cargo}.wasm`);
    expect(existsSync(join(root, `public/kernel/anexo-kernel-${cargo}.wasm`))).toBe(true);
  });

  test("[3] pin: wasm ka SHA-256 pin se barabar, aur public/kernel mein sirf EK wasm", () => {
    const f = readFileSync(join(root, "public/kernel", `anexo-kernel-${KERNEL_PIN.version}.wasm`));
    expect(createHash("sha256").update(f).digest("hex")).toBe(KERNEL_PIN.sha256);
    expect(readdirSync(join(root, "public/kernel")).filter((n) => n.endsWith(".wasm"))).toHaveLength(1);
  });

  test("[4] modules (ek kernel, andar modules): sha256, hmac, sniff, rank, live, rpc", () => {
    const lib = read("web-wasm/src/lib.rs");
    for (const m of ["sha256@1", "hmac@1", "sniff@1", "rank@1", "live@1", "rpc@1"]) expect(lib).toContain(`"${m}"`);
  });

  test("[5] app ka darwaza EK: sirf boot.ts kernel load/rpcStart karta hai", () => {
    const users = walk("src").filter((f) => /\.(ts|tsx)$/.test(f) && !f.endsWith(".test.ts") && read(f).includes("rpcStart("));
    expect(users.sort()).toEqual(["src/lib/kernel/boot.ts", "src/lib/kernel/kernel.ts"].sort());
  });

  test("[6] rpc.ts pehle kernel, phir fetch fallback; live.ts pehle kernel", () => {
    const r = read("src/lib/rpc.ts");
    expect(r.indexOf("kernelRpc(")).toBeGreaterThan(-1);
    expect(r.indexOf("kernelRpc(")).toBeLessThan(r.indexOf("await fetch("));
    expect(r).toContain("noteFetch(");
    expect(read("src/lib/live.ts")).toContain("getKernel");
  });

  test("[7] kernel page ke saath jaagta hai: AppShell mount par warmKernel", () => {
    expect(read("src/components/app/AppShell.tsx")).toMatch(/useEffect\(\(\) => warmKernel\(\), \[\]\)/);
  });

  test("[8] early-boot: kernel jaagne tak thora intezar, par page ko 1.5 s se zyada nahi rokta, aur ek baar hi (gaveUp)", () => {
    const b = read("src/lib/kernel/boot.ts");
    const m = /EARLY_WAIT_MS = (\d+)/.exec(b);
    expect(m).not.toBeNull();
    expect(Number(m![1])).toBeLessThanOrEqual(1500);
    expect(b).toContain("kernelForCall()");
    expect(b).toContain("gaveUp = true");
  });

  test("[9] request tag: HMAC-SHA256(session_key, \"<proc>.<ts>.<sha256hex(input)>\") — client aur server ka ek hi format", () => {
    expect(read("src/lib/kernel/boot.ts")).toContain("`${proc}.${ts}.${hash}`");
    const core = read("server/rust/wtrpc_core.rs");
    expect(core).toMatch(/pub fn tag_message/);
    expect(core).toMatch(/format!\("\{proc_name\}\.\{ts\}\.\{input_sha_hex\}"\)/);
  });

  test("[10] ticket 15 min, key sirf memory mein (window/localStorage par nahi)", () => {
    const b = read("src/lib/kernel/boot.ts");
    expect(b).toMatch(/840_000/);
    expect(b).not.toMatch(/localStorage\.setItem\([^)]*(key|ticket)/i);
    expect(b).not.toMatch(/window\[[^\]]*key/i);
  });

  test("[11] ANEXO_TAG_MODE: observe default, enforce par bina sahi tag 401", () => {
    const core = read("server/rust/wtrpc_core.rs");
    expect(core).toMatch(/enforce/);
    expect(read("server/rust/wtrpc_glue.rs")).toContain("ANEXO_TAG_MODE");
  });

  test("[12] server: /wt/rpc koi proc nahi rakhta, wohi dispatch() (HTTP /rpc wala) chalta hai", () => {
    const g = read("server/rust/wtrpc_glue.rs");
    expect(g).toContain("crate::dispatch(");
    expect(g).toMatch(/pub fn owns\(_proc: &str\) -> bool \{\s*false/);
  });

  test("[13] anexoKernel diagnostics: stats + fallbackProcs + rpcUp + info", () => {
    const b = read("src/lib/kernel/boot.ts");
    for (const k of ["get rpcUp()", "get info()", "get stats()", "get fallbackProcs()"]) expect(b).toContain(k);
    for (const k of ["kernel:", "fetch:", "tagged:", "untagged:", "ticketOk:", "ticketFail:"]) expect(b).toContain(k);
  });

  test("[14] typed contract + uska test maujood (Rust gates se drift = test fail)", () => {
    expect(existsSync(join(root, "src/lib/rpc-contract.ts"))).toBe(true);
    expect(existsSync(join(root, "src/lib/rpc-contract.test.ts"))).toBe(true);
  });

  test("[15] build script: cargo test + wasm build + SHA pin generate", () => {
    const s = read("scripts/build-kernel.sh");
    expect(s).toMatch(/cargo test/);
    expect(s).toMatch(/wasm32-unknown-unknown/);
    expect(s).toContain("pin.gen.ts");
  });

  test("[16] server installer wtrpc module ko lagata hai aur kernel-check maujood", () => {
    expect(read("docs/cursor-work/server/rust-engine-install.sh")).toContain("wtrpc");
    expect(existsSync(join(root, "docs/cursor-work/server/kernel-check.sh"))).toBe(true);
  });

  // Rule 52 ke jo hisse abhi poore nahi — test.todo, taake ye chup na rahein (RULE-52-PROOF.md "GAP" table).
  test.todo("[G1] ANEXOChat live (chat-transport.ts, chat-signal.ts) kernel ke andar ho — abhi apna alag `new WebTransport(/wt/chat)`");
  test.todo("[G2] kernel ka live@1 (/wt/events) aur rpc@1 (/wt/rpc) ek hi QUIC session par — abhi do alag session");
  test.todo("[G3] crm.live + org.members Rust par (abhi Bun fallback: kernel_status_404)");
});
