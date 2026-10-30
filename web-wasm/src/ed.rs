//! F2b (Rule 52, ek hi kernel): server ke Ed25519 sign kiye hue /founder/v1 jawab ki asliyat browser mein verify karna.
//! Module `ed25519@1` (verify) + `envelope@1` (kachchi body se verify-phir-parse). Sirf pure functions: koi network/DOM nahi.
//! Server ka paigham (server/founder/src/sign.rs): "<ts>.<sha256hex(data_json)>", data_json = `data` ke EXACT bytes jo body mein hain.
//! Isliye hum body ke bytes se `data` ka tukda nikaal kar hash karte hain, JSON dobara nahi banate (key-order/number ka farq mumkin nahi).
use ed25519_dalek::{Signature, VerifyingKey};
use sha2::{Digest, Sha256};

/// Browser mein pinned server public keys (kid, key). Badalna = naya kernel build + VERSION bump (key rotation, CRYPTO-FINAL §2).
/// `s1` = GET https://founderworkspace.anexomail.com/founder/v1/keys (30 Oct 2026), base64url `BvK2K2SrpbZoJAHblaB2c1DwXAzEmv4J-m27rVft7RQ`.
pub const PINNED: &[(&str, [u8; 32])] = &[("s1", [
    0x06, 0xf2, 0xb6, 0x2b, 0x64, 0xab, 0xa5, 0xb6, 0x68, 0x24, 0x01, 0xdb, 0x95, 0xa0, 0x76, 0x73,
    0x50, 0xf0, 0x5c, 0x0c, 0xc4, 0x9a, 0xfe, 0x09, 0xfa, 0x6d, 0xbb, 0xad, 0x57, 0xed, 0xed, 0x14,
])];

/// Natija code (JS bhi yahi dekhta hai).
pub const OK: u32 = 0;
pub const MALFORMED: u32 = 1; // body JSON object nahi / kharab
pub const MISSING: u32 = 2; // data/ts/sig_ed/kid/alg nahi
pub const UNKNOWN_KID: u32 = 3;
pub const STALE: u32 = 4; // ts window se bahar (device ghadi ya replay)
pub const BAD_SIG: u32 = 5; // 1 bit bhi badla => yahi
pub const DUP_KEY: u32 = 6; // upar ki level par ek hi naam do baar (ambiguity attack)

/// Seedhi verify: public key, message, signature. Strict (non-canonical / small-order rad).
pub fn verify(pk: &[u8], msg: &[u8], sig: &[u8]) -> bool {
    let (Ok(pk), Ok(sig)) = (<[u8; 32]>::try_from(pk), <[u8; 64]>::try_from(sig)) else { return false };
    let Ok(vk) = VerifyingKey::from_bytes(&pk) else { return false };
    vk.verify_strict(msg, &Signature::from_bytes(&sig)).is_ok()
}

fn ws(b: &[u8], mut i: usize) -> usize { while i < b.len() && matches!(b[i], b' ' | b'\t' | b'\n' | b'\r') { i += 1; } i }

/// `i` par string shuru ('"'); wapas: (andar ke bytes ka [start,end), agla index). Escapes ke saath.
fn string_at(b: &[u8], i: usize) -> Option<(usize, usize, usize)> {
    if b.get(i) != Some(&b'"') { return None; }
    let mut j = i + 1;
    while j < b.len() {
        match b[j] { b'\\' => j += 2, b'"' => return Some((i + 1, j, j + 1)), _ => j += 1 }
    }
    None
}

/// `i` par jo bhi JSON value hai uska agla index (string-aware bracket matching).
fn skip_value(b: &[u8], i: usize) -> Option<usize> {
    match *b.get(i)? {
        b'"' => string_at(b, i).map(|t| t.2),
        b'{' | b'[' => {
            let mut depth = 0usize;
            let mut j = i;
            while j < b.len() {
                match b[j] {
                    b'"' => j = string_at(b, j)?.2 - 1,
                    b'{' | b'[' => depth += 1,
                    b'}' | b']' => { depth -= 1; if depth == 0 { return Some(j + 1); } }
                    _ => {}
                }
                j += 1;
            }
            None
        }
        _ => { let mut j = i; while j < b.len() && !matches!(b[j], b',' | b'}' | b']' | b' ' | b'\n' | b'\r' | b'\t') { j += 1; } if j == i { None } else { Some(j) } }
    }
}

/// Upar ki level ke (key, value[start,end)) jode. Kharab/duplicate => Err(code).
fn top_fields(b: &[u8]) -> Result<Vec<(&[u8], usize, usize)>, u32> {
    let mut i = ws(b, 0);
    if b.get(i) != Some(&b'{') { return Err(MALFORMED); }
    i = ws(b, i + 1);
    let mut out: Vec<(&[u8], usize, usize)> = vec![];
    if b.get(i) == Some(&b'}') { return Ok(out); }
    loop {
        let (ks, ke, next) = string_at(b, i).ok_or(MALFORMED)?;
        let key = &b[ks..ke];
        if key.contains(&b'\\') { return Err(MALFORMED); } // hamare keys saade hain; escaped naam ambiguity hai
        i = ws(b, next);
        if b.get(i) != Some(&b':') { return Err(MALFORMED); }
        i = ws(b, i + 1);
        let end = skip_value(b, i).ok_or(MALFORMED)?;
        if out.iter().any(|(k, _, _)| *k == key) { return Err(DUP_KEY); }
        out.push((key, i, end));
        i = ws(b, end);
        match b.get(i) { Some(b',') => i = ws(b, i + 1), Some(b'}') => return if ws(b, i + 1) == b.len() { Ok(out) } else { Err(MALFORMED) }, _ => return Err(MALFORMED) }
    }
}

fn b64url(s: &[u8]) -> Option<Vec<u8>> {
    let val = |c: u8| match c { b'A'..=b'Z' => Some(c - b'A'), b'a'..=b'z' => Some(c - b'a' + 26), b'0'..=b'9' => Some(c - b'0' + 52), b'-' => Some(62), b'_' => Some(63), _ => None };
    let mut out = Vec::with_capacity(s.len() * 3 / 4);
    let (mut acc, mut bits) = (0u32, 0u32);
    for &c in s { acc = (acc << 6) | val(c)? as u32; bits += 6; if bits >= 8 { bits -= 8; out.push((acc >> bits) as u8); acc &= (1 << bits) - 1; } }
    if bits >= 6 { return None; } // be-maani lamba
    Some(out)
}

fn unquote<'a>(b: &'a [u8], s: usize, e: usize) -> Option<&'a [u8]> { if e >= s + 2 && b[s] == b'"' && b[e - 1] == b'"' { Some(&b[s + 1..e - 1]) } else { None } }

/// Kachchi body (bytes) verify. Ok => (data_start, data_end) body ke andar; JS sirf isi tukde ko parse karta hai.
pub fn envelope_verify(body: &[u8], now_s: i64, skew_s: i64) -> Result<(usize, usize), u32> { envelope_verify_with(body, now_s, skew_s, PINNED) }

pub fn envelope_verify_with(body: &[u8], now_s: i64, skew_s: i64, keys: &[(&str, [u8; 32])]) -> Result<(usize, usize), u32> {
    let f = top_fields(body)?;
    let get = |name: &str| f.iter().find(|(k, _, _)| *k == name.as_bytes()).map(|(_, s, e)| (*s, *e));
    let (ds, de) = get("data").ok_or(MISSING)?;
    let (ts_s, ts_e) = get("ts").ok_or(MISSING)?;
    let (sg_s, sg_e) = get("sig_ed").ok_or(MISSING)?;
    let (kd_s, kd_e) = get("kid").ok_or(MISSING)?;
    let (al_s, al_e) = get("alg").ok_or(MISSING)?;
    if unquote(body, al_s, al_e) != Some(b"ed25519") { return Err(MISSING); }
    let kid = unquote(body, kd_s, kd_e).ok_or(MALFORMED)?;
    let pk = keys.iter().find(|(k, _)| k.as_bytes() == kid).map(|(_, p)| p).ok_or(UNKNOWN_KID)?;
    let ts_txt = std::str::from_utf8(&body[ts_s..ts_e]).map_err(|_| MALFORMED)?;
    let ts: i64 = ts_txt.parse().map_err(|_| MALFORMED)?;
    let sig = b64url(unquote(body, sg_s, sg_e).ok_or(MALFORMED)?).ok_or(MALFORMED)?;
    let msg = format!("{}.{}", ts_txt, hex(&Sha256::digest(&body[ds..de])));
    if !verify(pk, msg.as_bytes(), &sig) { return Err(BAD_SIG); }
    if (now_s - ts).abs() > skew_s { return Err(STALE); } // asli sign ke BAAD ghadi dekho, taake "ghadi galat" aur "jaali" alag dikhein
    Ok((ds, de))
}

fn hex(b: &[u8]) -> String { b.iter().map(|x| format!("{x:02x}")).collect() }

#[cfg(test)]
mod tests {
    use super::*;
    use base64::{Engine, engine::general_purpose::URL_SAFE_NO_PAD as B64};
    use ring::signature::{Ed25519KeyPair, KeyPair};

    fn h(s: &str) -> Vec<u8> { (0..s.len()).step_by(2).map(|i| u8::from_str_radix(&s[i..i + 2], 16).unwrap()).collect() }

    // RFC 8032 section 7.1
    #[test]
    fn rfc8032_vectors() {
        let pk = h("d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a");
        let sig = h("e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b");
        assert!(verify(&pk, b"", &sig));
        let pk2 = h("3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c");
        let sig2 = h("92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00");
        assert!(verify(&pk2, &[0x72], &sig2));
        assert!(!verify(&pk2, &[0x73], &sig2)); // 1 byte badla
        assert!(!verify(&pk2[..31], &[0x72], &sig2)); // chhoti key
    }

    fn pair(seed: u8) -> Ed25519KeyPair { Ed25519KeyPair::from_seed_unchecked(&[seed; 32]).unwrap() }
    /// Server jaisa jawab banao (ring se sign), sirf test ke liye: PINNED key ke bajaye test key chahiye, isliye envelope_with.
    fn envelope_with(kp: &Ed25519KeyPair, kid: &str, ts: i64, data: &str) -> String {
        let msg = format!("{}.{}", ts, hex(&Sha256::digest(data.as_bytes())));
        let sig = B64.encode(kp.sign(msg.as_bytes()).as_ref());
        format!("{{\"alg\":\"ed25519\",\"data\":{data},\"kid\":\"{kid}\",\"sig\":\"x\",\"sig_ed\":\"{sig}\",\"ts\":{ts}}}")
    }
    /// envelope_verify ka wahi code, par test key ke saath.
    fn run(body: &str, kp: &Ed25519KeyPair, now: i64) -> Result<(usize, usize), u32> {
        // PINNED const hai; test mein body ke `kid` ko "s1" rakhte hain aur key ko is test key se badalne ke liye ek chhota seam:
        envelope_verify_with(body.as_bytes(), now, 120, &[("s1", kp.public_key().as_ref().try_into().unwrap())])
    }

    #[test]
    fn ring_signed_envelope_verifies_and_returns_exact_data_span() {
        let kp = pair(7);
        let data = r#"{"money":{"mrr_gbp":14500.5,"note":"a \"quoted\" } , {"},"z":[1,2,{"k":"v"}]}"#;
        let body = envelope_with(&kp, "s1", 1_000_000, data);
        let (s, e) = run(&body, &kp, 1_000_010).unwrap();
        assert_eq!(&body[s..e], data); // bilkul wahi bytes
    }
    #[test]
    fn tamper_one_bit_anywhere_in_data_fails() {
        let kp = pair(7);
        let body = envelope_with(&kp, "s1", 5, r#"{"a":1}"#);
        let bad = body.replace(r#"{"a":1}"#, r#"{"a":2}"#);
        assert_eq!(run(&bad, &kp, 5), Err(BAD_SIG));
    }
    #[test]
    fn wrong_key_unknown_kid_stale_missing_dup_malformed() {
        let (kp, other) = (pair(7), pair(9));
        let body = envelope_with(&kp, "s1", 100, r#"{"a":1}"#);
        assert_eq!(run(&body, &other, 100), Err(BAD_SIG)); // doosri key
        assert_eq!(run(&body.replace("\"s1\"", "\"s2\""), &kp, 100), Err(UNKNOWN_KID));
        assert_eq!(run(&body, &kp, 100 + 500), Err(STALE)); // purana jawab (replay)
        assert_eq!(run(&body, &kp, 100 - 500), Err(STALE)); // ghadi aage
        assert_eq!(run(&body.replace("\"sig_ed\"", "\"sigx\""), &kp, 100), Err(MISSING));
        assert_eq!(run(&body.replace("\"alg\":\"ed25519\"", "\"alg\":\"none\""), &kp, 100), Err(MISSING));
        let dup = body.replacen("{\"alg\"", "{\"data\":{\"a\":9},\"alg\"", 1);
        assert_eq!(run(&dup, &kp, 100), Err(DUP_KEY)); // do `data` — ambiguity attack
        assert_eq!(run("not json", &kp, 100), Err(MALFORMED));
        assert_eq!(run(&format!("{body} x"), &kp, 100), Err(MALFORMED)); // body ke baad kachra
        assert_eq!(run(&body[..body.len() - 5], &kp, 100), Err(MALFORMED)); // truncated
    }
    #[test]
    fn base64url_decoder() {
        assert_eq!(b64url(b"AAEC").unwrap(), vec![0, 1, 2]);
        assert_eq!(b64url(b"-_8").unwrap(), vec![0xfb, 0xff]);
        assert!(b64url(b"A").is_none());
        assert!(b64url(b"AA+/").is_none()); // standard alphabet nahi
    }
    #[test]
    fn pinned_key_is_the_server_key_and_a_valid_point() {
        assert_eq!(B64.encode(PINNED[0].1), "BvK2K2SrpbZoJAHblaB2c1DwXAzEmv4J-m27rVft7RQ");
        assert!(VerifyingKey::from_bytes(&PINNED[0].1).is_ok());
    }
}
