<!--TECHLAW-->
# THE REPO IS PUBLIC: HOW CODE THEFT IS STOPPED (founder 11 Nov 2026 17:27)
FACT (GitHub API, 11 Nov 17:40): naumansherwani/ANEXOMAIL-WORKSPACE is `visibility: public`. Anyone can read and copy all code, including the founder lane. Scan done: NO private key, API key, JWT, or token in the current tree and none in git history for private keys (crude scan; a full history scan with gitleaks is step 4 below).
## THE FIX, in this order (the repo must stay pullable by his server: /opt/anexomail-web pulls with plain https today, so private + deploy key must happen together, never private alone)
1. HIS HANDS, step A: on his server create a READ-ONLY deploy key (ssh-keygen ed25519, no passphrase, file /root/.ssh/anexo_deploy). I give the exact one-line commands at that time.
2. HIS HANDS, step B: GitHub repo Settings > Deploy keys > add the public key (read-only). Then I change the server remote to the ssh url (one line). Test: git fetch works.
3. ONLY THEN: GitHub Settings > General > Danger zone > Change visibility > Private. (If done before 1-2 his pull commands break.)
4. Turn on GitHub secret scanning + push protection; run a full-history secret scan (gitleaks) and ROTATE anything found.
5. LICENSE = proprietary, all rights reserved (added now): copying is then also illegal, not only difficult.
6. Founder lane secrets never belong in git: keys live in /etc/anexomail (already so: token key, sign key, vapid key, vault master).
7. Keep `lovable-gold/` (frozen Lovable copy, also public today) out of any public mirror once private.
STATUS: steps 1-4 OPEN (need his hands for 1-3). Step 5 done in this commit.
