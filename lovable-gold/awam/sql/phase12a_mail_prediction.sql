-- ANEXOMAIL — PHASE 12A: ADVANCED EMAIL WORD PREDICTION (inline ghost text)
-- Supabase #4 SQL editor mein poora block chalao. Idempotent + self-healing.
--
-- FOUNDER LOCK:
--   1. Prediction ASSISTIVE hai — kabhi khud se email nahi likhti, kabhi bhejti nahi.
--   2. Engine sirf: (a) global business phrase book, (b) SIRF usi user ke apne
--      likhe hue n-grams. Kisi doosre user / doosri conversation ka text kabhi nahi.
--   3. Koi secret/token/credential kabhi predict nahi hota (learn par filter).
--   4. Koi fabricated fact nahi — engine sirf seekhi hui continuation deta hai.
--   5. Engine down = feature chup-chaap band; composer poora chalta rehta hai.
--
-- Parallel surfaces (teen jagah same-to-same): anexomail.com (founder side),
-- founderworkspace.anexomail.com, ai.anexomail.com — ek hi RPC, ek hi UI.

-- ─────────────────────────────────────────────────────────────────
-- 1) phrase book: global (user_id null) + per-user learned n-grams
-- ─────────────────────────────────────────────────────────────────
do $$
begin
  if exists (select 1 from information_schema.tables
             where table_schema='public' and table_name='mail_predict_phrases')
     and not exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='mail_predict_phrases'
               and column_name='next_text') then
    execute 'alter table public.mail_predict_phrases rename to mail_predict_phrases_legacy';
  end if;
end $$;

create table if not exists public.mail_predict_phrases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,   -- null = global phrase book
  prefix text not null,                                       -- lowercase, 1–3 words
  next_text text not null,                                    -- word ya chhota phrase
  formality text not null default 'any' check (formality in ('any','formal','casual')),
  weight integer not null default 1,
  updated_at timestamptz not null default now()
);

create unique index if not exists mail_predict_phrases_uniq
  on public.mail_predict_phrases (coalesce(user_id, '00000000-0000-0000-0000-000000000000'::uuid), prefix, next_text);
create index if not exists mail_predict_phrases_prefix_idx
  on public.mail_predict_phrases (prefix, weight desc);

-- accepted / dismissed telemetry (quality tuning; koi content nahi)
create table if not exists public.mail_predict_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  action text not null check (action in ('accept','dismiss','conflict')),
  prefix text,
  created_at timestamptz not null default now()
);
create index if not exists mail_predict_events_user_idx
  on public.mail_predict_events (user_id, created_at desc);

-- ─────────────────────────────────────────────────────────────────
-- 2) grants (Data API ke liye lazmi)
-- ─────────────────────────────────────────────────────────────────
grant select on public.mail_predict_phrases to authenticated;
grant select, insert on public.mail_predict_events to authenticated;
grant all on public.mail_predict_phrases to service_role;
grant all on public.mail_predict_events to service_role;

-- ─────────────────────────────────────────────────────────────────
-- 3) RLS: global rows sab pad sakte hain; learned rows sirf apne
-- ─────────────────────────────────────────────────────────────────
alter table public.mail_predict_phrases enable row level security;
alter table public.mail_predict_events enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public'
                 and tablename='mail_predict_phrases' and policyname='mail_predict_read') then
    create policy mail_predict_read on public.mail_predict_phrases for select to authenticated
      using (user_id is null or user_id = auth.uid());
  end if;
  if not exists (select 1 from pg_policies where schemaname='public'
                 and tablename='mail_predict_events' and policyname='mail_predict_events_own') then
    create policy mail_predict_events_own on public.mail_predict_events for all to authenticated
      using (user_id = auth.uid()) with check (user_id = auth.uid());
  end if;
end $$;

-- ─────────────────────────────────────────────────────────────────
-- 4) global business phrase book (seed — idempotent)
-- ─────────────────────────────────────────────────────────────────
insert into public.mail_predict_phrases (user_id, prefix, next_text, formality, weight)
values
  (null, 'thank you for your', 'time and consideration.', 'formal', 60),
  (null, 'thank you for your', 'quick reply.', 'any', 40),
  (null, 'you for your', 'patience while we looked into this.', 'formal', 30),
  (null, 'i wanted to follow', 'up on our conversation.', 'any', 60),
  (null, 'wanted to follow', 'up on the proposal.', 'any', 45),
  (null, 'please find the', 'attached document.', 'formal', 60),
  (null, 'find the', 'attached invoice for this month.', 'formal', 30),
  (null, 'could you please', 'confirm the meeting time?', 'any', 60),
  (null, 'could you please', 'share the latest figures?', 'any', 35),
  (null, 'i hope this', 'email finds you well.', 'formal', 50),
  (null, 'i wanted to discuss the', 'proposal with you before next week''s meeting.', 'any', 55),
  (null, 'wanted to discuss the', 'timeline for the rollout.', 'any', 35),
  (null, 'let me know if', 'you need anything else from my side.', 'any', 55),
  (null, 'looking forward to', 'hearing from you.', 'formal', 55),
  (null, 'apologies for the', 'delay in getting back to you.', 'formal', 50),
  (null, 'as discussed on', 'our call earlier today,', 'any', 30),
  (null, 'i am writing to', 'confirm the details below.', 'formal', 40),
  (null, 'please let me', 'know a time that suits you.', 'any', 45),
  (null, 'happy to', 'walk you through it on a quick call.', 'casual', 40),
  (null, 'just a quick', 'note to keep you in the loop.', 'casual', 35),
  (null, 'we have', 'reviewed your request and can proceed.', 'formal', 30),
  (null, 'kind', 'regards,', 'formal', 45),
  (null, 'best', 'regards,', 'formal', 45),
  (null, 'many thanks', 'for your help with this.', 'any', 35),
  (null, 'i will', 'send the updated version shortly.', 'any', 40),
  (null, 'as per', 'our agreement, the next step is', 'formal', 25),
  (null, 'attached is the', 'summary you asked for.', 'any', 35),
  (null, 'let us', 'schedule a short call this week.', 'formal', 30),
  (null, 'sorry for the', 'confusion — here is the correct version.', 'any', 30),
  (null, 'can we', 'move the meeting to tomorrow morning?', 'any', 30)
on conflict (coalesce(user_id, '00000000-0000-0000-0000-000000000000'::uuid), prefix, next_text)
do update set weight = greatest(public.mail_predict_phrases.weight, excluded.weight),
              formality = excluded.formality,
              updated_at = now();

-- ─────────────────────────────────────────────────────────────────
-- 5) predict: prefix ka sab se lamba match jeetta hai; user rows global se upar
-- ─────────────────────────────────────────────────────────────────
create or replace function public.mail_predict(
  _user uuid,
  _prefix text,                          -- likha hua tail (last few words), lowercase
  _formality text default 'any',
  _limit integer default 3
) returns jsonb
language sql stable security definer set search_path = public as $$
  with tail as (
    select btrim(regexp_replace(lower(coalesce(_prefix, '')), '\s+', ' ', 'g')) as t
  ),
  words as (
    select case when t = '' then '{}'::text[] else string_to_array(t, ' ') end as w from tail
  ),
  cands as (
    select p.next_text,
           array_length(string_to_array(p.prefix, ' '), 1) as depth,
           p.weight,
           (p.user_id is not null) as mine
      from public.mail_predict_phrases p, words
     where array_length(words.w, 1) is not null
       and p.prefix = array_to_string(words.w[greatest(array_length(words.w,1) - array_length(string_to_array(p.prefix,' '),1) + 1, 1):array_length(words.w,1)], ' ')
       and (p.user_id is null or p.user_id = _user)
       and (p.formality = 'any' or _formality = 'any' or p.formality = _formality)
  )
  select coalesce(jsonb_agg(x order by x.rank), '[]'::jsonb)
    from (
      select next_text as text,
             case when mine then 'you' else 'business' end as source,
             least(0.99, (weight::numeric / 100) + depth * 0.1 + case when mine then 0.15 else 0 end) as confidence,
             row_number() over (order by depth desc, mine desc, weight desc) as rank
        from cands
       limit greatest(coalesce(_limit, 3), 1)
    ) x;
$$;

-- ─────────────────────────────────────────────────────────────────
-- 6) learn: SIRF usi user ka apna likha text; sensitive tokens block
-- ─────────────────────────────────────────────────────────────────
create or replace function public.mail_predict_learn(_user uuid, _text text)
returns integer language plpgsql security definer set search_path = public as $$
declare
  clean text;
  parts text[];
  i integer;
  n integer;
  learned integer := 0;
  pre text;
  nxt text;
begin
  clean := btrim(regexp_replace(coalesce(_text, ''), '\s+', ' ', 'g'));
  if length(clean) < 12 then return 0; end if;

  -- credentials / secrets / tokens / emails / long digit strings kabhi nahi seekhte
  if clean ~* '(password|passwd|secret|api[ _-]?key|token|bearer |otp|cvv|iban|sort code|account number)'
     or clean ~ '[0-9]{6,}'
     or clean ~ '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
     or clean ~ '(sk|pk|sb)[-_][A-Za-z0-9]{10,}'
  then
    return 0;
  end if;

  parts := string_to_array(lower(clean), ' ');
  n := coalesce(array_length(parts, 1), 0);
  if n < 4 then return 0; end if;

  i := 3;
  while i < n and learned < 40 loop
    pre := array_to_string(parts[greatest(i - 2, 1):i], ' ');
    nxt := array_to_string(parts[i + 1:least(i + 4, n)], ' ');
    if length(nxt) > 2 then
      insert into public.mail_predict_phrases (user_id, prefix, next_text, formality, weight)
      values (_user, pre, nxt, 'any', 1)
      on conflict (coalesce(user_id, '00000000-0000-0000-0000-000000000000'::uuid), prefix, next_text)
      do update set weight = public.mail_predict_phrases.weight + 1, updated_at = now();
      learned := learned + 1;
    end if;
    i := i + 2;
  end loop;

  return learned;
end $$;

-- ─────────────────────────────────────────────────────────────────
-- 7) event log (accept / dismiss / conflict)
-- ─────────────────────────────────────────────────────────────────
create or replace function public.mail_predict_event(_user uuid, _action text, _prefix text default null)
returns void language sql security definer set search_path = public as $$
  insert into public.mail_predict_events (user_id, action, prefix)
  select _user, _action, left(coalesce(_prefix, ''), 120)
   where _action in ('accept','dismiss','conflict');
$$;

grant execute on function public.mail_predict(uuid, text, text, integer) to authenticated, service_role;
grant execute on function public.mail_predict_learn(uuid, text) to authenticated, service_role;
grant execute on function public.mail_predict_event(uuid, text, text) to authenticated, service_role;
