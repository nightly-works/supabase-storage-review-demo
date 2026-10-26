-- The app as delivered: a tenant-screening app built with an AI app builder. Tenants upload their ID
-- scan and payslips; each user has an avatar shown next to their messages.
insert into storage.buckets (id, public) values
  ('avatars', true),     -- avatars are meant to be public
  ('documents', true);   -- created public "so the preview works"

-- Avatars: any signed-in user may upload and replace avatars.
create policy "avatars upload" on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars');
create policy "avatars replace" on storage.objects for update to authenticated
  using (bucket_id = 'avatars');
create policy "avatars read" on storage.objects for select to authenticated
  using (bucket_id = 'avatars');

-- Documents: each tenant uploads into a folder named after their user id ("<user id>/payslip-1.pdf").
create policy "documents upload" on storage.objects for insert to authenticated
  with check (bucket_id = 'documents' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "documents read" on storage.objects for select to authenticated
  using (bucket_id = 'documents');
create policy "documents delete" on storage.objects for delete to authenticated
  using (bucket_id = 'documents');
