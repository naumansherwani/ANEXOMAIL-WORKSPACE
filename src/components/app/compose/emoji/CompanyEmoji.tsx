// QC1e D4A (20 Nov 2026, AWAM ONLY): React glue of the company emoji pack: the hook and the lazy image. Pure logic = company_emoji_pure.ts.
import "./company_emoji.css";
import { useEffect, useState } from "react";
import { EMPTY_PACK, imageUrl, loadPack, onPack, type Pack } from "./companyEmoji";

/** The caller's pack (cached 60 s, refreshed after every add / remove). `load` = false keeps the hook idle until it is needed. */
export function useCompanyPack(load = true): Pack {
  const [p, setP] = useState<Pack>(EMPTY_PACK);
  useEffect(() => {
    if (!load) return;
    let live = true;
    void loadPack().then((v) => { if (live) setP(v); });
    const off = onPack((v) => { if (live) setP(v); });
    return () => { live = false; off(); };
  }, [load]);
  return p;
}

/** One picture. Loads lazily (only when it is on screen), falls back to the ":code:" text if it cannot load. */
export function CompanyImg({ code, sha, alt, size = 24, className }: { code: string; sha: string; alt?: string; size?: number; className?: string }) {
  const [src, setSrc] = useState<string | null>(null), [bad, setBad] = useState(false);
  useEffect(() => {
    let live = true; setSrc(null); setBad(false);
    imageUrl(code, sha).then((u) => { if (live) setSrc(u); }).catch(() => { if (live) setBad(true); });
    return () => { live = false; };
  }, [code, sha]);
  if (bad) return <span className="emo-co-txt" aria-hidden="true">:{code}:</span>;
  if (!src) return <span className="emo-co-ph" style={{ width: size, height: size }} aria-hidden="true" />;
  return <img className={className ?? "emo-co-img"} src={src} width={size} height={size} alt={alt ?? `:${code}:`} draggable={false} decoding="async" />;
}
