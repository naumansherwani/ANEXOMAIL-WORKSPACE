#!/usr/bin/env python3
"""ANEXOMAIL — G38 attachments safai (roz ek baar). SQL E48 `mail_attach_gc()`:
  - 24 ghante se purani "staged" (bheji na gayi, schedule mein bhi nahi) uploads ke rows
  - jin blobs ko ab koi nahi dekhta (na staged, na bheji hui mail) aur 2 din guzar gaye — unke rows DB se, phir file disk se
  - `<org>/.tmp/` mein ek din se purani adhoori uploads
DB pehle, file baad mein — aur har generation ka path alag hai, is liye dobara-upload purani file se kabhi nahi takrata.
Storage Box mount na ho (ATTACH_DIR directory hi nahi) to DB ko haath nahi lagata (warna rows ud jate aur files bhatakti reh jati).
Secret print nahi hota.  `--selftest` = sirf local test."""
import json, os, re, sys, time, urllib.request

ROOT = (os.environ.get("ATTACH_DIR") or "/mnt/anexomail-box/attachments").rstrip("/")
REL_RE = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{2}/[0-9a-f]{64}-[0-9a-f]{8}$")
UUID_RE = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")


def load_env(path):
    env = {}
    try:
        for line in open(path):
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            env[k.strip()] = v.strip().strip('"').strip("'")
    except OSError:
        pass
    return env


def remove_blob(root, rel):
    """rel = DB ka rel_path. Sirf shakl theek ho aur realpath root ke andar ho to hatao. True = hataya, False = pehle se nahi tha / radd."""
    if not REL_RE.match(rel) or not rel.split("/")[2].startswith(rel.split("/")[1]):
        return None
    full = os.path.join(root, rel)
    real_root = os.path.realpath(root)
    if not os.path.realpath(full).startswith(real_root + os.sep):
        return None
    try:
        os.unlink(full)
        removed = True
    except FileNotFoundError:
        removed = False
    d = os.path.dirname(full)
    try:
        os.rmdir(d)  # khali ho to
        os.rmdir(os.path.dirname(d)) if not os.listdir(os.path.dirname(d)) else None
    except OSError:
        pass
    return removed


def clean_tmp(root, max_age_s=86400, now=None):
    now = now or time.time()
    n = 0
    try:
        orgs = os.listdir(root)
    except OSError:
        return 0
    for org in orgs:
        if not UUID_RE.match(org):
            continue
        tdir = os.path.join(root, org, ".tmp")
        try:
            names = os.listdir(tdir)
        except OSError:
            continue
        for name in names:
            p = os.path.join(tdir, name)
            try:
                if os.path.isfile(p) and now - os.path.getmtime(p) > max_age_s:
                    os.unlink(p)
                    n += 1
            except OSError:
                pass
    return n


def selftest():
    import tempfile
    root = tempfile.mkdtemp()
    org = "11111111-1111-1111-1111-111111111111"
    sha = "ab" * 32
    rel = f"{org}/ab/{sha}-0123abcd"
    os.makedirs(os.path.join(root, org, "ab"))
    open(os.path.join(root, rel), "w").write("x")
    assert remove_blob(root, rel) is True and not os.path.exists(os.path.join(root, rel))
    assert remove_blob(root, rel) is False  # dobara: pehle se gayab
    assert remove_blob(root, "../../etc/passwd") is None
    assert remove_blob(root, f"/{rel}") is None
    assert remove_blob(root, f"{org}/cd/{sha}-0123abcd") is None
    # symlink se bahar nikalna
    outside = tempfile.mkdtemp(); open(os.path.join(outside, f"{sha}-0123abcd"), "w").write("keep")
    os.makedirs(os.path.join(root, org), exist_ok=True)
    os.symlink(outside, os.path.join(root, org, "ab"))
    assert remove_blob(root, rel) is None and os.path.exists(os.path.join(outside, f"{sha}-0123abcd"))
    # tmp safai
    os.makedirs(os.path.join(root, org, ".tmp"), exist_ok=True)
    old = os.path.join(root, org, ".tmp", "old"); new = os.path.join(root, org, ".tmp", "new")
    open(old, "w").write("1"); open(new, "w").write("1")
    os.utime(old, (time.time() - 90000, time.time() - 90000))
    assert clean_tmp(root) == 1 and not os.path.exists(old) and os.path.exists(new)
    print("selftest ok")


def main():
    if "--selftest" in sys.argv:
        return selftest()
    mp = os.environ.get("ATTACH_MOUNT") or ("/mnt/anexomail-box" if not os.environ.get("ATTACH_DIR") else "none")
    if (mp != "none" and not os.path.ismount(mp)) or not os.path.isdir(ROOT):
        print(f"attach-gc: {ROOT} tayyar nahi (Storage Box mount {mp}?) — kuch nahi kiya"); sys.exit(3)
    env = {**load_env(os.environ.get("ENV_FILE", "/opt/anexomail-web/.env")), **os.environ}
    url = env.get("SUPABASE4_URL") or env.get("SUPABASE_URL") or ""
    key = env.get("SUPABASE4_SERVICE_ROLE_KEY") or env.get("SUPABASE_SERVICE_ROLE_KEY") or ""
    if not url or not key:
        print("attach-gc: Supabase env nahi mila"); sys.exit(2)
    req = urllib.request.Request(url.rstrip("/") + "/rest/v1/rpc/mail_attach_gc", data=b"{}", method="POST",
                                 headers={"apikey": key, "Authorization": "Bearer " + key, "Content-Type": "application/json"})
    try:
        out = json.load(urllib.request.urlopen(req, timeout=120))
    except Exception as e:
        print("attach-gc: RPC fail (SQL E48 chala hai?):", str(e)[:200]); sys.exit(1)
    if not isinstance(out, dict) or out.get("ok") is not True:
        print("attach-gc: RPC jawab galat:", str(out)[:200]); sys.exit(1)
    removed = skipped = 0
    for rel in out.get("paths") or []:
        r = remove_blob(ROOT, str(rel))
        if r is True: removed += 1
        else: skipped += 1
    tmp = clean_tmp(ROOT)
    print(f"attach-gc {time.strftime('%FT%TZ', time.gmtime())} staged_rows_removed={out.get('staged_removed', 0)} blob_rows_removed={len(out.get('paths') or [])} files_removed={removed} files_already_gone={skipped} tmp_removed={tmp}")


if __name__ == "__main__":
    main()
