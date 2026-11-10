-- Maew Maps: "Delete my account" (Google Play requires this for apps with sign-in)
-- Paste all of this into Supabase: SQL Editor -> New query -> Run. Safe to run more than once.
--
-- Deletes the person's sign-in (email), nickname, comments, votes, ratings, sightings and reports.
-- Cats they added stay on the map for everyone else, but are no longer linked to them.

alter table public.cats alter column created_by drop not null;
alter table public.names alter column created_by drop not null;

create or replace function public.delete_my_account() returns void
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'Not signed in'; end if;
  delete from public.comments  where user_id = uid;
  delete from public.votes     where user_id = uid;
  delete from public.ratings   where user_id = uid;
  delete from public.sightings where user_id = uid;
  delete from public.reports   where user_id = uid;
  delete from public.profiles  where user_id = uid;
  update public.cats  set created_by = null where created_by = uid;
  update public.names set created_by = null where created_by = uid;
  delete from auth.users where id = uid;
end $$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
