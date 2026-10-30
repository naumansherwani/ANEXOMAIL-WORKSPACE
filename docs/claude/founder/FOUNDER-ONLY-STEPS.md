# FOUNDER-ONLY STEPS — jo sirf Nauman bhai kar sakte hain (Claude kabhi password nahi dalta). Yeh file ek jagah hai, har jawab mein dohrayi nahi jaati.

## L5 — host guard enforce (awam host par founder login band) — 3 qadam
Halat 30 Oct 2026 20:20: mode = `probe`, log khali (founder host par abhi koi naya login nahi hua; maujooda session purana hai).
1. Founder Command Center mein NS menu -> **Sign out**. Phir `https://founderworkspace.anexomail.com/founderlogin` par email + password se ek baar login.
2. Server par: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-hostguard.sh) status 2>&1 | tail -14` -> log mein `founder_host=true` dikhna chahiye.
3. Wohi command, `status` ki jagah `enforce`. Test: `anexomail.com/auth` par founder email = "founder portal" wala 403; founderworkspace par login chalta rahe. (Script khud inkaar karta hai agar `founder_host=true` ka saboot na ho: lock-out se bachao.)
Jab ye ho jaye: `status` ka output Claude ko paste -> L5 green likha jayega aur yeh section band.
