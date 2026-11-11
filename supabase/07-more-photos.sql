-- Maew Maps: more than one photo per cat (shown as a slideshow)
-- Paste all of this into Supabase: SQL Editor -> New query -> Run. Safe to run more than once.
--
--  * The cat's first photo stays where it is (cats.photo). Extra photos go in cat_photos.
--  * Up to 10 extra photos per cat. Signed-in people only. You can remove your own photos.
--  * Photos can be reported. 3 reports hide a photo, the same as comments.

create or replace function public.is_real_user() returns boolean
language sql stable as $$
  select coalesce((auth.jwt() ->> 'is_anonymous')::boolean, true) = false
$$;

create table if not exists public.cat_photos (
  id         uuid primary key default gen_random_uuid(),
  cat_id     uuid not null references public.cats(id) on delete cascade,
  photo      text not null check (length(photo) < 400000 and photo like 'data:image/%'),
  user_id    uuid not null default auth.uid(),
  hidden     boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists cat_photos_cat on public.cat_photos (cat_id);

-- No more than 10 extra photos per cat
create or replace function public.photo_limit() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from public.cat_photos where cat_id = new.cat_id) >= 10 then
    raise exception 'This cat already has 10 photos' using errcode = 'P0001';
  end if;
  return new;
end $$;
drop trigger if exists photo_limit on public.cat_photos;
create trigger photo_limit before insert on public.cat_photos
  for each row execute function public.photo_limit();

alter table public.cat_photos enable row level security;
drop policy if exists "read photos" on public.cat_photos;
create policy "read photos" on public.cat_photos for select using (not hidden);
drop policy if exists "add own photo" on public.cat_photos;
create policy "add own photo" on public.cat_photos for insert to authenticated with check (user_id = auth.uid() and hidden = false);
drop policy if exists "signed in to add" on public.cat_photos;
create policy "signed in to add" on public.cat_photos as restrictive for insert to authenticated with check (public.is_real_user());
drop policy if exists "remove own photo" on public.cat_photos;
create policy "remove own photo" on public.cat_photos for delete to authenticated using (user_id = auth.uid());

-- Photos can be reported too
alter table public.reports drop constraint if exists reports_target_type_check;
alter table public.reports add constraint reports_target_type_check check (target_type in ('cat','comment','photo'));

create or replace function public.on_report() returns trigger
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  select count(*) into n from public.reports where target_type = new.target_type and target_id = new.target_id;
  if n >= 3 then
    if new.target_type = 'cat' then update public.cats set hidden = true where id = new.target_id;
    elsif new.target_type = 'photo' then update public.cat_photos set hidden = true where id = new.target_id;
    else update public.comments set hidden = true where id = new.target_id; end if;
  end if;
  return new;
end $$;

-- Deleting an account also removes the photos that person added
alter table public.cats alter column created_by drop not null;
alter table public.names alter column created_by drop not null;
create or replace function public.delete_my_account() returns void
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'Not signed in'; end if;
  delete from public.comments   where user_id = uid;
  delete from public.votes      where user_id = uid;
  delete from public.ratings    where user_id = uid;
  delete from public.sightings  where user_id = uid;
  delete from public.reports    where user_id = uid;
  delete from public.warnings   where user_id = uid;
  delete from public.cat_photos where user_id = uid;
  delete from public.profiles   where user_id = uid;
  update public.cats  set created_by = null where created_by = uid;
  update public.names set created_by = null where created_by = uid;
  delete from auth.users where id = uid;
end $$;
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
