-- Finish / repair community tables + RLS (M8-02).
-- Idempotent: completes objects missing from the truncated remote apply of
-- `community_tables_rls`, and is a no-op when the full local migration already ran.

-- Fix mis-created post_polls policy (was INSERT under a SELECT name).
drop policy if exists post_polls_select_all on public.post_polls;

-- ---------------------------------------------------------------------------
-- Missing tables (create if not exists)
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

