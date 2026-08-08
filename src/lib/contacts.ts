/**
 * Contacts & Communication Intelligence — Phase 10.
 *
 * NO DUPLICATE rule: contact derivation from real mail, company rollups,
 * relationship scoring, reply-time maths, tag ownership and the universal
 * search index ALL live on the server (Server 2 -> Supabase 4). This file
 * only speaks HTTP.
 * NO MOCK rule: a missing endpoint surfaces as an honest "not wired" state.
 */

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import { api, ApiError } from "@/lib/api";

export type Relationship = "new" | "growing" | "stable" | "at_risk" | "dormant";

export const RELATIONSHIP_LABEL: Record<Relationship, string> = {
  new: "New",
  growing: "Growing",
  stable: "Stable",
  at_risk: "At risk",
  dormant: "Dormant",
};

export type ContactTag = { id: string; name: string; colour: string | null; count?: number };

export type Contact = {
  id: string;
  display_name: string | null;
  primary_address: string;
  addresses: string[];
  title: string | null;
  company_domain: string | null;
  company_name: string | null;
  tags: string[];
  vip: boolean;
  relationship: Relationship;
  health_score: number | null;
  last_contact_at: string | null;
  messages_in: number;
  messages_out: number;
  avg_reply_minutes: number | null;
  open_threads: number;
  notes: string | null;
};

export type Company = {
  domain: string;
  name: string | null;
  people_count: number;
  messages_total: number;
  open_threads: number;
  relationship: Relationship;
  health_score: number | null;
  last_contact_at: string | null;
};

export type TimelineEvent = {
  id: string;
  kind: "message_in" | "message_out" | "meeting" | "task" | "note" | "tag";
  at: string;
  title: string;
  detail: string | null;
  thread_id: string | null;
  actor: string | null;
};

export type ContactDetail = {
  contact: Contact;
  people?: Contact[];
};

export type SmartFilter =
  | "all"
  | "vip"
  | "customer"
  | "vendor"
  | "investor"
  | "at_risk"
  | "unanswered"
  | "dormant";

export const SMART_FILTERS: { id: SmartFilter; label: string }[] = [
  { id: "all", label: "Everyone" },
  { id: "vip", label: "VIP" },
  { id: "customer", label: "Customers" },
  { id: "vendor", label: "Vendors" },
  { id: "investor", label: "Investors" },
  { id: "at_risk", label: "At risk" },
  { id: "unanswered", label: "Unanswered" },
  { id: "dormant", label: "Dormant" },
];

export type PeopleQuery = { q?: string; filter?: SmartFilter; tag?: string | null };

function toSearch(query: PeopleQuery) {
  const params = new URLSearchParams();
  if (query.q?.trim()) params.set("q", query.q.trim());
  if (query.filter && query.filter !== "all") params.set("filter", query.filter);
  if (query.tag) params.set("tag", query.tag);
  return params.toString();
}

export function useContacts(query: PeopleQuery) {
  return useQuery<{ contacts: Contact[] }, ApiError>({
    queryKey: ["contacts", "list", query],
    queryFn: () => api<{ contacts: Contact[] }>(`/api/contacts?${toSearch(query)}`),
    retry: false,
    staleTime: 15_000,
  });
}

export function useContact(id: string | undefined) {
  return useQuery<ContactDetail, ApiError>({
    queryKey: ["contacts", "one", id],
    queryFn: () => api<ContactDetail>(`/api/contacts/${id}`),
    enabled: Boolean(id),
    retry: false,
  });
}

export function useContactTimeline(id: string | undefined) {
  return useQuery<{ events: TimelineEvent[] }, ApiError>({
    queryKey: ["contacts", "timeline", id],
    queryFn: () => api<{ events: TimelineEvent[] }>(`/api/contacts/${id}/timeline`),
    enabled: Boolean(id),
    retry: false,
  });
}

export function useContactTags() {
  return useQuery<{ tags: ContactTag[] }, ApiError>({
    queryKey: ["contacts", "tags"],
    queryFn: () => api<{ tags: ContactTag[] }>("/api/contacts/tags"),
    retry: false,
    staleTime: 60_000,
  });
}

export function useCompanies(query: { q?: string }) {
  return useQuery<{ companies: Company[] }, ApiError>({
    queryKey: ["companies", "list", query],
    queryFn: () =>
      api<{ companies: Company[] }>(
        `/api/companies${query.q?.trim() ? `?q=${encodeURIComponent(query.q.trim())}` : ""}`,
      ),
    retry: false,
    staleTime: 15_000,
  });
}

export function useCompany(domain: string | undefined) {
  return useQuery<{ company: Company; people: Contact[] }, ApiError>({
    queryKey: ["companies", "one", domain],
    queryFn: () =>
      api<{ company: Company; people: Contact[] }>(`/api/companies/${domain}`),
    enabled: Boolean(domain),
    retry: false,
  });
}

export function useCompanyTimeline(domain: string | undefined) {
  return useQuery<{ events: TimelineEvent[] }, ApiError>({
    queryKey: ["companies", "timeline", domain],
    queryFn: () => api<{ events: TimelineEvent[] }>(`/api/companies/${domain}/timeline`),
    enabled: Boolean(domain),
    retry: false,
  });
}

export function useContactTagAction() {
  const qc = useQueryClient();
  return useMutation<unknown, ApiError, { id: string; add?: string[]; remove?: string[] }>({
    mutationFn: ({ id, ...body }) =>
      api(`/api/contacts/${id}/tags`, { method: "POST", body: JSON.stringify(body) }),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["contacts"] });
    },
  });
}

export function useUpdateContact() {
  const qc = useQueryClient();
  return useMutation<
    unknown,
    ApiError,
    { id: string; display_name?: string; title?: string; notes?: string; vip?: boolean }
  >({
    mutationFn: ({ id, ...body }) =>
      api(`/api/contacts/${id}`, { method: "PATCH", body: JSON.stringify(body) }),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["contacts"] });
    },
  });
}

/* ---------------------------------------------------------------- search */

export type UniversalResults = {
  people: Contact[];
  companies: Company[];
  threads: {
    id: string;
    subject: string;
    snippet: string | null;
    from_address: string;
    folder: string;
    last_message_at: string;
  }[];
  attachments: {
    id: string;
    filename: string;
    size_bytes: number;
    thread_id: string | null;
    folder: string | null;
    sent_at: string;
  }[];
};

export function useUniversalSearch(q: string, enabled = true) {
  const term = q.trim();
  return useQuery<UniversalResults, ApiError>({
    queryKey: ["search", "universal", term],
    queryFn: () => api<UniversalResults>(`/api/search/universal?q=${encodeURIComponent(term)}`),
    enabled: enabled && term.length >= 2,
    retry: false,
    staleTime: 10_000,
  });
}

/* ---------------------------------------------------------------- format */

export function initialsOf(contact: Pick<Contact, "display_name" | "primary_address">) {
  const source = contact.display_name?.trim() || contact.primary_address;
  const parts = source.replace(/@.*/, "").split(/[\s._-]+/).filter(Boolean);
  return (parts[0]?.[0] ?? "?").concat(parts[1]?.[0] ?? "").toUpperCase();
}

export function replyTimeLabel(minutes: number | null) {
  if (minutes === null || Number.isNaN(minutes)) return "—";
  if (minutes < 60) return `${Math.round(minutes)}m`;
  const hours = minutes / 60;
  if (hours < 24) return `${hours.toFixed(hours < 10 ? 1 : 0)}h`;
  return `${Math.round(hours / 24)}d`;
}
