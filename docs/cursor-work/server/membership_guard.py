#!/usr/bin/env python3
"""Membership guard for the live Rust engine (founder "haan", 19 Oct 2026 — a removed member must not keep a workspace).

Every PostgREST read in src/main.rs that asks "which organisation does THIS USER belong to" (or "what is this user's role there")
is written as a string literal beginning `org_members?select=` and containing `user_id=eq.`. Brain's revoke sets
org_members.status = 'revoked' (row stays, for history), but those reads ignored it, so a removed member could still open the
organisation's mail through Rust. This script appends   &or=(status.is.null,status.neq.revoked)   to exactly those literals.

  membership_guard.py <main.rs>            patch in place, print what happened
  membership_guard.py <main.rs> --check    print what WOULD happen, change nothing
Exit 0 = patched / already patched / nothing to do; exit 4 = a read it cannot patch safely (printed) — nothing is written then.
Idempotent. Only touches string literals; never code. Reads keyed by org alone (member lists) are left alone: listing is not access.
"""
import re
import sys

GUARD = "&or=(status.is.null,status.neq.revoked)"
MARK = "status.neq.revoked"
# literal "org_members?select=...user_id=eq...." on ONE line, no embedded quotes
LIT = re.compile(r'"(org_members\?select=[^"\n]*user_id=eq\.[^"\n]*)"')
ANY = re.compile(r'org_members\?[^"\n]*')


def patch(src: str):
    new, already, skipped = 0, 0, []

    def rep(m):
        nonlocal new, already
        lit = m.group(1)
        if MARK in lit:
            already += 1
            return m.group(0)
        if "or=(" in lit or "&or=" in lit:
            skipped.append(lit)
            return m.group(0)
        new += 1
        return '"' + lit + GUARD + '"'

    out = LIT.sub(rep, src)
    # every other org_members read that mentions user_id but is NOT a plain literal (built with concat/format pieces) — report only
    other = []
    for line_no, line in enumerate(out.splitlines(), 1):
        if "org_members?" in line and "user_id" in line and MARK not in line and not LIT.search(line):
            if "select=" in line:
                other.append((line_no, line.strip()[:120]))
    return out, new, already, skipped, other


def main(argv):
    if not argv:
        print(__doc__)
        return 2
    path, check = argv[0], "--check" in argv[1:]
    src = open(path).read()
    out, new, already, skipped, other = patch(src)
    if skipped or other:
        for s in skipped:
            print("GUARD: ye read patch nahi ho sakta (pehle se `or=` hai): " + s)
        for n, l in other:
            print("GUARD: line %d seedha literal nahi — haath se dekhna: %s" % (n, l))
        return 4
    print("GUARD: %d read(s) ab revoked member ko bahar rakhte hain (naye: %d, pehle se: %d)" % (new + already, new, already))
    if new and not check:
        open(path, "w").write(out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
