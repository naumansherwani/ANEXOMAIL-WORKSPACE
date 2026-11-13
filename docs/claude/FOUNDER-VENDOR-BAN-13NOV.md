
# FOUNDER LAW: CLOUDFLARE IS BANNED. FOREVER. (founder Nauman Sherwani, 13 Nov 2026 21:54 PKT, in anger)

**THE FOUNDER HATES CLOUDFLARE. NO CLOUDFLARE ANYWHERE: NOT AS DNS, NOT AS CDN, NOT AS PROXY, NOT AS TUNNEL, NOT AS WAF, NOT AS A SUGGESTION, NOT AS AN OPTION IN A LIST.**

## What this means for Claude (every session, every compaction)
1. NEVER write the vendor's name in a reply to the founder, not even to say "no". Say "the banned vendor" if a reference is unavoidable, or offer other options only.
2. NEVER offer it as a choice (the 13 Nov 21:48 reply did, and made him angry). Options Claude lists must be vendor-free: his own Rust server, his own Caddy, his registrar (Namecheap), Hetzner.
3. This file is the ONLY place the name may stand. The rules-gate ("VENDOR BAN") refuses any commit whose added lines name the vendor anywhere else (this file and the gate itself are exempt).
4. Old mentions that already stood in the repo before this law (frozen lovable-gold, awam domains UI, a Caddy geoblock helper, old docs) are NOT touched by this law; no NEW mention may be added.

## What to do instead (the DNS HTTPS record problem, KP1)
Namecheap BasicDNS shows no HTTPS record type in its docs (his screen decides). Vendor-free answers, in the order Claude investigates them, each starting with a read-only command on HIS server first (SERVER-FIRST law):
- A. His Namecheap panel may already offer type HTTPS (to be seen on his screen).
- B. His own authoritative DNS in Rust (hickory-dns style, tokio, on his Hetzner server) for ONE subdomain only (`founderworkspace`), delegated from Namecheap with NS records; mail records stay at Namecheap untouched. Needs UDP+TCP 53 free on his server (port red line: read-only `ss` first).
- C. Another registrar-independent authoritative DNS host that is NOT the banned vendor, only if he names it.
Caddy cannot publish DNS records; it stays on 18443/80 and is not part of this answer.

## WIDENED 13 Nov 2026 21:59 (his word): NO BUSINESS WITH ANY THIRD-PARTY VENDOR, LIFETIME
Allowed only: **Caddy** (his web server), **Namecheap** (his registrar, he does the steps by hand), **Hetzner** (his server and Storage Box), and his own Rust code. Any other company is a vendor: Claude does not suggest it, does not put it in an option list, does not add it to code. Claude gives steps for HIS Namecheap panel and HIS server (Caddy where Caddy is the right tool), and he does them. When he names a vendor, Claude adds its lowercase name to `docs/claude/VENDOR-BAN-LIST.json` ("banned"); the VENDOR BAN gate reads that file and refuses any added line naming it.
