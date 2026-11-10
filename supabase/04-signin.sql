-- Maew Maps: proper sign-in
-- Paste all of this into Supabase: SQL Editor -> New query -> Run. Safe to run more than once.
--
-- Anyone can still look at the map. Adding cats, photos, names, votes, ratings,
-- comments, sightings, reports and nicknames now needs a signed-in account (email code).
-- Guests are quietly signed in "anonymously" so they can browse; this blocks them from posting.
--
-- To block someone: Authentication -> Users -> click the person -> Ban user.

create or replace function public.is_real_user() returns boolean
language sql stable as $$
  select coalesce((auth.jwt() ->> 'is_anonymous')::boolean, true) = false
$$;

do $$
declare t text;
begin
  foreach t in array array['cats','names','votes','ratings','comments','sightings','reports','profiles'] loop
    execute format('drop policy if exists "signed in to add" on public.%I', t);
    execute format('create policy "signed in to add" on public.%I as restrictive for insert to authenticated with check (public.is_real_user())', t);
  end loop;
  foreach t in array array['cats','votes','ratings','profiles'] loop
    execute format('drop policy if exists "signed in to change" on public.%I', t);
    execute format('create policy "signed in to change" on public.%I as restrictive for update to authenticated using (public.is_real_user())', t);
  end loop;
end $$;
