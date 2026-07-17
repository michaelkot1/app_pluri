-- replace_remaining_plan (M3-14): atomic Manage Plan persistence.
--
-- One SECURITY INVOKER function that, in a single transaction, verifies the
-- caller owns the plan, updates plan + profile settings, upserts the
-- replacement (and order-shifted preserved) workout rows + exercises, and
-- deletes the replaced scheduled rows by explicit ID — keeping the
-- insert-then-delete semantics of SPEC §14 #39 but making them atomic, so a
-- failure can never leave a partially replaced remote plan.
--
-- SECURITY INVOKER on purpose: the function runs as the authenticated
-- caller, so the owner-only RLS policies from 0001_pluri_schema_v1 apply to
-- every statement inside it. The explicit ownership check up front just
-- turns "row invisible under RLS" into a clear error.

create or replace function public.replace_remaining_plan(payload jsonb)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_plan_id uuid := (payload->>'plan_id')::uuid;
  v_plan_update jsonb := coalesce(payload->'plan_update', '{}'::jsonb);
  v_profile_update jsonb := coalesce(payload->'profile_update', '{}'::jsonb);
  v_upsert_workouts jsonb :=
    coalesce(payload->'insert_workouts', '[]'::jsonb)
    || coalesce(payload->'update_workouts', '[]'::jsonb);
  v_insert_exercises jsonb := coalesce(payload->'insert_exercises', '[]'::jsonb);
  v_delete_ids uuid[] := coalesce(
    (select array_agg(value::uuid) from jsonb_array_elements_text(coalesce(payload->'delete_workout_ids', '[]'::jsonb))),
    '{}'::uuid[]
  );
begin
  if v_plan_id is null then
    raise exception 'replace_remaining_plan: payload.plan_id is required';
  end if;

  -- Ownership check first (RLS would silently hide the row; be explicit).
  if not exists (
    select 1 from public.plans p
    where p.id = v_plan_id and p.user_id = (select auth.uid())
  ) then
    raise exception 'replace_remaining_plan: plan not found for this user';
  end if;

  -- Every workout row in the payload must target this plan.
  if exists (
    select 1
    from jsonb_to_recordset(v_upsert_workouts) as w(plan_id uuid)
    where w.plan_id is distinct from v_plan_id
  ) then
    raise exception 'replace_remaining_plan: workout rows must belong to the plan';
  end if;

  -- 1. Plan settings (Manage Plan §6.2). Missing keys keep current values.
  update public.plans
  set goal = coalesce(v_plan_update->>'goal', goal),
      name = coalesce(v_plan_update->>'name', name),
      start_date = coalesce((v_plan_update->>'start_date')::date, start_date),
      end_date = coalesce((v_plan_update->>'end_date')::date, end_date),
      weeks = coalesce((v_plan_update->>'weeks')::integer, weeks),
      schedule_type = coalesce(v_plan_update->>'schedule_type', schedule_type),
      status = coalesce(v_plan_update->>'status', status),
      updated_at = now()
  where id = v_plan_id;

  -- 2. Profile settings for the caller.
  update public.profiles
  set goal = coalesce(v_profile_update->>'goal', goal),
      days_per_week = coalesce((v_profile_update->>'days_per_week')::integer, days_per_week),
      workout_days = coalesce(
        (select array_agg(value) from jsonb_array_elements_text(v_profile_update->'workout_days')),
        workout_days
      ),
      schedule_type = coalesce(v_profile_update->>'schedule_type', schedule_type),
      program_weeks = coalesce((v_profile_update->>'program_weeks')::integer, program_weeks),
      session_minutes = coalesce((v_profile_update->>'session_minutes')::integer, session_minutes),
      start_date = coalesce((v_profile_update->>'start_date')::date, start_date),
      units = coalesce(v_profile_update->>'units', units)
  where id = (select auth.uid());

  -- 3. Insert replacement workouts + upsert preserved rows whose order
  --    shifted (same upsert path; replacement IDs are fresh, preserved IDs
  --    conflict and update in place). Retry-safe via on conflict.
  insert into public.plan_workouts (
    id, plan_id, week_number, scheduled_date, scheduled_day, name,
    workout_type, color, duration_minutes, status, order_index
  )
  select w.id, w.plan_id, w.week_number, w.scheduled_date, w.scheduled_day, w.name,
         w.workout_type, w.color, w.duration_minutes, w.status, w.order_index
  from jsonb_to_recordset(v_upsert_workouts) as w(
    id uuid, plan_id uuid, week_number integer, scheduled_date date,
    scheduled_day text, name text, workout_type text, color text,
    duration_minutes integer, status text, order_index integer
  )
  on conflict (id) do update
  set week_number = excluded.week_number,
      scheduled_date = excluded.scheduled_date,
      scheduled_day = excluded.scheduled_day,
      name = excluded.name,
      workout_type = excluded.workout_type,
      color = excluded.color,
      duration_minutes = excluded.duration_minutes,
      status = excluded.status,
      order_index = excluded.order_index,
      updated_at = now();

  -- 4. Exercises for the replacement workouts.
  insert into public.workout_exercises (
    id, plan_workout_id, workoutx_exercise_id, cached_metadata,
    target_sets, target_reps, target_duration_seconds, order_index
  )
  select e.id, e.plan_workout_id, e.workoutx_exercise_id, e.cached_metadata,
         e.target_sets, e.target_reps, e.target_duration_seconds, e.order_index
  from jsonb_to_recordset(v_insert_exercises) as e(
    id uuid, plan_workout_id uuid, workoutx_exercise_id text,
    cached_metadata jsonb, target_sets integer, target_reps text,
    target_duration_seconds integer, order_index integer
  )
  on conflict (id) do update
  set workoutx_exercise_id = excluded.workoutx_exercise_id,
      cached_metadata = excluded.cached_metadata,
      target_sets = excluded.target_sets,
      target_reps = excluded.target_reps,
      target_duration_seconds = excluded.target_duration_seconds,
      order_index = excluded.order_index;

  -- 5. Delete the replaced scheduled rows last (children explicitly first,
  --    matching the client path — we never depend on the FK cascade).
  if array_length(v_delete_ids, 1) > 0 then
    delete from public.workout_exercises
    where plan_workout_id = any(v_delete_ids);

    delete from public.plan_workouts
    where id = any(v_delete_ids) and plan_id = v_plan_id;
  end if;
end;
$$;

-- Signed-in users only; nothing here is anonymous-safe.
revoke execute on function public.replace_remaining_plan(jsonb) from public, anon;
grant execute on function public.replace_remaining_plan(jsonb) to authenticated;
