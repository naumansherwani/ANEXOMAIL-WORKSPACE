import { describe, expect, test } from "bun:test";
import { decide, founderHosts, guardMode, requestHost } from "./founder-host-guard";

const H = ["founderworkspace.anexomail.com"];
describe("founder host guard", () => {
  test("default is off and a bad value is off", () => {
    expect(guardMode({})).toBe("off");
    expect(guardMode({ FOUNDER_HOST_GUARD: "ENFORCE " })).toBe("enforce");
    expect(guardMode({ FOUNDER_HOST_GUARD: "yes" })).toBe("off");
  });
  test("host comes from Host header only, port stripped, x-forwarded-host ignored", () => {
    expect(requestHost({ host: "FounderWorkspace.anexomail.com:443" })).toBe("founderworkspace.anexomail.com");
    expect(requestHost({ host: "anexomail.com", "x-forwarded-host": "founderworkspace.anexomail.com" })).toBe("anexomail.com");
    expect(requestHost({})).toBe("");
  });
  test("off never changes anything", () => {
    expect(decide("off", "login", "anexomail.com", H, true)).toBe("allow");
  });
  test("probe logs but never refuses", () => {
    expect(decide("probe", "login", "anexomail.com", H, true)).toBe("log");
    expect(decide("probe", "login", "founderworkspace.anexomail.com", H, true)).toBe("allow");
  });
  test("enforce: founder refused on awam host, allowed on founder host; others untouched", () => {
    expect(decide("enforce", "login", "anexomail.com", H, true)).toBe("refuse");
    expect(decide("enforce", "login", "", H, true)).toBe("refuse");
    expect(decide("enforce", "login", "founderworkspace.anexomail.com", H, true)).toBe("allow");
    expect(decide("enforce", "login", "anexomail.com", H, false)).toBe("allow");
  });
  test("founder email never signs up through awam flow, on any host", () => {
    expect(decide("enforce", "signup", "founderworkspace.anexomail.com", H, true)).toBe("refuse");
    expect(decide("enforce", "signup", "anexomail.com", H, false)).toBe("allow");
  });
  test("hosts list is configurable", () => {
    expect(founderHosts({ FOUNDER_HOSTS: "a.example.com, B.example.com" })).toEqual(["a.example.com", "b.example.com"]);
    expect(founderHosts({})).toEqual(H);
  });
});
