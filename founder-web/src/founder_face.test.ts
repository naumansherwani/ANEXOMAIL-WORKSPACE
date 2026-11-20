import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
const pick = readFileSync(new URL("./EmojiPicker.tsx", import.meta.url), "utf8"), css = readFileSync(new URL("./emoji.css", import.meta.url), "utf8");
test("founder emoji button uses the own FounderFace SVG, keeps its accessible name, respects reduced motion", () => {
  expect(pick).toContain("export function FounderFace");
  expect(pick).toContain("<FounderFace />");
  expect(pick).toContain('aria-label="Insert emoji"'); expect(pick).toContain("aria-haspopup=\"dialog\"");
  expect(pick).not.toContain("innerHTML");
  expect(css).toContain("prefers-reduced-motion:reduce){.emo-face");
});
