-- Pluri schema v1 (M0-09) per PLAN §1.3.
-- Applied to the remote project as migration `pluri_schema_v1` on 2026-07-12.
-- Non-destructive: extends the existing profiles table and adds the core plan/
-- session tables. Legacy prototype tables (workout_plans, plan_days,
-- plan_day_exercises, user_equipment) are left untouched pending owner approval.

-- 1. profiles: add columns PLAN §1.3 expects that are missing.
alter table public.profiles
  add column if not exists display_name text,
  add column if not exists units text not null default 'metric' check (units in ('metric', 'imperial')),
  add column if not exists maintenance_calories integer check (maintenance_calories between 800 and 10000),
  add column if not exists allergies text[] not null default '{}',
  add column if not exists equipment text[] not null default '{}';

-- Owner-only delete (needed for App Store account deletion).
drop policy if exists profiles_delete_own on public.profiles;
create policy profiles_delete_own on public.profiles
  for delete using ((select auth.uid()) = id);

-- 2. plans
create table if not exists public.plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  goal text not null,
  name text,
  start_date date not null,
  end_date date not null,
  weeks integer not null check (weeks between 3 and 12),
  schedule_type text not null default 'scheduled' check (schedule_type in ('scheduled', 'flexible')),
  status text not null default 'active' check (status in ('active', 'completed', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 3. plan_workouts
create table if not exists public.plan_workouts (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.plans (id) on delete cascade,
  week_number integer not null check (week_number >= 1),
  scheduled_date date,
  scheduled_day text check (scheduled_day in ('mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun')),
  name text not null,
  workout_type text not null default 'weights' check (workout_type in ('weights', 'cardio', 'flexibility')),
  color text,
  duration_minutes integer not null check (duration_minutes between 10 and 240),
  status text not null default 'scheduled' check (status in ('scheduled', 'completed', 'skipped')),
  order_index integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 4. workout_exercises
create table if not exists public.workout_exercises (
  id uuid primary key default gen_random_uuid(),
  plan_workout_id uuid not null references public.plan_workouts (id) on delete cascade,
  workoutx_exercise_id text not null,
  cached_metadata jsonb not null default '{}',
  target_sets integer check (target_sets between 1 and 20),
  target_reps text,
  target_duration_seconds integer check (target_duration_seconds between 5 and 3600),
  order_index integer not null default 0,
  created_at timestamptz not null default now()
);

-- 5. workout_sessions (actual performances + manual logs, SPEC §9.3)
create table if not exists public.workout_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  plan_workout_id uuid references public.plan_workouts (id) on delete set null,
  activity_type text not null default 'workout' check (activity_type in ('workout', 'cardio', 'flexibility')),
  started_at timestamptz not null,
  ended_at timestamptz,
  duration_seconds integer check (duration_seconds >= 0),
  distance_meters numeric check (distance_meters >= 0),
  notes text,
  synced_to_health boolean not null default false,
  is_manual_log boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 6. set_logs
create table if not exists public.set_logs (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.workout_sessions (id) on delete cascade,
  workout_exercise_id uuid references public.workout_exercises (id) on delete set null,
  exercise_name text not null,
  set_number integer not null check (set_number >= 1),
  reps integer check (reps >= 0),
  weight_kg numeric check (weight_kg >= 0),
  duration_seconds integer check (duration_seconds >= 0),
  created_at timestamptz not null default now()
);

-- Indexes on foreign keys used by RLS subqueries and common lookups.
create index if not exists plans_user_id_idx on public.plans (user_id);
create index if not exists plan_workouts_plan_id_idx on public.plan_workouts (plan_id);
create index if not exists workout_exercises_plan_workout_id_idx on public.workout_exercises (plan_workout_id);
create index if not exists workout_sessions_user_id_idx on public.workout_sessions (user_id);
create index if not exists workout_sessions_plan_workout_id_idx on public.workout_sessions (plan_workout_id);
create index if not exists set_logs_session_id_idx on public.set_logs (session_id);

-- RLS: owner-only on everything.
alter table public.plans enable row level security;
alter table public.plan_workouts enable row level security;
alter table public.workout_exercises enable row level security;
alter table public.workout_sessions enable row level security;
alter table public.set_logs enable row level security;

-- plans: direct ownership.
drop policy if exists plans_select_own on public.plans;
create policy plans_select_own on public.plans
  for select using ((select auth.uid()) = user_id);
drop policy if exists plans_insert_own on public.plans;
create policy plans_insert_own on public.plans
  for insert with check ((select auth.uid()) = user_id);
drop policy if exists plans_update_own on public.plans;
create policy plans_update_own on public.plans
  for update using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
drop policy if exists plans_delete_own on public.plans;
create policy plans_delete_own on public.plans
  for delete using ((select auth.uid()) = user_id);

-- plan_workouts: ownership via plans.
drop policy if exists plan_workouts_select_own on public.plan_workouts;
create policy plan_workouts_select_own on public.plan_workouts
  for select using (exists (
    select 1 from public.plans p
    where p.id = plan_workouts.plan_id and p.user_id = (select auth.uid())
  ));
drop policy if exists plan_workouts_insert_own on public.plan_workouts;
create policy plan_workouts_insert_own on public.plan_workouts
  for insert with check (exists (
    select 1 from public.plans p
    where p.id = plan_workouts.plan_id and p.user_id = (select auth.uid())
  ));
drop policy if exists plan_workouts_update_own on public.plan_workouts;
create policy plan_workouts_update_own on public.plan_workouts
  for update using (exists (
    select 1 from public.plans p
    where p.id = plan_workouts.plan_id and p.user_id = (select auth.uid())
  ))
  with check (exists (
    select 1 from public.plans p
    where p.id = plan_workouts.plan_id and p.user_id = (select auth.uid())
  ));
drop policy if exists plan_workouts_delete_own on public.plan_workouts;
create policy plan_workouts_delete_own on public.plan_workouts
  for delete using (exists (
    select 1 from public.plans p
    where p.id = plan_workouts.plan_id and p.user_id = (select auth.uid())
  ));

-- workout_exercises: ownership via plan_workouts → plans.
drop policy if exists workout_exercises_select_own on public.workout_exercises;
create policy workout_exercises_select_own on public.workout_exercises
  for select using (exists (
    select 1 from public.plan_workouts pw
    join public.plans p on p.id = pw.plan_id
    where pw.id = workout_exercises.plan_workout_id and p.user_id = (select auth.uid())
  ));
drop policy if exists workout_exercises_insert_own on public.workout_exercises;
create policy workout_exercises_insert_own on public.workout_exercises
  for insert with check (exists (
    select 1 from public.plan_workouts pw
    join public.plans p on p.id = pw.plan_id
    where pw.id = workout_exercises.plan_workout_id and p.user_id = (select auth.uid())
  ));
drop policy if exists workout_exercises_update_own on public.workout_exercises;
create policy workout_exercises_update_own on public.workout_exercises
  for update using (exists (
    select 1 from public.plan_workouts pw
    join public.plans p on p.id = pw.plan_id
    where pw.id = workout_exercises.plan_workout_id and p.user_id = (select auth.uid())
  ))
  with check (exists (
    select 1 from public.plan_workouts pw
    join public.plans p on p.id = pw.plan_id
    where pw.id = workout_exercises.plan_workout_id and p.user_id = (select auth.uid())
  ));
drop policy if exists workout_exercises_delete_own on public.workout_exercises;
create policy workout_exercises_delete_own on public.workout_exercises
  for delete using (exists (
    select 1 from public.plan_workouts pw
    join public.plans p on p.id = pw.plan_id
    where pw.id = workout_exercises.plan_workout_id and p.user_id = (select auth.uid())
  ));

-- workout_sessions: direct ownership.
drop policy if exists workout_sessions_select_own on public.workout_sessions;
create policy workout_sessions_select_own on public.workout_sessions
  for select using ((select auth.uid()) = user_id);
drop policy if exists workout_sessions_insert_own on public.workout_sessions;
create policy workout_sessions_insert_own on public.workout_sessions
  for insert with check ((select auth.uid()) = user_id);
drop policy if exists workout_sessions_update_own on public.workout_sessions;
create policy workout_sessions_update_own on public.workout_sessions
  for update using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
drop policy if exists workout_sessions_delete_own on public.workout_sessions;
create policy workout_sessions_delete_own on public.workout_sessions
  for delete using ((select auth.uid()) = user_id);

-- set_logs: ownership via workout_sessions.
drop policy if exists set_logs_select_own on public.set_logs;
create policy set_logs_select_own on public.set_logs
  for select using (exists (
    select 1 from public.workout_sessions ws
    where ws.id = set_logs.session_id and ws.user_id = (select auth.uid())
  ));
drop policy if exists set_logs_insert_own on public.set_logs;
create policy set_logs_insert_own on public.set_logs
  for insert with check (exists (
    select 1 from public.workout_sessions ws
    where ws.id = set_logs.session_id and ws.user_id = (select auth.uid())
  ));
drop policy if exists set_logs_update_own on public.set_logs;
create policy set_logs_update_own on public.set_logs
  for update using (exists (
    select 1 from public.workout_sessions ws
    where ws.id = set_logs.session_id and ws.user_id = (select auth.uid())
  ))
  with check (exists (
    select 1 from public.workout_sessions ws
    where ws.id = set_logs.session_id and ws.user_id = (select auth.uid())
  ));
drop policy if exists set_logs_delete_own on public.set_logs;
create policy set_logs_delete_own on public.set_logs
  for delete using (exists (
    select 1 from public.workout_sessions ws
    where ws.id = set_logs.session_id and ws.user_id = (select auth.uid())
  ));
