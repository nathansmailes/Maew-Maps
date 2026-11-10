-- Maew Maps: Report button
-- Paste all of this into Supabase: SQL Editor -> New query -> Run. Safe to run more than once.
--
-- How it works:
--  * Anyone can report a cat listing or a comment, once each, with a reason.
--  * When 3 different people report the same thing, it is hidden from the app automatically.
--  * You review everything in Table Editor -> schema "admin" -> report_queue.
--    To hide something yourself, open the cats or comments table and tick "hidden".
--    To bring it back, untick "hidden". To remove it forever, delete the row.

alter table public.cats     add column if not exists hidden boolean not null default false;
alter table public.comments add column if not exists hidden boolean not null default false;
alter table public.names    add column if not exists hidden boolean not null default false;

create table if not exists public.reports (
  id          uuid primary key default gen_random_uuid(),
  target_type text not null check (target_type in ('cat','comment')),
  target_id   uuid not null,
  reason      text not null check (reason in ('rude','spam','fake','duplicate','private')),
  user_id     uuid not null default auth.uid(),
  created_at  timestamptz not null default now(),
  unique (target_type, target_id, user_id)
);

-- Hide automatically once 3 different people have reported it
create or replace function public.on_report() returns trigger
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  select count(*) into n from public.reports where target_type = new.target_type and target_id = new.target_id;
  if n >= 3 then
    if new.target_type = 'cat' then update public.cats set hidden = true where id = new.target_id;
    else update public.comments set hidden = true where id = new.target_id; end if;
  end if;
  return new;
end $$;
drop trigger if exists report_may_hide on public.reports;
create trigger report_may_hide after insert on public.reports
  for each row execute function public.on_report();

alter table public.reports enable row level security;
drop policy if exists "add own report" on public.reports;
create policy "add own report" on public.reports for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "see own reports" on public.reports;
create policy "see own reports" on public.reports for select to authenticated using (user_id = auth.uid());

-- Hidden things disappear from the app
drop policy if exists "read recent cats" on public.cats;
create policy "read recent cats" on public.cats for select
  using (last_seen > now() - interval '1 year' and not hidden);
drop policy if exists "read comments" on public.comments;
create policy "read comments" on public.comments for select using (not hidden);
drop policy if exists "read names" on public.names;
create policy "read names" on public.names for select using (not hidden);

-- Your review list. It lives in a separate "admin" schema so the app (and the public) can't read it.
create schema if not exists admin;
revoke all on schema admin from anon, authenticated;
create or replace view admin.report_queue as
select
  r.target_type                                    as what,
  coalesce(c.description, m.body)                  as text,
  coalesce(c.hidden, m.hidden)                     as hidden_now,
  count(*)                                         as reports,
  string_agg(distinct r.reason, ', ')              as reasons,
  max(r.created_at)                                as last_reported,
  r.target_id                                      as id
from public.reports r
left join public.cats     c on r.target_type = 'cat'     and c.id = r.target_id
left join public.comments m on r.target_type = 'comment' and m.id = r.target_id
group by r.target_type, r.target_id, c.description, m.body, c.hidden, m.hidden
order by max(r.created_at) desc;
