-- FormFlow initial schema: profiles, forms, recipients, responses + RLS.
--
-- JSON shapes stored by the app:
--   forms.questions   [{"title": "...", "type": "single", "required": true,
--                       "options": ["A", "B"], "allowOther": false}, ...]
--                     type ∈ shortText | paragraph | single | multiple | dropdown | date
--   responses.answers keyed by question index (as a string):
--                     {"0": "A",                     -- 簡答/段落/下拉/日期/選擇題
--                      "1": ["A", "B"],              -- 核取方塊
--                      "2": {"other": "自填內容"}}    -- 選擇題選「其他」


-- ─── Tables ────────────────────────────────────────────────────────────────

-- One row per auth user, created by the on_auth_user_created trigger.
-- Email is not copied here; the app reads it from the auth session.
create table public.profiles (
  id              uuid primary key references auth.users on delete cascade,
  display_name    text not null,
  department      text not null default '',
  role            text not null default 'member' check (role in ('admin', 'member')),
  notify_assigned boolean not null default true,
  weekly_digest   boolean not null default false,
  created_at      timestamptz not null default now()
);

create table public.forms (
  id          uuid primary key default gen_random_uuid(),
  title       text not null check (length(trim(title)) > 0),
  description text not null default '',
  deadline    date not null,
  status      text not null default 'draft'
              check (status in ('draft', 'pending', 'completed')),
  questions   jsonb not null default '[]' check (jsonb_typeof(questions) = 'array'),
  created_by  uuid default auth.uid() references public.profiles on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table public.form_recipients (
  form_id   uuid not null references public.forms on delete cascade,
  member_id uuid not null references public.profiles on delete cascade,
  primary key (form_id, member_id)
);

create index form_recipients_member_id_idx on public.form_recipients (member_id);

-- One response per member per form; resubmitting overwrites it (upsert).
-- The composite FK means only a recipient can respond, and removing a
-- recipient removes their response.
create table public.responses (
  id           uuid primary key default gen_random_uuid(),
  form_id      uuid not null,
  member_id    uuid not null default auth.uid(),
  answers      jsonb not null default '{}' check (jsonb_typeof(answers) = 'object'),
  submitted_at timestamptz not null default now(),
  unique (form_id, member_id),
  foreign key (form_id, member_id)
    references public.form_recipients (form_id, member_id) on delete cascade
);


-- ─── Helpers ───────────────────────────────────────────────────────────────

-- security definer so policies on profiles can call it without recursing
-- into profiles' own RLS.
create function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and role = 'admin'
  );
$$;


-- ─── Triggers ──────────────────────────────────────────────────────────────

create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'display_name', split_part(new.email, '@', 1))
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger forms_set_updated_at
  before update on public.forms
  for each row execute function public.set_updated_at();

-- The server decides when a response was submitted, not the client.
create function public.set_submitted_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.submitted_at := now();
  return new;
end;
$$;

create trigger responses_set_submitted_at
  before insert or update on public.responses
  for each row execute function public.set_submitted_at();

-- Marks a form completed once every recipient has responded. security
-- definer because members cannot update forms themselves.
create function public.complete_form_when_all_responded()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.forms f
  set status = 'completed'
  where f.id = new.form_id
    and f.status = 'pending'
    and not exists (
      select 1 from public.form_recipients r
      where r.form_id = f.id
        and not exists (
          select 1 from public.responses s
          where s.form_id = r.form_id and s.member_id = r.member_id
        )
    );
  return null;
end;
$$;

create trigger responses_complete_form
  after insert on public.responses
  for each row execute function public.complete_form_when_all_responded();


-- ─── Row Level Security ────────────────────────────────────────────────────

alter table public.profiles        enable row level security;
alter table public.forms           enable row level security;
alter table public.form_recipients enable row level security;
alter table public.responses       enable row level security;

-- profiles: everyone sees their own; admins see everyone (recipient picker,
-- tracking). Users edit their own profile but never their role.
create policy "read own profile, admins read all" on public.profiles
  for select to authenticated
  using (id = (select auth.uid()) or (select public.is_admin()));

create policy "update own profile" on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

revoke update on public.profiles from anon, authenticated;
grant update (display_name, department, notify_assigned, weekly_digest)
  on public.profiles to authenticated;

-- forms: admins manage everything; members see published forms sent to them.
create policy "admins manage forms" on public.forms
  for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

create policy "members read assigned published forms" on public.forms
  for select to authenticated
  using (
    status <> 'draft'
    and exists (
      select 1 from public.form_recipients r
      where r.form_id = forms.id and r.member_id = (select auth.uid())
    )
  );

-- form_recipients: admins manage; members see only their own assignments.
create policy "admins manage recipients" on public.form_recipients
  for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

create policy "members read own assignments" on public.form_recipients
  for select to authenticated
  using (member_id = (select auth.uid()));

-- responses: admins read all; members read and write only their own, on any
-- published form (pending or completed). Drafts are never answerable.
create policy "admins read responses" on public.responses
  for select to authenticated
  using ((select public.is_admin()));

create policy "members read own responses" on public.responses
  for select to authenticated
  using (member_id = (select auth.uid()));

create policy "members submit to published forms" on public.responses
  for insert to authenticated
  with check (
    member_id = (select auth.uid())
    and exists (
      select 1 from public.forms f
      where f.id = responses.form_id and f.status <> 'draft'
    )
  );

create policy "members resubmit to published forms" on public.responses
  for update to authenticated
  using (member_id = (select auth.uid()))
  with check (
    member_id = (select auth.uid())
    and exists (
      select 1 from public.forms f
      where f.id = responses.form_id and f.status <> 'draft'
    )
  );


-- ─── Realtime ──────────────────────────────────────────────────────────────

-- Lets the tracking page update live as responses arrive (RLS still applies).
alter publication supabase_realtime add table public.responses;


-- ─── First admin (run by hand after signing up) ────────────────────────────
--
--   update public.profiles set role = 'admin'
--   where id = (select id from auth.users where email = 'you@example.com');
