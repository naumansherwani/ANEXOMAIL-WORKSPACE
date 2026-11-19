// QC1e D4A (20 Nov 2026, AWAM ONLY): Admin > Company emoji. Owner / admin add and remove the company's own small pictures (logo, badge); everybody in the
// company can use them in the compose window (picker "Company" tab, or type :name). Plan docs/claude/QC1E-D4-PLAN-20NOV.md; rules live in Rust (emoji_glue.rs) + SQL E193.
import { createFileRoute } from "@tanstack/react-router";
import { useRef, useState } from "react";
import { Trash2, Upload } from "lucide-react";

import { CompanyImg, useCompanyPack } from "@/components/app/compose/emoji/CompanyEmoji";
import { addEmoji, removeEmoji } from "@/components/app/compose/emoji/companyEmoji";
import { cleanCode, codeFromFile, fileProblem, quotaLabel, quotaTone } from "@/components/app/compose/emoji/company_emoji_pure";
import { StateBlock } from "@/components/state/StateBlock";
import { AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent, AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogTitle } from "@/components/ui/alert-dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useAuth } from "@/lib/auth";
import { notify } from "@/lib/notify";
import "@/components/app/compose/emoji/company_emoji.css";

export const Route = createFileRoute("/app/admin/emoji")({
  head: () => ({
    meta: [
      { title: "Company emoji — ANEXOMAIL Admin" },
      { name: "description", content: "Add your logo or badge as a small picture your whole company can use in messages." },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: EmojiAdminPage,
});

function EmojiAdminPage() {
  const { organisation } = useAuth();
  const pack = useCompanyPack();
  const fileRef = useRef<HTMLInputElement>(null);
  const [file, setFile] = useState<File | null>(null), [code, setCode] = useState(""), [alt, setAlt] = useState(""), [busy, setBusy] = useState(false);
  const [gone, setGone] = useState<string | null>(null);
  const q = pack.quota, tone = quotaTone(q);

  if (!organisation) return <div className="mx-auto w-full max-w-3xl px-ax-4 py-ax-6 md:px-10 md:py-10"><StateBlock title="No organisation yet" body="Create your organisation first: the company emoji live inside it." /></div>;
  if (pack.available && !q.enabled) return <div className="mx-auto w-full max-w-3xl px-ax-4 py-ax-6 md:px-10 md:py-10"><StateBlock title="Not in your plan" body="Company emoji are part of the Business plans." /></div>;
  if (!pack.available) return <div className="mx-auto w-full max-w-3xl px-ax-4 py-ax-6 md:px-10 md:py-10"><StateBlock title="Company emoji could not be loaded" body="Check your connection and try again in a moment." /></div>;

  const pick = (f: File | null) => {
    setFile(f);
    if (f) { const p = fileProblem(f); if (p) { notify.failed("Picture not accepted", { description: p }); setFile(null); return; } if (!code) setCode(codeFromFile(f.name)); }
  };
  const cc = code ? cleanCode(code) : null;
  const ready = !!file && !!cc && cc.ok && pack.canManage && q.left > 0 && !busy;

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!file || !cc || !cc.ok) return;
    setBusy(true);
    try {
      await addEmoji({ code: cc.code, alt: alt.trim(), file });
      notify.done("Emoji added", `Everyone can now type :${cc.code}: or find it under Company in the emoji picker.`);
      setFile(null); setCode(""); setAlt(""); if (fileRef.current) fileRef.current.value = "";
    } catch (err) { notify.failed("Emoji not added", { description: (err as Error).message }); } finally { setBusy(false); }
  };

  return (
    <div className="mx-auto w-full max-w-3xl px-ax-4 py-ax-6 md:px-10 md:py-10">
      <p className="ax-eyebrow">Company</p>
      <h2 className="mt-3 text-3xl text-foreground">Company emoji</h2>
      <p className="mt-4 text-sm leading-relaxed text-muted-foreground">Add your logo or a badge as a small picture. Everyone in your company can use it in a message: type <b>:name</b> or open the emoji picker and choose Company. Until messages carry real inline pictures, the other side sees the text <b>:name:</b>.</p>

      <div className="mt-6" role="group" aria-label="Emoji limit">
        <div className="flex items-baseline justify-between text-sm"><span>{quotaLabel(q)}</span><span className="text-muted-foreground">{q.left} left</span></div>
        <div className={`coe-bar mt-2 ${tone}`} role="progressbar" aria-valuemin={0} aria-valuemax={q.limit} aria-valuenow={q.used}><i style={{ width: `${Math.min(100, (q.used / Math.max(1, q.limit)) * 100)}%` }} /></div>
      </div>

      {pack.canManage ? (
        <form className="mt-8 grid gap-4" onSubmit={submit}>
          <div className="grid gap-2"><Label htmlFor="coe-file">Picture (PNG or WebP, up to 512 KB)</Label>
            <Input id="coe-file" ref={fileRef} type="file" accept="image/png,image/webp" onChange={(e) => pick(e.target.files?.[0] ?? null)} /></div>
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="grid gap-2"><Label htmlFor="coe-code">Name you type after “:”</Label>
              <Input id="coe-code" value={code} onChange={(e) => setCode(e.target.value)} placeholder="acme" autoComplete="off" spellCheck={false} aria-invalid={!!cc && !cc.ok} aria-describedby="coe-code-h" />
              <p id="coe-code-h" className={`text-xs ${cc && !cc.ok ? "text-destructive" : "text-muted-foreground"}`}>{cc && !cc.ok ? cc.reason : "2-24 letters, digits, _ or -"}</p></div>
            <div className="grid gap-2"><Label htmlFor="coe-alt">Description (optional)</Label>
              <Input id="coe-alt" value={alt} onChange={(e) => setAlt(e.target.value)} maxLength={80} placeholder="Acme logo" autoComplete="off" /></div>
          </div>
          <div><Button type="submit" disabled={!ready} className="min-h-11"><Upload className="mr-2 h-4 w-4" aria-hidden="true" />{busy ? "Adding…" : "Add emoji"}</Button>
            {q.left <= 0 && <p className="mt-2 text-xs text-destructive" role="status">Your plan's limit is reached. Remove one first.</p>}</div>
        </form>
      ) : <p className="mt-6 text-sm text-muted-foreground">Only an owner or an admin can add or remove company emoji.</p>}

      <h3 className="mt-10 text-lg text-foreground">In your pack</h3>
      {pack.items.length === 0 ? <p className="mt-3 text-sm text-muted-foreground">Nothing yet.</p> : (
        <ul className="coe-grid mt-4">
          {pack.items.map((c) => (
            <li key={c.shortcode} className="coe-card">
              <CompanyImg code={c.shortcode} sha={c.sha256} alt={c.alt || `:${c.shortcode}:`} size={48} />
              <span className="coe-code" title={`:${c.shortcode}:`}>:{c.shortcode}:</span>
              {c.alt && <span className="truncate text-xs text-muted-foreground" title={c.alt}>{c.alt}</span>}
              {pack.canManage && <Button type="button" variant="outline" className="min-h-11" onClick={() => setGone(c.shortcode)} aria-label={`Remove :${c.shortcode}:`}><Trash2 className="mr-2 h-4 w-4" aria-hidden="true" />Remove</Button>}
            </li>
          ))}
        </ul>
      )}

      <AlertDialog open={!!gone} onOpenChange={(o) => { if (!o) setGone(null); }}>
        <AlertDialogContent>
          <AlertDialogHeader><AlertDialogTitle>Remove :{gone}: ?</AlertDialogTitle>
            <AlertDialogDescription>It disappears from the picker for everyone. Messages that already have the text stay as they are. This is written to the company's emoji log.</AlertDialogDescription></AlertDialogHeader>
          <AlertDialogFooter><AlertDialogCancel>Keep it</AlertDialogCancel>
            <AlertDialogAction onClick={async () => { const c = gone; setGone(null); if (!c) return; try { await removeEmoji(c); notify.done("Emoji removed", `:${c}: is gone.`); } catch (err) { notify.failed("Emoji not removed", { description: (err as Error).message }); } }}>Remove</AlertDialogAction></AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
