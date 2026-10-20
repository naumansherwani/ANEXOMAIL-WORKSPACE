/**
 * ANEXOMAIL — Company domains + addresses (blueprint #8, hissa D).
 *
 * Rust :3200 PRIMARY — `mail.domains.*` / `mail.addresses.*` (E15). Koi Bun
 * fallback nahi: yeh naya code hai, Rust-first (AGENTS locked). Hisaab DB
 * functions (`org_domain_*`, `org_address_*`) mein; yeh file sirf call karti hai.
 */
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import type { ApiError } from "@/lib/api";
import { rpc } from "@/lib/rpc";

export type DnsRecordKey = "txt" | "mx" | "spf" | "dkim" | "dmarc";

export type DnsRecord = {
  key: DnsRecordKey;
  type: "TXT" | "MX";
  /** Registrar mein "Host/Name" column — sirf yeh hissa (domain khud lag jata hai). */
  name: string;
  /** Poora hostname (sirf dikhane ke liye). */
  host: string;
  /** null = DKIM key abhi ban rahi hai. */
  value: string | null;
  priority?: number;
  pending?: boolean;
  ok: boolean;
};

export type OrgDomain = {
  id: string;
  domain: string;
  status: "pending" | "verified" | "removed";
  txt_ok: boolean;
  mx_ok: boolean;
  spf_ok: boolean;
  dkim_ok: boolean;
  dmarc_ok: boolean;
  last_checked_at: string | null;
  verified_at: string | null;
  created_at: string;
  records: DnsRecord[];
};

export type DomainsList = {
  domains: OrgDomain[];
  plan: string;
  /** null = unlimited */
  domain_cap: number | null;
  mail_host: string;
};

export type AddressKind = "mailbox" | "shared" | "alias";

export type OrgAddress = {
  id: string;
  domain_id: string;
  local_part: string;
  address: string;
  kind: AddressKind;
  owner_user_id: string | null;
  alias_target: string | null;
  active: boolean;
  created_at: string;
};

export type AddressesList = {
  addresses: OrgAddress[];
  plan: string;
  /** null = unlimited */
  mailbox_cap: number | null;
  mailbox_used: number;
  login_address: string;
};

export type DomainAddResult = {
  ok: boolean;
  error?: string;
  plan?: string;
  limit?: number | null;
  used?: number;
  domain?: OrgDomain;
};

export type DomainVerifyResult = {
  ok: boolean;
  error?: string;
  ready: boolean;
  checks: Record<DnsRecordKey, boolean>;
  domain: OrgDomain;
  /** D2 (20 Oct 2026): "authoritative" = seedha domain ke apne nameservers se (cache nahi); "public" = purana DoH raasta. */
  source?: "authoritative" | "public";
  zone?: string | null;
  nameservers?: string[];
  /** Duniya ke public resolvers kya dekh rahe hain (sirf jaankari — "phail raha hai"). */
  public?: Record<DnsRecordKey, boolean>;
};

export type AddressCreateResult = {
  ok: boolean;
  error?: string;
  plan?: string;
  limit?: number | null;
  used?: number;
  address?: OrgAddress;
};

const KEYS = {
  domains: ["mail", "domains"] as const,
  addresses: ["mail", "addresses"] as const,
};

export function useDomains() {
  return useQuery<DomainsList, ApiError>({
    queryKey: KEYS.domains,
    queryFn: () => rpc<DomainsList>("mail.domains.list", {}),
    retry: false,
    staleTime: 15_000,
  });
}

export function useAddresses() {
  return useQuery<AddressesList, ApiError>({
    queryKey: KEYS.addresses,
    queryFn: () => rpc<AddressesList>("mail.addresses.list", {}),
    retry: false,
    staleTime: 15_000,
  });
}

export function useAddDomain() {
  const qc = useQueryClient();
  return useMutation<DomainAddResult, ApiError, string>({
    mutationFn: (domain) => rpc<DomainAddResult>("mail.domains.add", { domain }),
    onSuccess: (r) => {
      // Naya domain foran list mein (wizard qadam 2 ko record chahiye), phir server se tasdeeq.
      if (r.ok && r.domain) {
        const added = r.domain;
        qc.setQueryData<DomainsList>(KEYS.domains, (old) =>
          old ? { ...old, domains: [...old.domains.filter((d) => d.id !== added.id), added] } : old,
        );
      }
      return qc.invalidateQueries({ queryKey: KEYS.domains });
    },
  });
}

export function useVerifyDomain() {
  const qc = useQueryClient();
  return useMutation<DomainVerifyResult, ApiError, string>({
    mutationFn: (domain_id) => rpc<DomainVerifyResult>("mail.domains.verify", { domain_id }),
    onSuccess: (r) => {
      // Ticks foran badlein: server ka naya domain row seedha cache mein.
      if (r.ok && r.domain) {
        const fresh = r.domain;
        qc.setQueryData<DomainsList>(KEYS.domains, (old) =>
          old ? { ...old, domains: old.domains.map((d) => (d.id === fresh.id ? fresh : d)) } : old,
        );
      }
      void qc.invalidateQueries({ queryKey: KEYS.domains });
      void qc.invalidateQueries({ queryKey: ["dashboard", "summary"] });
    },
  });
}

export function useRemoveDomain() {
  const qc = useQueryClient();
  return useMutation<{ ok: boolean }, ApiError, string>({
    mutationFn: (domain_id) => rpc<{ ok: boolean }>("mail.domains.remove", { domain_id }),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: KEYS.domains });
      void qc.invalidateQueries({ queryKey: KEYS.addresses });
      void qc.invalidateQueries({ queryKey: ["dashboard", "summary"] });
    },
  });
}

export function useCreateAddress() {
  const qc = useQueryClient();
  return useMutation<
    AddressCreateResult,
    ApiError,
    { domain_id: string; local_part: string; kind: AddressKind; alias_target?: string }
  >({
    mutationFn: async (input) => {
      try {
        return await rpc<AddressCreateResult>("mail.addresses.create", input);
      } catch (e) {
        // E52 fair-use trigger: 'alias_fair_use:<cap>' -> same shape as every other refusal.
        if (/alias_fair_use/.test(e instanceof Error ? e.message : String(e)))
          return { ok: false, error: "alias_fair_use" } as AddressCreateResult;
        throw e;
      }
    },
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: KEYS.addresses });
      void qc.invalidateQueries({ queryKey: ["mail", "identities"] });
      void qc.invalidateQueries({ queryKey: ["mail", "accounts"] });
    },
  });
}

export function useRemoveAddress() {
  const qc = useQueryClient();
  return useMutation<{ ok: boolean }, ApiError, string>({
    mutationFn: (address_id) => rpc<{ ok: boolean }>("mail.addresses.remove", { address_id }),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: KEYS.addresses });
      void qc.invalidateQueries({ queryKey: ["mail", "identities"] });
      void qc.invalidateQueries({ queryKey: ["mail", "accounts"] });
    },
  });
}

/** Server ke `error` codes -> insaan ki zubaan (E15). */
export function domainErrorText(
  code: string | undefined,
  extra?: { plan?: string; limit?: number | null },
): string {
  switch (code) {
    case "invalid_domain":
      return "Enter a domain like company.com.";
    case "reserved_domain":
      return "That domain can't be used here.";
    case "business_required":
      return "Company domains are for Business workspaces.";
    case "domain_taken":
      return "That domain is already connected to another workspace.";
    case "domain_limit_reached":
      return `Your ${extra?.plan ?? "current"} package allows ${extra?.limit ?? 0} domain${extra?.limit === 1 ? "" : "s"}. Remove one or upgrade.`;
    case "domain_not_found":
    case "not_found":
      return "That domain isn't in this workspace any more.";
    case "domain_not_verified":
      return "Verify the domain first — its DNS checks must be green.";
    case "invalid_local_part":
      return "Use letters, numbers, dots, dashes or underscores (e.g. sales).";
    case "address_taken":
      return "That address already exists.";
    case "mailbox_limit":
      return `Your ${extra?.plan ?? "current"} package allows ${extra?.limit ?? 0} mailboxes. Aliases don't count — or upgrade.`;
    case "alias_fair_use":
      return "You have reached the fair-use limit for aliases. Remove one you no longer use, or contact support if you need more.";
    case "alias_target_required":
      return "An alias needs an address to deliver to.";
    case "invalid_kind":
      return "Choose mailbox, shared or alias.";
    default:
      return code ? `Couldn't do that (${code}).` : "Couldn't do that.";
  }
}
