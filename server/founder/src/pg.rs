//! QCONNECT step 6 (20 Nov 2026): the LOCAL database engine of `Sb`. PostgreSQL 18 on the same server, unix socket only, pooled tokio-postgres (deadpool).
//! Same answers as the REST door (PostgREST) so no caller changes: rpc -> JSON value, rows -> JSON array, count -> i64, errors -> (status, message).
//! Chosen at start by env FOUNDER_DB=local (+ FOUNDER_PG_URL); without it the binary stays on REST exactly as before.
//! Safety: identifiers are NEVER taken from the caller's text. Function names, argument names, table names and column names are looked up in the catalog first (cached) and quoted; every VALUE is a bound parameter.
use deadpool_postgres::{Manager, ManagerConfig, Pool, RecyclingMethod};
use serde_json::{json, Value};
use std::collections::HashMap;
use std::sync::RwLock;
use tokio_postgres::NoTls;

#[derive(Clone, Debug)]
struct Arg { name: String, ty: String, has_default: bool, is_json: bool, is_array: bool }
#[derive(Clone, Debug)]
struct Proc { args: Vec<Arg>, set: bool, void: bool }

pub struct Pg { pool: Pool, procs: RwLock<HashMap<String, Vec<Proc>>>, cols: RwLock<HashMap<String, HashMap<String, String>>>, sql: RwLock<HashMap<String, String>> }

/// service_role is what PostgREST uses for the service key; the session is opened AS that role, with the same JWT claim, so every SQL door sees the same caller as before.
fn cfg_from(url: &str) -> Result<tokio_postgres::Config, String> {
    let mut c: tokio_postgres::Config = url.parse().map_err(|e: tokio_postgres::Error| e.to_string())?;
    c.options("-c role=service_role -c statement_timeout=8000 -c idle_in_transaction_session_timeout=8000 -c request.jwt.claims={\"role\":\"service_role\"}");
    c.application_name("anexomail-founder");
    Ok(c)
}

impl Pg {
    pub async fn connect(url: &str, size: usize) -> Result<Pg, String> {
        let mgr = Manager::from_config(cfg_from(url)?, NoTls, ManagerConfig { recycling_method: RecyclingMethod::Fast });
        let pool = Pool::builder(mgr).max_size(size.clamp(2, 64)).build().map_err(|e| e.to_string())?;
        let me = Pg { pool, procs: RwLock::new(HashMap::new()), cols: RwLock::new(HashMap::new()), sql: RwLock::new(HashMap::new()) };
        me.pool.get().await.map_err(|e| e.to_string())?.query_one("select 1", &[]).await.map_err(|e| e.to_string())?;
        Ok(me)
    }

    /// Catalog: every overload of public.<name> with its argument names and types (once, cached).
    async fn load_proc(&self, name: &str) -> Result<Vec<Proc>, (u16, String)> {
        if let Some(p) = self.procs.read().unwrap().get(name) { return Ok(p.clone()); }
        let c = self.pool.get().await.map_err(|e| (0u16, format!("database unreachable: {e}")))?;
        let rows = c.query(
            "select coalesce(p.proargnames, '{}'::text[]) as names, \
                    coalesce((select array_agg(format_type(t, null) order by o) from unnest(coalesce(p.proallargtypes::oid[], p.proargtypes::oid[])) with ordinality u(t, o)), '{}'::text[]) as types, \
                    coalesce(p.proargmodes::text[], '{}'::text[]) as modes, p.pronargs::int as nargs, p.pronargdefaults::int as ndef, p.proretset as retset, (p.prorettype = 'void'::regtype) as isvoid \
               from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = $1 and p.prokind = 'f'", &[&name]).await.map_err(|e| (500u16, e.to_string()))?;
        let mut out = vec![];
        for r in rows {
            let names: Vec<String> = r.get("names"); let types: Vec<String> = r.get("types"); let modes: Vec<String> = r.get("modes");
            let nargs: i32 = r.get("nargs"); let ndef: i32 = r.get("ndef");
            let mut args = vec![]; let mut seen = 0i32;
            for (i, ty) in types.iter().enumerate() {
                let mode = modes.get(i).map(|s| s.as_str()).unwrap_or("i");
                if mode != "i" && mode != "b" && mode != "v" { continue; }
                let nm = names.get(i).cloned().unwrap_or_default(); if nm.is_empty() { continue; }
                seen += 1;
                args.push(Arg { name: nm, ty: ty.clone(), has_default: seen > nargs - ndef, is_json: ty == "jsonb" || ty == "json", is_array: ty.ends_with("[]") });
            }
            out.push(Proc { args, set: r.get("retset"), void: r.get("isvoid") });
        }
        self.procs.write().unwrap().insert(name.to_string(), out.clone());
        Ok(out)
    }

    /// PostgREST rule: the overload whose argument names cover all keys of the body and whose non-default arguments are all given.
    fn pick<'a>(procs: &'a [Proc], keys: &[String]) -> Option<&'a Proc> {
        procs.iter().filter(|p| keys.iter().all(|k| p.args.iter().any(|a| &a.name == k)) && p.args.iter().all(|a| a.has_default || keys.contains(&a.name))).min_by_key(|p| p.args.len())
    }

    fn arg_expr(a: &Arg) -> String {
        let n = a.name.replace('\'', "''");
        if a.is_json { format!("($1::jsonb -> '{n}')::{}", a.ty) }
        else if a.is_array { format!("(select array_agg(x) from jsonb_array_elements_text($1::jsonb -> '{n}') x)::{}", a.ty) }
        else { format!("($1::jsonb ->> '{n}')::{}", a.ty) }
    }

    /// Build (or fetch) the one SQL text for this function and this set of given keys.
    async fn rpc_sql(&self, name: &str, body: &Value) -> Result<String, (u16, String)> {
        if name.is_empty() || !name.chars().all(|c| c.is_ascii_alphanumeric() || c == '_') { return Err((404, "no such function".into())); }
        let mut keys: Vec<String> = body.as_object().map(|o| o.keys().cloned().collect()).unwrap_or_default(); keys.sort();
        let ck = format!("{name}({})", keys.join(","));
        if let Some(s) = self.sql.read().unwrap().get(&ck) { return Ok(s.clone()); }
        let procs = self.load_proc(name).await?;
        let p = Self::pick(&procs, &keys).ok_or((404u16, "The requested function was not found in the schema cache (PGRST202)".to_string()))?;
        let call = format!("public.\"{name}\"({})", keys.iter().map(|k| { let a = p.args.iter().find(|a| &a.name == k).unwrap(); format!("\"{}\" => {}", a.name.replace('"', "\"\""), Self::arg_expr(a)) }).collect::<Vec<_>>().join(", "));
        let s = if p.void { format!("select 'null'::jsonb from (select {call}) _v") }
                else if p.set { format!("select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) from {call} t") }
                else { format!("select coalesce(to_jsonb({call}), 'null'::jsonb)") };
        self.sql.write().unwrap().insert(ck, s.clone());
        Ok(s)
    }

    /// Same contract as PostgREST /rpc/<name>: Ok(JSON value) or Err((HTTP status, message)); status 0 = the database is unreachable.
    pub async fn rpc(&self, name: &str, body: &Value) -> Result<Value, (u16, String)> {
        let sql = self.rpc_sql(name, body).await?;
        let c = self.pool.get().await.map_err(|e| (0u16, format!("database unreachable: {e}")))?;
        let st = c.prepare_cached(&sql).await.map_err(map_err)?;
        let row = c.query_one(&st, &[&if body.is_object() { body.clone() } else { json!({}) }]).await.map_err(map_err)?;
        Ok(row.get::<_, Value>(0))
    }

    async fn col_types(&self, table: &str) -> Result<HashMap<String, String>, (u16, String)> {
        if let Some(t) = self.cols.read().unwrap().get(table) { return Ok(t.clone()); }
        let c = self.pool.get().await.map_err(|e| (0u16, format!("database unreachable: {e}")))?;
        let rows = c.query("select a.attname::text, format_type(a.atttypid, null) from pg_attribute a join pg_class k on k.oid = a.attrelid join pg_namespace n on n.oid = k.relnamespace where n.nspname = 'public' and k.relname = $1 and k.relkind in ('r','v','m','p') and a.attnum > 0 and not a.attisdropped", &[&table]).await.map_err(map_err)?;
        let m: HashMap<String, String> = rows.iter().map(|r| (r.get::<_, String>(0), r.get::<_, String>(1))).collect();
        if m.is_empty() { return Err((404, format!("relation {table} does not exist"))); }
        self.cols.write().unwrap().insert(table.to_string(), m.clone());
        Ok(m)
    }

    /// PostgREST read: `table?select=a,b&col=eq.v&col=in.(x,y)&col=is.null&order=a.desc,b&limit=n`  -> JSON array.
    pub async fn rows(&self, path: &str) -> Result<Vec<Value>, (u16, String)> {
        let table = path.split('?').next().unwrap_or("").to_string();
        let types = self.col_types(&table).await?;
        let (sql, params) = translate(path, &types, false)?;
        let c = self.pool.get().await.map_err(|e| (0u16, format!("database unreachable: {e}")))?;
        let st = c.prepare_cached(&sql).await.map_err(map_err)?;
        let ps: Vec<&(dyn tokio_postgres::types::ToSql + Sync)> = params.iter().map(|p| p as &(dyn tokio_postgres::types::ToSql + Sync)).collect();
        let row = c.query_one(&st, &ps).await.map_err(map_err)?;
        Ok(match row.get::<_, Value>(0) { Value::Array(a) => a, _ => vec![] })
    }

    pub async fn count(&self, path: &str) -> Result<i64, (u16, String)> {
        let table = path.split('?').next().unwrap_or("").to_string();
        let types = self.col_types(&table).await?;
        let (sql, params) = translate(path, &types, true)?;
        let c = self.pool.get().await.map_err(|e| (0u16, format!("database unreachable: {e}")))?;
        let st = c.prepare_cached(&sql).await.map_err(map_err)?;
        let ps: Vec<&(dyn tokio_postgres::types::ToSql + Sync)> = params.iter().map(|p| p as &(dyn tokio_postgres::types::ToSql + Sync)).collect();
        Ok(c.query_one(&st, &ps).await.map_err(map_err)?.get::<_, i64>(0))
    }

    /// A tiny read that keeps one pooled connection warm and proves the socket answers.
    pub async fn ping(&self) -> bool { match self.pool.get().await { Ok(c) => c.query_one("select 1", &[]).await.is_ok(), Err(_) => false } }
}

/// The same HTTP status PostgREST would answer for a database error (raise exception = 400 with the message; unique = 409; no right = 403; no function = 404).
fn map_err(e: tokio_postgres::Error) -> (u16, String) {
    match e.as_db_error() {
        Some(d) => {
            let code = d.code().code();
            let st = match code { "P0001" => 400, "23505" => 409, c if c.starts_with("23") => 409, "42501" => 403, "42883" | "42P01" => 404, c if c.starts_with("22") => 400, _ => 500 };
            (st, d.message().to_string())
        }
        None => (0, "database unreachable".to_string()),
    }
}

fn pct(s: &str) -> String {
    let b = s.as_bytes(); let mut o = Vec::with_capacity(b.len()); let mut i = 0;
    while i < b.len() {
        if b[i] == b'%' && i + 2 < b.len() { if let Some(v) = std::str::from_utf8(&b[i + 1..i + 3]).ok().and_then(|h| u8::from_str_radix(h, 16).ok()) { o.push(v); i += 3; continue; } }
        o.push(b[i]); i += 1;
    }
    String::from_utf8_lossy(&o).into_owned()
}

fn ident(types: &HashMap<String, String>, c: &str) -> Result<String, (u16, String)> {
    if types.contains_key(c) { Ok(format!("\"{}\"", c.replace('"', "\"\""))) } else { Err((400, format!("column {c} does not exist"))) }
}

/// PostgREST subset -> (SQL, bound text parameters). Pure: unit tested without a database. Every value is `$n::text` cast to the column's real type, every identifier must exist in the catalog map.
pub fn translate(path: &str, types: &HashMap<String, String>, count: bool) -> Result<(String, Vec<String>), (u16, String)> {
    let (table, query) = path.split_once('?').unwrap_or((path, ""));
    if table.is_empty() || !table.chars().all(|c| c.is_ascii_alphanumeric() || c == '_') { return Err((404, "bad table".into())); }
    let mut sel = "*".to_string(); let mut order = String::new(); let mut limit = String::new(); let mut offset = String::new();
    let mut wh: Vec<String> = vec![]; let mut params: Vec<String> = vec![];
    for kv in query.split('&').filter(|s| !s.is_empty()) {
        let (k, v) = kv.split_once('=').unwrap_or((kv, "")); let (k, v) = (pct(k), pct(v));
        match k.as_str() {
            "select" => { if v != "*" { sel = v.split(',').map(|c| ident(types, c.trim())).collect::<Result<Vec<_>, _>>()?.join(", "); } }
            "order" => { order = v.split(',').map(|o| { let mut it = o.split('.'); let c = it.next().unwrap_or(""); let dir = match it.next() { Some("desc") => " desc", Some("asc") | None => "", _ => return Err((400, "bad order".to_string())) }; Ok(format!("{}{}", ident(types, c)?, dir)) }).collect::<Result<Vec<_>, (u16, String)>>()?.join(", "); }
            "limit" => { limit = v.parse::<u32>().map_err(|_| (400u16, "bad limit".to_string()))?.min(10_000).to_string(); }
            "offset" => { offset = v.parse::<u32>().map_err(|_| (400u16, "bad offset".to_string()))?.to_string(); }
            col => {
                let id = ident(types, col)?; let ty = types.get(col).cloned().unwrap_or_default();
                let (op, rest) = v.split_once('.').ok_or((400u16, "bad filter".to_string()))?;
                let mut bind = |val: &str| -> String { params.push(val.to_string()); format!("(${}::text)::{}", params.len(), ty) };
                let cond = match op {
                    "eq" => format!("{id} = {}", bind(rest)), "neq" => format!("{id} <> {}", bind(rest)),
                    "gt" => format!("{id} > {}", bind(rest)), "gte" => format!("{id} >= {}", bind(rest)), "lt" => format!("{id} < {}", bind(rest)), "lte" => format!("{id} <= {}", bind(rest)),
                    "is" => match rest { "null" => format!("{id} is null"), "true" => format!("{id} is true"), "false" => format!("{id} is false"), _ => return Err((400, "bad is".into())) },
                    "in" => { let inner = rest.strip_prefix('(').and_then(|r| r.strip_suffix(')')).ok_or((400u16, "bad in".to_string()))?; let items: Vec<String> = inner.split(',').map(|x| bind(x.trim().trim_matches('"'))).collect(); if items.is_empty() { "false".to_string() } else { format!("{id} in ({})", items.join(", ")) } }
                    _ => return Err((400, format!("operator {op} not supported"))),
                };
                wh.push(cond);
            }
        }
    }
    let w = if wh.is_empty() { String::new() } else { format!(" where {}", wh.join(" and ")) };
    let o = if order.is_empty() { String::new() } else { format!(" order by {order}") };
    let l = if limit.is_empty() { String::new() } else { format!(" limit {limit}") };
    let f = if offset.is_empty() { String::new() } else { format!(" offset {offset}") };
    let sql = if count { format!("select count(*)::bigint from public.\"{table}\"{w}") } else { format!("select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb) from (select {sel} from public.\"{table}\"{w}{o}{l}{f}) r") };
    Ok((sql, params))
}

#[cfg(test)]
mod tests {
    use super::*;
    fn ty() -> HashMap<String, String> { [("user_id", "uuid"), ("revoked_at", "timestamp with time zone"), ("seq", "bigint"), ("key", "text"), ("state", "text"), ("month", "date")].iter().map(|(a, b)| (a.to_string(), b.to_string())).collect() }
    #[test] fn eq_limit_select() { let (s, p) = translate("founder_accounts?select=user_id&user_id=eq.abc&limit=1", &ty(), false).unwrap(); assert!(s.contains("select \"user_id\" from public.\"founder_accounts\" where \"user_id\" = ($1::text)::uuid limit 1")); assert_eq!(p, vec!["abc"]); }
    #[test] fn in_is_order() { let (s, p) = translate("mail_outbox?select=seq&state=in.(queued,failed)&revoked_at=is.null&order=seq.desc,key", &ty(), true).unwrap(); assert!(s.starts_with("select count(*)::bigint")); assert!(s.contains("in (($1::text)::text, ($2::text)::text)") && s.contains("\"revoked_at\" is null")); assert_eq!(p, vec!["queued", "failed"]); let (s2, _) = translate("t?order=seq.desc,key", &ty(), false).unwrap(); assert!(s2.contains("order by \"seq\" desc, \"key\"")); }
    #[test] fn injection_is_refused() {
        assert!(translate("t?select=seq;drop table x", &ty(), false).is_err());
        assert!(translate("t;drop?select=seq", &ty(), false).is_err());
        assert!(translate("t?nope=eq.1", &ty(), false).is_err());
        assert!(translate("t?seq=eq.1%27%20or%201=1--", &ty(), false).is_ok(), "a value is only ever a bound parameter");
        let (s, p) = translate("t?key=eq.1' or 1=1--", &ty(), false).unwrap(); assert!(!s.contains("or 1=1") && p[0].contains("or 1=1"));
        assert!(translate("t?seq=like.*a", &ty(), false).is_err());
    }
    #[test] fn pick_overload_by_names() {
        let a = Proc { args: vec![Arg { name: "p_uid".into(), ty: "uuid".into(), has_default: false, is_json: false, is_array: false }], set: false, void: false };
        let b = Proc { args: vec![Arg { name: "p_uid".into(), ty: "uuid".into(), has_default: false, is_json: false, is_array: false }, Arg { name: "p_n".into(), ty: "integer".into(), has_default: true, is_json: false, is_array: false }], set: false, void: false };
        let v = vec![a, b]; assert_eq!(Pg::pick(&v, &["p_uid".into()]).unwrap().args.len(), 1); assert_eq!(Pg::pick(&v, &["p_n".into(), "p_uid".into()]).unwrap().args.len(), 2); assert!(Pg::pick(&v, &["p_x".into()]).is_none());
    }
}

/// Real-database proof (sandbox + his server): `PG_TEST_URL=postgresql://postgres@/anexo_q?host=/tmp&port=5546 cargo test pg_live -- --ignored`. Creates temp functions/tables in a schema-free way (public, dropped at the end).
#[cfg(test)]
mod live {
    use super::*;
    #[tokio::test] #[ignore]
    async fn pg_live_same_answers_as_rest() {
        let url = std::env::var("PG_TEST_URL").expect("PG_TEST_URL");
        let admin = { let (c, conn) = tokio_postgres::connect(&url, NoTls).await.unwrap(); tokio::spawn(conn); c };
        admin.batch_execute("
          drop table if exists qt_t cascade; create table qt_t(id uuid primary key default gen_random_uuid(), name text, n bigint, gone timestamptz, tags text[]);
          insert into qt_t(name,n,gone) values ('a',1,null),('b',2,now()),('c',3,null);
          grant select on qt_t to service_role;
          create or replace function public.qt_scalar(p_a int, p_b text default 'x') returns jsonb language sql as $$ select jsonb_build_object('a',p_a,'b',p_b) $$;
          create or replace function public.qt_set(p_min bigint) returns table(name text, n bigint) language sql as $$ select name, n from qt_t where n >= p_min order by n $$;
          create or replace function public.qt_void(p_x text) returns void language plpgsql as $$ begin perform 1; end $$;
          create or replace function public.qt_boom(p_x text) returns int language plpgsql as $$ begin raise exception 'plain words for the founder'; end $$;
          create or replace function public.qt_arr(p_ids text[], p_j jsonb) returns jsonb language sql as $$ select jsonb_build_object('n', cardinality(p_ids), 'j', p_j) $$;
          create or replace function public.qt_bool(p_x text) returns boolean language sql as $$ select p_x = 'yes' $$;
          grant execute on all functions in schema public to service_role;").await.unwrap();
        let pg = Pg::connect(&url, 4).await.unwrap();
        assert_eq!(pg.rpc("qt_scalar", &json!({"p_a": 7})).await.unwrap(), json!({"a": 7, "b": "x"}), "default argument is used when the key is missing");
        assert_eq!(pg.rpc("qt_scalar", &json!({"p_a": 7, "p_b": "y"})).await.unwrap(), json!({"a": 7, "b": "y"}));
        assert_eq!(pg.rpc("qt_set", &json!({"p_min": 2})).await.unwrap(), json!([{"name": "b", "n": 2}, {"name": "c", "n": 3}]));
        assert_eq!(pg.rpc("qt_void", &json!({"p_x": "z"})).await.unwrap(), Value::Null);
        assert_eq!(pg.rpc("qt_bool", &json!({"p_x": "yes"})).await.unwrap(), json!(true));
        assert_eq!(pg.rpc("qt_arr", &json!({"p_ids": ["a", "b"], "p_j": {"k": [1, 2]}})).await.unwrap(), json!({"n": 2, "j": {"k": [1, 2]}}));
        assert_eq!(pg.rpc("qt_boom", &json!({"p_x": "z"})).await.unwrap_err(), (400, "plain words for the founder".to_string()), "raise exception = 400 + the message, like PostgREST");
        assert_eq!(pg.rpc("qt_nope", &json!({})).await.unwrap_err().0, 404);
        assert_eq!(pg.rpc("qt_scalar", &json!({"p_zzz": 1})).await.unwrap_err().0, 404, "unknown argument name = not found, like PGRST202");
        assert_eq!(pg.rpc("qt_scalar", &json!({"p_a": 1})).await.is_ok(), true);
        let r = pg.rows("qt_t?select=name,n&n=in.(1,3)&order=n.desc").await.unwrap(); assert_eq!(r, vec![json!({"name": "c", "n": 3}), json!({"name": "a", "n": 1})]);
        assert_eq!(pg.rows("qt_t?select=name&gone=is.null&order=name&limit=1").await.unwrap(), vec![json!({"name": "a"})]);
        assert_eq!(pg.count("qt_t?select=id&gone=is.null").await.unwrap(), 2);
        assert_eq!(pg.rows("qt_t?select=name&name=eq.a%27%20or%20%271%27=%271").await.unwrap().len(), 0, "an injection string is only a value");
        assert!(pg.rows("qt_t?select=nope").await.is_err()); assert!(pg.rows("no_such_table?select=x").await.is_err());
        let me = pg.pool.get().await.unwrap().query_one("select current_user::text, current_setting('request.jwt.claims')", &[]).await.unwrap();
        assert_eq!(me.get::<_, String>(0), "service_role"); assert!(me.get::<_, String>(1).contains("service_role"));
        let t0 = std::time::Instant::now(); for _ in 0..200 { pg.rpc("qt_bool", &json!({"p_x": "yes"})).await.unwrap(); } let per = t0.elapsed().as_micros() / 200; eprintln!("pg_live: {per} us per rpc over the socket"); assert!(per < 5000);
        admin.batch_execute("drop function qt_scalar(int,text), qt_set(bigint), qt_void(text), qt_boom(text), qt_arr(text[],jsonb), qt_bool(text); drop table qt_t").await.unwrap();
    }
}
