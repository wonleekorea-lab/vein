-- =============================================================
-- journaling（vein） — 端末をまたいで日記を残す。テーブル定義と Row Level Security
-- =============================================================
-- 実行方法: Supabase ダッシュボード > SQL Editor にこのファイルの全文を貼って Run。
-- 冪等（何度実行しても同じ結果）に書いてあるので、作り直しや再実行も安全。
--
-- 設計は Sokugan（sokugan_state）と同じ形にしてある:
--   ・日記は「1ユーザー1行」の JSONB。マージはクライアント側でやる（core.html の merge）。
--     サーバでマージしないのは、両端末がオフラインで進んだ差分を1往復で解決するため。
--   ・rev による楽観的排他。PATCH は「読んだときの rev」と一致する行だけを更新する。
--     一致しなければ0件更新になり、クライアントは再pull→再マージして再試行する。
--     これで「端末Aの日記が端末Bの古い状態で上書きされる」事故が構造的に起きない。
--   ・RLS により、入っている本人の行以外は読めない・書けない。
--     日記は本文そのものなので、anon（未ログイン）には一切触らせない。

create table if not exists public.vein_state (
  user_id    uuid        primary key references auth.users(id) on delete cascade,
  state      jsonb       not null default '{}'::jsonb,
  rev        bigint      not null default 1,
  updated_at timestamptz not null default now()
);

comment on table  public.vein_state is 'journaling（vein）の日記。1ユーザー1行。マージはクライアント側。';
comment on column public.vein_state.rev is '楽観的排他用のリビジョン。更新ごとに+1する。';

-- ---------- Row Level Security ----------
alter table public.vein_state enable row level security;

drop policy if exists "vein_state_select_own" on public.vein_state;
drop policy if exists "vein_state_insert_own" on public.vein_state;
drop policy if exists "vein_state_update_own" on public.vein_state;
drop policy if exists "vein_state_delete_own" on public.vein_state;

create policy "vein_state_select_own"
  on public.vein_state for select
  using (auth.uid() = user_id);

create policy "vein_state_insert_own"
  on public.vein_state for insert
  with check (auth.uid() = user_id);

create policy "vein_state_update_own"
  on public.vein_state for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "vein_state_delete_own"
  on public.vein_state for delete
  using (auth.uid() = user_id);

-- 未ログインには一切触らせない。認証済みのみ。
revoke all on public.vein_state from anon;
grant select, insert, update, delete on public.vein_state to authenticated;

-- ---------- updated_at の自動更新 ----------
create or replace function public.vein_touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists vein_state_touch on public.vein_state;
create trigger vein_state_touch
  before update on public.vein_state
  for each row execute function public.vein_touch_updated_at();

-- ---------- 確認 ----------
-- 期待: rowsecurity = true、ポリシー4件
--   select relname, relrowsecurity from pg_class where relname = 'vein_state';
--   select policyname, cmd from pg_policies where tablename = 'vein_state';
