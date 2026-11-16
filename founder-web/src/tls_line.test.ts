import { describe, expect, test } from "bun:test";
import { TLS_LINE } from "./tls_line";
describe("tls line", () => { test("says TLS 1.3 and AES-256-GCM, plain words", () => { expect(TLS_LINE).toContain("TLS 1.3"); expect(TLS_LINE).toContain("AES-256-GCM"); expect(TLS_LINE.length).toBeLessThan(80); }); });
