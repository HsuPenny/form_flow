-- Departments become a managed list that profiles point at, and only admins
-- may change a profile's department. Safe to run more than once.


-- ─── departments ───────────────────────────────────────────────────────────

create table if not exists public.departments (
  name       text primary key check (length(trim(name)) > 0),
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

alter table public.departments enable row level security;

drop policy if exists "everyone reads departments" on public.departments;
create policy "everyone reads departments" on public.departments
  for select to authenticated
  using (true);

drop policy if exists "admins manage departments" on public.departments;
create policy "admins manage departments" on public.departments
  for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

insert into public.departments (name, sort_order) values
  ('營運管理', 10),
  ('產品設計', 20),
  ('工程部',   30),
  ('客戶成功', 40),
  ('行銷企劃', 50),
  ('業務開發', 60),
  ('財務行政', 70),
  ('人資',     80)
on conflict (name) do nothing;

-- Keep departments people typed in before this list existed.
insert into public.departments (name, sort_order)
select distinct trim(department), 1000
from public.profiles
where trim(coalesce(department, '')) <> ''
on conflict (name) do nothing;


-- ─── profiles.department → departments ─────────────────────────────────────

-- '' meant "no department"; with a foreign key that has to be null. The app
-- still sees ''.
alter table public.profiles alter column department drop not null;
alter table public.profiles alter column department drop default;
update public.profiles
set department = nullif(trim(department), '')
where department is distinct from nullif(trim(department), '');

alter table public.profiles drop constraint if exists profiles_department_fkey;
alter table public.profiles
  add constraint profiles_department_fkey
    foreign key (department) references public.departments (name)
    on update cascade on delete set null;


-- ─── Only admins change departments ────────────────────────────────────────

-- Column grants can't depend on the role, so a trigger does it. Requests
-- without a signed-in user (SQL Editor, seed.sql) are let through.
create or replace function public.guard_profile_department()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.department is distinct from old.department
     and (select auth.uid()) is not null
     and not public.is_admin() then
    raise exception 'only admins can change departments'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_guard_department on public.profiles;
create trigger profiles_guard_department
  before update of department on public.profiles
  for each row execute function public.guard_profile_department();
