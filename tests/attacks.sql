-- The four attacks, run as the API roles. Called with -v expect=works (the app as delivered: each attack
-- must succeed) or -v expect=refused (after the fixes: each must fail). Any other outcome stops the run.
\set alice '00000000-0000-0000-0000-00000000000a'
\set bob '00000000-0000-0000-0000-00000000000b'
select set_config('demo.expect', :'expect', false);

create or replace function pg_temp.verdict(n int, what text, worked boolean) returns void language plpgsql as $$
begin
  if worked <> (current_setting('demo.expect') = 'works') then
    raise exception 'attack %: % %, expected the attack to be %', n, what,
      case when worked then 'worked' else 'was refused' end, current_setting('demo.expect');
  end if;
  raise notice 'attack %: % % (as expected)', n, what, case when worked then 'worked' else 'was refused' end;
end $$;

-- 1. A stranger, not signed in, downloads Bob's ID scan from its URL.
reset role;
select set_config('request.jwt.claims', '', false);
set role anon;
select pg_temp.verdict(1, 'anonymous download of another tenant''s ID scan',
  storage.can_download('documents', :'bob' || '/id-scan.jpg'));

-- 2. Alice, signed in, lists the documents bucket and downloads Bob's ID scan with her own session.
reset role;
select set_config('request.jwt.claims', json_build_object('sub', :'alice')::text, false);
set role authenticated;
select pg_temp.verdict(2, 'signed-in tenant listing another tenant''s documents',
  exists (select 1 from storage.objects where bucket_id = 'documents' and name like :'bob' || '/%'));
select pg_temp.verdict(2, 'signed-in tenant downloading another tenant''s ID scan',
  storage.can_download('documents', :'bob' || '/id-scan.jpg'));

-- 3. Alice deletes Bob's ID scan. A delete must also pass the read policies, so fix 2 alone would stop
-- this one: the delete policy itself is checked too, for an own-folder condition.
select pg_temp.verdict(3, 'delete policy without an own-folder condition',
  not exists (select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects'
              and cmd = 'DELETE' and qual like '%foldername%'));
with gone as (delete from storage.objects where bucket_id = 'documents' and name = :'bob' || '/id-scan.jpg' returning 1)
select pg_temp.verdict(3, 'deleting another tenant''s document', exists (select 1 from gone));

-- 4. Alice replaces Bob's avatar, then uploads into Bob's avatar folder.
with changed as (
  update storage.objects set metadata = '{"replaced_by": "alice"}'
  where bucket_id = 'avatars' and name = :'bob' || '/avatar.png' returning 1)
select pg_temp.verdict(4, 'replacing another user''s avatar', exists (select 1 from changed));
do $$
declare worked boolean := true;
begin
  begin
    insert into storage.objects (bucket_id, name) values ('avatars', '00000000-0000-0000-0000-00000000000b/avatar-2.png');
  exception when insufficient_privilege then
    worked := false;
  end;
  perform pg_temp.verdict(4, 'uploading into another user''s avatar folder', worked);
  worked := true;
  begin
    update storage.objects set name = '00000000-0000-0000-0000-00000000000b/moved.png'
      where bucket_id = 'avatars' and name = '00000000-0000-0000-0000-00000000000a/avatar.png';
  exception when insufficient_privilege then
    worked := false;
  end;
  perform pg_temp.verdict(4, 'moving one''s own avatar into another user''s folder', worked);
end $$;
reset role;
