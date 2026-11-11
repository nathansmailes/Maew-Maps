-- Maew Maps: vote for a cat's best photo
-- Paste all of this into Supabase: SQL Editor -> New query -> Run. Safe to run more than once.
--
--  * Each person picks one favourite photo per cat (voting again moves the vote).
--  * photo_id is empty when the vote is for the cat's first photo, otherwise it's a photo in cat_photos.
--  * The photo with the most votes is shown first. Ties are decided by the app's sharpness/lighting check.

create table if not exists public.photo_votes (
  cat_id     uuid not null references public.cats(id) on delete cascade,
  user_id    uuid not null default auth.uid(),
  photo_id   uuid references public.cat_photos(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (cat_id, user_id)
);

alter table public.photo_votes enable row level security;
drop policy if exists "read photo votes" on public.photo_votes;
create policy "read photo votes" on public.photo_votes for select using (true);
drop policy if exists "add own photo vote" on public.photo_votes;
create policy "add own photo vote" on public.photo_votes for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "change own photo vote" on public.photo_votes;
create policy "change own photo vote" on public.photo_votes for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "remove own photo vote" on public.photo_votes;
create policy "remove own photo vote" on public.photo_votes for delete to authenticated using (user_id = auth.uid());
drop policy if exists "signed in to add" on public.photo_votes;
create policy "signed in to add" on public.photo_votes as restrictive for insert to authenticated with check (public.is_real_user());
drop policy if exists "signed in to change" on public.photo_votes;
create policy "signed in to change" on public.photo_votes as restrictive for update to authenticated using (public.is_real_user());

-- Deleting an account also removes that person's photo votes
create or replace function public.delete_my_account() returns void
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'Not signed in'; end if;
  delete from public.comments    where user_id = uid;
  delete from public.votes       where user_id = uid;
  delete from public.ratings     where user_id = uid;
  delete from public.sightings   where user_id = uid;
  delete from public.reports     where user_id = uid;
  delete from public.warnings    where user_id = uid;
  delete from public.photo_votes where user_id = uid;
  delete from public.cat_photos  where user_id = uid;
  delete from public.profiles    where user_id = uid;
  update public.cats  set created_by = null where created_by = uid;
  update public.names set created_by = null where created_by = uid;
  delete from auth.users where id = uid;
end $$;
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
