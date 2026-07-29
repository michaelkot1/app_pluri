-- ---------------------------------------------------------------------------
-- Ensure posts SELECT filters exist (already applied remotely; recreate safely)
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

-- ---------------------------------------------------------------------------
-- post_polls policies (correct set)
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
-- poll_votes
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
-- saved_posts
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
-- moderation tables
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
