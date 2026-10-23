//! dav_glue — CalDAV C1 (sirf padhna): /dav/* handler + app-password procs + secret calendar link (feed). Pure logic dav_core.rs mein hai.
//! SQL E80 aur E81 (feed) PEHLE. Env: CALDAV_PEPPER (kam az kam 24 akshar) na ho to DAV 503 deta hai — kabhi bina pepper ke hash nahi.
//! Sach: ek hi calendar `personal` (wohi events jin ka aap organiser ho ya guest). PUT/DELETE/MKCOL/PROPPATCH = 405.

use crate::cal_core::{self as cal, recur, EventSpec, Guest, Method, Person};
use crate::dav_core as dc;
use axum::{
    body::Body,
    extract::Request,
    http::{header, HeaderMap, HeaderValue, StatusCode},
    response::{IntoResponse, Response},
};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};

const CAL_KEY: &str = "personal";
const REALM: &str = "Basic realm=\"ANEXOMAIL CalDAV\", charset=\"UTF-8\"";

pub fn owns(proc: &str) -> bool {
    matches!(
        proc,
        "caldav.apppw.create" | "caldav.apppw.list" | "caldav.apppw.revoke" | "caldav.feed.create" | "caldav.feed.list" | "caldav.feed.revoke"
    )
}

fn st(v: &Value, k: &str) -> String {
    v.get(k).and_then(|x| x.as_str()).unwrap_or("").to_string()
}

fn now_epoch() -> i64 {
    std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs() as i64).unwrap_or(0)
}

fn pepper() -> Option<String> {
    let p = crate::env_var("CALDAV_PEPPER");
    if p.trim().len() >= 24 { Some(p.trim().to_string()) } else { None }
}

fn hash_of(pepper: &str, secret: &str) -> String {
    let mut h = Sha256::new();
    h.update(pepper.as_bytes());
    h.update(secret.as_bytes());
    h.finalize().iter().map(|b| format!("{b:02x}")).collect()
}

fn fail(status: StatusCode, code: &str, msg: &str) -> Response {
    crate::err(status, code, msg).into_response()
}

/* ----------------------------------------------------- app password procs */

pub async fn dispatch(proc: &str, token: &str, input: &Value) -> Response {
    let me = match crate::mail_identity(token, &st(input, "org_id")).await {
        Ok(m) => m,
        Err((status, code, detail)) => return fail(status, &code, &detail),
    };
    let Some(pep) = pepper() else {
        return fail(StatusCode::SERVICE_UNAVAILABLE, "caldav_not_configured", "CalDAV is not configured on this server yet.");
    };
    // `feed` = secret .ics link (SQL E81 kind='feed'); baqi `apppw` = CalDAV app password (kind='dav'). Revoke dono ka ek hi (id + user se).
    let feed = proc.starts_with("caldav.feed.");
    let (sql_list, sql_create, sql_missing) = if feed {
        ("caldav_feed_list", "caldav_feed_create", "Calendar link SQL (E81) is not installed yet.")
    } else {
        ("caldav_apppw_list", "caldav_apppw_create", "CalDAV SQL (E80) is not installed yet.")
    };
    match proc {
        "caldav.apppw.list" | "caldav.feed.list" => match crate::sb_rpc(sql_list, json!({ "p_user": me.id })).await {
            Ok(v) => crate::ok(json!({ "keys": v })).into_response(),
            Err(_) => fail(StatusCode::SERVICE_UNAVAILABLE, "caldav_sql_missing", sql_missing),
        },
        "caldav.apppw.revoke" | "caldav.feed.revoke" => {
            let id = st(input, "id");
            if !dc::uuid_ok(&id) {
                return fail(StatusCode::BAD_REQUEST, "bad_id", "Invalid key id.");
            }
            match crate::sb_rpc("caldav_apppw_revoke", json!({ "p_user": me.id, "p_id": id })).await {
                Ok(v) => crate::ok(json!({ "result": v })).into_response(),
                Err(_) => fail(StatusCode::SERVICE_UNAVAILABLE, "caldav_sql_missing", sql_missing),
            }
        }
        "caldav.apppw.create" | "caldav.feed.create" => {
            let label: String = st(input, "label").trim().chars().take(40).collect();
            let mut raw = [0u8; 19];
            {
                use std::io::Read;
                let ok = std::fs::File::open("/dev/urandom").and_then(|mut f| f.read_exact(&mut raw)).is_ok();
                if !ok {
                    return fail(StatusCode::INTERNAL_SERVER_ERROR, "server_error", "Could not generate a key.");
                }
            }
            let (tid, secret) = dc::app_password_from_bytes(&raw);
            let r = crate::sb_rpc(
                sql_create,
                json!({ "p_user": me.id, "p_org": me.org_id, "p_email": me.email.trim().to_lowercase(), "p_label": label, "p_token_id": tid, "p_hash": hash_of(&pep, &secret) }),
            )
            .await;
            match r {
                Ok(v) if v.get("error").is_some() => {
                    let code = st(&v, "error");
                    let status = if code == "too_many" { StatusCode::CONFLICT } else { StatusCode::BAD_REQUEST };
                    fail(status, &code, "Could not create the key.")
                }
                // asli chaabi / link SIRF isi jawab mein, ek baar — DB mein sirf hash hai
                Ok(v) if feed => crate::ok(json!({ "path": format!("/dav/feed/{tid}{secret}.ics"), "id": v.get("id") })).into_response(),
                Ok(v) => crate::ok(json!({ "key": dc::display_app_password(&tid, &secret), "id": v.get("id"), "username": me.email.trim().to_lowercase() })).into_response(),
                Err(_) => fail(StatusCode::SERVICE_UNAVAILABLE, "caldav_sql_missing", sql_missing),
            }
        }
        _ => fail(StatusCode::NOT_FOUND, "not_found", "Unknown proc."),
    }
}

/* ------------------------------------------------------------------ http */

struct Dav {
    user_id: String,
    org_id: String,
    email: String,
}

fn resp(status: StatusCode, ctype: &str, body: String, extra: &[(&str, String)]) -> Response {
    let mut r = Response::new(Body::from(body));
    *r.status_mut() = status;
    let h = r.headers_mut();
    h.insert(header::CONTENT_TYPE, HeaderValue::from_str(ctype).unwrap_or(HeaderValue::from_static("text/plain")));
    h.insert("DAV", HeaderValue::from_static(dc::DAV_HEADER));
    h.insert(header::CACHE_CONTROL, HeaderValue::from_static("no-store"));
    for (k, v) in extra {
        if let (Ok(n), Ok(val)) = (header::HeaderName::from_bytes(k.as_bytes()), HeaderValue::from_str(v)) {
            h.insert(n, val);
        }
    }
    r
}

fn plain(status: StatusCode, msg: &str) -> Response {
    resp(status, "text/plain; charset=utf-8", msg.to_string(), &[("Allow", dc::ALLOWED.to_string())])
}

fn unauthorized() -> Response {
    resp(StatusCode::UNAUTHORIZED, "text/plain; charset=utf-8", "Sign in with your email and a CalDAV app password.".into(), &[("WWW-Authenticate", REALM.to_string())])
}

fn email_ok(e: &str) -> bool {
    e.len() <= 254 && e.bytes().all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || b"@._+-".contains(&c))
}

async fn authed(headers: &HeaderMap) -> Result<Dav, Response> {
    let Some(pep) = pepper() else {
        return Err(plain(StatusCode::SERVICE_UNAVAILABLE, "CalDAV is not configured on this server."));
    };
    let Some(h) = headers.get(header::AUTHORIZATION).and_then(|v| v.to_str().ok()) else { return Err(unauthorized()) };
    let Some((user, pw)) = dc::parse_basic(h) else { return Err(unauthorized()) };
    let Some((tid, secret)) = dc::split_app_password(&pw) else { return Err(unauthorized()) };
    if !email_ok(&user) {
        return Err(unauthorized());
    }
    let row = match crate::sb_rpc("caldav_auth_lookup", json!({ "p_token_id": tid })).await {
        Ok(v) => v,
        Err(_) => return Err(plain(StatusCode::SERVICE_UNAVAILABLE, "CalDAV is not available (SQL E80 missing?).")),
    };
    if row.is_null() || row.get("id").is_none() {
        return Err(unauthorized());
    }
    let good = dc::ct_eq(hash_of(&pep, &secret).as_bytes(), st(&row, "secret_hash").as_bytes()) && st(&row, "email").to_lowercase() == user;
    let _ = crate::sb_rpc("caldav_auth_result", json!({ "p_id": st(&row, "id"), "p_ok": good })).await;
    if !good {
        return Err(unauthorized());
    }
    Ok(Dav { user_id: st(&row, "user_id"), org_id: st(&row, "org_id"), email: user })
}

/* ----------------------------------------------------------------- events */

fn pct(s: &str) -> String {
    s.bytes().map(|c| if c.is_ascii_alphanumeric() || b"-._~@".contains(&c) { (c as char).to_string() } else { format!("%{c:02X}") }).collect()
}

fn exdates_of(ev: &Value) -> Vec<i64> {
    ev.get("exdates").and_then(|v| v.as_array()).map(|a| a.iter().filter_map(|x| x.as_str().and_then(cal::parse_ts)).collect()).unwrap_or_default()
}

fn spec_of(ev: &Value, guests: &[Value], master_id: Option<&str>) -> Option<EventSpec> {
    let tzname = st(ev, "tz");
    let off = (ev.get("tz_offset_min").and_then(|x| x.as_i64()).unwrap_or(0).clamp(-840, 840) * 60) as i32;
    let zone = recur::load_tz(&tzname, off);
    let opt = |k: &str| -> Option<String> { let t = st(ev, k); if t.trim().is_empty() { None } else { Some(t) } };
    Some(EventSpec {
        id: master_id.map(|s| s.to_string()).unwrap_or_else(|| st(ev, "id")),
        sequence: ev.get("sequence").and_then(|x| x.as_i64()).unwrap_or(0).max(0) as u32,
        title: st(ev, "title"),
        agenda: opt("agenda"),
        starts: cal::parse_ts(&st(ev, "starts_at"))?,
        ends: cal::parse_ts(&st(ev, "ends_at"))?,
        location: opt("location"),
        organiser: Person { address: st(ev, "organiser").to_lowercase(), name: None },
        guests: guests
            .iter()
            .map(|r| Guest {
                address: st(r, "address").to_lowercase(),
                name: { let n = st(r, "display_name"); if n.trim().is_empty() { None } else { Some(n) } },
                optional: st(r, "role") == "optional",
                response: { let x = st(r, "response"); if x.is_empty() { "needs_action".into() } else { x } },
            })
            .collect(),
        now: now_epoch(),
        rrule: opt("rrule"),
        exdates: exdates_of(ev),
        recurrence_id: if master_id.is_some() { cal::parse_ts(&st(ev, "recurrence_id")) } else { None },
        tz: if tzname.is_empty() { None } else { Some((tzname, (*zone).clone())) },
    })
}

struct Res {
    id: String,
    ics: String,
    etag: String,
    modified: i64,
    from: i64,
    to: i64,
    recurring: bool,
}

async fn load(me: &Dav) -> Result<Vec<Res>, ()> {
    if !email_ok(&me.email) {
        return Err(());
    }
    // jin events mein main guest hoon
    let mine = crate::sb_select(&format!("calendar_attendees?select=event_id&address=eq.{}&limit=2000", pct(&me.email))).await.map_err(|_| ())?;
    let ids: Vec<String> = mine.as_array().cloned().unwrap_or_default().iter().map(|r| st(r, "event_id")).filter(|i| dc::uuid_ok(i)).collect();
    let mut filt = format!("organiser.eq.{}", pct(&me.email));
    if !ids.is_empty() {
        filt.push_str(&format!(",id.in.({})", ids.join(",")));
    }
    let q = format!(
        "calendar_events?select=*&org_id=eq.{}&cancelled_at=is.null&or=({})&order=starts_at.asc&limit=2000",
        me.org_id, filt
    );
    let rows = crate::sb_select(&q).await.map_err(|_| ())?;
    let all = rows.as_array().cloned().unwrap_or_default();
    let masters: Vec<Value> = all.into_iter().filter(|e| st(e, "series_id").is_empty() && st(e, "status") != "cancelled").collect();
    let mids: Vec<String> = masters.iter().map(|e| st(e, "id")).filter(|i| dc::uuid_ok(i)).collect();
    if mids.is_empty() {
        return Ok(vec![]);
    }
    let guests = crate::sb_select(&format!("calendar_attendees?select=*&event_id=in.({})&limit=5000", mids.join(","))).await.map_err(|_| ())?;
    let guests = guests.as_array().cloned().unwrap_or_default();
    let excs = crate::sb_select(&format!("calendar_events?select=*&series_id=in.({})&cancelled_at=is.null&limit=2000", mids.join(","))).await.map_err(|_| ())?;
    let excs = excs.as_array().cloned().unwrap_or_default();
    let mut out = Vec::new();
    for m in masters {
        let id = st(&m, "id");
        let g: Vec<Value> = guests.iter().filter(|r| st(r, "event_id") == id).cloned().collect();
        let Some(spec) = spec_of(&m, &g, None) else { continue };
        let mut ics = dc::strip_method(&cal::build_ics(Method::Request, &spec, ""));
        let mut rev = m.get("dav_rev").and_then(|x| x.as_i64()).unwrap_or(1);
        let mut modified = cal::parse_ts(&st(&m, "dav_updated_at")).unwrap_or(0);
        let mut extras = Vec::new();
        for e in excs.iter().filter(|e| st(e, "series_id") == id) {
            if let Some(es) = spec_of(e, &g, Some(&id)) {
                extras.push(dc::strip_method(&cal::build_ics(Method::Request, &es, "")));
            }
            rev += e.get("dav_rev").and_then(|x| x.as_i64()).unwrap_or(1);
            modified = modified.max(cal::parse_ts(&st(e, "dav_updated_at")).unwrap_or(0));
        }
        if !extras.is_empty() {
            ics = dc::merge_vevents(&ics, &extras);
        }
        out.push(Res { etag: dc::etag(&id, rev), id, ics, modified, from: spec.starts, to: spec.ends, recurring: spec.rrule.is_some() });
    }
    Ok(out)
}

fn xe(s: &str) -> String {
    dc::esc_xml(s)
}

fn coll_type(cal_too: bool) -> String {
    if cal_too { "<D:collection/><C:calendar/>".into() } else { "<D:collection/>".into() }
}

fn href_el(h: &str) -> String {
    format!("<D:href>{}</D:href>", xe(h))
}

fn ms(rs: &[dc::Resp]) -> Response {
    resp(StatusCode::MULTI_STATUS, "application/xml; charset=utf-8", dc::multistatus(rs), &[])
}

fn one(pf: &dc::PropFind, href: &str, have: Vec<(&str, String)>) -> dc::Resp {
    let (found, missing) = dc::pick(pf, &have);
    dc::Resp { href: href.to_string(), found, missing }
}

fn principal_props(me: &Dav) -> Vec<(&'static str, String)> {
    vec![
        ("resourcetype", "<D:principal/>".to_string()),
        ("displayname", xe(&me.email)),
        ("current-user-principal", href_el("/dav/p/")),
        ("principal-url", href_el("/dav/p/")),
        ("calendar-home-set", href_el("/dav/p/home/")),
        ("calendar-user-address-set", href_el(&format!("mailto:{}", me.email))),
    ]
}

fn event_props(r: &Res, with_data: bool) -> Vec<(&'static str, String)> {
    let mut v = vec![
        ("getetag", xe(&r.etag)),
        ("getcontenttype", "text/calendar; charset=utf-8; component=VEVENT".to_string()),
        ("getlastmodified", dc::http_date(r.modified.max(0))),
        ("getcontentlength", r.ics.len().to_string()),
        ("resourcetype", String::new()),
    ];
    if with_data {
        v.push(("calendar-data", xe(&r.ics)));
    }
    v
}

/* ----------------------------------------------------------------- feed */

/// Secret calendar link: `GET /dav/feed/<30 akshar>.ics` — sirf-padhna, login nahi, Google Calendar "From URL" ke liye.
/// Ghalat/purani/revoked link = 404 (401 nahi: bahar walon ko yeh pata nahi chalta ke link kabhi tha ya nahi). Chaabi sirf hash se parakhi jaati hai.
async fn feed(headers: &HeaderMap, key: &str, head: bool) -> Response {
    let Some(pep) = pepper() else {
        return plain(StatusCode::SERVICE_UNAVAILABLE, "Calendar link is not configured on this server.");
    };
    let Some((tid, secret)) = dc::split_app_password(key) else { return plain(StatusCode::NOT_FOUND, "Not found.") };
    let row = match crate::sb_rpc("caldav_feed_lookup", json!({ "p_token_id": tid })).await {
        Ok(v) => v,
        Err(_) => return plain(StatusCode::SERVICE_UNAVAILABLE, "Calendar link is not available (SQL E81 missing?)."),
    };
    if row.is_null() || row.get("id").is_none() {
        return plain(StatusCode::NOT_FOUND, "Not found.");
    }
    let good = dc::ct_eq(hash_of(&pep, &secret).as_bytes(), st(&row, "secret_hash").as_bytes());
    let _ = crate::sb_rpc("caldav_auth_result", json!({ "p_id": st(&row, "id"), "p_ok": good })).await;
    if !good {
        return plain(StatusCode::NOT_FOUND, "Not found.");
    }
    let me = Dav { user_id: st(&row, "user_id"), org_id: st(&row, "org_id"), email: st(&row, "email").to_lowercase() };
    let _ = &me.user_id;
    let Ok(list) = load(&me).await else { return plain(StatusCode::SERVICE_UNAVAILABLE, "Calendar unavailable.") };
    let ctag = crate::sb_rpc("caldav_ctag", json!({ "p_org": me.org_id })).await.ok().and_then(|v| v.as_i64()).unwrap_or(1);
    let newest = list.iter().map(|r| r.modified).max().unwrap_or(0).max(0);
    let etag = dc::feed_etag(ctag, list.len(), newest);
    // link kisi ko forward ho jaye to search engine/referrer se aage na jaye; cache sirf us user ke apne client mein
    let common = |extra: Vec<(&'static str, String)>| -> Vec<(&'static str, String)> {
        let mut v = vec![
            ("ETag", etag.clone()),
            ("Cache-Control", "private, max-age=300".to_string()),
            ("Referrer-Policy", "no-referrer".to_string()),
            ("X-Robots-Tag", "noindex, nofollow".to_string()),
            ("X-Content-Type-Options", "nosniff".to_string()),
        ];
        v.extend(extra);
        v
    };
    if headers.get(header::IF_NONE_MATCH).and_then(|v| v.to_str().ok()).is_some_and(|v| dc::etag_matches(v, &etag)) {
        return resp(StatusCode::NOT_MODIFIED, "text/calendar; charset=utf-8", String::new(), &common(vec![]));
    }
    let body = if head { String::new() } else { dc::feed_ics(&list.iter().map(|r| r.ics.clone()).collect::<Vec<_>>(), "ANEXOMAIL") };
    resp(
        StatusCode::OK,
        "text/calendar; charset=utf-8",
        body,
        &common(vec![("Last-Modified", dc::http_date(newest)), ("Content-Disposition", "inline; filename=\"anexomail.ics\"".to_string())]),
    )
}

pub async fn handle(req: Request) -> Response {
    let (parts, body) = req.into_parts();
    let route = dc::parse_route(parts.uri.path());
    let method = parts.method.as_str().to_string();
    if method == "OPTIONS" {
        return resp(StatusCode::OK, "text/plain; charset=utf-8", String::new(), &[("Allow", dc::ALLOWED.to_string())]);
    }
    if !matches!(method.as_str(), "PROPFIND" | "REPORT" | "GET" | "HEAD") {
        return plain(StatusCode::METHOD_NOT_ALLOWED, "This CalDAV server is read-only for now.");
    }
    // secret calendar link: Basic login nahi, sirf GET/HEAD; baqi tamam methods is raaste par 405
    if let dc::Route::Feed(key) = &route {
        return if matches!(method.as_str(), "GET" | "HEAD") {
            feed(&parts.headers, key, method == "HEAD").await
        } else {
            plain(StatusCode::METHOD_NOT_ALLOWED, "A calendar link can only be read.")
        };
    }
    // /dav/feed/... ki ghalat shakal: Basic login ka sawal nahi uthta — seedha 404 (link ka andaza lagane walon ko kuch nahi milta)
    if parts.uri.path().starts_with("/dav/feed") {
        return plain(StatusCode::NOT_FOUND, "Not found.");
    }
    let me = match authed(&parts.headers).await {
        Ok(m) => m,
        Err(r) => return r,
    };
    let bytes = match axum::body::to_bytes(body, dc::MAX_BODY).await {
        Ok(b) => b,
        Err(_) => return plain(StatusCode::PAYLOAD_TOO_LARGE, "Request too large."),
    };
    let text = String::from_utf8_lossy(&bytes).to_string();
    let depth = dc::depth_of(parts.headers.get("depth").and_then(|v| v.to_str().ok()));
    let kids = depth != dc::Depth::Zero; // Infinity bhi 1 ki tarah (hum gehre nahi jaate)
    let _ = &me.user_id;
    match (method.as_str(), route) {
        ("PROPFIND", dc::Route::Root) => {
            let pf = dc::parse_propfind(&text);
            let mut have = principal_props(&me);
            have.retain(|(n, _)| *n == "current-user-principal" || *n == "resourcetype" || *n == "principal-url");
            have.iter_mut().for_each(|(n, v)| if *n == "resourcetype" { *v = coll_type(false) });
            ms(&[one(&pf, "/dav/", have)])
        }
        ("PROPFIND", dc::Route::Principal) => {
            let pf = dc::parse_propfind(&text);
            ms(&[one(&pf, "/dav/p/", principal_props(&me))])
        }
        ("PROPFIND", dc::Route::Home) => {
            let pf = dc::parse_propfind(&text);
            let mut rs = vec![one(&pf, "/dav/p/home/", vec![("resourcetype", coll_type(false)), ("displayname", "Calendars".into()), ("current-user-principal", href_el("/dav/p/"))])];
            if kids {
                rs.push(one(&pf, &dc::href_calendar(CAL_KEY), calendar_props(&me).await));
            }
            ms(&rs)
        }
        ("PROPFIND", dc::Route::Calendar(k)) => {
            if k != CAL_KEY {
                return plain(StatusCode::NOT_FOUND, "No such calendar.");
            }
            let pf = dc::parse_propfind(&text);
            let mut rs = vec![one(&pf, &dc::href_calendar(CAL_KEY), calendar_props(&me).await)];
            if kids {
                let Ok(list) = load(&me).await else { return plain(StatusCode::SERVICE_UNAVAILABLE, "Calendar unavailable.") };
                for r in &list {
                    rs.push(one(&pf, &dc::href_event(CAL_KEY, &r.id), event_props(r, false)));
                }
            }
            ms(&rs)
        }
        ("PROPFIND", dc::Route::Event(k, id)) => {
            if k != CAL_KEY {
                return plain(StatusCode::NOT_FOUND, "No such calendar.");
            }
            let pf = dc::parse_propfind(&text);
            let Ok(list) = load(&me).await else { return plain(StatusCode::SERVICE_UNAVAILABLE, "Calendar unavailable.") };
            match list.iter().find(|r| r.id == id) {
                Some(r) => ms(&[one(&pf, &dc::href_event(CAL_KEY, &id), event_props(r, false))]),
                None => plain(StatusCode::NOT_FOUND, "No such event."),
            }
        }
        ("REPORT", dc::Route::Calendar(k)) => {
            if k != CAL_KEY {
                return plain(StatusCode::NOT_FOUND, "No such calendar.");
            }
            let Ok(list) = load(&me).await else { return plain(StatusCode::SERVICE_UNAVAILABLE, "Calendar unavailable.") };
            let want_data = text.to_ascii_lowercase().contains("calendar-data");
            let pf = dc::PropFind { all: false, names_only: false, props: vec!["getetag".into(), "getcontenttype".into(), "calendar-data".into()] };
            let mut rs = Vec::new();
            match dc::parse_report(&text) {
                dc::Report::Query { from, to } => {
                    for r in &list {
                        // chalne wali series ko hamesha bhejte hain (client khud expand karta hai); baqi time-range se
                        let inside = r.recurring || (from.map(|f| r.to > f).unwrap_or(true) && to.map(|t| r.from < t).unwrap_or(true));
                        if inside {
                            rs.push(one(&pf, &dc::href_event(CAL_KEY, &r.id), event_props(r, want_data)));
                        }
                    }
                }
                dc::Report::Multiget { hrefs } => {
                    for h in hrefs.iter().take(500) {
                        match dc::event_id_from_href(h).and_then(|id| list.iter().find(|r| r.id == id)) {
                            Some(r) => rs.push(one(&pf, &dc::href_event(CAL_KEY, &r.id), event_props(r, true))),
                            None => {}
                        }
                    }
                }
                dc::Report::Unsupported(n) => {
                    return plain(StatusCode::FORBIDDEN, &format!("Report '{}' is not supported yet (read-only phase).", n.chars().take(40).collect::<String>()));
                }
            }
            ms(&rs)
        }
        ("GET" | "HEAD", dc::Route::Event(k, id)) => {
            if k != CAL_KEY {
                return plain(StatusCode::NOT_FOUND, "No such calendar.");
            }
            let Ok(list) = load(&me).await else { return plain(StatusCode::SERVICE_UNAVAILABLE, "Calendar unavailable.") };
            match list.into_iter().find(|r| r.id == id) {
                Some(r) => {
                    let body = if method == "HEAD" { String::new() } else { r.ics };
                    resp(StatusCode::OK, "text/calendar; charset=utf-8", body, &[("ETag", r.etag), ("Last-Modified", dc::http_date(r.modified.max(0)))])
                }
                None => plain(StatusCode::NOT_FOUND, "No such event."),
            }
        }
        (_, dc::Route::NotFound) => plain(StatusCode::NOT_FOUND, "Not found."),
        _ => plain(StatusCode::METHOD_NOT_ALLOWED, "Not allowed on this resource."),
    }
}

async fn calendar_props(me: &Dav) -> Vec<(&'static str, String)> {
    let ctag = crate::sb_rpc("caldav_ctag", json!({ "p_org": me.org_id })).await.ok().and_then(|v| v.as_i64()).unwrap_or(1);
    vec![
        ("resourcetype", coll_type(true)),
        ("displayname", "ANEXOMAIL".into()),
        ("getctag", ctag.to_string()),
        ("supported-calendar-component-set", "<C:comp name=\"VEVENT\"/>".into()),
        ("supported-report-set", "<D:supported-report><D:report><C:calendar-query/></D:report></D:supported-report><D:supported-report><D:report><C:calendar-multiget/></D:report></D:supported-report>".into()),
        ("current-user-privilege-set", "<D:privilege><D:read/></D:privilege>".into()),
        ("owner", href_el("/dav/p/")),
    ]
}
