-- 表單管理 loads its lists in batches instead of every form at once:
-- * 最新回覆 pages through responses, newest first;
-- * 完成進度 pages through published forms, newest first;
-- * the totals above them come from progress_summary, so they still cover
--   every published form, not just the batches loaded so far.
-- Safe to run more than once.


-- ─── Indexes for the batched lists ─────────────────────────────────────────

create index if not exists responses_submitted_at_idx
  on public.responses (submitted_at desc, id desc);

create index if not exists forms_status_created_at_idx
  on public.forms (status, created_at desc);


-- ─── progress_summary ──────────────────────────────────────────────────────

-- 整體回覆率 / 已回覆 / 待回覆 across every published form: how many people
-- were asked and how many of them replied. security invoker, so RLS decides
-- what is counted (admins see everything).
create or replace function public.progress_summary()
returns table (recipients bigint, responded bigint)
language sql
stable
security invoker
set search_path = ''
as $$
  select
    (select count(*)
       from public.form_recipients r
       join public.forms f on f.id = r.form_id
      where f.status <> 'draft'),
    (select count(*)
       from public.responses s
       join public.forms f on f.id = s.form_id
      where f.status <> 'draft');
$$;


-- Make the API see the new function right away.
notify pgrst, 'reload schema';
