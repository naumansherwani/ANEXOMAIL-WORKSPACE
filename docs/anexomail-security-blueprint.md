# ANEXOMAIL — SERVER-SIDE SECURITY BLUEPRINT v1
# FOUNDER ORIGINAL — DO NOT MODIFY

> Save kiya: Sep 9 2026. Founder original. **Ek dot bhi implement nahi hua.**
> Koi code nahi. Sirf save. Implementation tab jab founder phase S1 bole.

---

## Core rule

Backup → Inspect → Add → Test → Verify → Enforce.

Existing working services, Caddy routes, application code aur ports ko bina inspection ke change nahi karna.

---

## 1. Security Foundation

### Server

- UFW/nftables firewall
- only required public ports
- SSH restricted
- unnecessary services disabled
- automatic security updates where safe

### SSH

- key authentication
- password login disabled only after confirming key access
- root login policy verified before changing
- brute-force protection
- separate emergency access path

---

## 2. Caddy Security Layer

Caddy becomes the first application-facing security gate:

```
Internet
   ↓
Caddy
   ├── TLS
   ├── HTTPS enforcement
   ├── Security headers
   ├── Request-size limits
   ├── Basic abuse/rate controls
   └── Reverse proxy
          ↓
      ANEXOMAIL
```

Headers should include appropriate protections such as:

- HSTS
- X-Content-Type-Options
- X-Frame-Options / CSP strategy
- Referrer policy
- restrictive permissions policy

**Important:** don't blindly deploy a CSP until we inspect the frontend's actual assets/API requirements.

---

## 3. Application/API Security

Every sensitive API gets:

```
Request
 ↓
Authentication
 ↓
Authorization
 ↓
Input validation
 ↓
Rate limit / abuse control
 ↓
Business logic
 ↓
Audit event
```

Protect especially:

- login
- password/reset
- email APIs
- file uploads
- video-call endpoints
- TURN credential endpoint
- admin/founder endpoints
- billing/payment endpoints
- internal service APIs

---

## 4. Video / TURN Security

For the VideoCall system:

- ephemeral TURN credentials
- short credential lifetime
- authenticated TURN access
- per-user/session limits
- connection abuse detection
- bandwidth limits
- no permanent TURN credentials in frontend
- TURN service isolated from unrelated application services

---

## 5. Database Security

```
Internet
   X
   ↓
Application
   ↓
Private DB
```

- DB not publicly exposed unless genuinely required
- least-privilege DB users
- separate application credentials
- restricted database permissions
- encrypted connections where applicable
- backup verification
- audit sensitive operations

---

## 6. Service Isolation

Each major service should have the minimum permissions it needs.

```
Caddy
  ↓
Web/API service
  ↓
Database
TURN ──────── separate service boundary
Mail ──────── separate service boundary
Workers ───── separate service boundary
```

A compromise of one service should not automatically mean control of the whole server.

---

## 7. Secrets

Secrets never belong in:

- frontend JavaScript
- Git
- public config
- browser responses
- logs
- error pages

Protect:

- `.env`
- private keys
- TURN secrets
- database credentials
- API tokens
- JWT/signing secrets
- mail credentials

with filesystem permissions and controlled service access.

---

## 8. Detection + Audit

Create one central security event stream:

- AUTH_FAILURE
- AUTH_SUCCESS
- RATE_LIMIT
- SUSPICIOUS_REQUEST
- FILE_ABUSE
- TURN_ABUSE
- ADMIN_ACTION
- PERMISSION_FAILURE
- SERVICE_FAILURE
- CONFIG_CHANGE

Then:

```
Event
 ↓
Security Log
 ↓
Detection
 ↓
Alert
 ↓
Founder/Admin review
```

---

## 9. Integrity Protection

Critical files/configuration get baseline hashes:

- Caddy config
- systemd units
- security configuration
- critical application configs
- security scripts

Then periodically:

```
Current hash
     ↓
Compare baseline
     ↓
UNCHANGED → OK
CHANGED   → SECURITY EVENT
```

---

## 10. Recovery — सबसे important

Security changes kabhi bhi system ko lockout nahi karne chahiye.

Before enforcement:

```
BACKUP
  ↓
CONFIG SNAPSHOT
  ↓
TEST
  ↓
DEPLOY
  ↓
HEALTH CHECK
  ↓
ROLLBACK AVAILABLE
```

If something breaks:

```
Security change
     ↓
Health check FAIL
     ↓
Automatic/manual rollback
     ↓
Previous known-good state
```

---

## Final Architecture

```
                    INTERNET
                       │
                       ▼
                 ┌───────────┐
                 │  CADDY    │
                 │ TLS/WAF-  │
                 │ style     │
                 │ controls  │
                 └─────┬─────┘
                       │
              ┌────────▼────────┐
              │  API SECURITY   │
              │ Auth/AuthZ      │
              │ Validation      │
              │ Rate Control    │
              └────────┬────────┘
                       │
        ┌──────────────┼──────────────┐
        ▼              ▼              ▼
     ANEXOMAIL       VIDEO          ADMIN
        │             │              │
        │             ▼              │
        │           TURN             │
        │             │              │
        └─────────────┼──────────────┘
                      ▼
                 PRIVATE DATA
                      │
              ┌───────┴───────┐
              ▼               ▼
           DATABASE         STORAGE
              │
              ▼
       BACKUP / RECOVERY
     ─────────────────────────────
        SECURITY MONITORING
        AUDIT + INTEGRITY
        DETECTION + ALERTING
     ─────────────────────────────
```

---

## Implementation order

| Phase | Name | Status |
|---|---|---|
| S1 | Backup & inspection | TODO |
| S2 | Firewall/SSH hardening | TODO |
| S3 | Caddy security headers + limits | TODO |
| S4 | API authentication/rate controls | TODO |
| S5 | TURN/video security | TODO |
| S6 | DB/service isolation | TODO |
| S7 | Secrets protection | TODO |
| S8 | Audit + detection | TODO |
| S9 | Integrity monitoring | TODO |
| S10 | Recovery/rollback verification | TODO |

**Yeh blueprint ka ek dot bhi nahi bana.** Implementation sirf founder ke "S1 shuru karo" pe.
