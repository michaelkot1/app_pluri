-- Mirrored exercise media columns (M9-M1 / SPEC §14 #79).
--
-- `gif_url` stays the untouched WorkoutX original (the upstream URL requires an
-- `X-WorkoutX-Key` header, so the iOS app can never fetch it directly). The
-- mirror pipeline (`Scripts/mirror_exercise_media.mjs`) transcodes each GIF to a
-- small looping MP4, uploads it to the `exercise-media` bucket, and records the
-- public CDN URL here so the client plays video with no upstream credentials.

alter table public.exercises
  add column if not exists video_path text,
  add column if not exists video_url text,
  add column if not exists video_bytes integer,
  add column if not exists video_mirrored_at timestamptz;

comment on column public.exercises.gif_url is
  'Original WorkoutX GIF URL. Requires the X-WorkoutX-Key header — never fetchable from the iOS client.';
comment on column public.exercises.video_path is
  'Object path inside the exercise-media Storage bucket, e.g. exercises/0001.mp4.';
comment on column public.exercises.video_url is
  'Public CDN URL of the mirrored MP4. This is what the iOS client plays.';
comment on column public.exercises.video_bytes is
  'Size of the mirrored MP4 in bytes (mirror-run diagnostics).';
comment on column public.exercises.video_mirrored_at is
  'When the MP4 mirror last succeeded for this exercise.';

-- No RLS change needed: `exercises_select_anon` / `exercises_select_all` are
-- table-level SELECT policies, so anon and authenticated already read every
-- column, new ones included. Writes stay service-role only (no INSERT/UPDATE
-- policy exists on this table).
