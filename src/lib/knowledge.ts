/**
 * Phase 20 — AI Knowledge Workspace (transport only).
 *
 * EMBEDDINGS RULE (locked): OpenAI key kabhi nahi. Recall keyword(trigram) +
 * pinned + recency par chalta hai; server hi ranking karta hai.
 * CITATION RULE: koi jawab bina citation nahi — server har answer ke saath
 * sources bhejta hai, warna answer nahi dikhta.
 */

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import type { ApiError } from "@/lib/api";
import { rpcOrRest } from "@/lib/rpc";

export type KnowledgeScope = "personal" | "business";

export type KnowledgeSpace = {
  id: string;
  name: string;
  scope: KnowledgeScope;
  documents: number;
  chunks: number;
  updated_at: string | null;
};

export type KnowledgeDoc = {
  id: string;
  space_id: string;
  title: string;
  source: string | null;
  kind: "note" | "mail" | "file" | "link";
  chunks: number;
  words: number;
  pinned: boolean;
  created_at: string;
  updated_at: string | null;
};

export type Citation = {
  doc_id: string;
  doc_title: string;
  chunk_id: string;
  quote: string;
  score: number;
};

export type KnowledgeAnswer = {
  id: string;
  question: string;
  answer: string;
  citations: Citation[];
  model: string | null;
  cost: number;
  currency: string;
  latency_ms: number | null;
  refused: boolean;
  refusal_reason: string | null;
};

export type KnowledgeHit = {
  doc_id: string;
  doc_title: string;
  chunk_id: string;
  excerpt: string;
  score: number;
  scope: KnowledgeScope;
};

const get = <T,>(procedure: string, path: string, input?: unknown) =>
  rpcOrRest<T>(procedure, { path }, input);

export function useKnowledgeSpaces() {
  return useQuery<{ spaces: KnowledgeSpace[] }, ApiError>({
    queryKey: ["knowledge", "spaces"],
    queryFn: () => get<{ spaces: KnowledgeSpace[] }>("knowledge.spaces", "/api/knowledge/spaces"),
    retry: false,
  });
}

export function useKnowledgeDocs(spaceId: string | null) {
  return useQuery<{ documents: KnowledgeDoc[] }, ApiError>({
    queryKey: ["knowledge", "docs", spaceId],
    queryFn: () =>
      get<{ documents: KnowledgeDoc[] }>(
        "knowledge.documents",
        spaceId ? `/api/knowledge/documents?space_id=${spaceId}` : "/api/knowledge/documents",
        { space_id: spaceId },
      ),
    retry: false,
  });
}

export function useKnowledgeSearch(query: string) {
  return useQuery<{ hits: KnowledgeHit[] }, ApiError>({
    queryKey: ["knowledge", "search", query],
    queryFn: () =>
      get<{ hits: KnowledgeHit[] }>(
        "knowledge.search",
        `/api/knowledge/search?q=${encodeURIComponent(query)}`,
        { q: query },
      ),
    enabled: query.trim().length > 1,
    retry: false,
  });
}

export function useAddDocument() {
  const qc = useQueryClient();
  return useMutation<
    { document: KnowledgeDoc },
    ApiError,
    { space_id?: string; scope?: KnowledgeScope; title: string; body: string; source?: string }
  >({
    mutationFn: (body) =>
      rpcOrRest<{ document: KnowledgeDoc }>(
        "knowledge.addDocument",
        { path: "/api/knowledge/documents", method: "POST", body },
        body,
      ),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["knowledge", "docs"] });
      void qc.invalidateQueries({ queryKey: ["knowledge", "spaces"] });
    },
  });
}

export function useDeleteDocument() {
  const qc = useQueryClient();
  return useMutation<{ deleted: number }, ApiError, { id: string }>({
    mutationFn: (body) =>
      rpcOrRest<{ deleted: number }>(
        "knowledge.deleteDocument",
        { path: `/api/knowledge/documents/${body.id}`, method: "DELETE" },
        body,
      ),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["knowledge", "docs"] });
      void qc.invalidateQueries({ queryKey: ["knowledge", "spaces"] });
    },
  });
}

export function usePinDocument() {
  const qc = useQueryClient();
  return useMutation<{ pinned: boolean }, ApiError, { id: string; pinned: boolean }>({
    mutationFn: (body) =>
      rpcOrRest<{ pinned: boolean }>(
        "knowledge.pinDocument",
        { path: `/api/knowledge/documents/${body.id}/pin`, method: "POST", body },
        body,
      ),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["knowledge", "docs"] }),
  });
}

/** Grounded ask — server refuses instead of guessing when nothing matches. */
export function useAskKnowledge() {
  return useMutation<KnowledgeAnswer, ApiError, { question: string; scope?: KnowledgeScope }>({
    mutationFn: (body) =>
      rpcOrRest<KnowledgeAnswer>(
        "knowledge.ask",
        { path: "/api/knowledge/ask", method: "POST", body },
        body,
      ),
  });
}

/** Turn a real thread into knowledge — no copy-paste, no duplicate store. */
export function useIngestThread() {
  const qc = useQueryClient();
  return useMutation<{ document: KnowledgeDoc }, ApiError, { thread_id: string; space_id?: string }>({
    mutationFn: (body) =>
      rpcOrRest<{ document: KnowledgeDoc }>(
        "knowledge.ingestThread",
        { path: "/api/knowledge/ingest/thread", method: "POST", body },
        body,
      ),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["knowledge", "docs"] }),
  });
}
