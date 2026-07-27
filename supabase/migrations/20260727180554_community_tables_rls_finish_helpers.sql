-- ---------------------------------------------------------------------------
-- Helpers (finish) — triggers + author sync function live in 80558.
-- Keep posts_guard search_path fixed here for idempotent repair.
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
