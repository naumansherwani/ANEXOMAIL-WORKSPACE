import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
const css = readFileSync(new URL("./mailbox.css", import.meta.url), "utf8"), bar = readFileSync(new URL("./MailReplyBar.tsx", import.meta.url), "utf8");
test("20 Nov: the list-row class mbx-rb is defined once and the reply bar never reuses it", () => {
  expect((css.match(/\.mbx-rb\{/g) ?? []).length).toBe(1);
  expect(bar).not.toContain('className="mbx-rb"');
  expect(bar).toContain('className="mbx-rpl"');
});
