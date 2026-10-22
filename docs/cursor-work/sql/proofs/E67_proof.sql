-- E67 behaviour proof (sandbox ONLY, rollback). Chalao: cd docs/cursor-work/sql/proofs && psql -v ON_ERROR_STOP=1 -f E67_proof.sql
begin;
create temp table r (ord int, item text, ok boolean) on commit drop;
do $$
declare
  u uuid := gen_random_uuid(); id1 uuid; raised boolean; found record; ok boolean; cnt int;
  hm bytea := decode(repeat('ab', 32), 'hex'); blob bytea := decode(repeat('cd', 40), 'hex');
begin
  insert into auth.users (id) values (u);
  insert into public.passkey_vault (user_id, cred_hmac, enc, device_name, transports, backup_eligible)
    values (u, hm, blob, 'My laptop', array['internal','hybrid'], true) returning id into id1;
  select * into found from public.passkey_vault_find(hm);
  insert into r values (1, 'blind index se row mili, enc wahi blob', found.id = id1 and found.user_id = u and found.enc = blob);
  insert into r values (2, 'ghalat hmac par kuch nahi', not exists (select 1 from public.passkey_vault_find(decode(repeat('00', 32), 'hex'))));

  ok := public.passkey_vault_bump(id1, 5);
  insert into r values (3, 'counter 0 -> 5 manzoor', ok and (select sign_count from public.passkey_vault where id = id1) = 5);
  ok := public.passkey_vault_bump(id1, 5);
  insert into r values (4, 'wahi counter dobara = replay/clone => FALSE', not ok);
  ok := public.passkey_vault_bump(id1, 3);
  insert into r values (5, 'counter peechhe = FALSE, value nahi badli', not ok and (select sign_count from public.passkey_vault where id = id1) = 5);
  ok := public.passkey_vault_bump(id1, 6);
  insert into r values (6, 'counter aage = TRUE', ok);

  raised := false; begin perform public.passkey_vault_bump(id1, -1); exception when sqlstate '22023' then raised := true; end;
  insert into r values (7, 'negative counter => bad_counter', raised);

  raised := false; begin insert into public.passkey_vault (user_id, cred_hmac, enc) values (u, decode(repeat('01', 31), 'hex'), blob); exception when check_violation then raised := true; end;
  insert into r values (8, 'chhota hmac (31 byte) mana', raised);
  raised := false; begin insert into public.passkey_vault (user_id, cred_hmac, enc) values (u, decode(repeat('02', 32), 'hex'), decode('00', 'hex')); exception when check_violation then raised := true; end;
  insert into r values (9, 'bahut chhota enc (nonce+tag se kam) mana', raised);
  raised := false; begin insert into public.passkey_vault (user_id, cred_hmac, enc) values (u, hm, blob); exception when unique_violation then raised := true; end;
  insert into r values (10, 'wahi credential dobara mana (unique blind index)', raised);
  raised := false; begin insert into public.passkey_vault (user_id, cred_hmac, enc, transports) values (u, decode(repeat('03', 32), 'hex'), blob, array['carrier-pigeon']); exception when check_violation then raised := true; end;
  insert into r values (11, 'anjaan transport mana', raised);
  raised := false; begin insert into public.passkey_vault (user_id, cred_hmac, enc, backup_eligible, backup_state) values (u, decode(repeat('04', 32), 'hex'), blob, false, true); exception when check_violation then raised := true; end;
  insert into r values (12, 'backup_state bina backup_eligible mana', raised);
  raised := false; begin insert into public.passkey_vault (user_id, cred_hmac, enc, device_name) values (u, decode(repeat('05', 32), 'hex'), blob, E'bad\nname'); exception when check_violation then raised := true; end;
  insert into r values (13, 'device_name mein control char mana', raised);

  insert into r values (14, 'list sirf metadata (enc / cred_hmac ke column nahi)',
    (select count(*) from public.passkey_vault_list(u)) = 1
    and not (select proargnames && array['enc', 'cred_hmac'] from pg_proc where proname = 'passkey_vault_list'));
  insert into r values (15, 'anon/authenticated ke haq nahi; service_role ke hain',
    not has_table_privilege('authenticated', 'public.passkey_vault', 'select') and not has_table_privilege('anon', 'public.passkey_vault', 'insert')
    and not has_function_privilege('authenticated', 'public.passkey_vault_find(bytea)', 'execute')
    and has_function_privilege('service_role', 'public.passkey_vault_bump(uuid,bigint)', 'execute'));
  insert into r values (16, 'RLS ON', (select relrowsecurity from pg_class where oid = 'public.passkey_vault'::regclass));
  delete from auth.users where id = u;
  select count(*) into cnt from public.passkey_vault where user_id = u;
  insert into r values (17, 'account delete => passkeys khud mit gaye (CASCADE)', cnt = 0);
end $$;
select ord, item, ok from r order by ord;
rollback;
