/**
 * Phase 28 — Cross-Platform: offline READ cache (IndexedDB).
 *
 * Locked scope for this phase: read cached threads and keep drafts safe while
 * offline. The real send queue (background sync) ships in Phase 30 — nothing
 * here ever claims a mail was sent.
 */

const DB_NAME = "anexomail";
const DB_VERSION = 1;
const STORES = ["threads", "thread", "drafts", "outbox"] as const;
export type OfflineStore = (typeof STORES)[number];

function open(): Promise<IDBDatabase | null> {
  if (typeof indexedDB === "undefined") return Promise.resolve(null);
  return new Promise((resolve) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION);
    request.onupgradeneeded = () => {
      const db = request.result;
      for (const name of STORES) {
        if (!db.objectStoreNames.contains(name)) db.createObjectStore(name, { keyPath: "key" });
      }
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => resolve(null);
  });
}

type Row<T> = { key: string; value: T; at: number };

export async function put<T>(store: OfflineStore, key: string, value: T) {
  const db = await open();
  if (!db) return;
  await new Promise<void>((resolve) => {
    const tx = db.transaction(store, "readwrite");
    tx.objectStore(store).put({ key, value, at: Date.now() } satisfies Row<T>);
    tx.oncomplete = () => resolve();
    tx.onerror = () => resolve();
  });
}

export async function get<T>(store: OfflineStore, key: string): Promise<{ value: T; at: number } | null> {
  const db = await open();
  if (!db) return null;
  return new Promise((resolve) => {
    const tx = db.transaction(store, "readonly");
    const request = tx.objectStore(store).get(key);
    request.onsuccess = () => {
      const row = request.result as Row<T> | undefined;
      resolve(row ? { value: row.value, at: row.at } : null);
    };
    request.onerror = () => resolve(null);
  });
}

export async function all<T>(store: OfflineStore): Promise<{ key: string; value: T; at: number }[]> {
  const db = await open();
  if (!db) return [];
  return new Promise((resolve) => {
    const tx = db.transaction(store, "readonly");
    const request = tx.objectStore(store).getAll();
    request.onsuccess = () => resolve((request.result as Row<T>[]) ?? []);
    request.onerror = () => resolve([]);
  });
}

export async function remove(store: OfflineStore, key: string) {
  const db = await open();
  if (!db) return;
  const tx = db.transaction(store, "readwrite");
  tx.objectStore(store).delete(key);
}

export async function clearOffline() {
  const db = await open();
  if (!db) return;
  const tx = db.transaction(STORES as unknown as string[], "readwrite");
  for (const name of STORES) tx.objectStore(name).clear();
}

export async function offlineSize(): Promise<{ threads: number; thread: number; drafts: number }> {
  const [threads, thread, drafts] = await Promise.all([
    all("threads"),
    all("thread"),
    all("drafts"),
  ]);
  return { threads: threads.length, thread: thread.length, drafts: drafts.length };
}