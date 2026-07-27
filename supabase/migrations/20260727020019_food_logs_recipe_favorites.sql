-- food_logs + recipe_favorites (M7-02) — nutrition logging & MealDB favorites
-- per SPEC §14 #67f / PLAN §1.3.
-- Owner-only RLS. FK user_id → profiles CASCADE.
-- Naming prefers #67f (`food_name`, `logged_date`) over vague PLAN wording.

-- 1. food_logs
create table if not exists public.food_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  food_name text not null,
  serving text not null,
  calories integer not null check (calories >= 0),
  macros jsonb,
  meal text not null check (meal in ('breakfast', 'lunch', 'dinner', 'dessert', 'snack')),
  logged_date date not null,
  mealdb_recipe_id text,
  nutrition_food_id text,
  created_at timestamptz not null default now()
);

create index if not exists food_logs_user_id_idx
  on public.food_logs (user_id);
create index if not exists food_logs_user_id_logged_date_idx
  on public.food_logs (user_id, logged_date);

alter table public.food_logs enable row level security;

drop policy if exists food_logs_select_own on public.food_logs;
create policy food_logs_select_own on public.food_logs
  for select using ((select auth.uid()) = user_id);

drop policy if exists food_logs_insert_own on public.food_logs;
create policy food_logs_insert_own on public.food_logs
  for insert with check ((select auth.uid()) = user_id);

drop policy if exists food_logs_update_own on public.food_logs;
create policy food_logs_update_own on public.food_logs
  for update using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists food_logs_delete_own on public.food_logs;
create policy food_logs_delete_own on public.food_logs
  for delete using ((select auth.uid()) = user_id);

-- 2. recipe_favorites
create table if not exists public.recipe_favorites (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  mealdb_recipe_id text not null,
  cached_title text,
  cached_thumb_url text,
  created_at timestamptz not null default now(),
  unique (user_id, mealdb_recipe_id)
);

create index if not exists recipe_favorites_user_id_idx
  on public.recipe_favorites (user_id);

alter table public.recipe_favorites enable row level security;

drop policy if exists recipe_favorites_select_own on public.recipe_favorites;
create policy recipe_favorites_select_own on public.recipe_favorites
  for select using ((select auth.uid()) = user_id);

drop policy if exists recipe_favorites_insert_own on public.recipe_favorites;
create policy recipe_favorites_insert_own on public.recipe_favorites
  for insert with check ((select auth.uid()) = user_id);

drop policy if exists recipe_favorites_update_own on public.recipe_favorites;
create policy recipe_favorites_update_own on public.recipe_favorites
  for update using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists recipe_favorites_delete_own on public.recipe_favorites;
create policy recipe_favorites_delete_own on public.recipe_favorites
  for delete using ((select auth.uid()) = user_id);
