-- Two tenants, Alice (…a) and Bob (…b), each with an ID scan and an avatar. Inserted as the service role.
insert into storage.objects (bucket_id, name, owner_id) values
  ('documents', '00000000-0000-0000-0000-00000000000a/id-scan.jpg', '00000000-0000-0000-0000-00000000000a'),
  ('documents', '00000000-0000-0000-0000-00000000000b/id-scan.jpg', '00000000-0000-0000-0000-00000000000b'),
  ('avatars', '00000000-0000-0000-0000-00000000000a/avatar.png', '00000000-0000-0000-0000-00000000000a'),
  ('avatars', '00000000-0000-0000-0000-00000000000b/avatar.png', '00000000-0000-0000-0000-00000000000b');
