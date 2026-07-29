-- Exercise media Storage (SPEC §14 #79), mirroring the `post-images` patterns.
-- Bucket `exercise-media`: public-read (CDN URLs), service-role write only.
-- Path convention: `exercises/{exercise_id}.mp4`; MIME video/mp4; ~5 MB cap.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'exercise-media',
  'exercise-media',
  true,
  5242880, -- 5 MiB; a transcoded exercise loop lands well under 1 MiB
  array['video/mp4']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Public-read via bucket.public = true. Deliberately no SELECT policy on
-- storage.objects — that would let anyone list the whole bucket (advisor 0025),
-- same reasoning as `post-images`.

-- No INSERT/UPDATE/DELETE policies either: this is catalog media mirrored by
-- the owner-run batch job with the service-role key (which bypasses RLS), not
-- user-generated content. End users must never write here.
