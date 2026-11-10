-- Maew Maps database setup
-- Paste all of this into Supabase: SQL Editor -> New query -> Run.
-- It is safe to run more than once.

-- ---------- Tables ----------

create table if not exists public.cats (
  id          uuid primary key default gen_random_uuid(),
  lat         double precision not null check (lat between 13.4 and 14.2),   -- roughly greater Bangkok
  lng         double precision not null check (lng between 100.2 and 101.0),
  coat        text not null,
  features    text[] not null default '{}',
  description text not null check (char_length(description) between 5 and 400),
  area        text check (char_length(area) <= 80),
  photo       text check (char_length(photo) <= 400000),                       -- small resized JPEG as a data URL
  example     boolean not null default false,
  sightings   integer not null default 1,
  created_by  uuid not null default auth.uid(),
  created_at  timestamptz not null default now(),
  last_seen   timestamptz not null default now()
);

create table if not exists public.names (
  id         uuid primary key default gen_random_uuid(),
  cat_id     uuid not null references public.cats(id) on delete cascade,
  name       text not null check (char_length(name) between 1 and 30),
  created_by uuid not null default auth.uid(),
  created_at timestamptz not null default now()
);
create unique index if not exists names_unique_per_cat on public.names (cat_id, lower(name));

-- One vote per person per cat. Changing your vote updates the row.
create table if not exists public.votes (
  cat_id  uuid not null references public.cats(id) on delete cascade,
  user_id uuid not null default auth.uid(),
  name_id uuid not null references public.names(id) on delete cascade,
  primary key (cat_id, user_id)
);

-- One friendliness rating per person per cat (1 Runs away ... 5 Lap cat).
create table if not exists public.ratings (
  cat_id  uuid not null references public.cats(id) on delete cascade,
  user_id uuid not null default auth.uid(),
  score   smallint not null check (score between 1 and 5),
  primary key (cat_id, user_id)
);

create table if not exists public.comments (
  id         uuid primary key default gen_random_uuid(),
  cat_id     uuid not null references public.cats(id) on delete cascade,
  user_id    uuid not null default auth.uid(),
  who        text check (char_length(who) <= 30),
  body       text not null check (char_length(body) between 1 and 500),
  created_at timestamptz not null default now()
);

create table if not exists public.sightings (
  id         uuid primary key default gen_random_uuid(),
  cat_id     uuid not null references public.cats(id) on delete cascade,
  user_id    uuid not null default auth.uid(),
  created_at timestamptz not null default now()
);

-- A sighting bumps the cat's "last seen" date and count.
create or replace function public.on_sighting() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  update public.cats set last_seen = now(), sightings = sightings + 1 where id = new.cat_id;
  return new;
end $$;
drop trigger if exists sighting_bumps_cat on public.sightings;
create trigger sighting_bumps_cat after insert on public.sightings
  for each row execute function public.on_sighting();

-- ---------- Safety rules (Row Level Security) ----------
-- Anyone can read. You must be signed in (anonymous sign-in counts) to add things,
-- and you can only change or remove your own vote and rating.
-- Cats not seen for a year are hidden from everyone.

alter table public.cats      enable row level security;
alter table public.names     enable row level security;
alter table public.votes     enable row level security;
alter table public.ratings   enable row level security;
alter table public.comments  enable row level security;
alter table public.sightings enable row level security;

drop policy if exists "read recent cats" on public.cats;
create policy "read recent cats" on public.cats for select
  using (last_seen > now() - interval '1 year');
drop policy if exists "add cats" on public.cats;
create policy "add cats" on public.cats for insert to authenticated
  with check (created_by = auth.uid() and example = false and sightings = 1);
-- Only the photo can be changed, and only when the cat has none yet.
drop policy if exists "add missing photo" on public.cats;
create policy "add missing photo" on public.cats for update to authenticated
  using (photo is null) with check (true);
revoke update on public.cats from anon, authenticated;
grant update (photo) on public.cats to authenticated;

drop policy if exists "read names" on public.names;
create policy "read names" on public.names for select using (true);
drop policy if exists "add names" on public.names;
create policy "add names" on public.names for insert to authenticated with check (created_by = auth.uid());

drop policy if exists "read votes" on public.votes;
create policy "read votes" on public.votes for select using (true);
drop policy if exists "add own vote" on public.votes;
create policy "add own vote" on public.votes for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "change own vote" on public.votes;
create policy "change own vote" on public.votes for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "read ratings" on public.ratings;
create policy "read ratings" on public.ratings for select using (true);
drop policy if exists "add own rating" on public.ratings;
create policy "add own rating" on public.ratings for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "change own rating" on public.ratings;
create policy "change own rating" on public.ratings for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "read comments" on public.comments;
create policy "read comments" on public.comments for select using (true);
drop policy if exists "add comments" on public.comments;
create policy "add comments" on public.comments for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "read sightings" on public.sightings;
create policy "read sightings" on public.sightings for select using (true);
drop policy if exists "add sightings" on public.sightings;
create policy "add sightings" on public.sightings for insert to authenticated with check (user_id = auth.uid());

-- ---------- Example cats (delete them any time in Table Editor -> cats) ----------
insert into public.cats (id, lat, lng, coat, features, description, area, example, sightings, created_by, created_at, last_seen)
select * from (values
  ('00000000-0000-0000-0000-000000000001'::uuid, 13.7307, 100.5418, 'ginger', array['kinked','eartip'],
   'Big chunky ginger boy with a kinked tail. Sleeps on the bench by the paddle boats most afternoons.',
   'Lumpini Park, near the boat lake', true, 12, '00000000-0000-0000-0000-000000000000'::uuid, now() - interval '20 days', now() - interval '1 day'),
  ('00000000-0000-0000-0000-000000000002'::uuid, 13.7212, 100.5697, 'tortie', array['eartip'],
   'Small tortoiseshell girl, orange patch on her nose. Waits by the 7-Eleven door at night.',
   'Sukhumvit Soi 24, outside the 7-Eleven', true, 6, '00000000-0000-0000-0000-000000000000'::uuid, now() - interval '9 days', now() - interval '2 days')
) as v
on conflict (id) do nothing;

insert into public.names (cat_id, name, created_by) values
  ('00000000-0000-0000-0000-000000000001', 'Mango',     '00000000-0000-0000-0000-000000000000'),
  ('00000000-0000-0000-0000-000000000001', 'Khao Pad',  '00000000-0000-0000-0000-000000000000'),
  ('00000000-0000-0000-0000-000000000002', 'Nam Phrik', '00000000-0000-0000-0000-000000000000')
on conflict do nothing;

insert into public.comments (cat_id, user_id, who, body)
select '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000', 'น้องฟ้า',
       'น้องแมวเชื่องมาก ชอบนอนบนม้านั่งตอนบ่าย ใครผ่านไปก็มาขอลูบหัว'
where not exists (select 1 from public.comments where cat_id = '00000000-0000-0000-0000-000000000001');
