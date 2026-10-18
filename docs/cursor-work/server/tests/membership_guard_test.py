import os, subprocess, sys, tempfile, unittest
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import membership_guard as g

REAL = os.path.join(os.path.dirname(__file__), "../../../../server/rust/main.rs")


class Guard(unittest.TestCase):
    def test_real_main_rs(self):
        src = open(REAL).read()
        out, new, already, skipped, other = g.patch(src)
        self.assertEqual((skipped, other), ([], []))
        self.assertEqual(new, 2)          # mail_identity + the role lookup
        self.assertIn('"org_members?select=org_id&user_id=eq.{id}&or=(status.is.null,status.neq.revoked)"', out)
        self.assertIn('"org_members?select=role&org_id=eq.{org}&user_id=eq.{user}&or=(status.is.null,status.neq.revoked)"', out)
        # nothing else changed: removing the guard text gives the original back
        self.assertEqual(out.replace(g.GUARD, ""), src)

    def test_idempotent(self):
        src = open(REAL).read()
        once = g.patch(src)[0]
        out, new, already, skipped, other = g.patch(once)
        self.assertEqual((new, already, out), (0, 2, once))

    def test_only_user_keyed_reads(self):
        src = 'a("org_members?select=email&org_id=eq.{}"); b("org_members?org_id=eq.{}&user_id=eq.{}"); c("org_members?select=role&user_id=eq.{u}")'
        out, new, *_ = g.patch(src)
        self.assertEqual(new, 1)
        self.assertIn('"org_members?select=email&org_id=eq.{}"', out)           # org-keyed list: untouched
        self.assertIn('"org_members?org_id=eq.{}&user_id=eq.{}"', out)           # PATCH/DELETE path: untouched
        self.assertIn('select=role&user_id=eq.{u}&or=(status.is.null,status.neq.revoked)', out)

    def test_refuses_what_it_cannot_do_safely(self):
        src = 'x("org_members?select=org_id&user_id=eq.{id}&or=(a.eq.1,b.eq.2)")'
        self.assertEqual(len(g.patch(src)[3]), 1)
        built = 'let q = format!("org_members?select=org_id,{}&user_id=", cols) + &id;'
        self.assertEqual(len(g.patch(built)[4]), 1)

    def test_cli_exit_codes_and_no_write_on_refusal(self):
        with tempfile.NamedTemporaryFile("w", suffix=".rs", delete=False) as f:
            f.write('x("org_members?select=org_id&user_id=eq.{id}&or=(a,b)"); y("org_members?select=r&user_id=eq.{u}")')
            p = f.name
        before = open(p).read()
        r = subprocess.run([sys.executable, os.path.join(os.path.dirname(__file__), "../membership_guard.py"), p], capture_output=True, text=True)
        self.assertEqual(r.returncode, 4)
        self.assertEqual(open(p).read(), before)       # refusal writes nothing, not even the safe one
        os.unlink(p)


if __name__ == "__main__":
    unittest.main()
