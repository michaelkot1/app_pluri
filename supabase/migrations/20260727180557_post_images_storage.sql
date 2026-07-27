-- Post images Storage (M8-03) per SPEC §14 #72c.
-- Bucket `post-images`: public-read; authenticated upload under `{user_id}/…`.
-- Path convention: `{user_id}/{post_id}.{ext}`; MIME jpeg/png/heic; ~5 MB.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'post-images',
  'post-images',
  true,
  5242880, -- 5 MiB
  array['image/jpeg', 'image/png', 'image/heic', 'image/heif']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Public-read via bucket.public = true (CDN URLs). No broad SELECT policy —
-- that would allow listing all objects (advisor 0025).

-- Authenticated upload only under own user_id folder prefix.
drop policy if exists post_images_insert_own on storage.objects;
create policy post_images_insert_own on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'post-images'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

-- Upsert / replace requires UPDATE (+ SELECT already granted above).
drop policy if exists post_images_update_own on storage.objects;
create policy post_images_update_own on storage.objects
  for update to authenticated
  using (
    bucket_id = 'post-images'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  )
  with check (
    bucket_id = 'post-images'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

drop policy if exists post_images_delete_own on storage.objects;
create policy post_images_delete_own on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'post-images'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );
