// ANEXOMAIL ADMIN DESK packages.rs (D5a-2, 22 Nov 2026): READ doors for the package registry (SQL AD6 + AD6b). Rust + Axum + Tokio; sealed router (Rule 52: Desk-signed
// answer, request MAC, replay nonce) and a live Desk session. Data comes only through desk.fadm_pkg_current / fadm_pkg_versions (desk_app has no table right).
// Features and limits only: no price, no money word exists in the registry. Desk-only: no founder or awam code.
use crate::bridge::owner;
use crate::door::rows;
use axum::{extract::Path, http::{header, HeaderMap, StatusCode}, response::{IntoResponse, Response}};

/// The seven packages the landing page publishes (src/lib/plans.ts); the registry table is not readable by desk_app, so the list is fixed here.
pub const PACKAGES: [&str; 7] = ["basic", "pro", "business", "business_pro", "ai_pro", "ai_business", "ai_executive"];
pub fn valid_id(s: &str) -> bool { PACKAGES.contains(&s) }
fn out(status: StatusCode, body: String) -> Response { (status, [(header::CONTENT_TYPE, "application/json")], body).into_response() }
fn err(status: StatusCode, e: &str) -> Response { out(status, serde_json::json!({"error": e}).to_string()) }

/// GET /desk/v1/packages: the current version of every package.
pub async fn list(h: HeaderMap) -> Response {
    let (c, _o) = match owner(&h).await { Ok(x) => x, Err(r) => return r };
    let ids = PACKAGES.iter().map(|p| format!("'{p}'")).collect::<Vec<_>>().join(",");
    let q = format!("select coalesce(jsonb_agg(to_jsonb(t) order by array_position(array[{ids}], t.pkg_id)), '[]'::jsonb)::text from (select p.id, (desk.fadm_pkg_current(p.id)).* from unnest(array[{ids}]) as p(id)) t");
    answer(rows(&c, &q).await)
}
/// GET /desk/v1/packages/{id}: the current version and every version of one package.
pub async fn one(h: HeaderMap, Path(id): Path<String>) -> Response {
    if !valid_id(&id) { return err(StatusCode::NOT_FOUND, "not_found"); }
    let (c, _o) = match owner(&h).await { Ok(x) => x, Err(r) => return r };
    let q = format!("select jsonb_build_object('current', (select to_jsonb(t) from desk.fadm_pkg_current('{id}') t), 'versions', (select coalesce(jsonb_agg(to_jsonb(v)), '[]'::jsonb) from desk.fadm_pkg_versions('{id}') v))::text");
    answer(rows(&c, &q).await)
}
fn answer(r: Result<Vec<tokio_postgres::SimpleQueryRow>, tokio_postgres::Error>) -> Response {
    match r {
        Ok(v) => out(StatusCode::OK, v.first().and_then(|r| r.get(0)).unwrap_or("null").to_string()),
        Err(e) => { eprintln!("desk packages: db: {e}"); err(StatusCode::SERVICE_UNAVAILABLE, "db_unavailable") }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn only_published_ids_pass() {
        for p in PACKAGES { assert!(valid_id(p)); }
        for bad in ["", "Basic", "basic'; drop table x;--", "../pro", "enterprise"] { assert!(!valid_id(bad), "{bad}"); }
    }
    /// Rust -> PostgreSQL on the scratch database (needs DESK_TEST_ADMIN_URL; skipped otherwise): no session = 401, session = all seven packages and the version history.
    #[tokio::test] async fn database_doors_need_a_session_and_return_the_registry() {
        let Ok(admin) = std::env::var("DESK_TEST_ADMIN_URL") else { eprintln!("no DESK_TEST_ADMIN_URL: skipped"); return; };
        let (a, conn) = tokio_postgres::connect(&admin, tokio_postgres::NoTls).await.unwrap(); tokio::spawn(conn);
        let hx = |b: &[u8]| b.iter().map(|x| format!("{x:02x}")).collect::<String>();
        let sfx = hx(&crate::auth::token_hash(&format!("{:?}", std::time::SystemTime::now()))[..4]);
        let h = "$argon2id$v=19$m=19456,t=2,p=1$c2VsZnRlc3Q$c2VsZnRlc3RoYXNo";
        let o = rows(&a, &format!("insert into desk.fadm_owner (email, display_name, role, pw_hash) values ('pk-{sfx}@selftest.invalid','T Pk','owner','{h}') returning id::text")).await.unwrap()[0].get(0).unwrap().to_string();
        let t = format!("{sfx}{}", "ab".repeat(28));
        rows(&a, &format!("select desk.fadm_session_create('{o}'::uuid, '\\x{}'::bytea, 600)::text", hx(&crate::auth::token_hash(&t)))).await.unwrap();
        rows(&a, "alter role desk_app login password 'scratch'").await.unwrap();
        let url = format!("postgres://desk_app:scratch@{}/anexo_desk?sslmode=disable", admin.split('@').next_back().unwrap().split('/').next().unwrap());
        unsafe { std::env::set_var("DESK_APP_URL", &url); }
        let body = |r: Response| async move { let st = r.status(); let b = axum::body::to_bytes(r.into_body(), 1 << 22).await.unwrap(); (st, serde_json::from_slice::<serde_json::Value>(&b).unwrap_or_default()) };
        let (st, _) = body(list(HeaderMap::new()).await).await; assert_eq!(st, StatusCode::UNAUTHORIZED);
        let mut hd = HeaderMap::new(); hd.insert(header::AUTHORIZATION, format!("Bearer {t}").parse().unwrap());
        let (st, v) = body(list(hd.clone()).await).await; assert_eq!(st, StatusCode::OK, "{v}");
        let arr = v.as_array().unwrap(); assert_eq!(arr.len(), 7); assert_eq!(arr[0]["pkg_id"], "basic"); assert_eq!(arr[6]["pkg_id"], "ai_executive");
        assert_eq!(arr[3]["limits"]["seats"], 570); assert_eq!(arr[0]["grace_days"], 3);
        let (st, v) = body(one(hd.clone(), Path("pro".into())).await).await; assert_eq!(st, StatusCode::OK); assert_eq!(v["current"]["pkg_id"], "pro"); assert!(!v["versions"].as_array().unwrap().is_empty());
        let (st, _) = body(one(hd, Path("enterprise".into())).await).await; assert_eq!(st, StatusCode::NOT_FOUND);
    }
}
