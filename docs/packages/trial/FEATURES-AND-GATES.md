# Trial — kya milta hai, gate kya (CEO faisla)
Plan id `trial` (resolve_plan, ek hi code path; server gate asli, UI aaina — Rule 57). Sab server-side.

| Cheez | Trial mein | Gate / hadd |
|---|---|---|
| Address | 1 asli `handle@anexomail.com` (claim mojooda) | 1 per insaan, reserved list, 30 din reserve baad mein |
| Mail | asli send/receive, folders, search, snooze/schedule (Pro jhalak) | bahar bhejna rozana hadd (CEO: 25/din), attachment 10MB |
| Calendar + booking | asli calendar, 1 booking link | Basic/Pro jaisi, 1 link |
| People/Companies | asli (khud ke contacts) | koi sample contacts nahi |
| CRM jhalak | accounts/leads/pipeline ka **khali asli board** | max 25 records (Pro ka jhalak, full nahi) |
| **ANEXOChat (basic)** | **1:1 + chhote groups (max 5 log), text, photo/doc (10MB), reply/forward/star, message->Task/Promise** | **Voice/video calls, relay calls, voice notes, pop-out, group calls = BAND** (Business+ ki cheez, "Upgrade" nishan) |
| Storage | 1 GB | hard cap, trial org ke andar hi |
| AI | **ZERO** (mojooda lock) | — |
| Custom domain, integrations, SSO | nahi | Pro+ |
| Security | passkey/devices dekhna, ek insaan = ek trial (device vault) | signup holds (trialx LIVE) |

## ANEXOChat trial mein kyun (CEO)
ANEXOChat hamara farq hai (email + chat + kaam ek jagah: message -> Task/Promise). Chat ke bina trial user sirf "ek aur email" dekhta hai. Isliye basic chat **(calls ke bina)**: seedha, sasta (storage/bandwidth chhota), aur abuse kam (calls SFU/TURN kharcha bhi nahi). Calls trial ko "Upgrade" ka wazeh sabab bante hain.
**Chat kis se:** trial workspace ke andar. User 2 guests tak invite kar sakta hai (woh bhi 48h trial pate hain — viral loop); trial chat kabhi real company ke chat se mix nahi.
**SQL zaroori:** `chat_ensure_workspace` ab plan trial par `chat_not_entitled` nahi dega, lekin `chat_caps` mein calls=false (SQL, BUILD-PLAN step 2).
## Pro-only jhalak ka nishan
Har Pro/Business feature par chhota "Pro" ya "Business" chip + "See plans" — fakta nishan, kuch fake nahi dikhana.
