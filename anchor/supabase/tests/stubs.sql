-- Stand-ins for what Supabase provides, so the migration and RLS tests can run on plain Postgres (PGlite).
-- NOT part of the migration; never run this on a real Supabase project.
create schema auth;
create table auth.users (id uuid primary key);

-- Same resolution order Supabase uses for auth.uid().
create function auth.uid() returns uuid language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$$;

create role anon nologin;
create role authenticated nologin;
grant usage on schema public, auth to anon, authenticated;
grant execute on function auth.uid() to anon, authenticated;

-- Supabase grants everything on new public objects to anon/authenticated by default. The migration then
-- revokes and re-grants the minimum, so mimic the default to prove that path.
alter default privileges in schema public grant all on tables to anon, authenticated;
alter default privileges in schema public grant all on functions to anon, authenticated;

create publication supabase_realtime;
