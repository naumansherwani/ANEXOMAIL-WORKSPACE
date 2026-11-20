import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
const pick = readFileSync(new URL("./EmojiPicker.tsx", import.meta.url), "utf8"), studio = readFileSync(new URL("../ComposeStudio.tsx", import.meta.url), "utf8");
test("awam emoji button is the sticker-face icon (own SVG), founder default stays the glyph", () => {
  expect(pick).toContain("export function StickerFace");
  expect(pick).toContain("sticker ? <StickerFace /> : <span aria-hidden=\"true\">🙂</span>");
  expect(studio).toContain("<EmojiToggle sticker dock={emo}");
});
