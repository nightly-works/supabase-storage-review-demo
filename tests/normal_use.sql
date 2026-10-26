-- Normal use after the fixes: each tenant works with their own files, avatars stay public.
\set alice '00000000-0000-0000-0000-00000000000a'
\set bob '00000000-0000-0000-0000-00000000000b'
reset role;
select set_config('request.jwt.claims', json_build_object('sub', :'alice')::text, false);
set role authenticated;
insert into storage.objects (bucket_id, name) values ('documents', :'alice' || '/payslip-1.pdf');
insert into storage.objects (bucket_id, name) values ('avatars', :'alice' || '/avatar-2.png');
update storage.objects set metadata = '{"size": 1}' where bucket_id = 'avatars' and name = :'alice' || '/avatar.png';
do $$ begin
  if (select count(*) from storage.objects where bucket_id = 'documents') <> 2 then
    raise exception 'Alice should see exactly her two documents';
  end if;
  if not storage.can_download('documents', '00000000-0000-0000-0000-00000000000a/payslip-1.pdf') then
    raise exception 'Alice should download her own payslip';
  end if;
end $$;
delete from storage.objects where bucket_id = 'documents' and name = :'alice' || '/payslip-1.pdf';
reset role;
select set_config('request.jwt.claims', '', false);
set role anon;
do $$ begin
  if not storage.can_download('avatars', '00000000-0000-0000-0000-00000000000b/avatar.png') then
    raise exception 'avatars should stay public';
  end if;
end $$;
reset role;
do $$ begin raise notice 'normal use works'; end $$;
