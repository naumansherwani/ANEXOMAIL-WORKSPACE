// Stateful mock of src/lib/domains.ts — same exported names and shapes, no network.
// Scenario comes from location.hash: #empty (default) | #list | #hosted | #loading | #error | #fast
import { useSyncExternalStore } from "react";

type Rec = { key: "txt" | "mx" | "spf" | "dkim" | "dmarc"; type: "TXT" | "MX"; name: string; host: string; value: string | null; priority?: number; pending?: boolean; ok: boolean };
type Dom = { id: string; domain: string; status: "pending" | "verified" | "removed"; txt_ok: boolean; mx_ok: boolean; spf_ok: boolean; dkim_ok: boolean; dmarc_ok: boolean; last_checked_at: string | null; verified_at: string | null; created_at: string; records: Rec[] };

const listeners = new Set<() => void>();
const emit = () => listeners.forEach((l) => l());
const sub = (cb: () => void) => (listeners.add(cb), () => listeners.delete(cb));
const KEYS = ["txt", "mx", "spf", "dkim", "dmarc"] as const;

function mkRecords(domain: string, dkimReady: boolean): Rec[] {
  return [
    { key: "txt", type: "TXT", name: "_anexo-verify", host: `_anexo-verify.${domain}`, value: "anexomail-verify=7f3a91c2e0b84d5aa1c6", ok: false },
    { key: "mx", type: "MX", name: "@", host: domain, value: "mail.anexomail.com", priority: 10, ok: false },
    { key: "spf", type: "TXT", name: "@", host: domain, value: "v=spf1 include:spf.anexomail.com ~all", ok: false },
    { key: "dkim", type: "TXT", name: "anexo._domainkey", host: `anexo._domainkey.${domain}`, value: dkimReady ? "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAu9Qx3mR2Zr0hT6yQ1bN8" : null, pending: !dkimReady, ok: false },
    { key: "dmarc", type: "TXT", name: "_dmarc", host: `_dmarc.${domain}`, value: "v=DMARC1; p=none; rua=mailto:dmarc@anexomail.com", ok: false },
  ];
}
const mkDom = (id: string, domain: string, okCount = 0, dkimReady = true): Dom => {
  const records = mkRecords(domain, dkimReady).map((r, i) => ({ ...r, ok: i < okCount }));
  return { id, domain, status: okCount === 5 ? "verified" : "pending", txt_ok: okCount > 0, mx_ok: okCount > 1, spf_ok: okCount > 2, dkim_ok: okCount > 3, dmarc_ok: okCount > 4, last_checked_at: okCount ? new Date().toISOString() : null, verified_at: okCount === 5 ? new Date().toISOString() : null, created_at: new Date().toISOString(), records };
};

const scenario = () => location.hash.replace("#", "");
// Dashboard checklist scenarios (hash): dashA no domain | dashB domain pending | dashC verified, no address | dashD verified+address | dashE same (mail decided by analytics stub) | dashcap0 plan without domains
const dash = () => (scenario().match(/dash([A-E])/) || [])[1] as string | undefined;
const seedDomains = (): Dom[] => {
  const d = dash();
  if (d === "B") return [mkDom("d2", "probuyer.axonetis.com", 2)];
  if (d === "C" || d === "D" || d === "E") return [mkDom("d1", "acme-studio.com", 5)];
  return scenario().includes("list") ? [mkDom("d1", "acme-studio.com", 5), mkDom("d2", "probuyer.axonetis.com", 2)] : [];
};
let domains: Dom[] = seedDomains();
const oneAddr = [{ id: "a1", domain_id: "d1", local_part: "sales", address: "sales@acme-studio.com", kind: "shared" as const, owner_user_id: null, alias_target: null, active: true, created_at: "" }];
let addresses: { id: string; domain_id: string; local_part: string; address: string; kind: "mailbox" | "shared" | "alias"; owner_user_id: string | null; alias_target: string | null; active: boolean; created_at: string }[] =
  scenario().includes("migrate") && !scenario().includes("nomb") ? [
    { id: "a9", domain_id: "d1", local_part: "pro.buyer", address: "pro.buyer@anexomail.com", kind: "mailbox", owner_user_id: "u1", alias_target: null, active: true, created_at: "" },
    { id: "a10", domain_id: "d1", local_part: "sara", address: "sara@acme-studio.co.uk", kind: "mailbox", owner_user_id: "u2", alias_target: null, active: true, created_at: "" },
  ] :
  dash() === "D" || dash() === "E" || (!dash() && scenario().includes("list")) ? oneAddr : [];
let verifyCalls = 0;

const asQuery = <T,>(get: () => T) => () => {
  const data = useSyncExternalStore(sub, get);
  const s = scenario();
  return { data: s.includes("loading") ? undefined : data, isLoading: s.includes("loading"), isError: s.includes("error"), refetch: async () => undefined };
};
const snapD = () => ({ domains: domains.slice(), plan: "pro", domain_cap: scenario().includes("cap0") ? 0 : 3, mail_host: "mail.anexomail.com" });
const snapA = () => ({ addresses: addresses.slice(), plan: "pro", mailbox_cap: 5, mailbox_used: addresses.filter((a) => a.kind === "mailbox").length, login_address: "pro.buyer@anexomail.com" });
let cacheD = snapD(), cacheA = snapA();
const getD = () => cacheD;
const getA = () => cacheA;
const refresh = () => { cacheD = snapD(); cacheA = snapA(); emit(); };

export const useDomains = asQuery(getD);
export const useAddresses = asQuery(getA);

function useMut<A, R>(run: (arg: A) => Promise<R>) {
  const state = { isPending: false };
  const api = {
    get isPending() { return state.isPending; },
    mutate(arg: A, o?: { onSuccess?: (r: R) => void; onError?: (e: unknown) => void }) {
      state.isPending = true; emit();
      const delay = scenario().includes("fast") ? 50 : 650;
      setTimeout(() => run(arg).then((r) => { state.isPending = false; refresh(); o?.onSuccess?.(r); }, (e) => { state.isPending = false; refresh(); o?.onError?.(e); }), delay);
    },
  };
  return api;
}
// one persistent mutation object per hook name so React re-renders see isPending
const pend = new Map<string, { isPending: boolean }>();
function usePend(name: string) {
  const p = pend.get(name) ?? { isPending: false }; pend.set(name, p);
  useSyncExternalStore(sub, () => p.isPending);
  return p;
}
function mutHook<A, R>(name: string, run: (arg: A) => Promise<R>) {
  return () => {
    const p = usePend(name);
    return {
      get isPending() { return p.isPending; },
      mutate(arg: A, o?: { onSuccess?: (r: R) => void; onError?: (e: unknown) => void }) {
        p.isPending = true; emit();
        const delay = scenario().includes("fast") ? 50 : 700;
        setTimeout(() => run(arg).then((r) => { p.isPending = false; refresh(); o?.onSuccess?.(r); }, (e) => { p.isPending = false; refresh(); o?.onError?.(e); }), delay);
      },
    };
  };
}
void useMut;

export const useAddDomain = mutHook<string, unknown>("add", async (name) => {
  const d = name.trim().toLowerCase();
  if (!d.includes(".")) return { ok: false, error: "invalid_domain" };
  if (d.includes("taken")) return { ok: false, error: "domain_taken" }; // 8e: another workspace owns it
  const id = "d" + (domains.length + 1) + Date.now();
  const dom = mkDom(id, d, 0, false);
  domains = [...domains, dom];
  setTimeout(() => { domains = domains.map((x) => (x.id === id ? mkDom(id, d, x.records.filter((r) => r.ok).length, true) : x)); // dkim ready after a few seconds
    domains = domains.map((x) => (x.id === id ? { ...x, records: mkRecords(d, true).map((r, i) => ({ ...r, ok: x.records[i]?.ok ?? false })) } : x)); refresh(); }, 3500);
  return { ok: true, domain: dom };
});
export const useVerifyDomain = mutHook<string, unknown>("verify", async (id) => {
  verifyCalls += 1;
  if (scenario().includes("stuck")) { const d0 = domains.find((x) => x.id === id)!; return { ok: true, ready: false, checks: Object.fromEntries(d0.records.map((r) => [r.key, r.ok])), domain: d0 }; } // 8d: DNS never shows up
  domains = domains.map((x) => {
    if (x.id !== id) return x;
    const have = x.records.filter((r) => r.ok).length;
    const next = Math.min(5, have + (verifyCalls % 2 === 0 ? 1 : 0) + (scenario().includes("fast") ? 5 : 0));
    const records = x.records.map((r, i) => ({ ...r, ok: i < next }));
    return { ...x, records, status: next === 5 ? "verified" : "pending", last_checked_at: new Date().toISOString() };
  });
  const dom = domains.find((x) => x.id === id)!;
  return { ok: true, ready: dom.status === "verified", checks: Object.fromEntries(dom.records.map((r) => [r.key, r.ok])), domain: dom };
});
export const useRemoveDomain = mutHook<string, unknown>("rmd", async (id) => { domains = domains.filter((d) => d.id !== id); return { ok: true }; });
export const useCreateAddress = mutHook<{ domain_id: string; local_part: string; kind: "mailbox" | "shared" | "alias"; alias_target?: string }, unknown>("mk", async (i) => {
  const dom = domains.find((d) => d.id === i.domain_id)!;
  const a = { id: "a" + Date.now(), domain_id: i.domain_id, local_part: i.local_part, address: `${i.local_part}@${dom.domain}`, kind: i.kind, owner_user_id: null, alias_target: i.alias_target ?? null, active: true, created_at: "" };
  addresses = [...addresses, a];
  return { ok: true, address: a };
});
export const useRemoveAddress = mutHook<string, unknown>("rma", async (id) => { addresses = addresses.filter((a) => a.id !== id); return { ok: true }; });

export function domainErrorText(code: string | undefined, extra?: { plan?: string; limit?: number | null }): string {
  switch (code) {
    case "invalid_domain": return "Enter a domain like company.com.";
    case "domain_limit_reached": return `Your ${extra?.plan ?? "current"} package allows ${extra?.limit ?? 0} domains. Remove one or upgrade.`;
    default: return code ? `Couldn't do that (${code}).` : "Couldn't do that.";
  }
}
