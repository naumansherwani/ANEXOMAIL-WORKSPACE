import { useCallback, useEffect, useState } from "react";
import { get } from "./api";
import type { DbscStatus } from "./dbsc_pure";
import { DbscCard } from "./DbscCard";

// K7 — Device-bound sessions (inside Settings → Privacy, under Security keys). Chrome keeps a private key in the computer's secure chip (TPM) and proves it on every refresh,
// so a stolen login cannot be replayed from another machine. Everything shown comes from the server (Rust dbsc.rs + E149 SQL); nothing is invented here.
export function Dbsc() {
  const [s, setS] = useState<DbscStatus | null>(null), [err, setErr] = useState<string | null>(null);
  const reload = useCallback(async () => { try { setS((await get<DbscStatus>("/founder/v1/dbsc/status")).data); setErr(null); } catch (e) { setErr((e as Error).message); } }, []);
  useEffect(() => { void reload(); const t = setInterval(() => { void reload(); }, 30000); return () => clearInterval(t); }, [reload]);
  if (err) return <section className="panel" aria-label="Device-bound sessions"><div className="panelhead"><h2>Device-bound sessions</h2><p className="dim">{err}</p></div></section>;
  if (!s) return <section className="panel" aria-label="Device-bound sessions"><div className="panelhead"><h2>Device-bound sessions</h2><p className="dim">Loading…</p></div></section>;
  return <DbscCard s={s} />;
}
