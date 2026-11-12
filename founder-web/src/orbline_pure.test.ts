import { describe, expect, test } from "bun:test";
import { orbLine } from "./orbline_pure";

describe("orbLine (LA-3)", () => {
  test("full good path", () => {
    const l = orbLine({ protocol: "quic", keySource: "dbsc", psrc: "webcrypto" })!;
    expect(l.text).toBe("HTTP/3 QUIC · Hardware key · ML-DSA-65"); expect(l.tone).toBe("ok");
  });
  test("fallback and software are warnings, said plainly", () => {
    const l = orbLine({ protocol: "h2", keySource: "webcrypto", psrc: "kernel" })!;
    expect(l.text).toBe("HTTP/2 (fallback) · Browser key · ML-DSA-65 (software)"); expect(l.tone).toBe("warn");
  });
  test("unknown parts are left out, never guessed", () => {
    expect(orbLine({ protocol: "unknown", keySource: "unknown", psrc: "" })).toBeNull();
    expect(orbLine({ protocol: "quic" })!.text).toBe("HTTP/3 QUIC");
  });
  test("no device key is a known fact and is shown", () => {
    expect(orbLine({ protocol: "quic", keySource: "none" })!.parts.map((p) => p.text)).toEqual(["HTTP/3 QUIC", "No device key"]);
  });
  test("screen reader sentence", () => { expect(orbLine({ protocol: "quic", keySource: "dbsc" })!.sr).toBe("Connection: HTTP/3 QUIC, Hardware key."); });
});
