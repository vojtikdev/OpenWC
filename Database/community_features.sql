-- Apply after schema.sql and account_requests.sql. Preserves existing records.
begin;
create table public.profiles (
 user_id uuid primary key references auth.users(id) on delete cascade default auth.uid(),
 display_name text not null check(length(trim(display_name)) between 1 and 40),
 bio text not null default '' check(length(bio) <= 160),
 avatar_symbol text not null default 'person.fill' check(avatar_symbol in ('person.fill','leaf.fill','sparkles','cup.and.saucer.fill','heart.fill','figure.walk')),
 accent text not null default 'violet' check(accent in ('violet','blue','mint','orange'))
);
alter table public.profiles enable row level security;
revoke all on public.profiles from anon, authenticated;
grant select, insert, update on public.profiles to authenticated;
create policy "Read own profile" on public.profiles for select to authenticated using ((select auth.uid())=user_id);
create policy "Insert own profile" on public.profiles for insert to authenticated with check ((select auth.uid())=user_id);
create policy "Update own profile" on public.profiles for update to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);

create table public.saved_places (
 user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
 place_id uuid not null references public.places(id) on delete cascade,
 primary key(user_id,place_id)
);
create index saved_places_place_idx on public.saved_places(place_id);
alter table public.saved_places enable row level security;
revoke all on public.saved_places from anon, authenticated;
grant select,insert,delete on public.saved_places to authenticated;
create policy "Read own saved places" on public.saved_places for select to authenticated using ((select auth.uid())=user_id);
create policy "Save own places" on public.saved_places for insert to authenticated with check ((select auth.uid())=user_id);
create policy "Remove own saved places" on public.saved_places for delete to authenticated using ((select auth.uid())=user_id);

create table public.code_checks (
 place_id uuid not null references public.places(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
 works boolean not null,
 observed_at timestamptz not null default now(),
 primary key(place_id,user_id)
);
create index code_checks_user_idx on public.code_checks(user_id);
create index code_checks_place_time_idx on public.code_checks(place_id,observed_at desc);
alter table public.code_checks enable row level security;
revoke all on public.code_checks from anon, authenticated;
grant select on public.code_checks to authenticated;
grant insert(place_id,user_id,works) on public.code_checks to authenticated;
grant update(works) on public.code_checks to authenticated;
create policy "Read own code checks" on public.code_checks for select to authenticated using ((select auth.uid())=user_id);
create policy "Insert own code checks" on public.code_checks for insert to authenticated with check ((select auth.uid())=user_id);
create policy "Update own code checks" on public.code_checks for update to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);

create schema if not exists openwc_private;
revoke all on schema openwc_private from public;
grant usage on schema openwc_private to authenticated;
create function openwc_private.stamp_check() returns trigger language plpgsql security invoker set search_path = '' as $$
begin new.observed_at = now(); return new; end;
$$;
revoke all on function openwc_private.stamp_check() from public, anon;
create trigger stamp_code_check before update on public.code_checks for each row execute function openwc_private.stamp_check();

-- Narrow aggregate access: voters remain private. No dynamic SQL or arbitrary table access.
create function openwc_private.check_summaries(place_ids uuid[])
returns table(place_id uuid, working_count bigint, broken_count bigint, last_checked timestamptz, last_report timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
 if (select auth.uid()) is null then raise exception 'Authentication required' using errcode='42501'; end if;
 if coalesce(cardinality(place_ids),0)>1000 then raise exception 'At most 1000 places per request'; end if;
 return query
 select p.id, c.working_count, c.broken_count, c.last_checked, greatest(c.last_broken,r.last_report)
 from public.places p
 cross join lateral (
  select count(*) filter(where works) as working_count,
   count(*) filter(where not works) as broken_count,
   max(observed_at) as last_checked,
   max(observed_at) filter(where not works) as last_broken
  from public.code_checks v where v.place_id=p.id and v.observed_at>=now()-interval '30 days'
 ) c
 cross join lateral (
  select max(created_at) as last_report from public.reports v where v.place_id=p.id and v.created_at>=now()-interval '30 days'
 ) r
 where p.id=any(place_ids);
end;
$$;
revoke all on function openwc_private.check_summaries(uuid[]) from public, anon;
grant execute on function openwc_private.check_summaries(uuid[]) to authenticated;
create function public.get_code_check_summaries(place_ids uuid[])
returns table(place_id uuid, working_count bigint, broken_count bigint, last_checked timestamptz, last_report timestamptz)
language sql stable security invoker set search_path = '' as $$
 select * from openwc_private.check_summaries(place_ids);
$$;
revoke all on function public.get_code_check_summaries(uuid[]) from public, anon;
grant execute on function public.get_code_check_summaries(uuid[]) to authenticated;
commit;
