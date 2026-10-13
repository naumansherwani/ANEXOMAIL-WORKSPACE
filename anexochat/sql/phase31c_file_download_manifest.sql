-- ============================================================================
-- ANEXOChat · PHASE 31C — FILE DOWNLOAD MANIFEST (Phase 16 "downloaded" step ka asli raasta)
--
-- Pehle `file_download_ack` tha magar browser ke paas download karne ka koi
-- raasta nahi tha — is liye "Downloaded" step kabhi likha nahi ja sakta tha.
-- Yeh function engine (Rust :3200 primary / Bun :3300 fallback) ko batata hai
-- ke kaun si version stream ho sakti hai aur har chunk ka sabit sha256 kya hai.
--
-- SACH KE QAWAID:
--   * sirf `available_at not null` + safety = 'clean' + state = 'ready' version
--   * caller owner ya conversation participant ho
--   * chunks tarteeb se, har ek ka DB sha256 — engine stream karte waqt match
--     karta hai; mismatch = stream band, "Downloaded" kabhi nahi likha jata
--   * storage prefix client ko kabhi nahi jata — sirf engine ko (service role)
--
-- Idempotent: dobara chalana safe hai.
-- ============================================================================

create or replace function public.file_download_manifest(_user uuid, _version uuid)
returns jsonb
language plpgsql stable security definer set search_path = public, extensions
as $$
declare
  v_v     public.chat_file_versions;
  v_f     public.chat_files;
  v_ok    boolean;
  v_chunks jsonb;
begin
  select * into v_v from public.chat_file_versions where id = _version;
  if not found then return jsonb_build_object('found', false, 'ok', false, 'reason', 'not_found'); end if;
  select * into v_f from public.chat_files where id = v_v.file_id;
  if not found or v_f.deleted_at is not null then
    return jsonb_build_object('found', false, 'ok', false, 'reason', 'not_found');
  end if;

  select (v_f.owner_id = _user
          or exists (select 1 from public.chat_participants p
                      where p.conversation_id = v_f.conversation_id and p.user_id = _user))
    into v_ok;
  if not v_ok then return jsonb_build_object('found', false, 'ok', false, 'reason', 'not_found'); end if;

  if v_v.state <> 'ready' then
    return jsonb_build_object('found', true, 'ok', false, 'reason', 'not_ready', 'state', v_v.state);
  end if;
  if v_v.available_at is null or v_v.safety <> 'clean' then
    return jsonb_build_object('found', true, 'ok', false, 'reason', 'not_available',
                              'safety', v_v.safety);
  end if;

  select coalesce(jsonb_agg(jsonb_build_object('idx', c.idx, 'bytes', c.bytes, 'sha256', c.sha256)
                            order by c.idx), '[]'::jsonb)
    into v_chunks
    from public.chat_file_chunks c
   where c.version_id = _version and c.state = 'verified';

  if jsonb_array_length(v_chunks) <> v_v.chunk_count then
    return jsonb_build_object('found', true, 'ok', false, 'reason', 'chunks_incomplete',
                              'verified', jsonb_array_length(v_chunks), 'expected', v_v.chunk_count);
  end if;

  return jsonb_build_object(
    'found', true, 'ok', true,
    'version_id', v_v.id, 'file_id', v_f.id, 'version', v_v.version,
    'name', v_f.name, 'content_type', coalesce(v_v.content_type, v_f.content_type, 'application/octet-stream'),
    'bytes', v_v.bytes, 'file_sha256', v_v.file_sha256,
    'chunk_size', v_v.chunk_size, 'chunk_count', v_v.chunk_count,
    'storage_prefix', v_v.storage_prefix,
    'chunks', v_chunks
  );
end $$;

revoke all on function public.file_download_manifest(uuid, uuid) from public, anon, authenticated;
grant execute on function public.file_download_manifest(uuid, uuid) to service_role;

-- verify: select public.file_download_manifest('00000000-0000-0000-0000-000000000000'::uuid, gen_random_uuid()) -> {"found":false,...}
