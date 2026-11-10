-- Maew Maps: spotter points, ranks and leaderboard
-- Paste all of this into Supabase: SQL Editor -> New query -> Run. Safe to run more than once.
--
-- Points: adding a new cat = 3 points, logging a sighting ("I saw this cat today" or "Same cat") = 1 point.
-- Fair play: one sighting per cat, per person, per day (Bangkok time).

-- Remove any same-day repeat sightings so the new rule can be added
delete from public.sightings s using public.sightings t
where s.cat_id = t.cat_id and s.user_id = t.user_id
  and (s.created_at at time zone 'Asia/Bangkok')::date = (t.created_at at time zone 'Asia/Bangkok')::date
  and s.created_at > t.created_at;

create unique index if not exists one_sighting_per_cat_per_day
  on public.sightings (cat_id, user_id, ((created_at at time zone 'Asia/Bangkok')::date));

-- Nicknames shown on the leaderboard
create table if not exists public.profiles (
  user_id    uuid primary key default auth.uid(),
  nickname   text not null check (char_length(btrim(nickname)) between 2 and 20),
  updated_at timestamptz not null default now()
);
alter table public.profiles enable row level security;
drop policy if exists "read nicknames" on public.profiles;
create policy "read nicknames" on public.profiles for select using (true);
drop policy if exists "set own nickname" on public.profiles;
create policy "set own nickname" on public.profiles for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "change own nickname" on public.profiles;
create policy "change own nickname" on public.profiles for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Everyone's points (hidden cats don't count)
create or replace view admin.points as
select user_id, sum(p)::int as points from (
  select created_by as user_id, 3 as p from public.cats where not hidden and not example
  union all
  select s.user_id, 1 from public.sightings s join public.cats c on c.id = s.cat_id where not c.hidden
) x group by user_id;

-- Top 10 for the app. Returns only nicknames and points, never user ids.
create or replace function public.leaderboard()
returns table (place int, nickname text, points int, is_me boolean)
language sql stable security definer set search_path = public, admin as $$
  select (row_number() over (order by p.points desc, p.user_id))::int,
         coalesce(pr.nickname, 'Anonymous cat fan'),
         p.points,
         p.user_id = auth.uid()
  from admin.points p left join public.profiles pr on pr.user_id = p.user_id
  order by p.points desc, p.user_id
  limit 10
$$;

-- Your own points and place
create or replace function public.my_stats()
returns table (points int, place int, spotters int)
language sql stable security definer set search_path = public, admin as $$
  select coalesce((select points from admin.points where user_id = auth.uid()), 0),
         (select count(*)::int + 1 from admin.points where points > coalesce((select points from admin.points where user_id = auth.uid()), 0)),
         (select count(*)::int from admin.points)
$$;

grant execute on function public.leaderboard() to anon, authenticated;
grant execute on function public.my_stats()   to anon, authenticated;

-- Points per person, so comments can show the writer's rank badge (like TripAdvisor contributor levels)
create or replace function public.all_points()
returns table (user_id uuid, points int)
language sql stable security definer set search_path = public, admin as $$
  select user_id, points from admin.points
$$;
grant execute on function public.all_points() to anon, authenticated;
