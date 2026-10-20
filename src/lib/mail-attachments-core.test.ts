import { describe, expect, test } from "bun:test";
import { anyUploading, attachErrorText, extOf, fmtBytes, precheck, readyIds, type AttachItem } from "./mail-attachments-core";

const L = { message_cap_bytes: 7_000_000, max_files: 3 };
const item = (o: Partial<AttachItem>): AttachItem => ({ key: "k", name: "a.pdf", size: 1000, status: "ready", progress: 100, id: "i", ...o });

describe("precheck", () => {
  test("ok file", () => expect(precheck({ name: "a.pdf", size: 1000 }, [], L)).toBeNull());
  test("empty", () => expect(precheck({ name: "a.pdf", size: 0 }, [], L)).toContain("empty"));
  test("blocked types (case + trailing dot/space tricks)", () => {
    expect(precheck({ name: "setup.EXE", size: 5 }, [], L)).toContain(".exe");
    expect(precheck({ name: "run.exe . ", size: 5 }, [], L)).toContain(".exe");
    expect(precheck({ name: "x.zip", size: 5 }, [], L)).toBeNull();
  });
  test("one file over cap", () => expect(precheck({ name: "big.bin", size: 7_000_001 }, [], L)).toContain("up to 7.0 MB"));
  test("running total over cap counts only live items", () => {
    const cur = [item({ size: 5_000_000 }), item({ size: 4_000_000, status: "error" })];
    expect(precheck({ name: "b.bin", size: 1_900_000 }, cur, L)).toBeNull();
    expect(precheck({ name: "b.bin", size: 2_100_000 }, cur, L)).toContain("in total");
  });
  test("file count", () => {
    const cur = [item({}), item({}), item({})];
    expect(precheck({ name: "d.pdf", size: 10 }, cur, L)).toContain("up to 3 files");
    expect(precheck({ name: "d.pdf", size: 10 }, [...cur.slice(0, 2), item({ status: "error" })], L)).toBeNull();
  });
});

describe("helpers", () => {
  test("extOf", () => { expect(extOf("a.tar.GZ")).toBe("gz"); expect(extOf(".bashrc")).toBe(""); expect(extOf("noext")).toBe(""); });
  test("fmtBytes", () => { expect(fmtBytes(999)).toBe("999 B"); expect(fmtBytes(1500)).toBe("1.5 kB"); expect(fmtBytes(7_000_000)).toBe("7.0 MB"); expect(fmtBytes(-1)).toBe("—"); });
  test("readyIds / anyUploading", () => {
    const items = [item({ id: "a" }), item({ id: "b", status: "uploading" }), item({ id: undefined, status: "error" })];
    expect(readyIds(items)).toEqual(["a"]);
    expect(anyUploading(items)).toBe(true);
    expect(anyUploading([item({})])).toBe(false);
  });
  test("error text", () => {
    expect(attachErrorText("file_too_large", "", 7_000_000)).toContain("7.0 MB");
    expect(attachErrorText("malware_detected", "Blocked: Eicar")).toBe("Blocked: Eicar");
    expect(attachErrorText("zzz", "")).toBe("Could not attach this file.");
  });
});
