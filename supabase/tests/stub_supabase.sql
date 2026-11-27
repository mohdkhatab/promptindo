-- =====================================================================
-- Local PostgreSQL 16 Test Harness Stubs for Supabase Environment
-- ONLY for local testing against promptindo_test — NEVER used in migrations.
-- =====================================================================

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin noinherit bypassrls;
  end if;
end $$;

create schema if not exists extensions;
create schema if not exists auth;
create schema if not exists storage;
create schema if not exists net;
create schema if not exists vault;
create schema if not exists cron;

grant usage on schema extensions to public, anon, authenticated, service_role;
grant usage on schema auth to anon, authenticated, service_role;
grant usage on schema storage to anon, authenticated, service_role;

-- auth stubs ------------------------------------------------------------
create table if not exists auth.users (
  id                 uuid primary key default gen_random_uuid(),
  email              text unique,
  raw_user_meta_data jsonb not null default '{}'::jsonb,
  raw_app_meta_data  jsonb not null default '{}'::jsonb,
  created_at         timestamptz not null default now()
);

create or replace function auth.jwt() returns jsonb
language sql stable
as $$
  select coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb
$$;

create or replace function auth.uid() returns uuid
language sql stable
as $$
  select nullif(auth.jwt() ->> 'sub', '')::uuid
$$;

grant execute on function auth.jwt() to anon, authenticated, service_role;
grant execute on function auth.uid() to anon, authenticated, service_role;
grant all on auth.users to service_role;

-- storage stubs ---------------------------------------------------------
create table if not exists storage.buckets (
  id                 text primary key,
  name               text not null,
  public             boolean not null default false,
  file_size_limit    bigint,
  allowed_mime_types text[]
);

create table if not exists storage.objects (
  id         uuid primary key default gen_random_uuid(),
  bucket_id  text not null references storage.buckets (id),
  name       text not null,
  owner      uuid,
  metadata   jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (bucket_id, name)
);

alter table storage.objects enable row level security;

create or replace function storage.foldername(name text) returns text[]
language sql immutable
as $$
  select case
    when strpos(name, '/') = 0 then '{}'::text[]
    else (string_to_array(name, '/'))[1 : array_length(string_to_array(name, '/'), 1) - 1]
  end
$$;

grant select on storage.buckets to anon, authenticated, service_role;
grant select, insert, update, delete on storage.objects to anon, authenticated, service_role;
grant all on storage.buckets, storage.objects to service_role;
grant execute on function storage.foldername(text) to anon, authenticated, service_role;

-- vault + pg_net stubs --------------------------------------------------
create table if not exists vault.decrypted_secrets (
  id               uuid primary key default gen_random_uuid(),
  name             text unique not null,
  decrypted_secret text not null
);

create table if not exists net._http_requests (
  id                   bigserial primary key,
  url                  text not null,
  body                 jsonb,
  headers              jsonb,
  timeout_milliseconds int,
  created_at           timestamptz not null default now()
);

create or replace function net.http_post(
  url text,
  body jsonb default '{}'::jsonb,
  params jsonb default '{}'::jsonb,
  headers jsonb default '{}'::jsonb,
  timeout_milliseconds int default 1000
) returns bigint
language plpgsql
as $$
declare v_id bigint;
begin
  if url like 'http://raise.test%' then
    raise exception 'Simulated network failure for %', url;
  end if;
  insert into net._http_requests (url, body, headers, timeout_milliseconds)
  values (url, body, headers, timeout_milliseconds)
  returning id into v_id;
  return v_id;
end $$;

-- cron stubs ------------------------------------------------------------
create table if not exists cron.job (
  jobid    bigserial primary key,
  jobname  text unique not null,
  schedule text not null,
  command  text not null
);

create or replace function cron.schedule(job_name text, schedule text, command text)
returns bigint
language plpgsql
as $$
declare v_id bigint;
begin
  insert into cron.job (jobname, schedule, command)
  values (job_name, schedule, command)
  on conflict (jobname) do update
    set schedule = excluded.schedule,
        command  = excluded.command
  returning jobid into v_id;
  return v_id;
end $$;

-- realtime publication stub ---------------------------------------------
do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
end $$;
