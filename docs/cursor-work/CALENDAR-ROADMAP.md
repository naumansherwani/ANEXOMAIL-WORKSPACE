# CALENDAR ROADMAP (G26/G27) — EK jagah, sach tarteeb. Founder spec 22 Oct 2026. Update: 22 Oct 07:20 PKT
Rule: "GREEN" = founder ka server output + live check. Is file ko har calendar step ke baad update karo (founder-commands/ledger se yahan ka hawala).

| # | Kaam | Haal |
|---|---|---|
| 0 | Layout v2 (Classic+Expanded, shehar-naam clock, 12h/24h/Auto, account sync E57) | GREEN |
| 1 | Working hours, out-of-office, alag calendars + rang, reminders (E58 SQL+Rust+web) | GREEN. Baaki polish: mail reminders ko server timer chahiye |
| 2 | Booking page B7c (E59 lock, rate limit, mails + .ics, cancel/reschedule) | GREEN (live verify 22 Oct) |
| 3 | iMIP reply G26 (E60 SQL, imip_core.rs, deliver hook, rsvp_via label) | SERVER-INSTALLED. Bug mila+fix push (fc51c04: attendee order=created_at live par nahi). Rust `cal` reinstall DONE (founder output 07:19), guest list live-verified (guest Waiting + organiser Yes). Invite pehli baar Gmail SPAM mein gaya (Not-spam kiya), Gmail ne event card tab 'Unable to load' dikhaya; dobara bhejne par card load hua lekin Gmail ka apna Yes/No/Maybe bar NAHI dikha (sirf mail ke andar link-buttons Yes/Maybe/No). Gmail-click se inbound iMIP abhi sabit NAHI. GREEN nahi |
| 4 | Timezone world-clock pins (kai zones), team overlay (sirf free/busy), ICS subscribe (external) | Shuru nahi. Sirf shehar-naam clock (#0) bana |
| 5 | Event par files (mail attach pipeline reuse, naya storage nahi) | Shuru nahi |
| 6 | CalDAV (B7d) — PROPFIND/REPORT, ctag/etag, tz, recurring exceptions, app password (27 Oct se passkey), Caddy .well-known surgical | Shuru nahi |
| 7 | Google Calendar sync (OAuth, watch+sync token, loop-guard) | Shuru nahi. FOUNDER: Google Cloud verification application abhi shuru kare |
| 8 | Rooms / resources (pseudo-attendee, wohi conflict engine) | Shuru nahi |

## Spec ke faislay (founder ko jawab, line by line)
- Google sync/CalDAV: practical. Webhook sirf "kuch badla" bolta hai, data sync token se; watch channel renew; do-taraf loop guard; "instant" = kuch seconds. Google verification asli rukawat (bina uske warning + 100 users). Android mein CalDAV built-in nahi (DAVx5). "Zero-copy", "Tokio main thread" = dawa nahi.
- Booking: practical. DB lock, rate limit, mail+.ics+link. WASM nahi (LCP kharab); LCP target 1.8 s naap kar.
- iMIP: sender == attendee + SPF/DKIM zaroori. Collision warning RSVP ke waqt (BAAKI). "Ledger prompt" = seedha conflict chip.
- Event elements: files practical (attach pipeline); alag calendars+rang practical; team overlay sirf free/busy; external = ICS subscribe (bina ijazat nahi); "hardware-accelerated" = smooth CSS, INP 150 ms naap kar; world-clock pins chhota kaam; rooms akhir mein.
