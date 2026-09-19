-- ============================================================
-- 스토어 재고장: Supabase 저장소
-- Supabase 대시보드 → SQL Editor 에 통째로 붙여 넣고 Run.
-- 여러 번 실행해도 안전합니다.
-- ============================================================

-- 1) 재고 데이터: 재고장 전체를 JSON 한 덩어리로 한 줄에 저장
--    version 은 저장할 때마다 1씩 올라감 (두 기기가 동시에 저장할 때 겹침 방지)
create table if not exists public.stock_ledger (
  id          integer     primary key check (id = 1),
  data        jsonb,                                   -- 비어 있으면 첫 로그인 때 기존 GitHub 데이터를 옮겨 옴
  version     bigint      not null default 0,
  summary     text,                                    -- 마지막 변경 내용 (예: 재고 변경: 상품명)
  updated_at  timestamptz not null default now(),
  updated_by  text
);
insert into public.stock_ledger (id) values (1) on conflict (id) do nothing;

-- 2) 변경 기록: 저장 직전 상태를 최근 300개까지 보관 (잘못 고쳤을 때 되돌리기용)
create table if not exists public.stock_history (
  id          bigint      generated always as identity primary key,
  version     bigint      not null,
  data        jsonb,
  summary     text,
  saved_at    timestamptz not null default now(),
  saved_by    text
);

-- 3) 재고를 고칠 수 있는 이메일 목록
create table if not exists public.stock_editors (
  email text primary key
);
-- ▼ 재고를 고칠 사람의 로그인 이메일 (다르면 바꾸고, 여러 명이면 줄을 추가)
insert into public.stock_editors (email) values ('sensual0925@gmail.com') on conflict do nothing;

-- 4) 보안 규칙
--    재고 데이터: 누구나 읽기만 가능 (쓰기는 아래 save_stock 함수로만)
--    변경 기록 · 편집자 목록: 페이지에서 직접 접근 불가
alter table public.stock_ledger  enable row level security;
alter table public.stock_history enable row level security;
alter table public.stock_editors enable row level security;

drop policy if exists "재고 누구나 보기" on public.stock_ledger;
create policy "재고 누구나 보기" on public.stock_ledger
  for select to anon, authenticated
  using (true);

revoke all on public.stock_ledger  from anon, authenticated;
revoke all on public.stock_history from anon, authenticated;
revoke all on public.stock_editors from anon, authenticated;
grant select on public.stock_ledger to anon, authenticated;

-- 5) 로그인한 사람이 편집자인지 확인
create or replace function public.is_stock_editor()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.stock_editors e
    where lower(e.email) = lower(auth.jwt() ->> 'email')
  );
$$;

-- 6) 저장: 편집자만, 내가 읽은 version 이 그대로일 때만 저장 (아니면 'conflict')
create or replace function public.save_stock(p_expected_version bigint, p_data jsonb, p_summary text)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  cur public.stock_ledger;
  new_version bigint;
begin
  if not public.is_stock_editor() then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  select * into cur from public.stock_ledger where id = 1 for update;
  if cur.version <> p_expected_version then
    raise exception 'conflict' using errcode = '40001';
  end if;

  insert into public.stock_history (version, data, summary, saved_by)
  values (cur.version, cur.data, cur.summary, cur.updated_by);
  delete from public.stock_history
  where id <= (select id from public.stock_history order by id desc offset 300 limit 1);

  update public.stock_ledger
  set data = p_data, version = cur.version + 1, summary = p_summary,
      updated_at = now(), updated_by = auth.jwt() ->> 'email'
  where id = 1
  returning version into new_version;

  return new_version;
end;
$$;

revoke execute on function public.is_stock_editor() from public, anon;
revoke execute on function public.save_stock(bigint, jsonb, text) from public, anon;
grant execute on function public.is_stock_editor() to authenticated;
grant execute on function public.save_stock(bigint, jsonb, text) to authenticated;
