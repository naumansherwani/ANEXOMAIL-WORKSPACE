# Server commands — Claude ke liye (founder ne 27 Oct 05:18 PKT par kaha: "yeh commands safe kar lo")

**Rule:** founder ko SIRF yahan ya `founder-commands.md` mein likhi hui commands do. Apni banai naye wrapper commands mat do (27 Oct ki galti: `deploy-pro.sh` / bare `sql-run.sh`). Har command ka prefix:
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/<SCRIPT>)`
Ab se `<S>` = yeh poora prefix with script `<S>`. Founder in commands ko bina badle chalata hai; unka output Claude ko deta hai.

## A) ASLI DEPLOY BLOCK (founder ki history se, kaam karta hai) — tarteeb badalna mana
0. SQL ho to PEHLE: `<sql-run.sh>` (bare = AUTO, nayi E-files number ki tarteeb, CHECK khud chalti hai; ya `... sql-run.sh E58_x CHECK_E58`)
1. Rust: `<rust-engine-install.sh> 2>&1 | tail -4`   (sab modules, idempotent, rollback line chhapta hai)
2. `pm2 restart anexomail-rust --update-env && pm2 save >/dev/null && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health`
3. Web: `<pull.sh> 2>&1 | tail -6`   (build + pm2 anexomail-web, "server==repo")
4. `sleep 20`
5. `<basic-gate-probe.sh> 2>&1 | grep -E "FAIL|ALL PASS"`  (Basic: har Pro proc 403)
6. `MODE=pro EMAIL=pro.buyer@anexomail.com bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/basic-gate-probe.sh) 2>&1 | grep -E "FAIL|ALL PASS"`
7. `<kernel-check.sh> 2>&1 | grep -E "FAIL|KERNEL|wasm jawab"`  (WASM kernel + QUIC saboot)
Sirf Rust badla: 1,2,4,5,6. Sirf Web: 3,4. Sirf SQL: 0. Brain (Bun) badla: brain-*-install.sh (neeche).
Aakhir mein browser Ctrl+Shift+R. Wapas lena: installer ki rollback line (`bash /root/rust-rollback-<ts>.sh`).

## B) Kab kaun si script (repo `docs/cursor-work/server/`)
**Deploy / sync:** `rust-engine-install.sh` (sab Rust modules; naya module = ALL_MODULES+CFG mein) · `pull.sh` (Web) · `sql-run.sh` (SQL) · `server-git-sync.sh` (server git dekhna; APPLY=1 se lagta hai) · `deploy-pro.sh` (sirf convenience; founder ke block se milta jaisa, tarjeeh block ko) · `rust-safe-deploy.sh`, `rust-crate-upgrade.sh`, `axum-*`, `rustc-edition-upgrade.sh`, `wtransport-upgrade.sh` (Rust upgrades, TECH-MAP 0a).
**Probes (gate/proof):** `basic-gate-probe.sh` (Basic 403 / `MODE=pro EMAIL=pro.buyer@...`) · `kernel-check.sh` · `wsx-live-test.sh` (workspace banana; nakli zz.wsx.* users, safai khud) · `tier-sweep.sh` (4 packages same calls) · `login-probe.sh` · `mig-live-test.sh` (import mail) · `imip-reply-proof.sh` · `caldav-check.sh`.
**READ-ONLY dekhna (kuch nahi badalte):** `buyer-accounts-look.sh` (*.buyer plan/kind) · `test-accounts-check.sh` · `attach-check.sh` + `attach-limit-measure.sh` (Postfix + clamd vs plan limits) · `file-safety-check.sh` (ClamAV EICAR) · `rls-open-check.sh` · `checks-all.sh` · `facts-tech-map.sh` · `repo-vs-server-audit.sh` · `brain-drift-check.sh` · `rust-procs-check.sh` · `calendar-status.sh` · `mailbox-facts.sh` · `org-authz-check.sh` · `crm-tenant-check.sh` · `workspace-api-check.sh` · `switch-journey-check.sh` · `jwt-life-probe.sh` · `calendar-invite-check.sh`.
**Brain (Bun :3100, pm2 anexomail-leo) fallback installs:** `brain-pro-install.sh` (Pro fallback) · `brain-kernel-install.sh` · `brain-mail-install.sh` · `brain-passkey-*.sh` · `brain-auth-harden-install.sh` · `brain-refresh-install.sh` · `brain-identity-install.sh` · `brain-org-install.sh` · `brain-crm-install.sh` · `brain-people-import-install.sh` · `brain-portal-install.sh` · `brain-attach-install.sh` · `brain-integrity-install.sh` · `brain-pricefix-install.sh`. Sirf tab jab Bun file badli ho.
**Rust purane per-feature installers (ab zaroorat nahi, rust-engine-install.sh kafi):** rust-auth-harden, rust-calendar, rust-deliver, rust-events, rust-inbound-attach, rust-jwt, rust-mail, rust-passkey.
**Accounts / repair (founder ki "haan" par):** `fix-buyer-kind.sh` (4 *.buyer kind business) · `bizpro-login-fix.sh` · `t7-send-identity-test.sh` · `t16-accounts-look.sh` · `device-hash-migrate.sh` · `e18-deploy-specific.sh` / `e18-restore.sh`.
**Infra (SIRF founder "haan" ke baad; Polar :3400 NO-TOUCH):** `clamd-tcp-fix.sh` · `attach-caddy-close-files.sh` · `caddy-*.sh` · `ops-ufw-passkey.sh` · `cron-root-mail-fix.sh` · `polar-*.sh` (control-plane, nonroot, secrets, product-ids) · `repo-capture-server.sh`.
**Claude ke apne (sandbox, founder nahi chalata):** `installer-dryrun.sh "<modules>"` (proc clash) · `count-endpoints.py` + `docs/claude/endpoint-package-map.py` (registry) · `manifest-sync.py <files>` / `manifest-verify.py` · `sql-editor-lint.py <sql>` · `cargo check --offline` in /tmp/axchk (patch main.rs with ALL_MODULES, tab `MODS=$(grep -m1 '^ALL_MODULES=' ... | sed 's/^ALL_MODULES="//;s/".*$//')`).

## C) Aaj ka asli haal (27 Oct 05:18 PKT)
SQL E93+E94 server par GREEN; clamd 64M; Pro 7 Rust endpoints (workx) repo mein, server par deploy BAAQI = block A (1,2,4,5,6,7) + `attach-limit-measure.sh`.
