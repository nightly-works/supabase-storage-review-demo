-- Fix 1: documents are private. Downloads then go through RLS (the user's session or a signed URL the
-- app creates for a short time), never through a permanent public URL.
update storage.buckets set public = false where id = 'documents';

-- Fix 2: a tenant reads only their own folder.
drop policy "documents read" on storage.objects;
create policy "documents read own" on storage.objects for select to authenticated
  using (bucket_id = 'documents' and (storage.foldername(name))[1] = (select auth.uid()::text));

-- Fix 3: and deletes only their own files.
drop policy "documents delete" on storage.objects;
create policy "documents delete own" on storage.objects for delete to authenticated
  using (bucket_id = 'documents' and (storage.foldername(name))[1] = (select auth.uid()::text));

-- Fix 4: avatars are written only into the user's own folder; a replace (update) checks the folder
-- both on the row it targets and on the row it leaves.
drop policy "avatars upload" on storage.objects;
drop policy "avatars replace" on storage.objects;
create policy "avatars upload own" on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid()::text));
create policy "avatars replace own" on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid()::text))
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid()::text));
