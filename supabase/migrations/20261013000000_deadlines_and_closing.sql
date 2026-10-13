-- Deadlines and closing (結案):
-- * a form takes replies through the end of its deadline day;
-- * admins can add recipients until then, and push the deadline back on a
--   form not everyone has answered, even after it passed;
-- * admins can close a published form for good (status 'closed');
-- * a form can't be published with a deadline that has already passed.
-- Safe to run more than once.


-- ─── 'closed' status ───────────────────────────────────────────────────────

alter table public.forms drop constraint if exists forms_status_check;
alter table public.forms add constraint forms_status_check
  check (status in ('draft', 'pending', 'completed', 'closed'));


-- ─── form_is_open ──────────────────────────────────────────────────────────

-- "Today" in the company's time zone; deadline is a plain date and the
-- database runs in UTC.
create or replace function public.local_today()
returns date
language sql
stable
set search_path = ''
as $$
  select (now() at time zone 'Asia/Taipei')::date;
$$;

-- True while a published, not closed form still takes replies.
create or replace function public.form_is_open(fid uuid)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select exists (
    select 1 from public.forms f
    where f.id = fid
      and f.status in ('pending', 'completed')
      and f.deadline >= public.local_today()
  );
$$;


-- ─── Response policies ─────────────────────────────────────────────────────

-- Members may answer, or change their answer, only while the form is open.
drop policy if exists "members submit to published forms" on public.responses;
drop policy if exists "members resubmit to published forms" on public.responses;

create policy "members submit to published forms" on public.responses
  for insert to authenticated
  with check (
    member_id = (select auth.uid())
    and public.form_is_open(form_id)
  );

create policy "members resubmit to published forms" on public.responses
  for update to authenticated
  using (member_id = (select auth.uid()))
  with check (
    member_id = (select auth.uid())
    and public.form_is_open(form_id)
  );


-- ─── Admin actions ─────────────────────────────────────────────────────────
-- All security invoker, so RLS still limits them to admins.

-- save_form from the previous migration, now refusing to publish a form
-- whose deadline has already passed (it would start out closed).
create or replace function public.save_form(form jsonb, recipient_ids uuid[])
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  fid uuid := (form ->> 'id')::uuid;
begin
  if form ->> 'status' <> 'draft'
     and (form ->> 'deadline')::date < public.local_today() then
    raise exception 'deadline % is in the past', form ->> 'deadline';
  end if;

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

-- Adds recipients to an open form. A completed form goes back to pending,
-- since the new recipients haven't replied.
create or replace function public.add_recipients(form_id uuid, member_ids uuid[])
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if not public.form_is_open(add_recipients.form_id) then
    raise exception 'form % is not open', add_recipients.form_id;
  end if;

  insert into public.form_recipients (form_id, member_id)
  select add_recipients.form_id, unnest(member_ids)
  on conflict do nothing;

  update public.forms f
  set status = 'pending'
  where f.id = add_recipients.form_id
    and f.status = 'completed'
    and exists (
      select 1 from public.form_recipients r
      where r.form_id = f.id
        and not exists (
          select 1 from public.responses s
          where s.form_id = r.form_id and s.member_id = r.member_id
        )
    );
end;
$$;

-- Moves the deadline of a form not everyone has answered. Works after the
-- old deadline too, which reopens the form.
create or replace function public.extend_deadline(form_id uuid, new_deadline date)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new_deadline < public.local_today() then
    raise exception 'deadline % is in the past', new_deadline;
  end if;

  update public.forms f
  set deadline = new_deadline
  where f.id = extend_deadline.form_id and f.status = 'pending';

  if not found then
    raise exception 'form % is not pending', extend_deadline.form_id;
  end if;
end;
$$;

-- Closes a published form for good.
create or replace function public.close_form(form_id uuid)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  update public.forms f
  set status = 'closed'
  where f.id = close_form.form_id and f.status in ('pending', 'completed');

  if not found then
    raise exception 'form % is not published', close_form.form_id;
  end if;
end;
$$;


-- Make the API see the new functions right away.
notify pgrst, 'reload schema';
