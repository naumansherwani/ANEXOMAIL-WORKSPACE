// ============================================================================
// mig_core.rs — the pure (std-only) heart of "move my old mailbox into ANEXOMAIL" (G30).
//
// Everything here can be unit-tested with plain `rustc --test` (no crates, no network). The I/O half is mig_glue.rs.
//
//   sha256 / evidence chain   per-email SHA-256 + an append-only hash chain (same canonical string as SQL E35)
//   uid ranges                "1:500,502:900" <-> list of UIDs (resume without re-copying)
//   providers                 Gmail / Outlook.com / Yahoo / iCloud / Zoho presets + custom host rules
//   host guard                a customer-supplied host can never reach our own network (SSRF): syntax + public-IP check
//   folder policy             which IMAP folder becomes which ANEXOMAIL folder; virtual duplicates (Gmail "All Mail") are skipped
//   backoff / error classes   throttling is RESPECTED (wait and retry), never bypassed
//   password handling         app passwords are normalised and live only in memory (never logged, never stored)
//
// Sub-modules (separate files, same crate directory — the installer copies them together):
//   mime  = mig_mime.rs   RFC 5322 / MIME reader (headers, RFC 2047, bodies, attachments' names)
//   imap  = mig_imap.rs   IMAP4rev1 client over any Read + Write (TLS is supplied by the glue)
//   run   = mig_run.rs    the copy loop (Source / Sink traits, chunking, retry, resume)
// ============================================================================

#[path = "mig_imap.rs"]
pub mod imap;
#[path = "mig_mime.rs"]
pub mod mime;
#[path = "mig_run.rs"]
pub mod run;

use std::net::IpAddr;

/* ------------------------------------------------------------------ SHA-256 */

const K: [u32; 64] = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
];

/// Streaming SHA-256: feed the message as it arrives, never hold two copies.
#[derive(Clone)]
pub struct Sha256 {
    h: [u32; 8],
    buf: [u8; 64],
    len: usize,
    total: u64,
}

impl Default for Sha256 {
    fn default() -> Self {
        Self::new()
    }
}

impl Sha256 {
    pub fn new() -> Self {
        Sha256 {
            h: [
                0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
            ],
            buf: [0; 64],
            len: 0,
            total: 0,
        }
    }

    fn block(h: &mut [u32; 8], b: &[u8]) {
        let mut w = [0u32; 64];
        for i in 0..16 {
            w[i] = u32::from_be_bytes([b[4 * i], b[4 * i + 1], b[4 * i + 2], b[4 * i + 3]]);
        }
        for i in 16..64 {
            let s0 = w[i - 15].rotate_right(7) ^ w[i - 15].rotate_right(18) ^ (w[i - 15] >> 3);
            let s1 = w[i - 2].rotate_right(17) ^ w[i - 2].rotate_right(19) ^ (w[i - 2] >> 10);
            w[i] = w[i - 16]
                .wrapping_add(s0)
                .wrapping_add(w[i - 7])
                .wrapping_add(s1);
        }
        let [mut a, mut bb, mut c, mut d, mut e, mut f, mut g, mut hh] = *h;
        for i in 0..64 {
            let s1 = e.rotate_right(6) ^ e.rotate_right(11) ^ e.rotate_right(25);
            let ch = (e & f) ^ ((!e) & g);
            let t1 = hh
                .wrapping_add(s1)
                .wrapping_add(ch)
                .wrapping_add(K[i])
                .wrapping_add(w[i]);
            let s0 = a.rotate_right(2) ^ a.rotate_right(13) ^ a.rotate_right(22);
            let maj = (a & bb) ^ (a & c) ^ (bb & c);
            let t2 = s0.wrapping_add(maj);
            hh = g;
            g = f;
            f = e;
            e = d.wrapping_add(t1);
            d = c;
            c = bb;
            bb = a;
            a = t1.wrapping_add(t2);
        }
        for (x, y) in h.iter_mut().zip([a, bb, c, d, e, f, g, hh]) {
            *x = x.wrapping_add(y);
        }
    }

    pub fn update(&mut self, mut data: &[u8]) {
        self.total = self.total.wrapping_add(data.len() as u64);
        if self.len > 0 {
            let take = (64 - self.len).min(data.len());
            self.buf[self.len..self.len + take].copy_from_slice(&data[..take]);
            self.len += take;
            data = &data[take..];
            if self.len == 64 {
                let b = self.buf;
                Self::block(&mut self.h, &b);
                self.len = 0;
            }
        }
        while data.len() >= 64 {
            Self::block(&mut self.h, &data[..64]);
            data = &data[64..];
        }
        if !data.is_empty() {
            self.buf[..data.len()].copy_from_slice(data);
            self.len = data.len();
        }
    }

    pub fn finish(mut self) -> [u8; 32] {
        let bits = self.total.wrapping_mul(8);
        let mut pad = vec![0x80u8];
        let rem = (self.len + 1) % 64;
        let zeros = if rem <= 56 { 56 - rem } else { 120 - rem };
        pad.extend(std::iter::repeat(0u8).take(zeros));
        pad.extend_from_slice(&bits.to_be_bytes());
        let keep = self.total;
        self.update(&pad);
        self.total = keep;
        let mut out = [0u8; 32];
        for (i, v) in self.h.iter().enumerate() {
            out[4 * i..4 * i + 4].copy_from_slice(&v.to_be_bytes());
        }
        out
    }
}

pub fn to_hex(b: &[u8]) -> String {
    const D: &[u8; 16] = b"0123456789abcdef";
    let mut s = String::with_capacity(b.len() * 2);
    for x in b {
        s.push(D[(x >> 4) as usize] as char);
        s.push(D[(x & 15) as usize] as char);
    }
    s
}

pub fn sha256_hex(data: &[u8]) -> String {
    let mut h = Sha256::new();
    h.update(data);
    to_hex(&h.finish())
}

pub fn is_hex64(s: &str) -> bool {
    s.len() == 64 && s.bytes().all(|c| c.is_ascii_digit() || (b'a'..=b'f').contains(&c))
}

/* ------------------------------------------------------------------ evidence chain
   One entry per e-mail the worker looked at, whatever happened to it. The DATABASE computes and stores the chain
   (E35 migration_ingest); this is the independent re-computation used by `migration.verify` and by the tests, so two
   implementations in two languages must agree byte for byte. Canonical text (all fields ASCII-safe):

     ANX-MIG-1|<prev>|<seq>|<outcome>|<folder hex>|<uidvalidity>|<uid>|<raw sha256>|<body sha256>|<message row id>|<ts>
     seal:  ANX-MIG-1|<prev>|<seq>|seal|<copied>|<duplicate>|<skipped>|<failed>|<ts>
     genesis (prev of seq 1) = sha256("ANX-MIG-GENESIS|<session id>|<mailbox hex>")                                     */

pub const ZERO_ID: &str = "00000000-0000-0000-0000-000000000000";

pub fn hex_of_text(s: &str) -> String {
    to_hex(s.as_bytes())
}

pub fn genesis(session_id: &str, mailbox: &str) -> String {
    sha256_hex(format!("ANX-MIG-GENESIS|{}|{}", session_id, hex_of_text(&mailbox.to_lowercase())).as_bytes())
}

#[derive(Debug, Clone, PartialEq)]
pub struct ChainRow {
    pub seq: i64,
    pub outcome: String, // copied | duplicate | too_large | failed | seal
    pub folder: String,
    pub uidvalidity: i64,
    pub uid: i64,
    pub raw_sha256: String,
    pub body_sha256: String,
    pub row_id: String, // mail_messages.id (ZERO_ID when nothing was written)
    pub ts: i64,
    // seal only
    pub copied: i64,
    pub duplicate: i64,
    pub skipped: i64,
    pub failed: i64,
    pub prev_hash: String,
    pub entry_hash: String,
}

pub fn canonical(r: &ChainRow, prev: &str) -> String {
    if r.outcome == "seal" {
        format!(
            "ANX-MIG-1|{}|{}|seal|{}|{}|{}|{}|{}",
            prev, r.seq, r.copied, r.duplicate, r.skipped, r.failed, r.ts
        )
    } else {
        format!(
            "ANX-MIG-1|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}",
            prev,
            r.seq,
            r.outcome,
            hex_of_text(&r.folder),
            r.uidvalidity,
            r.uid,
            r.raw_sha256,
            r.body_sha256,
            r.row_id,
            r.ts
        )
    }
}

pub fn entry_hash(r: &ChainRow, prev: &str) -> String {
    sha256_hex(canonical(r, prev).as_bytes())
}

#[derive(Debug, PartialEq)]
pub enum ChainCheck {
    Ok { entries: usize, head: String },
    Broken { seq: i64, why: &'static str },
}

/// Checks the chain one row at a time, so a mailbox with millions of e-mails can be verified page by page without
/// holding the whole chain in memory. The first thing that does not match is reported (same order as the SQL check).
pub struct ChainWalker {
    prev: String,
    want: i64,
    sealed: bool,
    entries: usize,
}

impl ChainWalker {
    pub fn new(session_id: &str, mailbox: &str) -> Self {
        ChainWalker { prev: genesis(session_id, mailbox), want: 1, sealed: false, entries: 0 }
    }
    /// Err((seq, why)) at the first broken link.
    pub fn push(&mut self, r: &ChainRow) -> Result<(), (i64, &'static str)> {
        if self.sealed {
            return Err((r.seq, "entries_after_seal"));
        }
        if r.seq != self.want {
            return Err((r.seq, "sequence_gap"));
        }
        if r.prev_hash != self.prev {
            return Err((r.seq, "prev_hash_mismatch"));
        }
        if entry_hash(r, &self.prev) != r.entry_hash {
            return Err((r.seq, "entry_hash_mismatch"));
        }
        self.sealed = r.outcome == "seal";
        self.prev = r.entry_hash.clone();
        self.want += 1;
        self.entries += 1;
        Ok(())
    }
    pub fn head(&self) -> &str {
        &self.prev
    }
    pub fn sealed(&self) -> bool {
        self.sealed
    }
    pub fn entries(&self) -> usize {
        self.entries
    }
    /// the next sequence number expected (for paging: ask the database for rows after `next_seq() - 1`)
    pub fn next_seq(&self) -> i64 {
        self.want
    }
}

/// Walk the exported rows (ordered by seq) and recompute every link.
pub fn verify_chain(session_id: &str, mailbox: &str, rows: &[ChainRow]) -> ChainCheck {
    let mut w = ChainWalker::new(session_id, mailbox);
    for r in rows {
        if let Err((seq, why)) = w.push(r) {
            return ChainCheck::Broken { seq, why };
        }
    }
    ChainCheck::Ok { entries: rows.len(), head: w.head().to_string() }
}

/* ------------------------------------------------------------------ UID ranges (resume) */

/// [1,2,3,7,8,10] -> "1:3,7:8,10"
pub fn uid_ranges(uids: &[u32]) -> String {
    let mut v: Vec<u32> = uids.to_vec();
    v.sort_unstable();
    v.dedup();
    let mut out = String::new();
    let mut i = 0;
    while i < v.len() {
        let start = v[i];
        let mut end = start;
        while i + 1 < v.len() && v[i + 1] == end + 1 {
            i += 1;
            end = v[i];
        }
        if !out.is_empty() {
            out.push(',');
        }
        if start == end {
            out.push_str(&start.to_string());
        } else {
            out.push_str(&format!("{start}:{end}"));
        }
        i += 1;
    }
    out
}

/// "1:3,7:8,10" -> [1,2,3,7,8,10]. Bad pieces are an error (a corrupt resume list must never silently skip mail).
pub fn parse_ranges(s: &str) -> Result<Vec<u32>, String> {
    let mut out = Vec::new();
    for part in s.split(',').map(str::trim).filter(|p| !p.is_empty()) {
        if let Some((a, b)) = part.split_once(':') {
            let a: u32 = a.parse().map_err(|_| format!("bad range {part}"))?;
            let b: u32 = b.parse().map_err(|_| format!("bad range {part}"))?;
            if a == 0 || b < a || (b - a) > 50_000_000 {
                return Err(format!("bad range {part}"));
            }
            out.extend(a..=b);
        } else {
            let a: u32 = part.parse().map_err(|_| format!("bad uid {part}"))?;
            if a == 0 {
                return Err("uid 0".into());
            }
            out.push(a);
        }
    }
    Ok(out)
}

/// The UIDs still to copy = all UIDs the server lists minus the ones already done (both sorted ascending).
pub fn remaining(all: &[u32], done: &[u32]) -> Vec<u32> {
    let mut d: Vec<u32> = done.to_vec();
    d.sort_unstable();
    all.iter().copied().filter(|u| d.binary_search(u).is_err()).collect()
}

/* ------------------------------------------------------------------ providers */

#[derive(Debug, Clone, Copy)]
pub struct Preset {
    pub id: &'static str,
    pub label: &'static str,
    pub host: &'static str,
    pub port: u16,
    /// one honest sentence shown to the user before they paste a password
    pub note: &'static str,
    /// Google shows app passwords as "abcd efgh ijkl mnop" — the spaces are not part of the password.
    pub strip_spaces: bool,
}

pub const PRESETS: &[Preset] = &[
    Preset {
        id: "gmail",
        label: "Gmail / Google Workspace",
        host: "imap.gmail.com",
        port: 993,
        note: "Turn on 2-Step Verification, then create an App Password in your Google account. Use that 16-letter password here, not your normal one.",
        strip_spaces: true,
    },
    Preset {
        id: "outlook",
        label: "Outlook.com / Hotmail",
        host: "outlook.office365.com",
        port: 993,
        note: "Personal Microsoft accounts: create an App Password under Security. Work or school Microsoft 365 accounts usually block passwords for IMAP; those need the sign-in method we add later.",
        strip_spaces: false,
    },
    Preset {
        id: "yahoo",
        label: "Yahoo Mail",
        host: "imap.mail.yahoo.com",
        port: 993,
        note: "Create an App Password in Yahoo Account Security and use it here.",
        strip_spaces: true,
    },
    Preset {
        id: "icloud",
        label: "iCloud Mail",
        host: "imap.mail.me.com",
        port: 993,
        note: "Create an app-specific password at appleid.apple.com and use it here.",
        strip_spaces: true,
    },
    Preset {
        id: "zoho",
        label: "Zoho Mail",
        host: "imap.zoho.com",
        port: 993,
        note: "Create an application-specific password in Zoho security settings. IMAP must be switched on in your Zoho mail settings.",
        strip_spaces: false,
    },
    Preset {
        id: "custom",
        label: "Another IMAP server",
        host: "",
        port: 993,
        note: "Enter your provider's IMAP host. Only secure connections (port 993) are accepted.",
        strip_spaces: false,
    },
];

pub fn preset(id: &str) -> Option<&'static Preset> {
    PRESETS.iter().find(|p| p.id == id)
}

/// The password exactly as the server wants it: provider quirks only, never trimmed beyond that.
pub fn normalize_password(p: &Preset, raw: &str) -> String {
    if p.strip_spaces {
        raw.chars().filter(|c| !c.is_whitespace()).collect()
    } else {
        raw.trim_matches(|c| c == '\r' || c == '\n').to_string()
    }
}

/* ------------------------------------------------------------------ host guard */

/// Syntax of a host name a customer typed. IP literals and internal-looking names are refused outright.
pub fn valid_host(h: &str) -> Result<String, &'static str> {
    let h = h.trim().trim_end_matches('.').to_lowercase();
    if h.is_empty() || h.len() > 253 {
        return Err("host_invalid");
    }
    if h.parse::<IpAddr>().is_ok() || h.contains(':') || h.contains('[') {
        return Err("host_is_ip");
    }
    let labels: Vec<&str> = h.split('.').collect();
    if labels.len() < 2 {
        return Err("host_invalid");
    }
    for l in &labels {
        if l.is_empty() || l.len() > 63 || l.starts_with('-') || l.ends_with('-') {
            return Err("host_invalid");
        }
        if !l.bytes().all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == b'-') {
            return Err("host_invalid");
        }
    }
    // the last label must not be all digits (that is an IPv4 in disguise, e.g. 127.1 / 2130706433)
    if labels.last().map(|l| l.bytes().all(|c| c.is_ascii_digit())).unwrap_or(true) {
        return Err("host_invalid");
    }
    const BAD_TLD: &[&str] = &["local", "localhost", "internal", "lan", "home", "corp", "intranet", "private", "test", "invalid", "example"];
    if BAD_TLD.contains(labels.last().unwrap()) {
        return Err("host_internal");
    }
    Ok(h)
}

/// True only for addresses on the public internet. Our own network, cloud metadata (169.254.x.x), loopback, private
/// ranges, CGNAT, multicast, documentation and mapped-IPv4 forms of all of those are refused.
pub fn is_public_ip(ip: &IpAddr) -> bool {
    match ip {
        IpAddr::V4(v) => {
            let o = v.octets();
            !(v.is_loopback()
                || v.is_private()
                || v.is_link_local()
                || v.is_broadcast()
                || v.is_documentation()
                || v.is_multicast()
                || v.is_unspecified()
                || o[0] == 0
                || (o[0] == 100 && (o[1] & 0xc0) == 64)      // 100.64.0.0/10 CGNAT
                || (o[0] == 192 && o[1] == 0 && o[2] == 0)   // 192.0.0.0/24
                || (o[0] == 198 && (o[1] == 18 || o[1] == 19)) // benchmarking
                || o[0] >= 240) // reserved
        }
        IpAddr::V6(v) => {
            if let Some(m) = v.to_ipv4_mapped() {
                return is_public_ip(&IpAddr::V4(m));
            }
            let s = v.segments();
            !(v.is_loopback()
                || v.is_unspecified()
                || v.is_multicast()
                || (s[0] & 0xfe00) == 0xfc00   // unique local fc00::/7
                || (s[0] & 0xffc0) == 0xfe80   // link local
                || (s[0] == 0x2001 && s[1] == 0x0db8) // documentation
                || (s[0] == 0x0064 && s[1] == 0xff9b)) // NAT64 (could point at 10.x)
        }
    }
}

pub const ALLOWED_PORT: u16 = 993;

/* ------------------------------------------------------------------ what the customer typed */

#[derive(Debug, Clone, PartialEq)]
pub struct Target {
    pub provider: String,
    pub host: String,
    pub port: u16,
    pub login: String,
    pub password: String,
}

/// Shape of a password only (no provider quirks): refuses anything that could break out of an IMAP command.
pub fn check_password(raw: &str) -> Result<(), &'static str> {
    if raw.is_empty() || raw.chars().count() > 256 || raw.chars().any(|c| c == '\r' || c == '\n' || c == '\0') {
        return Err("bad_password");
    }
    Ok(())
}

/// Validates provider + host + login + password from the start form. The host of a known provider always comes from
/// our own table (what the browser sends is ignored); only "custom" takes a typed host, and that goes through valid_host.
pub fn check_login_input(provider: &str, host: &str, login: &str, password: &str) -> Result<Target, &'static str> {
    let p = preset(provider.trim()).ok_or("bad_provider")?;
    let host = if p.host.is_empty() { valid_host(host)? } else { p.host.to_string() };
    let login = login.trim().to_string();
    if login.is_empty() || login.chars().count() > 320 || login.chars().any(|c| c.is_control()) {
        return Err("bad_login");
    }
    check_password(password)?;
    let password = normalize_password(p, password);
    if password.is_empty() {
        return Err("bad_password");
    }
    Ok(Target { provider: p.id.to_string(), host, port: ALLOWED_PORT, login, password })
}

/// One honest sentence per machine code. Never contains anything the server said (it can contain addresses).
pub fn user_message(code: &str) -> &'static str {
    match code {
        "auth_failed" => "The provider refused the login. Check the address and use an App Password (your normal password usually does not work for IMAP).",
        "tls_failed" => "We could not make a secure connection to that server. Check the server name.",
        "host_not_found" => "That server name could not be found.",
        "host_blocked" => "That server is not on the public internet, so we cannot connect to it.",
        "host_invalid" | "host_is_ip" | "host_internal" => "Enter the provider's IMAP server name (for example imap.example.com), not an address.",
        "bad_provider" => "Choose a provider from the list.",
        "bad_login" => "Enter the full e-mail address you sign in with at the old provider.",
        "bad_password" => "Enter the App Password for the old mailbox.",
        "provider_throttled" => "The provider asked us to slow down. Wait a few minutes, then try again (nothing is copied twice).",
        "connection_lost" => "The connection to the old provider dropped. Try again or resume — nothing is copied twice.",
        "folder_changed" => "The old provider renumbered a folder while we were copying. Start again so nothing is copied wrongly.",
        "time_limit" => "This copy ran for its maximum time. Resume to continue where it stopped.",
        "busy" => "Other copies are running right now. Try again in a few minutes.",
        "session_active" => "A copy for this mailbox is already in progress.",
        "too_many_sessions" => "Too many copies were started today. Try again tomorrow.",
        "still_running" => "This copy is still running.",
        "session_locked" => "This copy is finished and sealed. Start a new one if you need to.",
        "mailbox_not_found" => "That mailbox does not exist in this workspace.",
        "not_allowed" => "You cannot copy mail into that mailbox.",
        "not_found" => "That copy was not found.",
        _ => "The copy stopped because of a problem on our side. Resume to try again.",
    }
}

/* ------------------------------------------------------------------ folder policy */

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AppFolder {
    Inbox,
    Sent,
    Drafts,
    Trash,
    Spam,
    Archive,
}

impl AppFolder {
    /// the value stored in mail_threads.folder
    pub fn as_str(self) -> &'static str {
        match self {
            AppFolder::Inbox => "inbox",
            AppFolder::Sent => "sent",
            AppFolder::Drafts => "drafts",
            AppFolder::Trash => "trash",
            AppFolder::Spam => "spam",
            AppFolder::Archive => "archive",
        }
    }
    /// mail_messages.direction
    pub fn direction(self) -> &'static str {
        match self {
            AppFolder::Sent | AppFolder::Drafts => "out",
            _ => "in",
        }
    }
    /// copy order: INBOX first (so a duplicate is kept where the person expects it), then Sent, Drafts, the rest.
    pub fn order(self) -> u8 {
        match self {
            AppFolder::Inbox => 0,
            AppFolder::Sent => 1,
            AppFolder::Drafts => 2,
            AppFolder::Archive => 3,
            AppFolder::Spam => 4,
            AppFolder::Trash => 5,
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct FolderPlan {
    pub name: String,
    pub app: AppFolder,
}

#[derive(Debug, Clone, PartialEq)]
pub struct Skipped {
    pub name: String,
    pub why: &'static str,
}

/// `attrs` are the IMAP LIST attributes (case-insensitive, with the backslash).
pub fn plan_folders(
    listed: &[(String, Vec<String>)],
    include_trash_spam: bool,
) -> (Vec<FolderPlan>, Vec<Skipped>) {
    let mut plan: Vec<FolderPlan> = Vec::new();
    let mut skipped: Vec<Skipped> = Vec::new();
    for (name, attrs) in listed {
        let a: Vec<String> = attrs.iter().map(|x| x.to_lowercase()).collect();
        let has = |x: &str| a.iter().any(|y| y == x);
        let lname = name.to_lowercase();
        let base = lname.rsplit(|c| c == '/' || c == '.').next().unwrap_or(&lname).to_string();
        if has("\\noselect") || has("\\nonexistent") {
            skipped.push(Skipped { name: name.clone(), why: "not_a_mailbox" });
            continue;
        }
        if has("\\all") || has("\\flagged") || has("\\important") {
            skipped.push(Skipped { name: name.clone(), why: "duplicate_view" });
            continue;
        }
        let app = if lname == "inbox" {
            AppFolder::Inbox
        } else if has("\\sent") {
            AppFolder::Sent
        } else if has("\\drafts") {
            AppFolder::Drafts
        } else if has("\\trash") {
            AppFolder::Trash
        } else if has("\\junk") {
            AppFolder::Spam
        } else if has("\\archive") {
            AppFolder::Archive
        } else if matches!(base.as_str(), "sent" | "sent items" | "sent mail" | "sent messages") {
            AppFolder::Sent
        } else if matches!(base.as_str(), "drafts" | "draft") {
            AppFolder::Drafts
        } else if matches!(base.as_str(), "trash" | "deleted items" | "deleted messages" | "bin") {
            AppFolder::Trash
        } else if matches!(base.as_str(), "junk" | "junk e-mail" | "junk email" | "spam" | "bulk mail") {
            AppFolder::Spam
        } else if lname.starts_with("[gmail]/") || lname.starts_with("[google mail]/") {
            // a Gmail system label that is not Sent/Drafts/Trash/Spam (Important, Starred, All Mail ...) = a duplicate view
            skipped.push(Skipped { name: name.clone(), why: "duplicate_view" });
            continue;
        } else {
            AppFolder::Archive
        };
        if matches!(app, AppFolder::Trash | AppFolder::Spam) && !include_trash_spam {
            skipped.push(Skipped { name: name.clone(), why: "trash_or_spam_not_requested" });
            continue;
        }
        plan.push(FolderPlan { name: name.clone(), app });
    }
    plan.sort_by(|x, y| x.app.order().cmp(&y.app.order()).then_with(|| x.name.cmp(&y.name)));
    (plan, skipped)
}

/* ------------------------------------------------------------------ errors, backoff */

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ErrKind {
    /// wrong password / login refused / IMAP switched off
    Auth,
    /// the provider asked us to slow down — wait, then retry (we never try to get around a limit)
    Throttle,
    /// network drop, timeout, 4xx-style hiccup — reconnect and retry
    Transient,
    /// TLS certificate / handshake problem
    Tls,
    /// cannot continue (protocol nonsense, DNS refused, blocked host)
    Fatal,
}

/// Reads the words a server uses. Order matters: a throttle sentence can also contain "login".
pub fn classify_imap_text(t: &str) -> ErrKind {
    let l = t.to_lowercase();
    if l.contains("throttl")
        || l.contains("too many")
        || l.contains("rate limit")
        || l.contains("[limit]")
        || l.contains("bandwidth")
        || l.contains("exceeded command")
        || l.contains("try again later")
        || l.contains("temporarily unavailable")
        || l.contains("[unavailable]")
    {
        return ErrKind::Throttle;
    }
    if l.contains("authenticationfailed")
        || l.contains("authentication failed")
        || l.contains("invalid credentials")
        || l.contains("login failed")
        || l.contains("[auth")
        || l.contains("app password")
        || l.contains("application-specific")
        || l.contains("web login required")
        || l.contains("imap access is disabled")
        || l.contains("imap is disabled")
        || l.contains("logindisabled")
        || l.contains("basic authentication")
    {
        return ErrKind::Auth;
    }
    if l.contains("[nonexistent]") || l.contains("no such mailbox") || l.contains("[trycreate]") || l.contains("doesn't exist") {
        return ErrKind::Fatal; // this folder cannot be opened; retrying will not help
    }
    if l.contains("certificate") || l.contains("handshake") || l.contains("tls") {
        return ErrKind::Tls;
    }
    ErrKind::Transient
}

/// Wait before retry number `attempt` (0 = first retry): 2s, 4s, 8s ... capped. Throttling waits longer.
pub fn backoff_ms(attempt: u32, kind: ErrKind) -> u64 {
    let base: u64 = if kind == ErrKind::Throttle { 15_000 } else { 2_000 };
    let cap: u64 = if kind == ErrKind::Throttle { 15 * 60_000 } else { 60_000 };
    let shift = attempt.min(12);
    base.saturating_mul(1u64 << shift).min(cap)
}

/// Stable machine codes stored in mig_sessions.last_error (never the server's free text: it can contain addresses).
pub fn error_code(k: ErrKind) -> &'static str {
    match k {
        ErrKind::Auth => "auth_failed",
        ErrKind::Throttle => "provider_throttled",
        ErrKind::Transient => "connection_lost",
        ErrKind::Tls => "tls_failed",
        ErrKind::Fatal => "worker_error",
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sha256_known_vectors() {
        assert_eq!(sha256_hex(b""), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855");
        assert_eq!(sha256_hex(b"abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
        assert_eq!(
            sha256_hex(b"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"),
            "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"
        );
        let million: Vec<u8> = vec![b'a'; 1_000_000];
        assert_eq!(sha256_hex(&million), "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0");
    }

    #[test]
    fn sha256_streaming_equals_one_shot_for_every_split() {
        let data: Vec<u8> = (0..300u32).map(|i| (i * 7 % 251) as u8).collect();
        let whole = sha256_hex(&data);
        for cut in [0usize, 1, 55, 56, 63, 64, 65, 119, 120, 128, 299, 300] {
            let mut h = Sha256::new();
            h.update(&data[..cut]);
            h.update(&data[cut..]);
            assert_eq!(to_hex(&h.finish()), whole, "cut {cut}");
        }
        let mut h = Sha256::new();
        for b in &data {
            h.update(&[*b]);
        }
        assert_eq!(to_hex(&h.finish()), whole);
    }

    #[test]
    fn sha256_padding_boundaries_match_reference() {
        // reference values from GNU sha256sum for exactly 55, 56 and 64 bytes of 'x' (the padding edge cases)
        assert_eq!(sha256_hex(&vec![b'x'; 55]), "d5e285683cd4efc02d021a5c62014694958901005d6f71e89e0989fac77e4072");
        assert_eq!(sha256_hex(&vec![b'x'; 56]), "04c26261370ee7541549d16dee320c723e3fd14671e66a099afe0a377c16888e");
        assert_eq!(sha256_hex(&vec![b'x'; 64]), "7ce100971f64e7001e8fe5a51973ecdfe1ced42befe7ee8d5fd6219506b5393c");
    }

    fn row(seq: i64, outcome: &str, prev: &str) -> ChainRow {
        let mut r = ChainRow {
            seq,
            outcome: outcome.into(),
            folder: "INBOX".into(),
            uidvalidity: 1700000000,
            uid: seq * 3,
            raw_sha256: sha256_hex(format!("raw{seq}").as_bytes()),
            body_sha256: sha256_hex(format!("body{seq}").as_bytes()),
            row_id: "11111111-1111-1111-1111-111111111111".into(),
            ts: 1_760_000_000 + seq,
            copied: 0,
            duplicate: 0,
            skipped: 0,
            failed: 0,
            prev_hash: prev.into(),
            entry_hash: String::new(),
        };
        r.entry_hash = entry_hash(&r, prev);
        r
    }

    fn chain(n: i64) -> Vec<ChainRow> {
        let mut prev = genesis("s-1", "Me@Anexomail.com");
        let mut out = vec![];
        for i in 1..=n {
            let r = row(i, if i % 4 == 0 { "duplicate" } else { "copied" }, &prev);
            prev = r.entry_hash.clone();
            out.push(r);
        }
        let mut seal = row(n + 1, "seal", &prev);
        seal.copied = n - n / 4;
        seal.duplicate = n / 4;
        seal.entry_hash = entry_hash(&seal, &prev);
        out.push(seal);
        out
    }

    #[test]
    fn chain_verifies_and_genesis_is_case_insensitive_on_mailbox() {
        let c = chain(8);
        match verify_chain("s-1", "me@anexomail.com", &c) {
            ChainCheck::Ok { entries, head } => {
                assert_eq!(entries, 9);
                assert_eq!(head, c.last().unwrap().entry_hash);
            }
            x => panic!("{x:?}"),
        }
    }

    #[test]
    fn chain_detects_every_kind_of_tampering() {
        let base = chain(6);
        // 1) change a stored hash of an e-mail
        let mut c = base.clone();
        c[2].raw_sha256 = sha256_hex(b"other");
        assert_eq!(verify_chain("s-1", "me@anexomail.com", &c), ChainCheck::Broken { seq: 3, why: "entry_hash_mismatch" });
        // 2) delete one entry
        let mut c = base.clone();
        c.remove(1);
        assert!(matches!(verify_chain("s-1", "me@anexomail.com", &c), ChainCheck::Broken { seq: 3, why: "sequence_gap" }));
        // 3) re-order
        let mut c = base.clone();
        c.swap(1, 2);
        assert!(matches!(verify_chain("s-1", "me@anexomail.com", &c), ChainCheck::Broken { .. }));
        // 4) change an entry AND recompute only its own hash (the next link must catch it)
        let mut c = base.clone();
        c[1].uid += 1;
        let prev = c[1].prev_hash.clone();
        c[1].entry_hash = entry_hash(&c[1], &prev);
        assert_eq!(verify_chain("s-1", "me@anexomail.com", &c), ChainCheck::Broken { seq: 3, why: "prev_hash_mismatch" });
        // 5) other session id / other mailbox = different genesis
        assert!(matches!(verify_chain("s-2", "me@anexomail.com", &base), ChainCheck::Broken { seq: 1, .. }));
        assert!(matches!(verify_chain("s-1", "you@anexomail.com", &base), ChainCheck::Broken { seq: 1, .. }));
        // 6) anything written after the seal
        let mut c = base.clone();
        let last = c.last().unwrap().entry_hash.clone();
        let extra = row(8, "copied", &last);
        c.push(extra);
        assert_eq!(verify_chain("s-1", "me@anexomail.com", &c), ChainCheck::Broken { seq: 8, why: "entries_after_seal" });
    }

    #[test]
    fn walker_pages_give_the_same_answer_as_the_whole_chain() {
        let c = chain(10);
        let mut w = ChainWalker::new("s-1", "me@anexomail.com");
        for page in c.chunks(3) {
            for r in page {
                w.push(r).unwrap();
            }
        }
        assert_eq!(w.entries(), 11);
        assert!(w.sealed());
        assert_eq!(w.next_seq(), 12);
        assert_eq!(w.head(), c.last().unwrap().entry_hash);
        // a broken row in the middle of a later page is found
        let mut bad = c.clone();
        bad[7].uid += 1;
        let mut w = ChainWalker::new("s-1", "me@anexomail.com");
        let mut hit = None;
        for r in &bad {
            if let Err(e) = w.push(r) {
                hit = Some(e);
                break;
            }
        }
        assert_eq!(hit, Some((8, "entry_hash_mismatch")));
    }

    #[test]
    fn login_input_rules() {
        let t = check_login_input("gmail", "evil.example.com", " me@gmail.com ", "abcd efgh ijkl mnop").unwrap();
        assert_eq!(t.host, "imap.gmail.com"); // the browser's host is ignored for a known provider
        assert_eq!(t.port, 993);
        assert_eq!(t.login, "me@gmail.com");
        assert_eq!(t.password, "abcdefghijklmnop"); // Google's spaces are not part of the password
        let t = check_login_input("custom", "Mail.Example.com.", "me", "pw with spaces").unwrap();
        assert_eq!(t.host, "mail.example.com");
        assert_eq!(t.password, "pw with spaces");
        assert_eq!(check_login_input("custom", "127.0.0.1", "me", "x"), Err("host_is_ip"));
        assert_eq!(check_login_input("custom", "db.internal", "me", "x"), Err("host_internal"));
        assert_eq!(check_login_input("custom", "", "me", "x"), Err("host_invalid"));
        assert_eq!(check_login_input("nope", "", "me", "x"), Err("bad_provider"));
        assert_eq!(check_login_input("yahoo", "", "", "x"), Err("bad_login"));
        assert_eq!(check_login_input("yahoo", "", "a\r\nb", "x"), Err("bad_login"));
        assert_eq!(check_login_input("yahoo", "", "me", ""), Err("bad_password"));
        assert_eq!(check_login_input("yahoo", "", "me", "a\r\nA1 LOGOUT"), Err("bad_password"));
        assert_eq!(check_login_input("yahoo", "", "me", "a\0b"), Err("bad_password"));
        assert_eq!(check_login_input("yahoo", "", "me", "    "), Err("bad_password")); // only spaces: stripped to nothing
        assert_eq!(check_login_input("yahoo", "", "me", &"x".repeat(257)), Err("bad_password"));
        assert!(check_password("pässwörd-ünïcode").is_ok());
    }

    #[test]
    fn every_error_code_has_a_sentence_and_none_leak_server_text() {
        for code in [
            "auth_failed", "tls_failed", "host_not_found", "host_blocked", "host_invalid", "host_is_ip", "host_internal", "bad_provider",
            "bad_login", "bad_password", "provider_throttled", "connection_lost", "folder_changed", "time_limit", "busy", "session_active",
            "too_many_sessions", "still_running", "session_locked", "mailbox_not_found", "not_allowed", "not_found", "worker_error",
        ] {
            let m = user_message(code);
            assert!(m.len() > 10 && m.ends_with('.'), "{code}");
            assert!(!m.contains('@') || code == "bad_login", "{code}");
        }
        for k in [ErrKind::Auth, ErrKind::Throttle, ErrKind::Transient, ErrKind::Tls, ErrKind::Fatal] {
            assert!(!user_message(error_code(k)).is_empty());
        }
    }

    #[test]
    fn canonical_text_is_pinned() {
        // This exact text is what SQL E35 builds too — if this test changes, the SQL must change with it.
        let r = ChainRow {
            seq: 2,
            outcome: "copied".into(),
            folder: "Sent Items".into(),
            uidvalidity: 5,
            uid: 9,
            raw_sha256: "a".repeat(64),
            body_sha256: "b".repeat(64),
            row_id: ZERO_ID.into(),
            ts: 100,
            copied: 0,
            duplicate: 0,
            skipped: 0,
            failed: 0,
            prev_hash: String::new(),
            entry_hash: String::new(),
        };
        assert_eq!(
            canonical(&r, "PREV"),
            format!(
                "ANX-MIG-1|PREV|2|copied|53656e74204974656d73|5|9|{}|{}|00000000-0000-0000-0000-000000000000|100",
                "a".repeat(64),
                "b".repeat(64)
            )
        );
        let s = ChainRow { seq: 3, outcome: "seal".into(), copied: 10, duplicate: 2, skipped: 1, failed: 0, ts: 7, ..r };
        assert_eq!(canonical(&s, "PREV"), "ANX-MIG-1|PREV|3|seal|10|2|1|0|7");
    }

    #[test]
    fn known_vector_for_sql() {
        // The same inputs are hard-wired in SQL E35's self-test; both languages must print this exact hash.
        let sid = "00000000-0000-0000-0000-0000000000a1";
        let g = genesis(sid, "me@anexomail.com");
        let r = ChainRow {
            seq: 1,
            outcome: "copied".into(),
            folder: "INBOX".into(),
            uidvalidity: 1700000000,
            uid: 42,
            raw_sha256: sha256_hex(b"raw"),
            body_sha256: sha256_hex(b"body"),
            row_id: "11111111-1111-1111-1111-111111111111".into(),
            ts: 1760000000,
            copied: 0,
            duplicate: 0,
            skipped: 0,
            failed: 0,
            prev_hash: g.clone(),
            entry_hash: String::new(),
        };
        assert_eq!(entry_hash(&r, &g), "983fb03f3a7f3db65d5ec7782a9fc722553fa10b288b09bd12e7400774fb4fed");
    }

    #[test]
    fn ranges_round_trip_and_reject_garbage() {
        let u = [1, 2, 3, 7, 8, 10, 10, 4_000_000_000];
        assert_eq!(uid_ranges(&u), "1:3,7:8,10,4000000000");
        assert_eq!(uid_ranges(&[]), "");
        assert_eq!(parse_ranges("1:3,7:8,10").unwrap(), vec![1, 2, 3, 7, 8, 10]);
        assert_eq!(parse_ranges("").unwrap(), Vec::<u32>::new());
        assert!(parse_ranges("3:1").is_err());
        assert!(parse_ranges("0").is_err());
        assert!(parse_ranges("a:b").is_err());
        assert!(parse_ranges("1:99999999999").is_err());
        assert_eq!(remaining(&[1, 2, 3, 4, 5, 9], &[2, 4, 100]), vec![1, 3, 5, 9]);
    }

    #[test]
    fn password_normalisation_is_provider_specific() {
        let g = preset("gmail").unwrap();
        assert_eq!(normalize_password(g, "abcd efgh ijkl mnop"), "abcdefghijklmnop");
        let z = preset("zoho").unwrap();
        assert_eq!(normalize_password(z, "pa ss\r\n"), "pa ss");
    }

    #[test]
    fn host_rules() {
        assert_eq!(valid_host(" IMAP.Gmail.com. ").unwrap(), "imap.gmail.com");
        for bad in ["localhost", "127.0.0.1", "10.0.0.5", "intranet", "mail.local", "a_b.com", "-x.com", "x..com", "[::1]", "::1", "1.2.3", "2130706433", "mail.internal", ""] {
            assert!(valid_host(bad).is_err(), "{bad}");
        }
        assert!(valid_host(&format!("{}.com", "a".repeat(64))).is_err());
    }

    #[test]
    fn only_public_addresses_pass() {
        let ok = ["8.8.8.8", "142.250.80.109", "2607:f8b0:4004:c1b::6d", "52.96.0.1"];
        let bad = [
            "127.0.0.1", "10.1.2.3", "172.16.0.1", "172.31.255.255", "192.168.1.1", "169.254.169.254", "100.64.0.1", "0.0.0.0",
            "255.255.255.255", "224.0.0.1", "198.18.0.1", "240.0.0.1", "192.0.0.5", "::1", "::", "fe80::1", "fd00::1", "fc00::1",
            "::ffff:127.0.0.1", "::ffff:10.0.0.1", "64:ff9b::a00:1", "2001:db8::1", "ff02::1",
        ];
        for s in ok {
            assert!(is_public_ip(&s.parse().unwrap()), "{s} should be public");
        }
        for s in bad {
            assert!(!is_public_ip(&s.parse().unwrap()), "{s} must be refused");
        }
        assert!(is_public_ip(&"172.32.0.1".parse().unwrap()));
    }

    fn l(n: &str, a: &[&str]) -> (String, Vec<String>) {
        (n.to_string(), a.iter().map(|x| x.to_string()).collect())
    }

    #[test]
    fn gmail_layout_skips_duplicate_views_and_orders_inbox_first() {
        let listed = vec![
            l("[Gmail]/All Mail", &["\\HasNoChildren", "\\All"]),
            l("[Gmail]/Sent Mail", &["\\HasNoChildren", "\\Sent"]),
            l("[Gmail]/Drafts", &["\\Drafts"]),
            l("[Gmail]/Starred", &["\\Flagged"]),
            l("[Gmail]/Important", &["\\Important"]),
            l("[Gmail]/Spam", &["\\Junk"]),
            l("[Gmail]/Trash", &["\\Trash"]),
            l("[Gmail]", &["\\Noselect", "\\HasChildren"]),
            l("Clients/ACME", &["\\HasNoChildren"]),
            l("INBOX", &["\\HasNoChildren"]),
        ];
        let (plan, skipped) = plan_folders(&listed, false);
        let names: Vec<&str> = plan.iter().map(|p| p.name.as_str()).collect();
        assert_eq!(names, vec!["INBOX", "[Gmail]/Sent Mail", "[Gmail]/Drafts", "Clients/ACME"]);
        assert_eq!(plan[1].app, AppFolder::Sent);
        assert_eq!(plan[3].app, AppFolder::Archive);
        assert_eq!(skipped.len(), 6);
        assert!(skipped.iter().any(|s| s.name == "[Gmail]/All Mail" && s.why == "duplicate_view"));
        assert!(skipped.iter().any(|s| s.name == "[Gmail]/Trash" && s.why == "trash_or_spam_not_requested"));
        let (with, _) = plan_folders(&listed, true);
        assert!(with.iter().any(|p| p.app == AppFolder::Trash) && with.iter().any(|p| p.app == AppFolder::Spam));
        assert_eq!(with.last().unwrap().app, AppFolder::Trash);
    }

    #[test]
    fn plain_names_work_without_special_use_flags() {
        let listed = vec![
            l("Sent Items", &[]),
            l("Deleted Items", &[]),
            l("Junk E-mail", &[]),
            l("INBOX/Sent", &[]),
            l("Drafts", &[]),
            l("Inbox", &[]),
            l("Projects.2024", &[]),
        ];
        let (plan, _) = plan_folders(&listed, true);
        let get = |n: &str| plan.iter().find(|p| p.name == n).unwrap().app;
        assert_eq!(get("Sent Items"), AppFolder::Sent);
        assert_eq!(get("Deleted Items"), AppFolder::Trash);
        assert_eq!(get("Junk E-mail"), AppFolder::Spam);
        assert_eq!(get("INBOX/Sent"), AppFolder::Sent);
        assert_eq!(get("Drafts"), AppFolder::Drafts);
        assert_eq!(get("Inbox"), AppFolder::Inbox);
        assert_eq!(get("Projects.2024"), AppFolder::Archive);
        assert_eq!(AppFolder::Sent.direction(), "out");
        assert_eq!(AppFolder::Archive.direction(), "in");
        assert_eq!(AppFolder::Spam.as_str(), "spam");
    }

    #[test]
    fn classify_reads_server_words() {
        assert_eq!(classify_imap_text("NO [AUTHENTICATIONFAILED] Invalid credentials (Failure)"), ErrKind::Auth);
        assert_eq!(classify_imap_text("NO [ALERT] Application-specific password required"), ErrKind::Auth);
        assert_eq!(classify_imap_text("NO [LIMIT] Account exceeded command or bandwidth limits"), ErrKind::Throttle);
        assert_eq!(classify_imap_text("BAD Too many commands, throttled"), ErrKind::Throttle);
        assert_eq!(classify_imap_text("invalid peer certificate: UnknownIssuer"), ErrKind::Tls);
        assert_eq!(classify_imap_text("connection reset by peer"), ErrKind::Transient);
        assert_eq!(classify_imap_text("NO [NONEXISTENT] Unknown Mailbox"), ErrKind::Fatal);
    }

    #[test]
    fn backoff_grows_and_is_capped() {
        assert_eq!(backoff_ms(0, ErrKind::Transient), 2_000);
        assert_eq!(backoff_ms(3, ErrKind::Transient), 16_000);
        assert_eq!(backoff_ms(20, ErrKind::Transient), 60_000);
        assert_eq!(backoff_ms(0, ErrKind::Throttle), 15_000);
        assert_eq!(backoff_ms(20, ErrKind::Throttle), 900_000);
        assert_eq!(error_code(ErrKind::Auth), "auth_failed");
    }

    #[test]
    fn presets_are_sane() {
        for p in PRESETS {
            if p.id != "custom" {
                assert_eq!(valid_host(p.host).unwrap(), p.host);
                assert_eq!(p.port, ALLOWED_PORT);
            }
            assert!(!p.note.is_empty());
        }
        assert!(preset("gmail").is_some() && preset("nope").is_none());
    }
}
