// QUI-H4: one additive line for the per-message proof popover. Fetches only when the popover is opened (the door may write ONE idempotent ledger checkpoint).
import { useEffect, useState } from "react";
import { verifyAnchorInKernel } from "./mail_api";

export function MailAnchorLine({ box, id }: { box: string; id: string }) {
  const [r, setR] = useState<Awaited<ReturnType<typeof verifyAnchorInKernel>> | undefined>(undefined);
  useEffect(() => { let live = true; setR(undefined); verifyAnchorInKernel(box, id).then((x) => { if (live) setR(x); }).catch(() => { if (live) setR(null); }); return () => { live = false; }; }, [box, id]);
  const t = r === undefined ? "Checking the audit Merkle proof in your browser…" : r === null ? "Audit Merkle proof not available (not verified)" : r.state === "proven" ? `Audit tree: ${r.text}` : r.state === "pending" ? `Audit tree: ${r.text}` : `Audit tree proof FAILED: ${r.text}`;
  return <span className="mx-anchor" data-state={r === undefined ? "busy" : r === null ? "off" : r.state}>{t}</span>;
}
