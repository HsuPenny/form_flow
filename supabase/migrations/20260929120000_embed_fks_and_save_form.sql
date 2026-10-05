-- What the app's API calls need on top of the initial schema. Safe to run
-- more than once.


-- ─── Foreign keys for PostgREST embeds ─────────────────────────────────────

-- Let the API embed responses in forms and the responder's profile in each
-- response. The app names these constraints in its select strings.
alter table public.responses
  drop constraint if exists responses_form_id_fkey,
  drop constraint if exists responses_member_id_fkey;

alter table public.responses
  add constraint responses_form_id_fkey
    foreign key (form_id) references public.forms on delete cascade,
  add constraint responses_member_id_fkey
    foreign key (member_id) references public.profiles on delete cascade;


-- ─── save_form ─────────────────────────────────────────────────────────────

-- Saves a form and its recipient list in one transaction. security invoker,
-- so RLS still decides who may call it (admins only).
create or replace function public.save_form(form jsonb, recipient_ids uuid[])
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  fid uuid := (form ->> 'id')::uuid;
begin
  insert into public.forms (id, title, description, deadline, status, questions)
  values (
    fid,
    form ->> 'title',
    coalesce(form ->> 'description', ''),
    (form ->> 'deadline')::date,
    form ->> 'status',
    coalesce(form -> 'questions', '[]')
  )
  on conflict (id) do update set
    title       = excluded.title,
    description = excluded.description,
    deadline    = excluded.deadline,
    status      = excluded.status,
    questions   = excluded.questions;

  delete from public.form_recipients
  where form_id = fid and member_id <> all (recipient_ids);

  insert into public.form_recipients (form_id, member_id)
  select fid, unnest(recipient_ids)
  on conflict do nothing;
end;
$$;


-- ─── Response policies ─────────────────────────────────────────────────────

-- Members may answer any published form, not only pending ones. Recreated
-- here in case the database was set up before that change.
drop policy if exists "members submit to open forms" on public.responses;
drop policy if exists "members resubmit to open forms" on public.responses;
drop policy if exists "members submit to published forms" on public.responses;
drop policy if exists "members resubmit to published forms" on public.responses;

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


-- ─── Backfill profiles ─────────────────────────────────────────────────────

-- Users created before the on_auth_user_created trigger existed have no
-- profile, and the app can't sign them in without one.
insert into public.profiles (id, display_name)
select id, coalesce(raw_user_meta_data ->> 'display_name', split_part(email, '@', 1))
from auth.users
on conflict (id) do nothing;


-- Make the API see the new constraints and function right away.
notify pgrst, 'reload schema';
