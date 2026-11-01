# Awam side — mobile-number login + mandatory country at sign-up (founder, 1 Nov 2026 12:45)
Founder: "main awam side ke liye ab mobile number se login wala system bhi leke aa raha hoon. account create ke andar awam side apni country bhi likhe gi, yeh lazmi hai. yeh awam side pe repo main likh lena."
**Status: REQUIREMENT ONLY. No awam code is written here** (awam is its own phase; founder side never mixes with awam, Rule 35; awam stays on its current stack until a written order).

## Requirements as given
1. **Mobile-number login** for awam users (a second way to sign in besides email). The number is a verified identity, stored in E.164.
2. **Country is mandatory at account creation** (awam sign-up form). Required field, not skippable; stored as ISO 3166-1 alpha-2.

## Questions the founder must settle before any awam build (not guessed here)
- Login = SMS OTP only, or OTP + passkey/password? (Awam already has passkey-required-by-deadline for business accounts, see FINAL-FOUNDER-BLUEPRINT.)
- SMS provider (cost per country; Pakistan and Gulf routes) and whether the same provider serves the founder recovery (founder step 7-5).
- Existing users: forced to add country on next login? (needed for the mandatory rule to mean anything).
- Number uniqueness: one number per account? Recycled-number handling.
- Abuse: OTP rate limits per number/IP/country, SIM-swap signals (awam "who changed what" ledger entry on a number change).

## Where it will live when ordered
Awam sign-up/sign-in routes + SQL (E-series, E-file + CHECK) + awam Settings → Privacy row ("Sign in with mobile number"), with Explain / Blast radius / History like every awam setting. It must not reuse founder tables; if a shared OTP provider is chosen it is called from each side separately.
