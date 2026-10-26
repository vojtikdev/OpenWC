-- Apply after schema.sql. Private request queue; operator must actively monitor it.
begin;
create table public.account_requests (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
    kind text not null check (kind in ('access', 'correction', 'deletion', 'other')),
    message text not null default '' check (length(message) <= 2000),
    status text not null default 'pending' check (status in ('pending', 'processing', 'completed')),
    created_at timestamptz not null default now(),
    processed_at timestamptz
);
create index account_requests_user_idx on public.account_requests(user_id);
create unique index account_requests_one_pending_kind_idx on public.account_requests(user_id,kind) where status = 'pending';
alter table public.account_requests enable row level security;
revoke all on public.account_requests from anon, authenticated;
grant select on public.account_requests to authenticated;
grant insert (user_id, kind, message) on public.account_requests to authenticated;
create policy "Members submit own account requests" on public.account_requests
for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Members read own account requests" on public.account_requests
for select to authenticated using ((select auth.uid()) = user_id);
commit;
