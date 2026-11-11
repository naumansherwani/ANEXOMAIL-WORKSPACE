import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
const api = readFileSync(new URL("./api.ts", import.meta.url), "utf8");
test("K8d: reads and writes go through net(), not raw fetch", () => {
  expect(api).toContain("kernelRpc(m, path");
  expect(api).toContain('await net(path, { method: "POST"');
  expect(api).toContain('await net(path, { method: "PUT"');
  expect(api).toContain("const r = await net(path, { headers");
});
test("K8d: a write is never repeated automatically", () => {
  expect(api).toContain('if (m !== "GET") throw');
});
