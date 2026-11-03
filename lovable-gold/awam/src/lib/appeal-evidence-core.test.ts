import { describe, expect, test } from "bun:test";

import {
  anyUploading,
  countChars,
  EVIDENCE_ACCEPT,
  evidenceErrorText,
  precheck,
  readyIds,
  statementState,
  type EvidenceItem,
  type EvidenceLimits,
} from "./appeal-evidence-core";

const limits: EvidenceLimits = {
  eligible: true,
  statement_min: 20,
  statement_max: 20_000,
  max_files: 5,
  max_file_bytes: 10_000_000,
  max_total_bytes: 25_000_000,
};
const item = (o: Partial<EvidenceItem> = {}): EvidenceItem => ({
  key: "k",
  name: "a.png",
  size: 100,
  status: "ready",
  progress: 100,
  id: "i",
  ...o,
});

describe("appeal statement (E72)", () => {
  test("20,000 characters is the limit; 19 is too short; 20,001 too long", () => {
    expect(statementState("a".repeat(19)).tooShort).toBe(true);
    expect(statementState("a".repeat(20)).ok).toBe(true);
    expect(statementState("a".repeat(20_000)).ok).toBe(true);
    const long = statementState("a".repeat(20_001));
    expect(long.tooLong).toBe(true);
    expect(long.ok).toBe(false);
    expect(long.label).toBe("1 over the 20,000-character limit");
  });
  test("counts characters, not bytes: Urdu, emoji and trimming", () => {
    expect(countChars("ب".repeat(20_000))).toBe(20_000);
    expect(countChars("😀".repeat(25))).toBe(25);
    expect(countChars("   abc   ")).toBe(3);
    expect(statementState("ب".repeat(20_000)).ok).toBe(true);
  });
  test("labels show the running count", () => {
    expect(statementState("a".repeat(1234)).label).toBe("1,234 / 20,000");
    expect(statementState("abc").label).toBe("3 / 20,000 — at least 20 characters");
    expect(statementState("a".repeat(30)).remaining).toBe(19_970);
  });
});

describe("evidence precheck (E72)", () => {
  test("accepts screenshots, PDFs, text and Office files", () => {
    for (const n of ["shot.png", "SHOT.JPG", "x.pdf", "mail.eml", "n.txt", "a.docx", "b.xlsx"])
      expect(precheck({ name: n, size: 10 }, [], limits)).toBeNull();
  });
  test("refuses executables, archives, html/svg and no-extension names", () => {
    for (const n of ["a.exe", "a.zip", "a.html", "a.svg", "a.js", "noext", "a.png.exe"])
      expect(precheck({ name: n, size: 10 }, [], limits)).not.toBeNull();
  });
  test("empty, too big, too many, total and duplicates", () => {
    expect(precheck({ name: "a.png", size: 0 }, [], limits)).toContain("empty");
    expect(precheck({ name: "a.png", size: 10_000_001 }, [], limits)).toContain("10 MB");
    expect(
      precheck(
        { name: "z.png", size: 1 },
        Array.from({ length: 5 }, (_, i) => item({ key: String(i), name: `f${i}.png` })),
        limits,
      ),
    ).toContain("up to 5");
    expect(
      precheck(
        { name: "z.png", size: 9_000_000 },
        [item({ size: 9_000_000, name: "a.png" }), item({ size: 9_000_000, name: "b.png" })],
        limits,
      ),
    ).toContain("25 MB");
    expect(precheck({ name: "a.png", size: 100 }, [item()], limits)).toContain("already attached");
  });
  test("failed items do not take a slot", () => {
    const failed = Array.from({ length: 5 }, (_, i) =>
      item({ key: String(i), name: `f${i}.png`, status: "error" }),
    );
    expect(precheck({ name: "z.png", size: 1 }, failed, limits)).toBeNull();
  });
  test("accept list matches the server allowlist", () => {
    expect(EVIDENCE_ACCEPT.split(",")).toContain(".pdf");
    expect(EVIDENCE_ACCEPT).not.toContain(".zip");
    expect(EVIDENCE_ACCEPT).not.toContain(".exe");
  });
});

describe("evidence helpers (E72)", () => {
  test("ids only from ready items; uploading is detected", () => {
    const items = [
      item({ id: "a" }),
      item({ id: "b", status: "uploading" }),
      item({ id: undefined }),
      item({ id: "c", status: "error" }),
    ];
    expect(readyIds(items)).toEqual(["a"]);
    expect(anyUploading(items)).toBe(true);
    expect(anyUploading([item()])).toBe(false);
  });
  test("error texts are human and carry limits", () => {
    expect(evidenceErrorText("file_too_large", "", 10_000_000)).toContain("10 MB");
    expect(evidenceErrorText("rate_limited", "")).toContain("tomorrow");
    expect(evidenceErrorText("file_type_blocked", "Not a real .png file.")).toBe(
      "Not a real .png file.",
    );
    expect(evidenceErrorText("weird", "")).toBe("Could not attach this file.");
  });
});
