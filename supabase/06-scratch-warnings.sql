-- Maew Maps: "It scratched or bit me" warnings
-- Paste all of this into Supabase: SQL Editor -> New query -> Run. Safe to run more than once.
-- Each person can flag each cat once. Any flag shows a warning on the cat's profile and pin.

create table if not exists public.warnings (
  cat_id     uuid not null references public.cats(id) on delete cascade,
  user_id    uuid not null default auth.uid(),
  created_at timestamptz not null default now(),
  primary key (cat_id, user_id)
);

alter table public.warnings enable row level security;
drop policy if exists "read warnings" on public.warnings;
create policy "read warnings" on public.warnings for select using (true);
drop policy if exists "add own warning" on public.warnings;
create policy "add own warning" on public.warnings for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "signed in to add" on public.warnings;
create policy "signed in to add" on public.warnings as restrictive for insert to authenticated with check (public.is_real_user());
drop policy if exists "remove own warning" on public.warnings;
create policy "remove own warning" on public.warnings for delete to authenticated using (user_id = auth.uid());

-- Deleting an account also removes their warnings
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
  delete from public.warnings  where user_id = uid;
  delete from public.profiles  where user_id = uid;
  update public.cats  set created_by = null where created_by = uid;
  update public.names set created_by = null where created_by = uid;
  delete from auth.users where id = uid;
end $$;
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
