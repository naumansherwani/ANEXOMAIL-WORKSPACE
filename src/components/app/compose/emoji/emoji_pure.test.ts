import { describe, expect, test } from "bun:test";
import { rankRecent, acceptShortcode, shortcodeAt, shortcodeSearch, fold, inGroup, insertAt, loadList, loadTone, pushRecent, search, withTone, type Emoji, type Group, MAX_RECENT } from "./emoji_pure";
const groups: Group[] = [{ key: "smileys-emotion", message: "smileys", order: 0 }, { key: "component", message: "components", order: 2 }, { key: "flags", message: "flags", order: 9 }];
const all: Emoji[] = [
  { hexcode: "1F600", label: "grinning face", unicode: "😀", group: 0, order: 1, tags: ["face", "grin"] },
  { hexcode: "1F602", label: "face with tears of joy", unicode: "😂", group: 0, order: 2, tags: ["laugh", "tear"] },
  { hexcode: "270B", label: "raised hand", unicode: "✋", group: 1, order: 3, tags: ["hand", "stop"], skins: [1, 2, 3, 4, 5].map((n) => ({ hexcode: `270B-${n}`, label: `raised hand: tone ${n}`, unicode: `✋${n}` })) },
  { hexcode: "1F3FB", label: "light skin tone", unicode: "🏻", group: 2, order: 4, tags: ["skin"] },
  { hexcode: "1F1F5-1F1F0", label: "flag: Pakistan", unicode: "🇵🇰", group: 9, order: 5, tags: ["flag"] },
];
describe("emoji_pure", () => {
  test("fold", () => { expect(fold(" Zoyá ")).toBe("zoya"); });
  test("a group keeps the Unicode order and the component group is empty", () => { expect(inGroup(all, 0, groups).map((e) => e.hexcode)).toEqual(["1F600", "1F602"]); expect(inGroup(all, 2, groups)).toEqual([]); });
  test("skin tone only where the emoji has skins", () => { expect(withTone(all[2], "medium").unicode).toBe("✋3"); expect(withTone(all[0], "dark").unicode).toBe("😀"); expect(withTone(all[2], "").unicode).toBe("✋"); });
  test("search: label before tag, all words must hit, component skipped, from one character", () => {
    expect(search(all, groups, "gri").map((e) => e.hexcode)).toEqual(["1F600"]);
    expect(search(all, groups, "laugh").map((e) => e.hexcode)).toEqual(["1F602"]);
    expect(search(all, groups, "tears joy").map((e) => e.hexcode)).toEqual(["1F602"]);
    expect(search(all, groups, "skin")).toEqual([]);
    expect(search(all, groups, "p").map((e) => e.hexcode)).toEqual(["1F1F5-1F1F0"]);
    expect(search(all, groups, "  ")).toEqual([]);
    expect(search(all, groups, "face").map((e) => e.hexcode)).toEqual(["1F600", "1F602"]);
  });
  test("recent: newest first, no duplicates, capped", () => {
    expect(pushRecent(["a", "b", "c"], "b")).toEqual(["b", "a", "c"]);
    let l: string[] = []; for (let i = 0; i < 50; i++) l = pushRecent(l, `h${i}`); expect(l.length).toBe(MAX_RECENT); expect(l[0]).toBe("h49");
  });
  test("insert at the caret and over a selection, bounds are clamped", () => {
    expect(insertAt("hello world", 5, 5, "😀")).toEqual({ text: "hello😀 world", caret: 7 });
    expect(insertAt("hello world", 0, 5, "😀")).toEqual({ text: "😀 world", caret: 2 });
    expect(insertAt("hi", 99, 120, "😀")).toEqual({ text: "hi😀", caret: 4 });
    expect(insertAt("hi", -3, -1, "😀").text).toBe("😀hi");
  });
  test("storage readers never throw", () => { expect(loadList("not json")).toEqual([]); expect(loadList('["a",1,"b"]')).toEqual(["a", "b"]); expect(loadTone("medium")).toBe("medium"); expect(loadTone("zzz")).toBe(""); expect(loadTone(null)).toBe(""); });
});

import { BASELINE, graphemes, hasEmoji, hexOf, inWords, nameIndex, newerEmoji, versionMap, versionOf } from "./emoji_pure";
describe("QC1e-D1 new-emoji safety", () => {
  const vm = versionMap({ "0.6": ["1F600", "2764-FE0F"], "15.1": ["1F426-200D-1F525"], "16": ["1FAE9"], "17": ["1FACD", "1F46F-1F3FB"], bad: ["1F600"] });
  const names = new Map([["😀", "grinning face"], ["🪍", "orca"], ["🫩", "face with bags under eyes"]]);
  test("the version map ignores a key that is not a number", () => { expect(vm.get("1FACD")).toBe(17); expect(vm.size).toBe(6); });
  test("hexcodes are upper-case, dash-joined", () => { expect(hexOf("😀")).toBe("1F600"); expect(hexOf("❤️")).toBe("2764-FE0F"); });
  test("a skin-tone variant falls back to the base emoji", () => { expect(versionOf("1F46F-1F3FC", vm)).toBeUndefined(); expect(versionOf("1F46F-1F3FB", vm)).toBe(17); expect(versionOf("2764", vm)).toBe(0.6); });
  test("only emoji NEWER than the baseline are flagged, distinct, in order of use", () => {
    const f = newerEmoji("hi 😀 \u{1FACD} and \u{1FAE9} again \u{1FACD}", vm, names);
    expect(f.map((x) => x.version)).toEqual([17, 16]); expect(f[0].name).toBe("new emoji"); expect(f[1].name).toBe("face with bags under eyes");
    expect(newerEmoji("plain text 1 2 3 # *", vm, names)).toEqual([]);
    expect(newerEmoji("😀 ❤️", vm, names)).toEqual([]);
    expect(BASELINE).toBe(15.1);
  });
  test("an emoji we know nothing about is never flagged", () => { expect(newerEmoji("\u{1F9FF}", vm, names)).toEqual([]); });
  test("in words: every flagged emoji becomes its name, the rest is untouched", () => {
    const t = "look \u{1FAE9} and 😀"; expect(inWords(t, newerEmoji(t, vm, names))).toBe("look [face with bags under eyes] and 😀");
  });
  test("a family or flag is one grapheme", () => { expect(graphemes("a👨‍👩‍👧b🇵🇰").length).toBe(4); expect(hasEmoji("abc")).toBe(false); expect(hasEmoji("a🇵🇰")).toBe(true); });
  test("name index covers skin variants", () => { const m = nameIndex([{ hexcode: "1F44B", label: "waving hand", unicode: "👋", skins: [{ hexcode: "1F44B-1F3FB", label: "waving hand: light skin tone", unicode: "👋🏻" }] }]); expect(m.get("👋🏻")).toContain("light skin"); });

  test("D2 shortcode: colon at start or after a space, 2..24 chars, never inside 12:30 or a link", () => {
    expect(shortcodeAt(":sm", 3)).toEqual({ start: 0, query: "sm" });
    expect(shortcodeAt("hi :thumbs_up", 13)).toEqual({ start: 3, query: "thumbs_up" });
    expect(shortcodeAt("hi\n:fa", 7)).toEqual({ start: 3, query: "fa" });
    expect(shortcodeAt("meet at 12:30", 13)).toBeNull(); expect(shortcodeAt("https://example", 15)).toBeNull();
    expect(shortcodeAt(":s", 2)).toBeNull(); expect(shortcodeAt("hi :", 4)).toBeNull(); expect(shortcodeAt(":" + "a".repeat(25), 26)).toBeNull();
    expect(shortcodeAt("a :sm now", 5)).toEqual({ start: 2, query: "sm" });
  });
  test("D2 shortcode search + accept", () => {
    expect(shortcodeSearch(all, groups, "face_with")[0].hexcode).toBe("1F602");
    const r = acceptShortcode("hi :gri now", 3, 7, "😀"); expect(r.text).toBe("hi 😀 now"); expect(r.caret).toBe(5);
  });
  test("D2 ranking: recently used first, then search order, stable", () => {
    const l = [all[0], all[1], all[2]]; expect(rankRecent(l, []).map((e) => e.hexcode)).toEqual(["1F600", "1F602", "270B"]);
    expect(rankRecent(l, ["270B", "1F602"]).map((e) => e.hexcode)).toEqual(["270B", "1F602", "1F600"]);
  });
});
