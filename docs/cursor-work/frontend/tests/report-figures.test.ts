import { describe, expect, test } from "bun:test";

import { reportLabel, reportValue } from "../../../../src/lib/report-figures";

describe("reportLabel", () => {
  test("known keys get hand-written labels", () => {
    expect(reportLabel("self_heals")).toBe("Problems fixed automatically");
    expect(reportLabel("threads_started")).toBe("Conversations started");
  });
  test("unit suffixes leave the label, unknown keys are sentence-cased", () => {
    expect(reportLabel("avg_first_reply_minutes")).toBe("Avg first reply");
    expect(reportLabel("delivery_rate_percent")).toBe("Delivery rate");
    expect(reportLabel("storage_used_gb")).toBe("Storage used");
    expect(reportLabel("spend_gbp")).toBe("Spend");
    expect(reportLabel("open_tickets")).toBe("Open tickets");
  });
});

describe("reportValue", () => {
  test("units follow the key", () => {
    expect(reportValue("avg_first_reply_minutes", 44)).toBe("44 min");
    expect(reportValue("delivery_rate_percent", 98.4)).toBe("98.4%");
    expect(reportValue("storage_used_gb", 41.2)).toBe("41.2 GB");
    expect(reportValue("spend_gbp", 1164)).toBe("£1,164");
    expect(reportValue("spend_gbp", 1164.5)).toBe("£1,164.5");
  });
  test("plain counts get thousands separators; zero stays zero", () => {
    expect(reportValue("messages_sent", 5120)).toBe("5,120");
    expect(reportValue("incidents_recorded", 0)).toBe("0");
  });
  test("numeric strings parse, anything else is shown as given, never NaN", () => {
    expect(reportValue("messages_sent", "2893")).toBe("2,893");
    expect(reportValue("note", "n/a")).toBe("n/a");
    expect(reportValue("x", null)).toBe("—");
    expect(reportValue("x", undefined)).toBe("—");
  });
});
