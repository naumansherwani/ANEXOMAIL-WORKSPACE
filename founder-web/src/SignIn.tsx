import { useEffect, useState, type FormEvent } from "react";
import { motion } from "motion/react";
import { Eye, EyeOff, KeyRound, Mail, ShieldCheck } from "lucide-react";
import { canSubmit, classifyLogin, cleanEmail, messageFor, sessionEntries, type LoginOutcome } from "./signin_pure";
import { BrandMark } from "./signin/BrandMark";
import { HoverA } from "./signin/BrandLoader";
import { AuthCinema } from "./signin/AuthCinema";
import { Button } from "./signin/ui/button";
import { Input } from "./signin/ui/input";
import { Label } from "./signin/ui/label";
import { Checkbox } from "./signin/ui/checkbox";

/** The founder's own sign-in. LOOK + CODE = the awam login (auth.tsx, AuthCinema, BrandMark, shadcn Button/Input/Label, same Tailwind classes), copied into the founder lane (the awam files are only read, never edited),
 *  moved onto the founder stack (React 19, Tailwind 4.2, motion, lucide-react, TypeScript strict). Only the line "Founder protocol / Welcome, Founder" is added (founder order 10 Nov 2026 01:13/01:24/01:58).
 *  Talks only to /founder/v1/auth/login (Rust). One build for every screen: the side panel appears from lg (1024px), controls are 44px on touch. */
const PENDING = "This step is being moved into the new founder sign-in and is not available yet. Use your password for now.";

const SAVE_KEY = "anexo.founder.savepw"; // same behaviour as the awam page: ON by default, remembered per browser
const readSave = () => { try { return window.localStorage.getItem(SAVE_KEY) !== "0"; } catch { return true; } };
const writeSave = (on: boolean) => { try { window.localStorage.setItem(SAVE_KEY, on ? "1" : "0"); } catch { /* ignore */ } };

export function SignIn() {
  const [savePassword, setSavePassword] = useState(readSave);
  const [email, setEmail] = useState(""), [password, setPassword] = useState(""), [busy, setBusy] = useState(false), [msg, setMsg] = useState(""), [show, setShow] = useState(false), [splash, setSplash] = useState(false), [minDone, setMinDone] = useState(false);
  useEffect(() => {
    if (!splash) return;
    const t = window.setTimeout(() => setMinDone(true), 1400), u = window.setTimeout(() => window.location.reload(), 2500);
    return () => { window.clearTimeout(t); window.clearTimeout(u); };
  }, [splash]);
  async function submit(e: FormEvent) {
    e.preventDefault();
    const addr = email.includes("@") ? email : email.trim() ? email.trim() + "@anexomail.com" : "";
    if (!canSubmit(addr, password, busy)) { setMsg(messageFor("bad_input")); return; }
    setBusy(true); setMsg("");
    let out: LoginOutcome;
    try {
      const r = await fetch("/founder/v1/auth/login", { method: "POST", headers: { "content-type": "application/json" }, cache: "no-store", body: JSON.stringify({ email: cleanEmail(addr), password }) });
      let j: unknown = null; try { j = await r.json(); } catch { /* not json */ }
      out = classifyLogin(r.status, j);
    } catch { out = { kind: "offline" }; }
    if (out.kind === "ok") {
      try { for (const [k, v] of sessionEntries(out)) window.localStorage.setItem(k, v); } catch { setBusy(false); setMsg("This browser blocks storage, so the sign-in cannot be kept. Allow site data and try again."); return; }
      setPassword(""); setSplash(true); return;
    }
    setBusy(false); setPassword(""); setMsg(messageFor(out.kind));
  }
  return (
    <>
      <main className="fa flex min-h-screen overflow-hidden bg-background">
        <AuthCinema className="hidden lg:flex" />
        <div className="flex flex-1 items-center justify-center px-6 py-12 lg:px-14">
          <div className="ax-in w-full max-w-[28rem]">
            <div className="mb-6 lg:hidden"><BrandMark home={false} /></div>
            <div className="mb-ax-4 text-center">
              <p className="text-xs font-semibold uppercase tracking-[0.2em] text-muted-foreground">Founder protocol</p>
              <h1 className="mt-1 text-3xl font-semibold tracking-tight text-foreground">Welcome, Founder</h1>
            </div>
            <div className="rounded-2xl border border-border bg-card p-ax-5 shadow-2xl">
              <div className="text-center">
                <h2 className="ax-heading text-foreground">Sign in</h2>
                <p className="ax-caption mt-1">Your mail, people, calendar and work — one surface.</p>
              </div>
              <form onSubmit={submit} noValidate name="login" method="post" autoComplete={savePassword ? "on" : "off"} className="mt-ax-4 space-y-ax-3">
                <div className="space-y-1.5">
                  <Label htmlFor="email" className="text-[13px] font-semibold text-foreground">Email</Label>
                  <div className="flex h-10 overflow-hidden rounded-md border border-border bg-[#F9FAFB] ring-offset-background focus-within:ring-1 focus-within:ring-ring">
                    <input id="email" type="text" inputMode="email" autoCapitalize="none" autoCorrect="off" spellCheck={false} autoComplete="username webauthn" placeholder="yourname" aria-label="Email" value={email} onChange={(e) => setEmail(e.target.value)}
                      className="w-0 min-w-0 flex-1 bg-transparent px-3 text-[15px] font-semibold text-[#0B1220] outline-none placeholder:font-normal placeholder:text-[#6B7280]" />
                    {!email.includes("@") && <span aria-hidden className="flex shrink-0 items-center border-l border-[#E5E7EB] bg-[#E5E7EB] px-3 text-[15px] font-semibold text-[#0B1220] select-none">@anexomail.com</span>}
                  </div>
                </div>
                <div className="space-y-1.5">
                  <Label htmlFor="password" className="ax-caption text-foreground">Password</Label>
                  <div className="relative">
                    <Input id="password" name="password" type={show ? "text" : "password"} value={password} required autoComplete={savePassword ? "current-password" : "off"}
                      className="pr-10 bg-[#F9FAFB] text-[15px] font-semibold text-[#0B1220] placeholder:font-normal placeholder:text-[#6B7280]" onChange={(e) => setPassword(e.target.value)} />
                    <button type="button" className="absolute inset-y-0 right-0 flex w-10 items-center justify-center text-muted-foreground transition-colors hover:text-foreground focus-visible:outline-none" aria-label={show ? "Hide password" : "Show password"} title={show ? "Hide password" : "Show password"} onClick={() => setShow((v) => !v)}>
                      {show ? <EyeOff className="size-4" /> : <Eye className="size-4" />}
                    </button>
                  </div>
                </div>
                <label htmlFor="save-password" className="flex cursor-pointer items-center gap-2.5 rounded-lg border border-border bg-secondary/40 px-3 py-2.5">
                  <Checkbox id="save-password" checked={savePassword} onCheckedChange={(v) => { const on = v === true; setSavePassword(on); writeSave(on); }} />
                  <span className="text-[13px] font-semibold text-foreground">Save password</span>
                </label>
                {msg && (
                  <motion.p initial={{ opacity: 0, y: -4 }} animate={{ opacity: 1, y: 0 }} role="alert" className="ax-caption text-destructive">{msg}</motion.p>
                )}
                <Button type="submit" className="ax-press ax-a-hover w-full" disabled={busy}>
                  <HoverA busy={busy} />
                  Sign in
                </Button>
              </form>
              <div className="my-ax-4 flex items-center gap-3">
                <div aria-hidden className="ax-hairline h-px flex-1" />
                <span className="ax-caption">or</span>
                <div aria-hidden className="ax-hairline h-px flex-1" />
              </div>
              <div className="space-y-ax-2">
                <Button type="button" variant="outline" className="ax-press w-full" onClick={() => setMsg(PENDING)} disabled={busy}><KeyRound className="size-4" />Continue with a passkey</Button>
                <Button type="button" variant="ghost" className="w-full" onClick={() => setMsg(PENDING)}><Mail className="size-4" />Email me a sign-in link</Button>
                <Button type="button" variant="ghost" className="w-full" onClick={() => setMsg(PENDING)}><ShieldCheck className="size-4" />Lost your passkey? Use a recovery code</Button>
              </div>
            </div>
            <p className="ax-caption mt-ax-4 flex items-center justify-center gap-1.5">
              <ShieldCheck className="size-3.5 text-cyan-accent" />
              Sessions are device-bound and revocable from your account at any time.
            </p>
          </div>
        </div>
      </main>
      {splash && (
        <div role="status" aria-live="polite" className="fa fixed inset-0 z-[200] flex flex-col items-center justify-center gap-ax-4 bg-background">
          <BrandMark home={false} />
          <p className="text-xs font-semibold uppercase tracking-[0.25em] text-muted-foreground">Founder protocol</p>
          <p className="text-2xl font-semibold tracking-tight text-foreground">{minDone ? "Activated" : "Activating\u2026"}</p>
          <div className="h-1 w-48 overflow-hidden rounded-full bg-border">
            <div className="h-full rounded-full bg-cyan-accent transition-all duration-[1400ms] ease-out" style={{ width: minDone ? "100%" : "70%" }} />
          </div>
        </div>
      )}
    </>
  );
}
