import sys, re
p = sys.argv[1]
base = sys.argv[2]
s = open(p).read()
h = open(base + "/helpers.rs").read()
a = open(base + "/arms.rs").read()
assert "mail.domains.list" not in s, "already_applied"
A1 = "        // mail.send — Bun pe delegate."
A2 = "async fn file_ping() -> impl IntoResponse {"
assert s.count(A1) == 1, ("anchor1", s.count(A1))
assert s.count(A2) == 1, ("anchor2", s.count(A2))
s = s.replace(A1, a + A1)
s = s.replace(A2, h + A2)
open(p, "w").write(s)
print("PATCH_OK")
