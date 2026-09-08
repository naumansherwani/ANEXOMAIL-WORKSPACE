-- PHASE 60 — founder + family ka real shared ANEXOChat workspace.
-- Idempotent: existing chats/messages delete ya move nahi hotay.

create or replace function public.family_chat_workspace_apply()
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  founder_id uuid;
  humza_id uuid;
  raana_id uuid;
  ws uuid;
  founder_humza uuid;
  founder_raana uuid;
begin
  select id into founder_id from auth.users
   where lower(email) = 'naumansherwani.founder@anexomail.com' limit 1;
  select id into humza_id from auth.users
   where lower(email) = 'humzasherwani@anexomail.com' limit 1;
  select id into raana_id from auth.users
   where lower(email) = 'raanasherwani@anexomail.com' limit 1;

  if founder_id is null or humza_id is null or raana_id is null then
    return jsonb_build_object('ok', false, 'reason', 'founder_family_auth_users_missing');
  end if;
  if not public.chat_access(founder_id)
     or not public.chat_access(humza_id)
     or not public.chat_access(raana_id) then
    return jsonb_build_object('ok', false, 'reason', 'founder_family_chat_access_missing');
  end if;

  select w.id into ws
    from public.chat_workspaces w
   where w.owner_user_id = founder_id and w.name = 'ANEXOMAIL Family'
   order by w.created_at
   limit 1;
  if ws is null then
    insert into public.chat_workspaces (name, owner_user_id)
    values ('ANEXOMAIL Family', founder_id)
    returning id into ws;
  end if;

  insert into public.chat_members (workspace_id, user_id, display_name, role) values
    (ws, founder_id, 'Muhammad Nauman Sherwani', 'owner'),
    (ws, humza_id, 'Humza Sherwani', 'member'),
    (ws, raana_id, 'Raana Sherwani', 'member')
  on conflict (workspace_id, user_id) do update
    set display_name = excluded.display_name,
        role = excluded.role;

  founder_humza := public.chat_direct_conversation(ws, founder_id, humza_id);
  founder_raana := public.chat_direct_conversation(ws, founder_id, raana_id);

  return jsonb_build_object(
    'ok', true,
    'workspace_id', ws,
    'members', 3,
    'founder_humza_conversation_id', founder_humza,
    'founder_raana_conversation_id', founder_raana
  );
end $$;

revoke all on function public.family_chat_workspace_apply() from public, anon, authenticated;
grant execute on function public.family_chat_workspace_apply() to service_role;

-- Shared family workspace ko in teen accounts ke solo workspace se pehle kholo.
create or replace function public.chat_ensure_workspace(_user uuid, _name text default 'Workspace')
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare ws uuid;
begin
  if not public.chat_access(_user) then raise exception 'chat_not_entitled'; end if;
  select m.workspace_id into ws
    from public.chat_members m
    join public.chat_workspaces w on w.id = m.workspace_id
   where m.user_id = _user
   order by (w.name = 'ANEXOMAIL Family') desc, m.created_at
   limit 1;
  if ws is not null then return ws; end if;
  insert into public.chat_workspaces (name, owner_user_id)
  values (coalesce(_name,'Workspace'), _user)
  returning id into ws;
  insert into public.chat_members (workspace_id, user_id, role)
  values (ws, _user, 'owner') on conflict do nothing;
  return ws;
end $$;

revoke all on function public.chat_ensure_workspace(uuid, text) from public, anon;
grant execute on function public.chat_ensure_workspace(uuid, text) to authenticated, service_role;

select public.family_chat_workspace_apply() as family_chat_workspace;