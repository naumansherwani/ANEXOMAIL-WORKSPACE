//! KP1b: founder-dns, the founder's OWN authoritative DNS for ONE zone. Rust + tokio. Authoritative only: no recursion, never an open resolver.
//! Why it exists: his registrar (Namecheap) has no HTTPS record type (his screenshot 13 Nov 22:03) and he does business with no third-party vendor (docs/claude/FOUNDER-VENDOR-BAN-13NOV.md).
//! The HTTPS RR (RFC 9460, `1 . alpn="h3"`) is what lets a browser reach an HTTP/3-only site on its very first visit.
pub mod zone;
pub mod auth;
pub mod rrl;
pub mod net;
