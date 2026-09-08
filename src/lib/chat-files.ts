/**
 * ANEXOChat · PHASE 13 + 14 + 15 — FILE ENGINE (browser side)
 *
 * TRANSPORT LOCK: PRIMARY Rust engine — `/rpc/file.*` (tRPC-style) + raw chunk
 * path `POST /file/chunk` Caddy HTTP/3 (QUIC) par. Bun `/api/chat/file/*` SIRF
 * fallback. TRUTH: progress, missing chunk list, pool, versions — sab Supabase #4
 * rows se. Yeh file kabhi apni marzi ka "100%" nahi dikhati.
 *
 * PHASE 13 — storage (rakhi hui bytes) aur transfer (chali hui bytes) alag.
 *            Same naam dobara = nayi version, purani zinda.
 * PHASE 14 — har chunk ka sha256; server apna hash nikaal kar match karta hai.
 *            Mismatch = sirf woh chunk dobara, poori file kabhi nahi.
 *            Backpressure: inflight bytes cap + plan ka max_concurrent.
 * PHASE 15 — resume identity (naam + bytes + fingerprint). Connection gaya to
 *            "Transfer paused", wapis aaya to wahi transfer 94% se aage.
 */
import { useCallback, useEffect, useRef, useState } from "react";
import { useQuery } from "@tanstack/react-query";

import { ApiError, api, sessionToken } from "./api";
import { chatCall } from "./chat-transport";

const BASE = (import.meta.env["VITE_API_URL"] as string | undefined)?.replace(/\/$/, "") ?? "";

export const CHUNK_BYTES = 8 * 1024 * 1024; // 8 MB
const INFLIGHT_CAP = 24 * 1024 * 1024; // backpressure: 24 MB max in the air
const MAX_CHUNK_ATTEMPTS = 4;

export type Pool = {
  plan: string;
  entitled: boolean;
  max_file_bytes: number;
  pool_bytes: number;
  stored_bytes: number;
  remaining_bytes: number;
  percent: number;
  transfer_unlimited: boolean;
  transfer_month_bytes: number;
  transfer_month_limit: number | null;
  max_concurrent: number;
  active_transfers: number;
  versions_kept: number;
};

export type EngineFile = {
  file_id: string;
  name: string;
  bytes: number;
  content_type: string | null;
  version: number;
  versions: number;
  updated_at: string;
};

export type ServerTransfer = {
  transfer_id: string;
  state: "active" | "paused" | "complete" | "failed";
  transport: string;
  name: string | null;
  bytes_total: number;
  bytes_done: number;
  started_at: string;
  last_seen_at: string;
  error: string | null;
};

export type EngineState = { pool: Pool; files: EngineFile[]; transfers: ServerTransfer[] };

export type FileVersion = {
  version_id: string;
  version: number;
  bytes: number;
  state: "transferring" | "ready" | "corrupt" | "abandoned";
  file_sha256: string | null;
  chunk_count: number;
  created_at: string;
  ready_at: string | null;
};

export type TransferUi = {
  key: string;
  name: string;
  bytes: number;
  bytesDone: number;
  percent: number;
  state:
    | "preparing"
    | "transferring"
    | "paused"
    | "verifying"
    | "scanning"
    | "available"
    | "blocked"
    | "failed"
    | "rejected";
  detail: string;
  transport: "rust-quic" | "bun-fallback" | "offline";
  transferId: string | null;
  versionId: string | null;
  resumed: boolean;
  repaired: number;
};

/**
 * PHASE 16 — FILE TRUTH. Chain ke saat step. UI kabhi "Delivered" nahi likhta
 * jab tak `available` row DB mein sabit na ho — browser ka upload khatam hona
 * sirf `uploaded` hai, us se aage kuch nahi.
 */
export const EVIDENCE_STEPS = [
  "selected",
  "uploading",
  "uploaded",
  "scanning",
  "verified",
  "available",
  "downloaded",
] as const;

export type EvidenceStep = (typeof EVIDENCE_STEPS)[number];

export type FileTruth = {
  found: boolean;
  version_id?: string;
  bytes?: number;
  version?: number;
  safety?: "pending" | "scanning" | "clean" | "flagged" | "blocked" | "error";
  safety_reason?: string | null;
  available?: boolean;
  blocked?: boolean;
  chain?: { state: EvidenceStep | "blocked"; at: string; actor: string; detail: unknown }[];
  scan?: {
    state: string;
    engines: string[];
    findings: { code?: string; detail?: string }[];
    verdict: string | null;
    attempts: number;
    finished_at: string | null;
  } | null;
  downloads?: number;
};

export type FileSafety = {
  enforcement: { strikes: number; action: string; last_event: string | null };
  queue: { pending: number; scanning: number };
  events: {
    id: number;
    name: string | null;
    classification: string;
    decision: string;
    reasons: { code?: string; detail?: string }[];
    engines: string[];
    review_state: string;
    created_at: string;
  }[];
  engines: string[];
  external_api: boolean;
};

/** Evidence chain — server ka sach, poll par. */
export function useFileTruth(versionId: string | null, live = true) {
  return useQuery<FileTruth>({
    queryKey: ["file-engine", "truth", versionId],
    enabled: Boolean(versionId),
    refetchInterval: live ? 3000 : false,
    queryFn: () =>
      chatCall<FileTruth>(
        "file.truth",
        { version_id: versionId },
        { path: `/api/chat/file/truth?version=${encodeURIComponent(versionId!)}`, method: "GET" },
      ),
  });
}

/** PHASE 17/18 — kaun kaun local engine chali, queue, aur enforcement state. */
export function useFileSafety() {
  return useQuery<FileSafety>({
    queryKey: ["file-engine", "safety"],
    refetchInterval: 15000,
    queryFn: () =>
      chatCall<FileSafety>(
        "file.safety.state",
        {},
        { path: "/api/chat/file/safety", method: "GET" },
      ),
  });
}

/** Downloaded step: sirf asli download ke baad. Blocked file par server mana karta hai. */
export async function ackDownload(versionId: string, bytes: number) {
  const body = { version_id: versionId, bytes, device: "browser" };
  return chatCall<{ ok: boolean; reason?: string }>("file.download.ack", body, {
    path: "/api/chat/file/download/ack",
    method: "POST",
    body,
  }).catch(() => ({ ok: false, reason: "unreachable" }) as { ok: boolean; reason?: string });
}

export type DownloadOutcome =
  | { ok: true; bytes: number; acked: boolean; sha256_expected: string | null }
  | { ok: false; reason: string; truth?: unknown };

/**
 * PHASE 31C — asli download. PRIMARY Rust `GET {BASE}/file/download` (HTTP/3);
 * 404/502/offline par Bun `/api/chat/file/download`. Engine har chunk ka sha256
 * DB ke sabit hash se match karke hi bytes deta hai. Browser poore bytes milne
 * ke BAAD `file.download.ack` bhejta hai — "Downloaded" step kabhi pehle nahi.
 * File System Access API ho to disk par stream (5 GB safe), warna blob.
 */
export async function downloadFile(
  versionId: string,
  onProgress?: (received: number, total: number | null) => void,
): Promise<DownloadOutcome> {
  const token = sessionToken.get();
  if (!token) return { ok: false, reason: "not_signed_in" };
  const headers = { authorization: `Bearer ${token}` };
  const q = `version=${encodeURIComponent(versionId)}`;

  let res: Response | null = null;
  try {
    res = await fetch(`${BASE}/file/download?${q}`, { headers });
    if ([404, 501, 502, 503, 504].includes(res.status) && !res.headers.get("x-file-version")) {
      res = null;
    }
  } catch {
    res = null;
  }
  if (!res) {
    try {
      res = await fetch(`${BASE}/api/chat/file/download?${q}`, { headers });
    } catch {
      return { ok: false, reason: "unreachable" };
    }
  }
  if (!res.ok) {
    let payload: unknown = null;
    try {
      payload = await res.json();
    } catch {
      /* no body */
    }
    const p = payload as { error?: string | { code?: string }; truth?: unknown } | null;
    const reason =
      typeof p?.error === "string" ? p.error : (p?.error?.code ?? `http_${res.status}`);
    return { ok: false, reason, truth: p?.truth };
  }

  const total = Number(res.headers.get("content-length")) || null;
  const expected = res.headers.get("x-file-sha256");
  const name = /filename="([^"]+)"/.exec(res.headers.get("content-disposition") ?? "")?.[1] ?? "file";
  if (!res.body) return { ok: false, reason: "no_body" };

  let received = 0;
  const reader = res.body.getReader();

  // Disk stream jab browser de (Chromium): 5 GB memory mein nahi aati.
  const picker = (
    window as unknown as {
      showSaveFilePicker?: (o: { suggestedName: string }) => Promise<{
        createWritable: () => Promise<WritableStreamDefaultWriter<Uint8Array> & { close(): Promise<void> }>;
      }>;
    }
  ).showSaveFilePicker;

  try {
    if (picker) {
      const handle = await picker({ suggestedName: name });
      const w = await handle.createWritable();
      for (;;) {
        const { value, done } = await reader.read();
        if (done) break;
        await w.write(value);
        received += value.byteLength;
        onProgress?.(received, total);
      }
      await w.close();
    } else {
      const parts: BlobPart[] = [];
      for (;;) {
        const { value, done } = await reader.read();
        if (done) break;
        parts.push(value);
        received += value.byteLength;
        onProgress?.(received, total);
      }
      const url = URL.createObjectURL(new Blob(parts));
      const a = document.createElement("a");
      a.href = url;
      a.download = name;
      a.click();
      setTimeout(() => URL.revokeObjectURL(url), 30_000);
    }
  } catch (e) {
    // Engine ne mismatch par stream band kiya, ya user ne picker cancel kiya.
    return { ok: false, reason: (e as Error)?.name === "AbortError" ? "cancelled" : "stream_broken" };
  }

  if (total !== null && received !== total) {
    return { ok: false, reason: "incomplete", truth: { received, total } };
  }
  const ack = await ackDownload(versionId, received);
  return { ok: true, bytes: received, acked: ack.ok === true, sha256_expected: expected };
}



export async function fileTruth(versionId: string): Promise<FileTruth> {
  return chatCall<FileTruth>(
    "file.truth",
    { version_id: versionId },
    { path: `/api/chat/file/truth?version=${encodeURIComponent(versionId)}`, method: "GET" },
  );
}

export function bytesLabel(n: number): string {
  if (!Number.isFinite(n) || n <= 0) return "0 B";
  const units = ["B", "KB", "MB", "GB", "TB"];
  const i = Math.min(Math.floor(Math.log(n) / Math.log(1024)), units.length - 1);
  const v = n / 1024 ** i;
  return `${v >= 10 || i === 0 ? Math.round(v) : v.toFixed(1)} ${units[i]}`;
}

async function sha256Hex(buf: ArrayBuffer): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", buf);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/**
 * Resume identity fingerprint: naam + bytes + (head 1MB + tail 1MB) ka sha256.
 * Yeh POORI file ka hash NAHI hai (5 GB browser mein do dafa parhna sazaa hai) —
 * poori file ki integrity per-chunk sha256 se aati hai, jo har byte cover karta hai.
 */
async function identityFingerprint(file: File): Promise<string> {
  const edge = 1024 * 1024;
  const head = await file.slice(0, Math.min(edge, file.size)).arrayBuffer();
  const tail = await file.slice(Math.max(0, file.size - edge)).arrayBuffer();
  const merged = new Uint8Array(head.byteLength + tail.byteLength + 8);
  merged.set(new Uint8Array(head), 0);
  merged.set(new Uint8Array(tail), head.byteLength);
  new DataView(merged.buffer).setFloat64(head.byteLength + tail.byteLength, file.size);
  return sha256Hex(merged.buffer);
}

type BeginResult = {
  allowed: boolean;
  reason?: string;
  transfer_id: string;
  version: number;
  chunk_size: number;
  chunk_count: number;
  missing: number[];
  verified_bytes: number;
  max_concurrent: number;
  resumed: boolean;
  max_file_bytes?: number;
  pool?: Pool;
};

async function begin(input: {
  name: string;
  content_type: string;
  bytes: number;
  file_sha256: string;
  chunk_size: number;
  conversation_id: string | null;
  device: string;
}): Promise<BeginResult> {
  return chatCall<BeginResult>("file.begin", input, {
    path: "/api/chat/file/begin",
    method: "POST",
    body: input,
  });
}

export async function transferState(transferId: string) {
  return chatCall<{
    found: boolean;
    state: string;
    bytes_done: number;
    bytes_total: number;
    percent: number;
    missing: number[];
    corrupt: number[];
  }>(
    "file.transfer.state",
    { transfer_id: transferId },
    { path: `/api/chat/file/transfer?id=${encodeURIComponent(transferId)}`, method: "GET" },
  );
}

async function mark(
  transferId: string,
  state: "active" | "paused" | "failed",
  transport: string,
  error?: string,
) {
  const body = { transfer_id: transferId, state, transport, error: error ?? null };
  return chatCall<{ ok: boolean }>("file.transfer.mark", body, {
    path: "/api/chat/file/mark",
    method: "POST",
    body,
  }).catch(() => ({ ok: false }));
}

async function commit(transferId: string, fingerprint: string) {
  const body = { transfer_id: transferId, file_sha256: fingerprint };
  return chatCall<{
    ok: boolean;
    reason?: string;
    missing?: number[];
    corrupt?: number[];
    version?: number;
    version_id?: string;
    safety?: string;
    available?: boolean;
  }>("file.commit", body, { path: "/api/chat/file/commit", method: "POST", body });
}

export function useFileEngine() {
  return useQuery<EngineState>({
    queryKey: ["file-engine", "state"],
    queryFn: () =>
      chatCall<EngineState>("file.state", {}, { path: "/api/chat/file/state", method: "GET" }),
    refetchInterval: 5000,
  });
}

export function useFileVersions(fileId: string | null) {
  return useQuery<{ file_id: string; versions: FileVersion[] }>({
    queryKey: ["file-engine", "versions", fileId],
    enabled: Boolean(fileId),
    queryFn: () =>
      chatCall(
        "file.versions",
        { file_id: fileId },
        { path: `/api/chat/file/versions?file=${encodeURIComponent(fileId!)}`, method: "GET" },
      ),
  });
}

/**
 * Ek chunk bhejna. PRIMARY: Rust `POST {BASE}/file/chunk` (HTTP/3 · QUIC).
 * Rust reachable na ho to Bun `/api/chat/file/chunk`. 409 = server ka sha256
 * mismatch → chunk corrupt → wahi chunk dobara (recovery), poori file nahi.
 */
/** Chunk ack ka asli shape — Rust primary aur Bun fallback, dono. */
type ChunkAck = {
  bytes_done?: number | string;
  result?: { data?: { bytes_done?: number | string } };
};

async function putChunk(input: {
  transferId: string;
  idx: number;
  blob: Blob;
  sha: string;
  signal: AbortSignal;
}): Promise<{
  ok: boolean;
  bytes_done: number;
  transport: "rust-quic" | "bun-fallback";
  corrupt: boolean;
}> {
  const token = sessionToken.get();
  const headers: Record<string, string> = {
    "content-type": "application/octet-stream",
    "x-transfer-id": input.transferId,
    "x-chunk-index": String(input.idx),
    "x-chunk-sha256": input.sha,
  };
  if (token) headers["authorization"] = `Bearer ${token}`;

  if (BASE) {
    try {
      const res = await fetch(`${BASE}/file/chunk`, {
        method: "POST",
        headers,
        body: input.blob,
        signal: input.signal,
      });
      if (res.status === 409) {
        return { ok: false, bytes_done: 0, transport: "rust-quic", corrupt: true };
      }
      if (res.ok) {
        const json = (await res.json().catch(() => null)) as ChunkAck | null;
        return {
          ok: true,
          bytes_done: Number(json?.result?.data?.bytes_done ?? json?.bytes_done ?? 0),
          transport: "rust-quic",
          corrupt: false,
        };
      }
      if (![404, 501, 502, 503, 504].includes(res.status)) {
        throw new ApiError(`chunk ${input.idx} reject (${res.status})`, res.status, "chunk_failed");
      }
    } catch (e) {
      if ((e as Error).name === "AbortError") throw e;
      if (e instanceof ApiError && ![404, 501, 502, 503, 504].includes(e.status)) throw e;
    }
  }

  // FALLBACK — Bun 3300, same contract.
  const res = await fetch(`${BASE}/api/chat/file/chunk`, {
    method: "POST",
    headers,
    body: input.blob,
    signal: input.signal,
  });
  if (res.status === 409)
    return { ok: false, bytes_done: 0, transport: "bun-fallback", corrupt: true };
  if (!res.ok)
    throw new ApiError(`chunk ${input.idx} reject (${res.status})`, res.status, "chunk_failed");
  const json = (await res.json().catch(() => null)) as ChunkAck | null;
  return {
    ok: true,
    bytes_done: Number(json?.bytes_done ?? 0),
    transport: "bun-fallback",
    corrupt: false,
  };
}

/**
 * Uploader: chunking · integrity · resumability · concurrency · backpressure ·
 * truthful progress. Pause khud ka bhi hai aur network ka bhi — dono par bytes
 * server par mehfooz rehti hain aur wapis aane par wahi transfer aage chalta hai.
 */
export function useFileTransfers(conversationId: string | null = null) {
  const [items, setItems] = useState<TransferUi[]>([]);
  const controls = useRef(
    new Map<string, { abort: AbortController; paused: boolean; file: File; fingerprint: string }>(),
  );
  const [online, setOnline] = useState(true);

  useEffect(() => {
    setOnline(typeof navigator === "undefined" ? true : navigator.onLine);
    const up = () => setOnline(true);
    const down = () => setOnline(false);
    window.addEventListener("online", up);
    window.addEventListener("offline", down);
    return () => {
      window.removeEventListener("online", up);
      window.removeEventListener("offline", down);
    };
  }, []);

  const patch = useCallback((key: string, next: Partial<TransferUi>) => {
    setItems((list) => list.map((t) => (t.key === key ? { ...t, ...next } : t)));
  }, []);

  const run = useCallback(
    async (key: string, file: File, fingerprint: string, resumeTransferId?: string) => {
      const abort = new AbortController();
      const existing = controls.current.get(key);
      controls.current.set(key, { abort, paused: false, file, fingerprint });

      try {
        let transferId = resumeTransferId ?? null;
        let chunkSize = CHUNK_BYTES;
        let missing: number[] = [];
        let done = 0;
        let concurrency = 3;
        let resumed = Boolean(resumeTransferId);

        if (transferId) {
          const st = await transferState(transferId);
          if (!st.found) transferId = null;
          else {
            missing = [...(st.missing ?? []), ...(st.corrupt ?? [])];
            done = st.bytes_done;
          }
        }

        if (!transferId) {
          const b = await begin({
            name: file.name,
            content_type: file.type || "application/octet-stream",
            bytes: file.size,
            file_sha256: fingerprint,
            chunk_size: CHUNK_BYTES,
            conversation_id: conversationId,
            device: existing?.file ? "resume" : "browser",
          });
          if (!b.allowed) {
            patch(key, {
              state: "rejected",
              detail:
                b.reason === "file_too_large"
                  ? `Single file limit ${bytesLabel(b.max_file_bytes ?? 0)}`
                  : b.reason === "pool_full"
                    ? "Workspace pool full — space free karo ya plan barhao"
                    : b.reason === "transfer_quota"
                      ? "Is mahine ka transfer volume khatam"
                      : "Is plan mein file engine shamil nahi",
            });
            return;
          }
          transferId = b.transfer_id;
          chunkSize = b.chunk_size;
          missing = b.missing ?? [];
          done = b.verified_bytes ?? 0;
          concurrency = Math.max(1, Math.min(b.max_concurrent ?? 3, 6));
          resumed = b.resumed;
        }

        patch(key, {
          transferId,
          state: "transferring",
          resumed,
          bytesDone: done,
          percent: file.size ? Math.min((done / file.size) * 100, 100) : 0,
          detail: resumed
            ? `Connection restored. Resuming from ${Math.floor((done / Math.max(file.size, 1)) * 100)}%`
            : "Transferring over HTTP/3",
        });
        await mark(transferId!, "active", "rust-quic");

        const queue = [...missing].sort((a, b) => a - b);
        const attempts = new Map<number, number>();
        let inflight = 0;
        let repaired = 0;
        let failure: Error | null = null;

        const worker = async () => {
          while (queue.length && !failure) {
            const ctl = controls.current.get(key);
            if (!ctl || ctl.paused || ctl.abort.signal.aborted) return;
            while (inflight >= INFLIGHT_CAP) {
              await new Promise((r) => setTimeout(r, 120)); // backpressure
              if (controls.current.get(key)?.paused) return;
            }
            const idx = queue.shift();
            if (idx === undefined) return;

            const start = idx * chunkSize;
            const blob = file.slice(start, Math.min(start + chunkSize, file.size));
            inflight += blob.size;
            try {
              const buf = await blob.arrayBuffer();
              const sha = await sha256Hex(buf);
              const out = await putChunk({
                transferId: transferId!,
                idx,
                blob,
                sha,
                signal: abort.signal,
              });
              if (out.corrupt) {
                const tries = (attempts.get(idx) ?? 0) + 1;
                attempts.set(idx, tries);
                repaired += 1;
                if (tries >= MAX_CHUNK_ATTEMPTS) {
                  failure = new Error(`Chunk ${idx} integrity check kaamyab nahi hui`);
                  return;
                }
                queue.push(idx);
                patch(key, {
                  repaired,
                  detail: `Chunk ${idx} dobara bheja ja raha hai (integrity)`,
                });
              } else {
                done = out.bytes_done || done + blob.size;
                patch(key, {
                  bytesDone: done,
                  percent: file.size ? Math.min((done / file.size) * 100, 100) : 0,
                  transport: out.transport,
                  detail:
                    out.transport === "rust-quic"
                      ? "Transferring over HTTP/3"
                      : "Fallback path (HTTP/1.1)",
                });
              }
            } catch (e) {
              if ((e as Error).name === "AbortError") return;
              const tries = (attempts.get(idx) ?? 0) + 1;
              attempts.set(idx, tries);
              if (tries >= MAX_CHUNK_ATTEMPTS) {
                failure = e as Error;
                return;
              }
              queue.push(idx);
              await new Promise((r) => setTimeout(r, 800 * tries));
            } finally {
              inflight -= blob.size;
            }
          }
        };

        await Promise.all(Array.from({ length: concurrency }, worker));

        const ctl = controls.current.get(key);
        if (!ctl || ctl.paused || ctl.abort.signal.aborted) {
          await mark(transferId!, "paused", "rust-quic");
          patch(key, {
            state: "paused",
            detail: "Transfer paused — resume karne par yahin se chalega",
          });
          return;
        }
        const fatal = failure as Error | null;
        if (fatal) {
          await mark(transferId!, "failed", "rust-quic", fatal.message);
          patch(key, { state: "failed", detail: fatal.message });
          return;
        }

        patch(key, { state: "verifying", detail: "Chunks verify ho rahe hain" });
        const res = await commit(transferId!, fingerprint);
        if (!res.ok) {
          const again = [...(res.missing ?? []), ...(res.corrupt ?? [])];
          if (again.length) {
            patch(key, { detail: `${again.length} chunk dobara chahiye — recovery chal rahi hai` });
            await run(key, file, fingerprint, transferId!);
            return;
          }
          patch(key, { state: "failed", detail: res.reason ?? "Commit nahi hua" });
          return;
        }
        // PHASE 16: bytes pohonch gayi — bas. Yeh "Delivered" nahi hai.
        patch(key, {
          state: "scanning",
          percent: 100,
          bytesDone: file.size,
          versionId: res.version_id ?? null,
          detail: "Uploaded — safety check chal raha hai (local engines)",
        });

        // PHASE 17/18: availability ka faisla server par hota hai. Frontend
        // sirf chain parhta hai; koi bhi step khud se green nahi karta.
        if (res.version_id) {
          for (let i = 0; i < 200; i += 1) {
            const truth = await fileTruth(res.version_id).catch(() => null);
            if (truth?.blocked) {
              patch(key, {
                state: "blocked",
                detail:
                  truth.safety_reason ??
                  truth.scan?.findings?.[0]?.detail ??
                  "Blocked by content safety policy",
              });
              return;
            }
            if (truth?.available) {
              patch(key, {
                state: "available",
                detail: `Verified and available · version ${res.version}`,
              });
              return;
            }
            if (truth?.safety === "flagged") {
              patch(key, {
                state: "blocked",
                detail: truth.safety_reason ?? "Held for review — not available yet",
              });
              return;
            }
            await new Promise((r) => setTimeout(r, 1500));
          }
          patch(key, { state: "scanning", detail: "Safety check still running — review pending" });
          return;
        }
        patch(key, { state: "scanning", detail: "Uploaded — awaiting safety verdict" });
      } catch (e) {
        if ((e as Error).name === "AbortError") return;
        patch(key, { state: "failed", detail: (e as Error).message });
      }
    },
    [conversationId, patch],
  );

  /** Network wapis aaya to har paused transfer khud aage se shuru hota hai. */
  useEffect(() => {
    if (!online) {
      controls.current.forEach((c) => {
        c.paused = true;
        c.abort.abort();
      });
      setItems((list) =>
        list.map((t) =>
          t.state === "transferring"
            ? {
                ...t,
                state: "paused",
                transport: "offline",
                detail: "Transfer paused — connection gayab",
              }
            : t,
        ),
      );
      return;
    }
    items
      .filter((t) => t.state === "paused" && t.transferId)
      .forEach((t) => {
        const ctl = controls.current.get(t.key);
        if (!ctl) return;
        void run(t.key, ctl.file, ctl.fingerprint, t.transferId!);
      });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [online]);

  const add = useCallback(
    async (files: File[]) => {
      for (const file of files) {
        const key = `${file.name}:${file.size}:${Date.now()}`;
        setItems((list) => [
          {
            key,
            name: file.name,
            bytes: file.size,
            bytesDone: 0,
            percent: 0,
            state: "preparing",
            detail: "Selected — resume identity ban rahi hai",
            transport: "rust-quic",
            transferId: null,
            versionId: null,
            resumed: false,
            repaired: 0,
          },
          ...list,
        ]);
        const fingerprint = await identityFingerprint(file);
        void run(key, file, fingerprint);
      }
    },
    [run],
  );

  const pause = useCallback(
    (key: string) => {
      const ctl = controls.current.get(key);
      if (!ctl) return;
      ctl.paused = true;
      ctl.abort.abort();
      patch(key, { state: "paused", detail: "Transfer paused" });
    },
    [patch],
  );

  const resume = useCallback(
    (key: string) => {
      const ctl = controls.current.get(key);
      const item = items.find((t) => t.key === key);
      if (!ctl || !item) return;
      void run(key, ctl.file, ctl.fingerprint, item.transferId ?? undefined);
    },
    [items, run],
  );

  return { items, add, pause, resume, online };
}
