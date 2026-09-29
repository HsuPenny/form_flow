-- Test data: 17 members, 4 forms in different states, and
-- app@example.com.tw as admin. Run in the Supabase SQL Editor after both
-- migrations. Safe to run again: every row has a fixed id.
--
-- Sign up app@example.com.tw in the app first; if it doesn't exist yet the
-- script still runs, but that account isn't made admin or added to forms.
--
-- Seed members use example.com addresses and have no password, so they can
-- never sign in. They exist to be recipients and responders.
--
-- To remove all of it again:
--   delete from public.forms where id::text like 'f0000000-%';
--   delete from auth.users   where id::text like 'a0000000-%';

-- No begin/commit: the SQL Editor may run each statement separately. If a
-- run fails part-way, just run the whole file again.

-- In case an earlier run stopped between disabling and re-enabling it below.
alter table public.responses enable trigger responses_set_submitted_at;


-- ─── Admin ─────────────────────────────────────────────────────────────────

update public.profiles
set role = 'admin'
where id = (select id from auth.users where email = 'app@example.com.tw');


-- ─── Members ───────────────────────────────────────────────────────────────

-- Member n gets id a0000000-0000-4000-8000-00000000000n. No temp tables:
-- the SQL Editor may run each statement in its own session.
--
-- The token columns must be '' rather than NULL, or Supabase Auth fails to
-- load these users. An empty password hash means they can't sign in.
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change
)
select
  '00000000-0000-0000-0000-000000000000',
  ('a0000000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid,
  'authenticated', 'authenticated', email, '', now(),
  '{"provider": "email", "providers": ["email"]}',
  jsonb_build_object('display_name', name, 'department', department),
  now(), now(),
  '', '', '', ''
from (values
  ( 1, '林郁婷', '產品設計', 'yuting.lin@example.com'),
  ( 2, '陳柏安', '工程部',   'boan.chen@example.com'),
  ( 3, '吳思妤', '客戶成功', 'siyu.wu@example.com'),
  ( 4, '黃子軒', '行銷企劃', 'zixuan.huang@example.com'),
  ( 5, '張雅雯', '財務行政', 'yawen.chang@example.com'),
  ( 6, '蔡承翰', '工程部',   'chenghan.tsai@example.com'),
  ( 7, '李冠廷', '業務開發', 'guanting.li@example.com'),
  ( 8, '周品妍', '人資',     'pinyan.chou@example.com'),
  ( 9, '許家豪', '工程部',   'jiahao.hsu@example.com'),
  (10, '鄭宇翔', '工程部',   'yuxiang.cheng@example.com'),
  (11, '高詩涵', '產品設計', 'shihan.kao@example.com'),
  (12, '楊凱文', '客戶成功', 'kaiwen.yang@example.com'),
  (13, '謝佳穎', '行銷企劃', 'jiaying.hsieh@example.com'),
  (14, '林志明', '業務開發', 'zhiming.lin@example.com'),
  (15, '張雅婷', '業務開發', 'yating.chang@example.com'),
  (16, '周美玲', '財務行政', 'meiling.chou@example.com'),
  (17, '王思涵', '人資',     'sihan.wang@example.com')
) as seed(n, name, department, email)
-- Refresh the name and department of members left by an earlier run.
on conflict (id) do update
  set raw_user_meta_data = excluded.raw_user_meta_data;

-- handle_new_user created the profiles with the name; copy the department.
update public.profiles p
set display_name = u.raw_user_meta_data ->> 'display_name',
    department   = u.raw_user_meta_data ->> 'department'
from auth.users u
where p.id = u.id
  and u.id::text like 'a0000000-%'
  and u.raw_user_meta_data ? 'department';


-- ─── Forms ─────────────────────────────────────────────────────────────────

insert into public.forms
  (id, title, description, deadline, status, questions, created_by, created_at)
values
  (
    'f0000000-0000-4000-8000-000000000001',
    '2026 Q3 產品策略工作坊回饋',
    '收集本次工作坊的即時回饋，協助我們把下一次活動做得更精準。',
    '2026-09-30', 'pending',
    '[
      {"title": "這次的會議節奏是否適合你的工作安排？", "type": "single", "required": true,
       "options": ["非常適合", "大致適合", "需要調整"], "allowOther": false},
      {"title": "你希望下次工作坊增加哪些內容？", "type": "multiple", "required": false,
       "options": ["實作演練", "案例分享", "跨部門交流", "會後資料包"], "allowOther": false}
    ]',
    (select id from auth.users where email = 'app@example.com.tw'),
    '2026-09-20 10:00+08'
  ),
  (
    'f0000000-0000-4000-8000-000000000002',
    '資訊安全意識年度檢核',
    '請完成年度安全意識小測驗，花費約 3 分鐘。',
    '2026-10-08', 'pending',
    '[
      {"title": "收到可疑的登入連結時，你會怎麼做？", "type": "single", "required": true,
       "options": ["直接點擊確認", "回報資安窗口", "轉寄給同事"], "allowOther": false},
      {"title": "哪些資料不應該貼到公開頻道？", "type": "multiple", "required": true,
       "options": ["客戶個資", "內部密碼", "會議時間", "合約內容"], "allowOther": false},
      {"title": "你覺得公司還可以加強哪方面的資安宣導？", "type": "paragraph", "required": false,
       "options": [], "allowOther": false}
    ]',
    (select id from auth.users where email = 'app@example.com.tw'),
    '2026-09-17 09:00+08'
  ),
  (
    'f0000000-0000-4000-8000-000000000003',
    '專案結案回顧｜星港改版',
    '整理專案過程中的觀察，讓團隊把有效的方法留下來。',
    '2026-10-15', 'draft',
    '[
      {"title": "你的聯絡信箱", "type": "shortText", "required": true,
       "options": [], "allowOther": false},
      {"title": "你在專案中的角色", "type": "dropdown", "required": true,
       "options": ["專案經理", "設計", "前端工程", "後端工程", "測試"], "allowOther": false},
      {"title": "你最後一次參與專案的日期", "type": "date", "required": false,
       "options": [], "allowOther": false},
      {"title": "整體來說，這次合作的順暢程度？", "type": "single", "required": true,
       "options": ["非常順暢", "還算順暢", "不太順暢"], "allowOther": true},
      {"title": "哪些工具對你幫助最大？", "type": "multiple", "required": false,
       "options": ["Figma", "Jira", "Slack", "Notion"], "allowOther": false},
      {"title": "這個專案中最有效的做法是什麼？", "type": "paragraph", "required": true,
       "options": [], "allowOther": false}
    ]',
    (select id from auth.users where email = 'app@example.com.tw'),
    '2026-09-25 15:30+08'
  ),
  (
    'f0000000-0000-4000-8000-000000000004',
    '九月部門午餐調查',
    '下個月的部門午餐想吃什麼？投票決定！',
    '2026-09-20', 'pending',  -- becomes completed once everyone has answered
    '[
      {"title": "想吃哪一種料理？", "type": "single", "required": true,
       "options": ["日式", "義式", "泰式"], "allowOther": true},
      {"title": "方便的日期", "type": "date", "required": true,
       "options": [], "allowOther": false}
    ]',
    (select id from auth.users where email = 'app@example.com.tw'),
    '2026-09-10 12:00+08'
  )
on conflict (id) do nothing;


-- ─── Recipients ────────────────────────────────────────────────────────────

insert into public.form_recipients (form_id, member_id)
select 'f0000000-0000-4000-8000-000000000001'::uuid, ('a0000000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid
from generate_series(1, 6) n
union all
select 'f0000000-0000-4000-8000-000000000002'::uuid, ('a0000000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid
from generate_series(1, 8) n
union all
select 'f0000000-0000-4000-8000-000000000004'::uuid, ('a0000000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid
from generate_series(9, 13) n
union all
-- Lets the admin try filling in a form too.
select 'f0000000-0000-4000-8000-000000000002'::uuid, id
from auth.users where email = 'app@example.com.tw'
on conflict do nothing;


-- ─── Responses ─────────────────────────────────────────────────────────────

-- Keep the submitted_at values below instead of stamping them with now().
alter table public.responses disable trigger responses_set_submitted_at;

insert into public.responses (form_id, member_id, answers, submitted_at)
values
  -- Workshop feedback: 4 of 6 answered.
  ('f0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000001',
   '{"0": "非常適合", "1": ["實作演練", "案例分享"]}', '2026-09-21 14:22+08'),
  ('f0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000002',
   '{"0": "大致適合", "1": ["實作演練"]}', '2026-09-21 16:08+08'),
  ('f0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000003',
   '{"0": "非常適合", "1": ["跨部門交流", "會後資料包"]}', '2026-09-22 09:14+08'),
  ('f0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000004',
   '{"0": "需要調整", "1": ["案例分享"]}', '2026-09-22 11:42+08'),

  -- Security check: 7 of 8 members answered; the admin hasn't yet.
  ('f0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000001',
   '{"0": "回報資安窗口", "1": ["客戶個資", "內部密碼"], "2": "希望多一些實際案例"}', '2026-09-18 10:00+08'),
  ('f0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000002',
   '{"0": "回報資安窗口", "1": ["客戶個資", "內部密碼", "合約內容"]}', '2026-09-18 11:05+08'),
  ('f0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000003',
   '{"0": "回報資安窗口", "1": ["客戶個資", "內部密碼"], "2": "新人訓練可以加入資安課程"}', '2026-09-19 12:10+08'),
  ('f0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000004',
   '{"0": "轉寄給同事", "1": ["內部密碼"]}', '2026-09-19 13:15+08'),
  ('f0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000005',
   '{"0": "回報資安窗口", "1": ["客戶個資", "內部密碼", "合約內容"], "2": "定期寄送釣魚信演練"}', '2026-09-20 14:20+08'),
  ('f0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000006',
   '{"0": "回報資安窗口", "1": ["客戶個資", "內部密碼"]}', '2026-09-20 15:25+08'),
  ('f0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000007',
   '{"0": "回報資安窗口", "1": ["客戶個資", "合約內容"], "2": "密碼管理工具的使用教學"}', '2026-09-21 16:30+08'),

  -- Lunch survey: everyone answered, so the trigger marks it completed.
  ('f0000000-0000-4000-8000-000000000004', 'a0000000-0000-4000-8000-000000000009',
   '{"0": "日式", "1": "2026-10-16"}', '2026-09-11 09:30+08'),
  ('f0000000-0000-4000-8000-000000000004', 'a0000000-0000-4000-8000-000000000010',
   '{"0": "泰式", "1": "2026-10-16"}', '2026-09-11 10:12+08'),
  ('f0000000-0000-4000-8000-000000000004', 'a0000000-0000-4000-8000-000000000011',
   '{"0": {"other": "韓式烤肉"}, "1": "2026-10-17"}', '2026-09-12 13:45+08'),
  ('f0000000-0000-4000-8000-000000000004', 'a0000000-0000-4000-8000-000000000012',
   '{"0": "日式", "1": "2026-10-16"}', '2026-09-15 17:20+08'),
  ('f0000000-0000-4000-8000-000000000004', 'a0000000-0000-4000-8000-000000000013',
   '{"0": "義式", "1": "2026-10-17"}', '2026-09-18 11:03+08')
on conflict (form_id, member_id) do nothing;

alter table public.responses enable trigger responses_set_submitted_at;


-- ─── Check ─────────────────────────────────────────────────────────────────

-- The admin should show role = admin. No row means app@example.com.tw hasn't
-- signed up yet: sign up in the app, then run this file again.
select u.email, p.display_name, p.role
from auth.users u
join public.profiles p on p.id = u.id
where u.email = 'app@example.com.tw';

select f.title, f.status,
       (select count(*) from public.form_recipients r where r.form_id = f.id) as recipients,
       (select count(*) from public.responses s where s.form_id = f.id) as responses
from public.forms f
order by f.created_at desc;
