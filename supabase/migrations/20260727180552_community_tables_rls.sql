-- Community tables + RLS (M8-02) per SPEC §14 #72 / #73 / PLAN §1.3.
-- Posts publicly readable when not staff-hidden; viewer hide/block/report soft-filters;
-- owner writes; moderation tables owner-scoped; narrow author view for display_name.

-- ---------------------------------------------------------------------------
-- 1. posts
-- ---------------------------------------------------------------------------
create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  title text not null,
  body text not null,
  post_type text not null check (
    post_type in ('general', 'gear', 'recipe', 'share_workout')
  ),
  image_path text,
  workout_snapshot jsonb,
  reported boolean not null default false,
  report_count integer not null default 0 check (report_count >= 0),
  hidden boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists posts_created_at_idx
  on public.posts (created_at desc);
create index if not exists posts_user_id_idx
  on public.posts (user_id);
create index if not exists posts_post_type_idx
  on public.posts (post_type);
create index if not exists posts_hidden_created_at_idx
  on public.posts (hidden, created_at desc);

alter table public.posts enable row level security;

-- ---------------------------------------------------------------------------
-- 2. post_likes
-- ---------------------------------------------------------------------------
create table if not exists public.post_likes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  post_id uuid not null references public.posts (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, post_id)
);

create index if not exists post_likes_post_id_idx
  on public.post_likes (post_id);
create index if not exists post_likes_user_id_idx
  on public.post_likes (user_id);

alter table public.post_likes enable row level security;

-- ---------------------------------------------------------------------------
-- 3. post_comments
-- ---------------------------------------------------------------------------
create table if not exists public.post_comments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  post_id uuid not null references public.posts (id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now()
);

create index if not exists post_comments_post_id_idx
  on public.post_comments (post_id);
create index if not exists post_comments_user_id_idx
  on public.post_comments (user_id);
create index if not exists post_comments_post_id_created_at_idx
  on public.post_comments (post_id, created_at);

alter table public.post_comments enable row level security;

-- ---------------------------------------------------------------------------
-- 4. post_polls
-- ---------------------------------------------------------------------------
create table if not exists public.post_polls (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts (id) on delete cascade,
  question text not null,
  options jsonb not null,
  created_at timestamptz not null default now(),
  unique (post_id)
);

create index if not exists post_polls_post_id_idx
  on public.post_polls (post_id);

alter table public.post_polls enable row level security;

-- ---------------------------------------------------------------------------
-- 5. poll_votes
-- ---------------------------------------------------------------------------
create table if not exists public.poll_votes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  poll_id uuid not null references public.post_polls (id) on delete cascade,
  option_index integer not null check (option_index >= 0),
  created_at timestamptz not null default now(),
  unique (user_id, poll_id)
);

create index if not exists poll_votes_poll_id_idx
  on public.poll_votes (poll_id);
create index if not exists poll_votes_user_id_idx
  on public.poll_votes (user_id);

alter table public.poll_votes enable row level security;

-- ---------------------------------------------------------------------------
-- 6. saved_posts
-- ---------------------------------------------------------------------------
create table if not exists public.saved_posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  post_id uuid not null references public.posts (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, post_id)
);

create index if not exists saved_posts_user_id_idx
  on public.saved_posts (user_id);
create index if not exists saved_posts_post_id_idx
  on public.saved_posts (post_id);

alter table public.saved_posts enable row level security;

-- ---------------------------------------------------------------------------
-- 7. post_reports / post_hides / user_blocks
-- ---------------------------------------------------------------------------
create table if not exists public.post_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles (id) on delete cascade,
  post_id uuid not null references public.posts (id) on delete cascade,
  reason text not null default '',
  created_at timestamptz not null default now(),
  unique (reporter_id, post_id)
);

create index if not exists post_reports_post_id_idx
  on public.post_reports (post_id);
create index if not exists post_reports_reporter_id_idx
  on public.post_reports (reporter_id);

alter table public.post_reports enable row level security;

create table if not exists public.post_hides (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  post_id uuid not null references public.posts (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, post_id)
);

create index if not exists post_hides_user_id_idx
  on public.post_hides (user_id);
create index if not exists post_hides_post_id_idx
  on public.post_hides (post_id);

alter table public.post_hides enable row level security;

create table if not exists public.user_blocks (
  id uuid primary key default gen_random_uuid(),
  blocker_id uuid not null references public.profiles (id) on delete cascade,
  blocked_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create index if not exists user_blocks_blocker_id_idx
  on public.user_blocks (blocker_id);
create index if not exists user_blocks_blocked_id_idx
  on public.user_blocks (blocked_id);

alter table public.user_blocks enable row level security;

-- ---------------------------------------------------------------------------
-- 8. Helpers: report bump + guard staff-hidden / report counters
-- ---------------------------------------------------------------------------
create or replace function public.bump_post_report_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.posts
  set
    reported = true,
    report_count = report_count + 1,
    updated_at = now()
  where id = new.post_id;
  return new;
end;
$$;

revoke all on function public.bump_post_report_count() from public;
revoke all on function public.bump_post_report_count() from anon, authenticated;

drop trigger if exists post_reports_bump_count on public.post_reports;
create trigger post_reports_bump_count
  after insert on public.post_reports
  for each row
  execute function public.bump_post_report_count();

create or replace function public.posts_guard_moderation_columns()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if tg_op = 'UPDATE' then
    -- Clients may not flip staff hide or manually rewrite report flags.
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

drop trigger if exists posts_guard_moderation on public.posts;
create trigger posts_guard_moderation
  before update on public.posts
  for each row
  execute function public.posts_guard_moderation_columns();

-- ---------------------------------------------------------------------------
-- 9. Narrow author attribution table (no full profiles leak)
-- ---------------------------------------------------------------------------
-- Populated by sync triggers in a later migration once posts exist; stub table
-- here so fresh installs match the final shape (see 20260727180558_*).
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

-- ---------------------------------------------------------------------------
-- 10. RLS — posts
-- ---------------------------------------------------------------------------
drop policy if exists posts_select_visible on public.posts;
create policy posts_select_visible on public.posts
  for select using (
    hidden = false
    and (
      (select auth.uid()) is null
      or (
        not exists (
          select 1 from public.post_hides h
          where h.post_id = posts.id
            and h.user_id = (select auth.uid())
        )
        and not exists (
          select 1 from public.user_blocks b
          where b.blocked_id = posts.user_id
            and b.blocker_id = (select auth.uid())
        )
        and not exists (
          select 1 from public.post_reports r
          where r.post_id = posts.id
            and r.reporter_id = (select auth.uid())
        )
      )
    )
  );

drop policy if exists posts_insert_own on public.posts;
create policy posts_insert_own on public.posts
  for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and hidden = false
    and reported = false
    and report_count = 0
  );

drop policy if exists posts_update_own on public.posts;
create policy posts_update_own on public.posts
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists posts_delete_own on public.posts;
create policy posts_delete_own on public.posts
  for delete to authenticated
  using ((select auth.uid()) = user_id);

-- ---------------------------------------------------------------------------
-- 11. RLS — post_likes (public read for counts; owner write)
-- ---------------------------------------------------------------------------
drop policy if exists post_likes_select_all on public.post_likes;
create policy post_likes_select_all on public.post_likes
  for select using (true);

drop policy if exists post_likes_insert_own on public.post_likes;
create policy post_likes_insert_own on public.post_likes
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists post_likes_delete_own on public.post_likes;
create policy post_likes_delete_own on public.post_likes
  for delete to authenticated
  using ((select auth.uid()) = user_id);

-- ---------------------------------------------------------------------------
-- 12. RLS — post_comments
-- ---------------------------------------------------------------------------
drop policy if exists post_comments_select_all on public.post_comments;
create policy post_comments_select_all on public.post_comments
  for select using (true);

drop policy if exists post_comments_insert_own on public.post_comments;
create policy post_comments_insert_own on public.post_comments
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists post_comments_update_own on public.post_comments;
create policy post_comments_update_own on public.post_comments
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists post_comments_delete_own on public.post_comments;
create policy post_comments_delete_own on public.post_comments
  for delete to authenticated
  using ((select auth.uid()) = user_id);

-- ---------------------------------------------------------------------------
-- 13. RLS — post_polls (readable with post; owner insert via post ownership)
-- ---------------------------------------------------------------------------
drop policy if exists post_polls_select_all on public.post_polls;
create policy post_polls_select_all on public.post_polls
  for select using (true);

drop policy if exists post_polls_insert_own on public.post_polls;
create policy post_polls_insert_own on public.post_polls
  for insert to authenticated
  with check (
    exists (
      select 1 from public.posts p
      where p.id = post_polls.post_id
        and p.user_id = (select auth.uid())
    )
  );

drop policy if exists post_polls_update_own on public.post_polls;
create policy post_polls_update_own on public.post_polls
  for update to authenticated
  using (
    exists (
      select 1 from public.posts p
      where p.id = post_polls.post_id
        and p.user_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public.posts p
      where p.id = post_polls.post_id
        and p.user_id = (select auth.uid())
    )
  );

drop policy if exists post_polls_delete_own on public.post_polls;
create policy post_polls_delete_own on public.post_polls
  for delete to authenticated
  using (
    exists (
      select 1 from public.posts p
      where p.id = post_polls.post_id
        and p.user_id = (select auth.uid())
    )
  );

-- ---------------------------------------------------------------------------
-- 14. RLS — poll_votes
-- ---------------------------------------------------------------------------
drop policy if exists poll_votes_select_all on public.poll_votes;
create policy poll_votes_select_all on public.poll_votes
  for select using (true);

drop policy if exists poll_votes_insert_own on public.poll_votes;
create policy poll_votes_insert_own on public.poll_votes
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists poll_votes_update_own on public.poll_votes;
create policy poll_votes_update_own on public.poll_votes
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists poll_votes_delete_own on public.poll_votes;
create policy poll_votes_delete_own on public.poll_votes
  for delete to authenticated
  using ((select auth.uid()) = user_id);

-- ---------------------------------------------------------------------------
-- 15. RLS — saved_posts (owner-only)
-- ---------------------------------------------------------------------------
drop policy if exists saved_posts_select_own on public.saved_posts;
create policy saved_posts_select_own on public.saved_posts
  for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists saved_posts_insert_own on public.saved_posts;
create policy saved_posts_insert_own on public.saved_posts
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists saved_posts_delete_own on public.saved_posts;
create policy saved_posts_delete_own on public.saved_posts
  for delete to authenticated
  using ((select auth.uid()) = user_id);

-- ---------------------------------------------------------------------------
-- 16. RLS — post_reports / post_hides / user_blocks
-- ---------------------------------------------------------------------------
drop policy if exists post_reports_select_own on public.post_reports;
create policy post_reports_select_own on public.post_reports
  for select to authenticated
  using ((select auth.uid()) = reporter_id);

drop policy if exists post_reports_insert_own on public.post_reports;
create policy post_reports_insert_own on public.post_reports
  for insert to authenticated
  with check ((select auth.uid()) = reporter_id);

drop policy if exists post_hides_select_own on public.post_hides;
create policy post_hides_select_own on public.post_hides
  for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists post_hides_insert_own on public.post_hides;
create policy post_hides_insert_own on public.post_hides
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists post_hides_delete_own on public.post_hides;
create policy post_hides_delete_own on public.post_hides
  for delete to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists user_blocks_select_own on public.user_blocks;
create policy user_blocks_select_own on public.user_blocks
  for select to authenticated
  using ((select auth.uid()) = blocker_id);

drop policy if exists user_blocks_insert_own on public.user_blocks;
create policy user_blocks_insert_own on public.user_blocks
  for insert to authenticated
  with check ((select auth.uid()) = blocker_id);

drop policy if exists user_blocks_delete_own on public.user_blocks;
create policy user_blocks_delete_own on public.user_blocks
  for delete to authenticated
  using ((select auth.uid()) = blocker_id);
