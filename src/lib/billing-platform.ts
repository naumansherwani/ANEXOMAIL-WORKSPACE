/**
 * Phase 21 — Billing Platform (transport only).
 *
 * Workspace plans (Basic £20 · Pro £40 · Business £85) sirf anexomail.com ke
 * liye — AI plans yahan kabhi nahi (woh ai.anexomail.com par hai).
 * NO DUPLICATE: proration, tax, invoice numbering, VAT aur receipts sab server
 * par. UI sirf sach dikhati hai.
 */

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import type { ApiError } from "@/lib/api";
import { rpcOrRest } from "@/lib/rpc";

export type WorkspacePlanId = "basic" | "pro" | "business" | "business_pro";

export type Subscription = {
  plan: WorkspacePlanId | null;
  state: "trialing" | "active" | "past_due" | "cancelled" | "none";
  seats: number;
  seats_used: number;
  price_per_seat: number;
  currency: string;
  interval: "month" | "year";
  renews_at: string | null;
  cancel_at: string | null;
  storage_per_mailbox_gb: number | null;
};

export type Invoice = {
  id: string;
  number: string;
  state: "paid" | "open" | "void";
  subtotal: number;
  tax: number;
  total: number;
  currency: string;
  period_start: string | null;
  period_end: string | null;
  issued_at: string;
  paid_at: string | null;
  pdf_url: string | null;
};

export type TaxProfile = {
  legal_name: string | null;
  country: string | null;
  vat_number: string | null;
  vat_validated: boolean;
  reverse_charge: boolean;
  address: string | null;
};

export type PaymentMethod = {
  id: string;
  brand: string;
  last4: string;
  exp: string;
  default: boolean;
};

export type PlanChangePreview = {
  plan: WorkspacePlanId;
  seats: number;
  charge_now: number;
  credit_back: number;
  next_total: number;
  currency: string;
  effective_at: string;
};

const get = <T>(procedure: string, path: string, input?: unknown) =>
  rpcOrRest<T>(procedure, { path }, input);

export function useSubscription() {
  return useQuery<Subscription, ApiError>({
    queryKey: ["billing", "subscription"],
    queryFn: () => get<Subscription>("billing.subscription", "/api/billing/subscription"),
    retry: false,
  });
}

export function useInvoices() {
  return useQuery<{ invoices: Invoice[] }, ApiError>({
    queryKey: ["billing", "invoices"],
    queryFn: () => get<{ invoices: Invoice[] }>("billing.invoices", "/api/billing/invoices"),
    retry: false,
  });
}

export function useTaxProfile() {
  return useQuery<TaxProfile, ApiError>({
    queryKey: ["billing", "tax"],
    queryFn: () => get<TaxProfile>("billing.tax", "/api/billing/tax"),
    retry: false,
  });
}

export function usePaymentMethods() {
  return useQuery<{ methods: PaymentMethod[] }, ApiError>({
    queryKey: ["billing", "methods"],
    queryFn: () => get<{ methods: PaymentMethod[] }>("billing.methods", "/api/billing/methods"),
    retry: false,
  });
}

export function useSaveTaxProfile() {
  const qc = useQueryClient();
  return useMutation<TaxProfile, ApiError, Partial<TaxProfile>>({
    mutationFn: (body) =>
      rpcOrRest<TaxProfile>(
        "billing.saveTax",
        { path: "/api/billing/tax", method: "POST", body },
        body,
      ),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["billing", "tax"] }),
  });
}

export function usePreviewPlanChange() {
  return useMutation<PlanChangePreview, ApiError, { plan: WorkspacePlanId; seats: number }>({
    mutationFn: (body) =>
      rpcOrRest<PlanChangePreview>(
        "billing.previewChange",
        { path: "/api/billing/preview", method: "POST", body },
        body,
      ),
  });
}

export function useChangePlan() {
  const qc = useQueryClient();
  return useMutation<Subscription, ApiError, { plan: WorkspacePlanId; seats: number }>({
    mutationFn: (body) =>
      rpcOrRest<Subscription>(
        "billing.changePlan",
        { path: "/api/billing/change", method: "POST", body },
        body,
      ),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["billing", "subscription"] });
      void qc.invalidateQueries({ queryKey: ["billing", "invoices"] });
    },
  });
}

/** Founder god-view: revenue truth across every tenant. */
export type RevenueTruth = {
  mrr: number;
  arr: number;
  currency: string;
  paying_tenants: number;
  trialing: number;
  past_due: number;
  churn_30d: number;
  by_plan: { plan: string; tenants: number; mrr: number }[];
  unpaid_total: number;
};

export function useRevenueTruth() {
  return useQuery<RevenueTruth, ApiError>({
    queryKey: ["billing", "founder", "revenue"],
    queryFn: () => get<RevenueTruth>("billing.revenueTruth", "/api/founder/billing/revenue"),
    retry: false,
  });
}

export type FounderReply = {
  id: string;
  user_id: string | null;
  thread_id: string | null;
  customer_email: string;
  subject: string;
  plan: WorkspacePlanId;
  response_due_hours: 24 | 48 | 72;
  received_at: string;
  respond_by: string;
  state: "awaiting_reply" | "replied" | "closed";
  replied_at: string | null;
  overdue: boolean;
  remaining_minutes: number;
};

export function useFounderReplyQueue() {
  return useQuery<{ replies: FounderReply[] }, ApiError>({
    queryKey: ["billing", "founder", "reply-queue"],
    queryFn: () =>
      get<{ replies: FounderReply[] }>("billing.founderReplyQueue", "/api/founder/support/replies"),
    retry: false,
  });
}

export function useMarkFounderReplySent() {
  const qc = useQueryClient();
  return useMutation<{ id: string; state: "replied"; replied_at: string }, ApiError, string>({
    mutationFn: (id) =>
      rpcOrRest(
        "billing.markFounderReplySent",
        { path: `/api/founder/support/replies/${id}/replied`, method: "POST" },
        { id },
      ),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["billing", "founder", "reply-queue"] }),
  });
}

export const PLAN_LABEL: Record<WorkspacePlanId, string> = {
  basic: "Basic — £20",
  pro: "Pro — £40",
  business: "Business — £85",
  business_pro: "Business Pro — £2,500",
};

export const gbp = (v: number) => `£${v.toFixed(2)}`;
