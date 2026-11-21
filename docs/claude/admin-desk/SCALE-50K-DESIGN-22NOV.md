# ADMIN DESK AT 50,000 EMPLOYEES: LIFETIME DESIGN (his 22 Nov 2026 01:05 PKT)
Goal: Desk serves awam problems; today 1 owner, tomorrow 50,000 staff, no redesign ever. Everything built IN-HOUSE (vendor ban): Rust + Postgres only. Desk stays its own security domain (isolation law).

## Research findings (sources at bottom)
- Google Zanzibar: one central authorization service, tuples "object#relation@user", millions qps, p95 < 10 ms, 99.999%+; consistency tokens ("zookies") so a permission change is never seen out of order.
- Multi-tenant Postgres: shared tables + tenant key is the one that scales; schema-per-tenant and DB-per-tenant break near a few hundred tenants (catalog bloat, connection limits). RLS alone is not trusted: app must also filter; partition big tables.
- Uber support chat: stateless routers, queue + skill + priority + SLA routing, ack-driven reservation (no ack = reassign), end-to-end contact lifecycle tracking; delivery reliability mattered most (46% -> 0.45% failed events).

## Design (each row = a sub-phase, advance technology, in-house)
| Sub | Feature | Technology | Needs his haan |
|---|---|---|---|
| S1 | Org model: org > department > team > queue; 50k staff rows, never per-person grants | Postgres `fadm_org`, `fadm_team`, `fadm_member`, partitioned by hash(team) | yes (before SQL) |
| S2 | Authorization = Zanzibar-style relation tuples (`fadm_rel`: object, relation, subject), roles are relations (agent, lead, supervisor, admin), check() in Rust with cache; every check signed in ledger decisions | Rust axum + Postgres, tuple store, consistency token per write | yes |
| S3 | Least privilege + just-in-time: elevated access expires (minutes), needs a second person's approval; break-glass = loud, ledgered, auto-review | Postgres + hash-chained ledger | yes |
| S4 | Onboarding at scale: own SCIM 2.0 endpoint (bulk import/offboard 1,000s at once), one-click offboard kills sessions + keys instantly | Rust, SCIM RFC 7643/7644 | yes |
| S5 | Staff sign-in: passkeys only (WebAuthn), device-bound sessions (DBSC), no shared logins, per-staff Rule 52 key | webauthn-rs, DBSC, Ed25519 | yes |
| S6 | Case routing: queue + skill + priority + SLA clock; ack-driven reservation (no ack in N s = next agent); sticky to previous agent; supervisor overflow | Rust routers (stateless, horizontal), Postgres `FOR UPDATE SKIP LOCKED` queue | yes |
| S7 | Live fan-out of cases/status to thousands of agents: WebTransport/QUIC streams per team, SSE fallback, no WebSocket | Rust wtransport/quinn, HTTP/3 | yes |
| S8 | Data scale: tenant key everywhere + RLS (belt and braces), monthly partitions for cases/messages/ledger, pgbouncer-style pool in Rust, read replicas for dashboards, cold archive to Hetzner Storage Box | Postgres partitioning, Hetzner | yes |
| S9 | Tamper-proof audit: SHA-256 hash chain + daily Merkle root anchored; every staff action, every awam-data view logged; supervisors see who looked at what | Postgres ledger, Rust | yes |
| S10 | Capacity + proof: load test 50,000 staff / 5,000 concurrent / 100 cases per second in my sandbox, published numbers; p95 targets (auth check < 10 ms, case assign < 200 ms) | Rust load tool, k6-free | yes |
| S11 | Scale-out ladder (no rewrite): 1 server now; split read replicas; then Desk shards by team hash; Desk binary stateless behind Caddy | Hetzner, Caddy | later |

## Order
This design is the LANDING TARGET. Build order unchanged: R3d (Rule 52) > dashboard shell + bridge (real data) > inboxes > S1..S10 in number order, S1+S2 before the inboxes are shared with a second person. Nothing is built until his haan per row.
## Sources
- Zanzibar paper page: https://research.google/pubs/zanzibar-googles-consistent-global-authorization-system/
- Uber support chat: https://www.uber.com/blog/building-scalable-real-time-chat/
- Postgres tenancy: https://planetscale.com/blog/approaches-to-tenancy-in-postgres
