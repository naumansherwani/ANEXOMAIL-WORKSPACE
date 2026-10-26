import { describe, expect, test } from "bun:test";
import { readFileSync } from "node:fs";

import { PROC_MIN_PLAN, minPlanOf } from "./rpc-contract";

const rs = (f: string) => readFileSync(new URL(`../../server/rust/${f}`, import.meta.url), "utf8");
const quoted = (src: string) => [...src.matchAll(/"([a-z]+(?:\.[A-Za-z]+)+)"/g)].map((m) => m[1] as string);

function fnBody(src: string, name: string): string {
  const i = src.indexOf(`pub fn ${name}`);
  expect(i).toBeGreaterThan(-1);
  const j = src.indexOf("\n}\n", i);
  return src.slice(i, j);
}

describe("rpc contract == Rust server gates", () => {
  test("mailx pro_only_proc procs are all 'pro' in the contract", () => {
    const procs = quoted(fnBody(rs("mailx_core.rs"), "pro_only_proc")).filter((p) => p.startsWith("mail."));
    expect(procs.length).toBeGreaterThanOrEqual(11);
    for (const p of procs) expect(minPlanOf(p), p).toBe("pro");
  });

  test("calendar pro_only_cal_proc procs are all 'pro' in the contract (meta.set goal is partial, excluded)", () => {
    const procs = quoted(fnBody(rs("cal_core.rs"), "pro_only_cal_proc")).filter((p) => p !== "calendar.meta.set");
    expect(procs.sort()).toEqual(["calendar.availability", "calendar.files.attach", "calendar.files.list", "calendar.files.remove", "calendar.focus"]);
    for (const p of procs) expect(minPlanOf(p), p).toBe("pro");
  });

  test("every contract proc is enforced somewhere in Rust (no UI-only claim)", () => {
    const all = ["mailx_core.rs", "cal_core.rs", "analytics_core.rs"].map(rs).join("\n");
    for (const p of Object.keys(PROC_MIN_PLAN)) expect(all.includes(`"${p}"`), `${p} Rust mein nahi`).toBe(true);
  });

  test("Basic-open procs are not in the contract", () => {
    for (const p of ["calendar.create", "calendar.findtime", "calendar.busy", "analytics.responseDebt", "mail.threads"]) expect(minPlanOf(p), p).toBeNull();
  });
});
