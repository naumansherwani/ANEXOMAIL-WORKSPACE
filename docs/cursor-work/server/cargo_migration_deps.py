#!/usr/bin/env python3
"""Cargo.toml mein migration worker ke liye sirf 2 crate judta hai (founder ne G30 ke liye ijazat di, 19 Oct 2026):

    rustls        = { version = "0.23", default-features = false, features = ["ring", "std", "tls12"] }
    webpki-roots  = "0.26"

Kya karta hai:
  * sirf `[dependencies]` section mein, uske aakhri item ke baad, ek line per crate jodta hai;
  * jo crate pehle se likha ho use nahi chhedta (idempotent: dobara chalane par kuch nahi badalta);
  * kuch bhi samajh na aaye (section nahi mila, file khali) => kuch likhe baghair exit 4.
Baqi Cargo.toml (version, features, profile.release) jaisa hai waisa rehta hai.

usage: python3 -I cargo_migration_deps.py <Cargo.toml>
"""
import re
import sys

NEED = [
    ("rustls", 'rustls = { version = "0.23", default-features = false, features = ["ring", "std", "tls12"] }'),
    ("webpki-roots", 'webpki-roots = "0.26"'),
]


def patch(text):
    """returns (new_text, added_names, present_names) or raises ValueError."""
    m = re.search(r"^\[dependencies\][ \t]*\r?$", text, re.M)
    if not m:
        raise ValueError("`[dependencies]` section nahi mila")
    nxt = re.search(r"^\[", text[m.end():], re.M)
    end = m.end() + nxt.start() if nxt else len(text)
    body = text[m.end():end]
    if not body.strip():
        raise ValueError("`[dependencies]` khali hai — ajeeb, kuch nahi badla")
    added, present, lines = [], [], []
    for name, line in NEED:
        if re.search(r"^[ \t]*" + re.escape(name) + r"[ \t]*=", body, re.M):
            present.append(name)
        else:
            added.append(name)
            lines.append(line)
    if not lines:
        return text, added, present
    stripped = body.rstrip()
    tail = body[len(stripped):]  # blank lines before the next section (or the final newline)
    if not tail:
        tail = "\n"
    new_body = stripped + "\n" + "\n".join(lines) + tail
    return text[: m.end()] + new_body + text[end:], added, present


def main(argv):
    if len(argv) != 2:
        print("usage: cargo_migration_deps.py <Cargo.toml>")
        return 2
    path = argv[1]
    try:
        text = open(path, encoding="utf-8").read()
    except OSError as e:
        print("Cargo.toml padh nahi saka: %s" % e)
        return 4
    try:
        new, added, present = patch(text)
    except ValueError as e:
        print("PATCH FAIL: %s" % e)
        return 4
    if present:
        print("   Cargo.toml: pehle se hai -> %s" % ", ".join(present))
        mm = re.search(r"^[ \t]*rustls[ \t]*=.*$", text, re.M)
        if mm and '"ring"' not in mm.group(0):
            print("   (dhyan: rustls ki maujooda line mein \"ring\" feature nahi — build fail ho sakta hai; fail hua to sab wapas ho jata hai)")
    if added:
        with open(path, "w", encoding="utf-8") as f:
            f.write(new)
        print("   Cargo.toml: judne wale crate -> %s" % ", ".join(added))
    else:
        print("   Cargo.toml: kuch judna nahi hai")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
