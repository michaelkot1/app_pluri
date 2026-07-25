-- plan_workouts.focus CHECK (M3-20 follow-up): allow only SessionFocusCode
-- snake_case values (or NULL for legacy rows). Column + RPC already landed
-- in 20260717211519_plan_workouts_focus.

alter table public.plan_workouts
  drop constraint if exists plan_workouts_focus_check;

alter table public.plan_workouts
  add constraint plan_workouts_focus_check
  check (
    focus is null
    or focus in (
      'full_body_a',
      'full_body_b',
      'push',
      'pull',
      'legs',
      'upper',
      'lower',
      'chest_triceps',
      'back_biceps',
      'shoulders_arms',
      'accessories'
    )
  );
