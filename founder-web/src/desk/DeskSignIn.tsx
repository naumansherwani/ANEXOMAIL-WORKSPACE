import { useState, type FormEvent } from "react";
import { Eye, EyeOff } from "lucide-react";
import { canSubmit, cleanEmail } from "../signin_pure";
import { BrandMark } from "../signin/BrandMark";
import { HoverA } from "../signin/BrandLoader";
import { AuthCinema } from "../signin/AuthCinema";
import { Button } from "../signin/ui/button";
import { Input } from "../signin/ui/input";
import { Label } from "../signin/ui/label";
import { postJson, realDeps } from "../signin_passkey";
import { DESK_LOGIN_PATH, DESK_SESSION_KEY, deskLoginMessage } from "./desk_pure";

/** Admin Desk sign-in (/adminlogin). LOOK = the founder sign-in (same BrandMark, AuthCinema, shadcn Button/Input/Label, same classes); only the words differ.
 *  Password signs in; a passkey is OPTIONAL and arrives later (R6). Talks only to the Desk door /desk/v1/auth/login (Rust, R3a2). Before the session exists it is the one plain POST helper the founder passkey sign-in also uses (postJson); no new raw fetch. */
export function DeskSignIn() {
  const [email, setEmail] = useState(""), [password, setPassword] = useState(""), [busy, setBusy] = useState(false), [msg, setMsg] = useState(""), [show, setShow] = useState(false);
  async function submit(e: FormEvent) {
    e.preventDefault();
    const addr = email.includes("@") ? email : email.trim() ? email.trim() + "@anexomail.com" : "";
    if (!canSubmit(addr, password, busy)) { setMsg("Enter your email and password."); return; }
    setBusy(true); setMsg("");
    try {
      const r = await postJson(realDeps(), DESK_LOGIN_PATH, { email: cleanEmail(addr), password }), j = (r.json && typeof r.json === "object" ? r.json : null) as { token?: string } | null;
      if (r.status === 200 && typeof j?.token === "string") { try { window.localStorage.setItem(DESK_SESSION_KEY, j.token); } catch { setMsg("This browser blocks storage, so the sign-in cannot be kept."); setBusy(false); return; } window.location.assign("/dashboard"); return; }
      setMsg(deskLoginMessage(r.status));
    } catch { setMsg(deskLoginMessage(0)); }
    setBusy(false); setPassword("");
  }
  return (
    <main className="fa flex min-h-screen overflow-hidden bg-background">
      <AuthCinema className="hidden lg:flex" />
      <div className="flex flex-1 items-center justify-center px-6 py-12 lg:px-14">
        <div className="ax-in w-full max-w-[28rem]">
          <div className="mb-6 lg:hidden"><BrandMark home={false} /></div>
          <div className="mb-ax-4 text-center">
            <p className="text-xs font-semibold uppercase tracking-[0.2em] text-muted-foreground">Admin Desk</p>
            <h1 className="mt-1 text-3xl font-semibold tracking-tight text-foreground">Welcome to the Desk</h1>
          </div>
          <div className="rounded-2xl border border-border bg-card p-ax-5 shadow-2xl">
            <div className="text-center"><h2 className="ax-heading text-foreground">Sign in</h2><p className="ax-caption mt-1">Company mail, one place.</p></div>
            <form onSubmit={submit} noValidate name="desklogin" method="post" autoComplete="on" className="mt-ax-4 space-y-ax-3">
              <div className="space-y-1.5">
                <Label htmlFor="email" className="text-[13px] font-semibold text-foreground">Email</Label>
                <div className="flex h-10 overflow-hidden rounded-md border border-border bg-[#F9FAFB] focus-within:ring-1 focus-within:ring-ring">
                  <input id="email" type="text" inputMode="email" autoCapitalize="none" autoCorrect="off" spellCheck={false} autoComplete="username" placeholder="yourname" aria-label="Email" value={email} onChange={(e) => setEmail(e.target.value)}
                    className="w-0 min-w-0 flex-1 bg-transparent px-3 text-[15px] font-semibold text-[#0B1220] outline-none placeholder:font-normal placeholder:text-[#6B7280]" />
                  {!email.includes("@") && <span aria-hidden className="flex shrink-0 items-center border-l border-[#E5E7EB] bg-[#E5E7EB] px-3 text-[15px] font-semibold text-[#0B1220] select-none">@anexomail.com</span>}
                </div>
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="password" className="ax-caption text-foreground">Password</Label>
                <div className="relative">
                  <Input id="password" name="password" type={show ? "text" : "password"} value={password} required autoComplete="current-password" className="pr-10 bg-[#F9FAFB] text-[15px] font-semibold text-[#0B1220]" onChange={(e) => setPassword(e.target.value)} />
                  <button type="button" className="absolute inset-y-0 right-0 flex w-11 items-center justify-center text-muted-foreground hover:text-foreground focus-visible:outline-none" aria-label={show ? "Hide password" : "Show password"} onClick={() => setShow(!show)}>
                    {show ? <EyeOff className="size-4" /> : <Eye className="size-4" />}
                  </button>
                </div>
              </div>
              {msg && <p role="alert" className="ax-caption text-destructive">{msg}</p>}
              <Button type="submit" className="ax-press ax-a-hover w-full" disabled={busy}><HoverA busy={busy} />Sign in</Button>
            </form>
          </div>
        </div>
      </div>
    </main>
  );
}
