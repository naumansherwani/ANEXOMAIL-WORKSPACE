# ADMIN DESK: ONLY TWO SERVER COMMANDS (his 21 Nov 2026 21:41, written 21 Nov 2026 21:42 PKT)
His word: "aaj ke baad sirf ek install ki command hogi jis mein sab kuch hoga, jaise founder ki install command thi, aur ek SQL ki command hogi, is ke ilawa koi command nahi hogi."
1. INSTALL (everything: build all Rust files, page, service, own database login desk_app + Supabase CA pin, checks):
   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:admin-desk/scripts/desk-install.sh) 2>&1 | tail -15
2. SQL (runs every AD file not yet in the database, says "already run" for the rest, then its CHECK):
   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:admin-desk/scripts/ad-auto.sh) 2>&1 | tail -25
Every new Desk server step goes INSIDE one of these two scripts, never as a third command.
