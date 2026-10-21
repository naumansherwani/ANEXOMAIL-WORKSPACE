#!/usr/bin/env python3
"""B2 hardening: Bun fallback (/api/auth/passkey/verify, /register/verify) mein challenge SINGLE-USE (pehle mitao) + shape check + user match.
   python3 -I brain_passkey_harden.py <live auth-passkey.ts> <out.ts>   -> "same" | "update" | exit 3 (marker nahi mila)
Live file repo se thori alag ho sakti hai (refresh patch) — isliye poori file nahi, sirf 3 surgical jagah."""
import sys
src,out=sys.argv[1:3]
s=open(src).read()
PAIRS=[('      const { data: row, error } = await getAdmin()\n        .from("webauthn_challenges")\n        .select("challenge,origin,rp_id,expires_at")\n        .eq("user_id", identity.user.id)\n        .eq("kind", "register")\n        .eq("challenge", client.challenge || "")\n        .maybeSingle();\n      if (error || !row || new Date(row.expires_at).getTime() < Date.now()) {\n        return fail(res, 400, "passkey_challenge_expired");\n      }',
  '      // B2 hardening: challenge SINGLE-USE — pehle mitao (DB-side expiry), phir verify. Replay ka darwaza band.\n      if (!/^[A-Za-z0-9_-]{1,128}$/.test(String(client.challenge || ""))) return fail(res, 400, "passkey_challenge_expired");\n      const { data: consumed, error } = await getAdmin()\n        .from("webauthn_challenges")\n        .delete()\n        .eq("user_id", identity.user.id)\n        .eq("kind", "register")\n        .eq("challenge", client.challenge)\n        .gt("expires_at", new Date().toISOString())\n        .select("challenge,origin,rp_id,expires_at");\n      const row = Array.isArray(consumed) ? consumed[0] : null;\n      if (error || !row) {\n        return fail(res, 400, "passkey_challenge_expired");\n      }'),
 ('      const { data: ch } = await getAdmin()\n        .from("webauthn_challenges")\n        .select("*")\n        .eq("kind", "authenticate")\n        .eq("challenge", client.challenge || "")\n        .maybeSingle();\n      if (!ch || new Date(ch.expires_at).getTime() < Date.now()) {\n        return fail(res, 400, "passkey_challenge_expired");\n      }',
  '      // B2 hardening: challenge SINGLE-USE — pehle mitao (DB-side expiry), phir signature. Pakda hua jawab dobara nahi chalta.\n      if (!/^[A-Za-z0-9_-]{1,128}$/.test(String(client.challenge || ""))) return fail(res, 400, "passkey_challenge_expired");\n      const { data: consumed } = await getAdmin()\n        .from("webauthn_challenges")\n        .delete()\n        .eq("kind", "authenticate")\n        .eq("challenge", client.challenge)\n        .gt("expires_at", new Date().toISOString())\n        .select("*");\n      const ch = Array.isArray(consumed) ? consumed[0] : null;\n      if (!ch) {\n        return fail(res, 400, "passkey_challenge_expired");\n      }'),
 ('      if (!stored) return fail(res, 400, "passkey_unknown");\n',
  '      if (!stored) return fail(res, 400, "passkey_unknown");\n      // challenge kisi khaas user ke liye bana tha to usi ka passkey chalega\n      if (ch.user_id && ch.user_id !== stored.user_id) return fail(res, 400, "passkey_unknown");\n')]
if all(new in s for _,new in PAIRS):
    open(out,"w").write(s); print("same"); sys.exit(0)
for old,new in PAIRS:
    if new in s: continue
    if s.count(old)!=1:
        print("STOP: marker nahi mila / ek se zyada (%d): %s" % (s.count(old), old[:70].replace("\n"," | "))); sys.exit(3)
    s=s.replace(old,new)
open(out,"w").write(s); print("update")
