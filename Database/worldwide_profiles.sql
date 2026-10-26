-- Apply after community_features.sql. Existing places and profiles are retained.
begin;
alter table public.profiles add column avatar_path text;
alter table public.profiles add constraint own_avatar_path check (
 avatar_path is null or avatar_path ~ ('^' || user_id::text || '/[0-9a-f-]{36}\.jpg$')
);
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('profile-photos','profile-photos',false,1000000,array['image/jpeg']);
create policy "Members read own profile photos" on storage.objects for select to authenticated
using(bucket_id='profile-photos' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy "Members upload own profile photos" on storage.objects for insert to authenticated
with check(bucket_id='profile-photos' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy "Members remove own profile photos" on storage.objects for delete to authenticated
using(bucket_id='profile-photos' and (storage.foldername(name))[1]=(select auth.uid())::text);

create index places_latitude_longitude_idx on public.places(latitude,longitude);
create function public.get_places_nearby(center_lat double precision,center_lon double precision,radius_m integer default 10000,max_results integer default 200)
returns setof public.places language plpgsql stable security invoker set search_path = '' as $$
begin
 if center_lat is null or center_lon is null or center_lat not between -90 and 90 or center_lon not between -180 and 180 then
  raise exception 'Invalid map coordinates';
 end if;
 if radius_m is null or radius_m not between 500 and 50000 or max_results is null or max_results not between 1 and 200 then
  raise exception 'Radius must be 500 to 50000 metres; limit 1 to 200';
 end if;
 return query
 select p.* from public.places p
 cross join lateral (
  select 12742000.0*asin(sqrt(least(1.0,greatest(0.0,
   power(sin(radians(p.latitude-center_lat)/2),2)+cos(radians(center_lat))*cos(radians(p.latitude))*power(sin(radians(p.longitude-center_lon)/2),2)
  )))) as metres
 ) d
 where p.latitude between greatest(-90.0,center_lat-radius_m/110000.0) and least(90.0,center_lat+radius_m/110000.0)
 and d.metres<=radius_m
 order by d.metres,p.created_at desc,p.id
 limit max_results;
end;
$$;
revoke all on function public.get_places_nearby(double precision,double precision,integer,integer) from public,anon;
grant execute on function public.get_places_nearby(double precision,double precision,integer,integer) to authenticated;
commit;
