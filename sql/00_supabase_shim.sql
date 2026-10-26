-- The parts of Supabase the app relies on, reproduced on plain PostgreSQL so the demo runs anywhere.
-- API roles and auth.uid(): Supabase derives the user from the signed JWT of each request (here: the
-- request.jwt.claims setting).
create role anon nologin;
create role authenticated nologin;
create schema auth;
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claims', true)::json ->> 'sub', '')::uuid
$$;
grant usage on schema auth to anon, authenticated;

-- Storage keeps one row per file in storage.objects, guarded by row-level security; buckets are rows of
-- storage.buckets. The API roles may touch storage.objects, and the policies decide which rows.
create schema storage;
create table storage.buckets (
  id text primary key,
  public boolean not null default false
);
create table storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text not null references storage.buckets,
  name text not null,
  metadata jsonb,
  owner_id text default (current_setting('request.jwt.claims', true)::json ->> 'sub'),
  created_at timestamptz not null default now(),
  unique (bucket_id, name)
);
alter table storage.objects enable row level security;
grant usage on schema storage to anon, authenticated;
grant select, insert, update, delete on storage.objects to anon, authenticated;
grant select on storage.buckets to anon, authenticated;

-- storage.foldername('u1/scans/id.jpg') = {u1,scans}: the folders of an object's path.
create function storage.foldername(name text) returns text[] language sql immutable as $$
  select (string_to_array(name, '/'))[1:array_length(string_to_array(name, '/'), 1) - 1]
$$;

-- What the Storage API does for a download, reduced to the access decision. Supabase's docs: a public
-- bucket "effectively bypasses access controls for both retrieving and serving files", so anyone with the
-- URL gets the file; a private bucket serves it only if the caller's RLS policies let them select the row.
create function storage.object_exists(bucket text, path text) returns boolean language sql stable security definer
  set search_path = '' as $$
  select exists (select 1 from storage.objects where bucket_id = bucket and name = path)
$$;
-- The Storage service's own lookup, used by can_download below (not part of Supabase's SQL API).
revoke execute on function storage.object_exists(text, text) from public;
grant execute on function storage.object_exists(text, text) to anon, authenticated;
create function storage.can_download(bucket text, path text) returns boolean language plpgsql security invoker as $$
begin
  if (select public from storage.buckets where id = bucket) then
    -- Served to anyone, policies or not, if the file exists (a missing file is a 404).
    return storage.object_exists(bucket, path);
  end if;
  return exists (select 1 from storage.objects where bucket_id = bucket and name = path);
end $$;
grant execute on function storage.can_download(text, text) to anon, authenticated;
