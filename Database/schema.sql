-- Run once in a dedicated OpenWC Supabase project.
begin;
create table public.places (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
    name text not null check (length(trim(name)) between 1 and 200),
    address text not null check (length(address) <= 1000),
    latitude double precision not null check (latitude between -90 and 90),
    longitude double precision not null check (longitude between -180 and 180),
    code text not null check (length(trim(code)) between 1 and 32),
    notes text not null default '' check (length(notes) <= 1000),
    accessible boolean not null default false,
    photo_path text,
    created_at timestamptz not null default now(),
    constraint own_photo check (photo_path is null or photo_path = user_id::text || '/' || id::text || '.jpg')
);
create index places_created_at_idx on public.places(created_at desc);
create index places_owner_idx on public.places(user_id);
alter table public.places enable row level security;
revoke all on public.places from anon, authenticated;
grant select, insert on public.places to authenticated;
create policy "Members read shared places" on public.places for select to authenticated using (true);
create policy "Members add their own places" on public.places for insert to authenticated with check ((select auth.uid()) = user_id);

create table public.reports (
    id uuid primary key default gen_random_uuid(),
    place_id uuid not null references public.places(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
    reason text not null check (length(reason) between 1 and 1000),
    created_at timestamptz not null default now(),
    unique (place_id, user_id)
);
create index reports_owner_idx on public.reports(user_id);
alter table public.reports enable row level security;
revoke all on public.reports from anon, authenticated;
grant insert, select on public.reports to authenticated;
create policy "Members submit reports" on public.reports for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Members read own reports" on public.reports for select to authenticated using ((select auth.uid()) = user_id);

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('place-photos', 'place-photos', true, 5000000, array['image/jpeg']);
-- Photos are public community assets; never store private information here.
create policy "Members upload own photos" on storage.objects for insert to authenticated
with check (bucket_id = 'place-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "Members read own upload records" on storage.objects for select to authenticated
using (bucket_id = 'place-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "Members clean up own photos" on storage.objects for delete to authenticated
using (bucket_id = 'place-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);
commit;
