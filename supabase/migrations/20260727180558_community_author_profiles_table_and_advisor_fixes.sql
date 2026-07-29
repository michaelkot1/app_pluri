-- Community author attribution as a narrow synced table + advisor fixes (M8-02/03).
-- Replaces SECURITY DEFINER view `community_author_profiles` (lint 0010).
-- Fixes posts_guard search_path (lint 0011) and drops broad public listing on
-- `post-images` (lint 0025 — public buckets serve CDN URLs without SELECT).

drop view if exists public.community_author_profiles;

create table if not exists public.community_author_profiles (
  id uuid primary key references public.profiles (id) on delete cascade,
  display_name text,
  updated_at timestamptz not null default now()
);

alter table public.community_author_profiles enable row level security;

drop policy if exists community_author_profiles_select_all on public.community_author_profiles;
create policy community_author_profiles_select_all on public.community_author_profiles
  for select using (true);

revoke insert, update, delete on public.community_author_profiles from anon, authenticated;
grant select on public.community_author_profiles to anon, authenticated;

create or replace function public.sync_community_author_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_table_name = 'profiles' then
    update public.community_author_profiles
    set display_name = new.display_name, updated_at = now()
    where id = new.id;
    return new;
  end if;

  if tg_table_name = 'posts' then
    if new.hidden = false then
      insert into public.community_author_profiles (id, display_name)
      select p.id, p.display_name
      from public.profiles p
      where p.id = new.user_id
      on conflict (id) do update
        set display_name = excluded.display_name,
            updated_at = now();
    end if;
    return new;
  end if;

  return new;
end;
$$;

revoke all on function public.sync_community_author_profile() from public;
revoke all on function public.sync_community_author_profile() from anon, authenticated;

drop trigger if exists profiles_sync_community_author on public.profiles;
create trigger profiles_sync_community_author
  after update of display_name on public.profiles
  for each row
  execute function public.sync_community_author_profile();

drop trigger if exists posts_sync_community_author on public.posts;
create trigger posts_sync_community_author
  after insert or update of user_id, hidden on public.posts
  for each row
  execute function public.sync_community_author_profile();

insert into public.community_author_profiles (id, display_name)
select distinct p.id, p.display_name
from public.profiles p
join public.posts po on po.user_id = p.id and po.hidden = false
on conflict (id) do update
  set display_name = excluded.display_name,
      updated_at = now();

create or replace function public.posts_guard_moderation_columns()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if tg_op = 'UPDATE' then
    if coalesce(auth.role(), '') is distinct from 'service_role' then
      new.hidden := old.hidden;
      new.reported := old.reported;
      new.report_count := old.report_count;
    end if;
    new.updated_at := now();
  end if;
  return new;
end;
$$;

drop policy if exists post_images_select_public on storage.objects;
