-- =====================================================================
-- PromptIndo — Supabase schema (Postgres 15/16+). Replaces firestore.rules,
-- firestore.indexes.json, storage.rules and every Cloud Function trigger.
-- Column names are intentionally IDENTICAL to the old Firestore field names
-- so the Dart models' fromMap()/toMap() keep working.
-- =====================================================================

create extension if not exists pg_trgm with schema extensions;

do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_net') then
    create extension if not exists pg_net;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 1. Helper functions
-- ---------------------------------------------------------------------
create or replace function public.is_admin() returns boolean
language sql stable set search_path = ''
as $$ select coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') = 'admin' $$;

-- ---------------------------------------------------------------------
-- 2. Tables
-- ---------------------------------------------------------------------
create table public.profiles (
  id                   uuid primary key references auth.users (id) on delete cascade,
  name                 text not null default '' check (char_length(name) <= 60),
  username             text not null check (username ~ '^[A-Za-z0-9_]{3,24}$'),
  username_lower       text generated always as (lower(username)) stored,
  avatar_url           text not null default '',
  bio                  text not null default '' check (char_length(bio) <= 200),
  role                 text not null default 'user'   check (role in ('user', 'admin')),
  status               text not null default 'active' check (status in ('active', 'banned')),
  follower_count       int  not null default 0 check (follower_count >= 0),
  following_count      int  not null default 0 check (following_count >= 0),
  prompt_count         int  not null default 0 check (prompt_count >= 0),
  total_likes_received int  not null default 0 check (total_likes_received >= 0),
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  constraint profiles_username_lower_key unique (username_lower)   -- fixes README §13.6 race
);
create index profiles_username_prefix_idx on public.profiles (username_lower text_pattern_ops);

create or replace function public.is_active() returns boolean
language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.profiles where id = auth.uid() and status = 'active') $$;

create table public.categories (
  id           uuid primary key default gen_random_uuid(),
  name         text not null check (char_length(name) between 1 and 60),
  slug         text not null unique check (slug ~ '^[a-z0-9-]{1,60}$'),
  icon         text not null default '',
  description  text not null default '' check (char_length(description) <= 500),
  sort_order   int  not null default 0,
  prompt_count int  not null default 0 check (prompt_count >= 0),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create table public.prompts (
  id               uuid primary key default gen_random_uuid(),
  creator_id       uuid not null references public.profiles (id) on delete cascade,
  creator_username text not null default '',      -- filled by trigger, never by the client
  creator_avatar   text not null default '',      -- filled by trigger
  title            text not null check (char_length(title) between 1 and 120),
  description      text not null default '' check (char_length(description) <= 1000),
  prompt_content   text not null check (char_length(prompt_content) between 1 and 20000),
  category_id      uuid references public.categories (id) on delete set null,
  tags             text[] not null default '{}' check (cardinality(tags) <= 12),
  ai_model         text not null default '',
  visibility       text not null default 'public' check (visibility in ('public', 'unlisted', 'private')),
  status           text not null default 'active' check (status in ('active', 'hidden', 'removed')),
  thumbnail_url    text not null default '',
  thumbnail_path   text not null default '',
  like_count       int not null default 0 check (like_count >= 0),
  copy_count       int not null default 0 check (copy_count >= 0),
  view_count       int not null default 0 check (view_count >= 0),
  comment_count    int not null default 0 check (comment_count >= 0),
  bookmark_count   int not null default 0 check (bookmark_count >= 0),
  is_featured      boolean not null default false,
  trend_score      int not null default 0 check (trend_score >= 0),
  remixed_from_id  uuid references public.prompts (id) on delete set null,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
-- Partial indexes = the 19 Firestore composite indexes, but smaller and faster.
create index prompts_latest_idx   on public.prompts (created_at desc, id desc)
  where status = 'active' and visibility = 'public';
create index prompts_trending_idx on public.prompts (trend_score desc, created_at desc, id desc)
  where status = 'active' and visibility = 'public';
create index prompts_category_idx on public.prompts (category_id, created_at desc, id desc)
  where status = 'active' and visibility = 'public';
create index prompts_creator_idx  on public.prompts (creator_id, created_at desc, id desc)
  where status = 'active';
create index prompts_tags_idx     on public.prompts using gin (tags)
  where status = 'active' and visibility = 'public';
create index prompts_ai_model_idx on public.prompts (ai_model, created_at desc)
  where status = 'active' and visibility = 'public';
create index prompts_featured_idx on public.prompts (created_at desc, id desc)
  where is_featured and status = 'active' and visibility = 'public';
create index prompts_title_trgm_idx on public.prompts using gin (title extensions.gin_trgm_ops)
  where status = 'active' and visibility = 'public';
create index prompts_remix_idx    on public.prompts (remixed_from_id) where remixed_from_id is not null;

create table public.likes (
  user_id    uuid not null references public.profiles (id) on delete cascade,
  prompt_id  uuid not null references public.prompts (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, prompt_id)
);
create index likes_prompt_idx on public.likes (prompt_id);
create index likes_user_recent_idx on public.likes (user_id, created_at desc);

create table public.bookmarks (
  user_id    uuid not null references public.profiles (id) on delete cascade,
  prompt_id  uuid not null references public.prompts (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, prompt_id)
);
create index bookmarks_prompt_idx on public.bookmarks (prompt_id);
create index bookmarks_user_recent_idx on public.bookmarks (user_id, created_at desc);

create table public.follows (
  follower_id uuid not null references public.profiles (id) on delete cascade,
  followed_id uuid not null references public.profiles (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (follower_id, followed_id),
  check (follower_id <> followed_id)
);
create index follows_followed_idx on public.follows (followed_id, created_at desc);
create index follows_follower_recent_idx on public.follows (follower_id, created_at desc);

create table public.comments (
  id              uuid primary key default gen_random_uuid(),
  prompt_id       uuid not null references public.prompts (id) on delete cascade,
  parent_id       uuid,   -- deliberately NO foreign key: replies survive a deleted parent ("comment removed")
  author_id       uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  author_username text not null default '',   -- filled by trigger
  author_avatar   text not null default '',   -- filled by trigger
  content         text not null check (char_length(content) between 1 and 2000),
  like_count      int  not null default 0 check (like_count >= 0),
  status          text not null default 'active' check (status in ('active', 'removed')),
  created_at      timestamptz not null default now()
);
create index comments_prompt_idx on public.comments (prompt_id, created_at) where status = 'active';
create index comments_author_idx on public.comments (author_id);
create index comments_parent_idx on public.comments (parent_id) where parent_id is not null;

create table public.comment_likes (
  user_id    uuid not null references public.profiles (id) on delete cascade,
  comment_id uuid not null references public.comments (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, comment_id)
);
create index comment_likes_comment_idx on public.comment_likes (comment_id);

create table public.notifications (
  id             uuid primary key default gen_random_uuid(),
  recipient_id   uuid not null references public.profiles (id) on delete cascade,
  actor_id       uuid references public.profiles (id) on delete cascade,
  actor_username text not null default '',
  actor_name     text not null default '',
  actor_avatar   text not null default '',
  type           text not null check (type in
                   ('like','comment','reply','comment_like','follow','remix','report_resolved','system')),
  prompt_id      uuid references public.prompts (id) on delete cascade,
  comment_id     uuid references public.comments (id) on delete cascade,
  is_read        boolean not null default false,
  data           jsonb not null default '{}',
  created_at     timestamptz not null default now()
);
create index notifications_recipient_idx on public.notifications (recipient_id, created_at desc);
create index notifications_unread_idx    on public.notifications (recipient_id) where not is_read;
create index notifications_actor_idx     on public.notifications (actor_id);
create index notifications_prompt_idx    on public.notifications (prompt_id);

create table public.fcm_tokens (
  token      text primary key check (char_length(token) between 1 and 4096),
  user_id    uuid not null references public.profiles (id) on delete cascade,
  platform   text not null default 'android' check (char_length(platform) between 1 and 32),
  updated_at timestamptz not null default now()
);
create index fcm_tokens_user_idx on public.fcm_tokens (user_id);

create table public.reports (
  id              uuid primary key default gen_random_uuid(),
  reporter_id     uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  target_type     text not null check (target_type in ('prompt', 'comment', 'user')),
  target_id       uuid not null,
  reason          text not null check (char_length(reason) between 1 and 200),
  details         text not null default '' check (char_length(details) <= 1000),
  status          text not null default 'pending' check (status in ('pending', 'resolved', 'rejected')),
  resolution_note text not null default '',
  resolved_by     uuid references public.profiles (id) on delete set null,
  resolved_at     timestamptz,
  created_at      timestamptz not null default now()
);
create index reports_status_idx   on public.reports (status, created_at desc);
create index reports_target_idx   on public.reports (target_id, created_at desc);
create index reports_reporter_idx on public.reports (reporter_id, target_id, created_at desc);

create table public.admin_actions (
  id          uuid primary key default gen_random_uuid(),
  admin_id    uuid references public.profiles (id) on delete set null,
  action_type text not null,
  target_type text not null,
  target_id   text not null,
  notes       text not null default '' check (char_length(notes) <= 1000),
  created_at  timestamptz not null default now()
);
create index admin_actions_recent_idx on public.admin_actions (created_at desc);

-- 24h view-dedupe table. No client access at all (RLS on, zero policies).
create table public.prompt_views (
  viewer_key text not null,
  prompt_id  uuid not null references public.prompts (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (viewer_key, prompt_id)
);
create index prompt_views_created_idx on public.prompt_views (created_at);

-- ---------------------------------------------------------------------
-- 3. Internal helpers (service_role / trigger use only; never callable from anon/authenticated)
-- ---------------------------------------------------------------------
create or replace function public.create_notification(
  p_recipient uuid, p_actor uuid, p_type text,
  p_prompt uuid default null, p_comment uuid default null, p_data jsonb default '{}'::jsonb)
returns void language plpgsql security definer set search_path = ''
as $$
declare a record;
begin
  if p_recipient is null or p_recipient = p_actor then return; end if;           -- no self-notifications
  if not exists (select 1 from public.profiles where id = p_recipient) then return; end if;
  select username, name, avatar_url into a from public.profiles where id = p_actor;
  insert into public.notifications
    (recipient_id, actor_id, actor_username, actor_name, actor_avatar, type, prompt_id, comment_id, data)
  values
    (p_recipient, p_actor, coalesce(a.username, ''), coalesce(a.name, ''), coalesce(a.avatar_url, ''),
     p_type, p_prompt, p_comment, coalesce(p_data, '{}'::jsonb));
end $$;

-- Calls the Next.js backend through pg_net. URL + secret live in Supabase Vault.
-- Failure must NEVER roll back the user's action (push is best-effort, the inbox row is the truth).
create or replace function public.call_webhook(p_path text, p_payload jsonb)
returns void language plpgsql security definer set search_path = ''
as $$
declare v_base text; v_secret text;
begin
  select decrypted_secret into v_base   from vault.decrypted_secrets where name = 'api_base_url';
  select decrypted_secret into v_secret from vault.decrypted_secrets where name = 'webhook_secret';
  if v_base is null or v_secret is null then return; end if;
  perform net.http_post(
    url := v_base || p_path,
    body := p_payload,
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-webhook-secret', v_secret),
    timeout_milliseconds := 3000);
exception when others then
  raise warning 'call_webhook(%) failed: %', p_path, sqlerrm;
end $$;

-- ---------------------------------------------------------------------
-- 4. Auth → profile provisioning (replaces onUserCreate; atomic, no retry loop in Flutter)
-- ---------------------------------------------------------------------
create or replace function public.username_base(p_name text, p_email text) returns text
language plpgsql immutable set search_path = ''
as $$
declare v_from_name text; v_from_email text; v_base text;
begin
  v_from_name  := regexp_replace(lower(coalesce(p_name, '')), '[^a-z0-9_]', '', 'g');
  v_from_email := regexp_replace(lower(split_part(coalesce(p_email, ''), '@', 1)), '[^a-z0-9_]', '', 'g');
  v_base := case when char_length(v_from_name) >= 3 then v_from_name else v_from_email end;
  v_base := left(v_base, 20);
  if char_length(v_base) < 3 then v_base := left('user_' || v_base, 20); end if;
  if char_length(v_base) < 3 then v_base := 'user'; end if;
  return v_base;
end $$;

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  v_meta     jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_name     text  := coalesce(nullif(btrim(v_meta ->> 'name'), ''), nullif(btrim(v_meta ->> 'full_name'), ''), '');
  v_avatar   text  := coalesce(v_meta ->> 'avatar_url', v_meta ->> 'picture', '');
  v_base     text  := public.username_base(v_name, new.email);
  v_username text;
  v_try      int   := 0;
begin
  loop
    v_username := left(case when v_try = 0 then v_base
                            else left(v_base, 20) || (100 + floor(random() * 900))::int::text end, 24);
    begin
      insert into public.profiles (id, name, username, avatar_url)
      values (new.id, left(coalesce(nullif(v_name, ''), v_username), 60), v_username, v_avatar)
      on conflict (id) do nothing;
      exit;
    exception when unique_violation then          -- username taken: try another suffix
      v_try := v_try + 1;
      if v_try > 8 then
        insert into public.profiles (id, name, username, avatar_url)
        values (new.id, left(coalesce(nullif(v_name, ''), 'user'), 60),
                'user_' || substr(md5(new.id::text), 1, 12), v_avatar)
        on conflict (id) do nothing;
        exit;
      end if;
    end;
  end loop;
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------
-- 5. Row-level triggers: denormalised fields, counters, notifications
-- ---------------------------------------------------------------------
create or replace function public.profiles_before_update() returns trigger
language plpgsql set search_path = ''
as $$ begin new.updated_at := now(); return new; end $$;
create trigger profiles_before_update before update on public.profiles
  for each row execute function public.profiles_before_update();

-- keep denormalised author fields fresh when a profile changes (Firestore version never did)
create or replace function public.profiles_after_update() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if new.username is distinct from old.username or new.avatar_url is distinct from old.avatar_url then
    update public.prompts  set creator_username = new.username, creator_avatar = new.avatar_url where creator_id = new.id;
    update public.comments set author_username  = new.username, author_avatar  = new.avatar_url where author_id  = new.id;
  end if;
  return null;
end $$;
create trigger profiles_after_update after update of username, avatar_url on public.profiles
  for each row execute function public.profiles_after_update();

-- prompts ----------------------------------------------------------------
create or replace function public.prompts_before_insert() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare p record;
begin
  select username, avatar_url into p from public.profiles where id = new.creator_id;
  new.creator_username := coalesce(p.username, '');
  new.creator_avatar   := coalesce(p.avatar_url, '');
  new.tags := array(select lower(btrim(t)) from unnest(new.tags) with ordinality as u(t, i)
                    where btrim(t) <> '' order by i);
  return new;
end $$;
create trigger prompts_before_insert before insert on public.prompts
  for each row execute function public.prompts_before_insert();

create or replace function public.prompts_before_update() returns trigger
language plpgsql set search_path = ''
as $$
begin
  if new.tags is distinct from old.tags then
    new.tags := array(select lower(btrim(t)) from unnest(new.tags) with ordinality as u(t, i)
                      where btrim(t) <> '' order by i);
  end if;
  -- updated_at means "edited by the author", not "a like arrived"
  if row(new.title, new.description, new.prompt_content, new.category_id, new.tags, new.ai_model,
         new.visibility, new.thumbnail_url)
     is distinct from
     row(old.title, old.description, old.prompt_content, old.category_id, old.tags, old.ai_model,
         old.visibility, old.thumbnail_url) then
    new.updated_at := now();
  end if;
  return new;
end $$;
create trigger prompts_before_update before update on public.prompts
  for each row execute function public.prompts_before_update();

create or replace function public.prompts_after_insert() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare v_src_owner uuid;
begin
  update public.profiles set prompt_count = prompt_count + 1 where id = new.creator_id;
  if new.category_id is not null then
    update public.categories set prompt_count = prompt_count + 1 where id = new.category_id;
  end if;
  if new.remixed_from_id is not null then
    select creator_id into v_src_owner from public.prompts where id = new.remixed_from_id;
    perform public.create_notification(v_src_owner, new.creator_id, 'remix', new.remixed_from_id, null,
      jsonb_build_object('remix_prompt_id', new.id, 'title', left(new.title, 80)));
  end if;
  return null;
end $$;
create trigger prompts_after_insert after insert on public.prompts
  for each row execute function public.prompts_after_insert();

create or replace function public.prompts_after_update_category() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if old.category_id is not null then
    update public.categories set prompt_count = greatest(0, prompt_count - 1) where id = old.category_id;
  end if;
  if new.category_id is not null then
    update public.categories set prompt_count = prompt_count + 1 where id = new.category_id;
  end if;
  return null;
end $$;
create trigger prompts_after_update_category after update of category_id on public.prompts
  for each row when (old.category_id is distinct from new.category_id)
  execute function public.prompts_after_update_category();

create or replace function public.prompts_after_delete() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  update public.profiles
     set prompt_count = greatest(0, prompt_count - 1),
         total_likes_received = greatest(0, total_likes_received - old.like_count)
   where id = old.creator_id;
  if old.category_id is not null then
    update public.categories set prompt_count = greatest(0, prompt_count - 1) where id = old.category_id;
  end if;
  if old.thumbnail_path <> '' then       -- storage objects can only be removed through the Storage API
    perform public.call_webhook('/api/webhooks/prompt-deleted',
      jsonb_build_object('id', old.id, 'creator_id', old.creator_id, 'thumbnail_path', old.thumbnail_path));
  end if;
  return null;
end $$;
create trigger prompts_after_delete after delete on public.prompts
  for each row execute function public.prompts_after_delete();

-- likes (trend_score is maintained incrementally; cron only handles the recency decay) -----
create or replace function public.likes_after_insert() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare v_owner uuid; v_title text;
begin
  update public.prompts set like_count = like_count + 1, trend_score = trend_score + 3
   where id = new.prompt_id returning creator_id, title into v_owner, v_title;
  if v_owner is null then return null; end if;
  update public.profiles set total_likes_received = total_likes_received + 1 where id = v_owner;
  perform public.create_notification(v_owner, new.user_id, 'like', new.prompt_id, null,
                                     jsonb_build_object('title', v_title));
  return null;
end $$;
create trigger likes_after_insert after insert on public.likes
  for each row execute function public.likes_after_insert();

create or replace function public.likes_after_delete() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare v_owner uuid;
begin
  update public.prompts
     set like_count = greatest(0, like_count - 1), trend_score = greatest(0, trend_score - 3)
   where id = old.prompt_id returning creator_id into v_owner;
  if v_owner is not null then
    update public.profiles set total_likes_received = greatest(0, total_likes_received - 1) where id = v_owner;
  end if;
  return null;
end $$;
create trigger likes_after_delete after delete on public.likes
  for each row execute function public.likes_after_delete();

-- bookmarks --------------------------------------------------------------
create or replace function public.bookmarks_after_change() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    update public.prompts set bookmark_count = bookmark_count + 1 where id = new.prompt_id;
  else
    update public.prompts set bookmark_count = greatest(0, bookmark_count - 1) where id = old.prompt_id;
  end if;
  return null;
end $$;
create trigger bookmarks_after_change after insert or delete on public.bookmarks
  for each row execute function public.bookmarks_after_change();

-- follows ----------------------------------------------------------------
create or replace function public.follows_after_change() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    update public.profiles set follower_count  = follower_count  + 1 where id = new.followed_id;
    update public.profiles set following_count = following_count + 1 where id = new.follower_id;
    perform public.create_notification(new.followed_id, new.follower_id, 'follow');
  else
    update public.profiles set follower_count  = greatest(0, follower_count  - 1) where id = old.followed_id;
    update public.profiles set following_count = greatest(0, following_count - 1) where id = old.follower_id;
  end if;
  return null;
end $$;
create trigger follows_after_change after insert or delete on public.follows
  for each row execute function public.follows_after_change();

-- comments ---------------------------------------------------------------
create or replace function public.comments_before_insert() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare p record;
begin
  select username, avatar_url into p from public.profiles where id = new.author_id;
  new.author_username := coalesce(p.username, '');
  new.author_avatar   := coalesce(p.avatar_url, '');
  if new.parent_id is not null and
     not exists (select 1 from public.comments c where c.id = new.parent_id and c.prompt_id = new.prompt_id) then
    raise exception 'parent comment does not belong to this prompt' using errcode = '23514';
  end if;
  return new;
end $$;
create trigger comments_before_insert before insert on public.comments
  for each row execute function public.comments_before_insert();

create or replace function public.comments_after_insert() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare v_owner uuid; v_parent_author uuid;
begin
  if new.status = 'active' then
    update public.prompts set comment_count = comment_count + 1 where id = new.prompt_id returning creator_id into v_owner;
    if new.parent_id is not null then
      select author_id into v_parent_author from public.comments where id = new.parent_id;
      perform public.create_notification(v_parent_author, new.author_id, 'reply', new.prompt_id, new.parent_id,
                                         jsonb_build_object('excerpt', left(new.content, 80)));
    else
      perform public.create_notification(v_owner, new.author_id, 'comment', new.prompt_id, new.id,
                                         jsonb_build_object('excerpt', left(new.content, 80)));
    end if;
  end if;
  return null;
end $$;
create trigger comments_after_insert after insert on public.comments
  for each row execute function public.comments_after_insert();

create or replace function public.comments_after_delete() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if old.status = 'active' then
    update public.prompts set comment_count = greatest(0, comment_count - 1) where id = old.prompt_id;
  end if;
  return null;
end $$;
create trigger comments_after_delete after delete on public.comments
  for each row execute function public.comments_after_delete();

-- admin soft-delete (status -> removed) also unwinds the counter
create or replace function public.comments_after_update_status() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if old.status = 'active' and new.status = 'removed' then
    update public.prompts set comment_count = greatest(0, comment_count - 1) where id = new.prompt_id;
  end if;
  return null;
end $$;
create trigger comments_after_update_status after update of status on public.comments
  for each row execute function public.comments_after_update_status();

-- comment likes ----------------------------------------------------------
create or replace function public.comment_likes_after_change() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare v_author uuid; v_prompt uuid;
begin
  if tg_op = 'INSERT' then
    update public.comments set like_count = like_count + 1 where id = new.comment_id
      returning author_id, prompt_id into v_author, v_prompt;
    perform public.create_notification(v_author, new.user_id, 'comment_like', v_prompt, new.comment_id);
  else
    update public.comments set like_count = greatest(0, like_count - 1) where id = old.comment_id;
  end if;
  return null;
end $$;
create trigger comment_likes_after_change after insert or delete on public.comment_likes
  for each row execute function public.comment_likes_after_change();

-- notifications → FCM push (via Next.js) ---------------------------------
create or replace function public.notifications_after_insert() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  perform public.call_webhook('/api/webhooks/push', to_jsonb(new));
  return null;
end $$;
create trigger notifications_after_insert after insert on public.notifications
  for each row execute function public.notifications_after_insert();

-- reports: same silent rules as onReportCreate (target must exist; 1 report / reporter / target / hour)
create or replace function public.reports_before_insert() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare v_exists boolean;
begin
  v_exists := case new.target_type
    when 'prompt'  then exists (select 1 from public.prompts  where id = new.target_id)
    when 'comment' then exists (select 1 from public.comments where id = new.target_id)
    when 'user'    then exists (select 1 from public.profiles where id = new.target_id)
    else false end;
  if not v_exists then return null; end if;
  if exists (select 1 from public.reports r
              where r.reporter_id = new.reporter_id and r.target_id = new.target_id
                and r.created_at > now() - interval '1 hour') then
    return null;
  end if;
  return new;
end $$;
create trigger reports_before_insert before insert on public.reports
  for each row execute function public.reports_before_insert();

-- ---------------------------------------------------------------------
-- 6. RPCs the Flutter app calls directly (no extra HTTP hop)
-- ---------------------------------------------------------------------
create or replace function public.copy_prompt(p_prompt_id uuid) returns void
language plpgsql security definer set search_path = ''
as $$
begin
  update public.prompts set copy_count = copy_count + 1, trend_score = trend_score + 5
   where id = p_prompt_id and status = 'active' and visibility = 'public';
  if not found then raise exception 'Prompt not available' using errcode = 'P0002'; end if;
end $$;

create or replace function public.record_view(p_prompt_id uuid, p_anon_id text default null) returns boolean
language plpgsql security definer set search_path = ''
as $$
declare v_key text; v_counted boolean;
begin
  if auth.uid() is not null then v_key := auth.uid()::text;
  elsif p_anon_id ~ '^[A-Za-z0-9-]{8,64}$' then v_key := 'anon:' || p_anon_id;
  else raise exception 'A valid anonId is required' using errcode = '22023';
  end if;

  if not exists (
    select 1 from public.prompts
     where id = p_prompt_id and status = 'active' and (visibility = 'public' or creator_id = auth.uid())
  ) then
    return false;
  end if;

  insert into public.prompt_views as v (viewer_key, prompt_id) values (v_key, p_prompt_id)
  on conflict (viewer_key, prompt_id) do update set created_at = now()
    where v.created_at < now() - interval '24 hours'
  returning true into v_counted;                       -- row only comes back when inserted/refreshed

  if v_counted then
    update public.prompts set view_count = view_count + 1, trend_score = trend_score + 1 where id = p_prompt_id;
  end if;
  return coalesce(v_counted, false);
end $$;

create or replace function public.register_fcm_token(p_token text, p_platform text default 'android') returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'not signed in' using errcode = '28000'; end if;
  if btrim(coalesce(p_token, '')) = '' then raise exception 'token required' using errcode = '22023'; end if;
  insert into public.fcm_tokens (token, user_id, platform) values (p_token, auth.uid(), coalesce(nullif(btrim(p_platform), ''), 'android'))
  on conflict (token) do update set user_id = excluded.user_id, platform = excluded.platform, updated_at = now();
end $$;

create or replace function public.unregister_fcm_token(p_token text) returns void
language sql security definer set search_path = ''
as $$ delete from public.fcm_tokens where token = p_token and user_id = auth.uid() $$;

-- title-prefix / substring / tag search (replaces the client-side Firestore merge)
-- SECURITY DEFINER (with strict status = 'active' and visibility = 'public') avoids the
-- PostgreSQL RLS security barrier on non-leakproof ILIKE / @> operators so GIN indexes are used.
-- Written as pure SQL (no CTE) so scalar patterns are evaluated once and GIN indexes are always used.
create or replace function public.search_prompts(q text, lim int default 20)
returns setof public.prompts language sql stable security definer set search_path = ''
as $$
  select p.*
    from public.prompts p
   where btrim(coalesce(q, '')) <> ''
     and p.status = 'active'
     and p.visibility = 'public'
     and (
       p.title ilike '%' || replace(replace(replace(btrim(coalesce(q, '')), '\', '\\'), '%', '\%'), '_', '\_') || '%'
       or p.tags @> array[lower(btrim(coalesce(q, '')))]
     )
   order by (p.title ilike replace(replace(replace(btrim(coalesce(q, '')), '\', '\\'), '%', '\%'), '_', '\_') || '%') desc,
            p.created_at desc
   limit least(greatest(coalesce(lim, 20), 1), 50)
$$;

-- Fast tag feed RPC (avoids RLS security barrier blocking non-leakproof @> on prompts_tags_idx)
create or replace function public.prompts_by_tag(
  p_tag text,
  p_lim int default 12,
  p_cursor_created timestamptz default null,
  p_cursor_id uuid default null
)
returns setof public.prompts language sql stable security definer set search_path = ''
as $$
  select p.*
    from public.prompts p
   where btrim(coalesce(p_tag, '')) <> ''
     and p.status = 'active'
     and p.visibility = 'public'
     and p.tags @> array[lower(btrim(coalesce(p_tag, '')))]
     and (
       p_cursor_created is null
       or (p.created_at, p.id) < (p_cursor_created, coalesce(p_cursor_id, 'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid))
     )
   order by p.created_at desc, p.id desc
   limit least(greatest(coalesce(p_lim, 12), 1), 50)
$$;

-- trend_score = likes*3 + copies*5 + views*1 + recency bonus (40 → 0 over 48h).
-- Counters keep the first three terms fresh instantly; this only refreshes prompts still inside the decay window.
create or replace function public.recompute_trending() returns int
language plpgsql security definer set search_path = ''
as $$
declare n int;
begin
  update public.prompts p
     set trend_score = s.score
    from (select id,
                 (like_count * 3 + copy_count * 5 + view_count
                  + round(40 * greatest(0::numeric, 1 - least(1::numeric,
                        extract(epoch from (now() - created_at))::numeric / 3600 / 48))))::int as score
            from public.prompts
           where status = 'active' and created_at > now() - interval '49 hours') s
   where p.id = s.id and p.trend_score is distinct from s.score;
  get diagnostics n = row_count;
  return n;
end $$;

-- ---------------------------------------------------------------------
-- 7. Row Level Security (replaces firestore.rules). auth.uid() wrapped in (select …) so it is evaluated once.
-- ---------------------------------------------------------------------
alter table public.profiles      enable row level security;
alter table public.categories    enable row level security;
alter table public.prompts       enable row level security;
alter table public.likes         enable row level security;
alter table public.bookmarks     enable row level security;
alter table public.follows       enable row level security;
alter table public.comments      enable row level security;
alter table public.comment_likes enable row level security;
alter table public.notifications enable row level security;
alter table public.fcm_tokens    enable row level security;
alter table public.reports       enable row level security;
alter table public.admin_actions enable row level security;
alter table public.prompt_views  enable row level security;

create policy profiles_read   on public.profiles for select using (true);
create policy profiles_update on public.profiles for update to authenticated
  using (id = (select auth.uid()) and (select public.is_active()))
  with check (id = (select auth.uid()));

create policy categories_read on public.categories for select using (true);

create policy prompts_read on public.prompts for select using (
  (select public.is_admin())
  or (visibility = 'public' and status = 'active')
  or (creator_id = (select auth.uid()) and status = 'active'));
create policy prompts_insert on public.prompts for insert to authenticated
  with check (creator_id = (select auth.uid()) and (select public.is_active()));
create policy prompts_update on public.prompts for update to authenticated
  using (creator_id = (select auth.uid()) and status = 'active' and (select public.is_active()))
  with check (creator_id = (select auth.uid()));
create policy prompts_delete on public.prompts for delete to authenticated
  using (creator_id = (select auth.uid()));

-- likes / bookmarks / comment_likes: own rows only; the target must be visible to the caller (RLS applies to the sub-select)
create policy likes_read   on public.likes for select to authenticated using (user_id = (select auth.uid()));
create policy likes_insert on public.likes for insert to authenticated
  with check (user_id = (select auth.uid()) and exists (select 1 from public.prompts p where p.id = prompt_id));
create policy likes_delete on public.likes for delete to authenticated using (user_id = (select auth.uid()));

create policy bookmarks_read   on public.bookmarks for select to authenticated using (user_id = (select auth.uid()));
create policy bookmarks_insert on public.bookmarks for insert to authenticated
  with check (user_id = (select auth.uid()) and exists (select 1 from public.prompts p where p.id = prompt_id));
create policy bookmarks_delete on public.bookmarks for delete to authenticated using (user_id = (select auth.uid()));

create policy follows_read on public.follows for select to authenticated
  using (follower_id = (select auth.uid()) or followed_id = (select auth.uid()));
create policy follows_insert on public.follows for insert to authenticated
  with check (follower_id = (select auth.uid()) and follower_id <> followed_id);
create policy follows_delete on public.follows for delete to authenticated using (follower_id = (select auth.uid()));

create policy comments_read   on public.comments for select using (status = 'active' or (select public.is_admin()));
create policy comments_insert on public.comments for insert to authenticated
  with check (author_id = (select auth.uid()) and status = 'active' and (select public.is_active())
              and exists (select 1 from public.prompts p where p.id = prompt_id));
create policy comments_update on public.comments for update to authenticated
  using (author_id = (select auth.uid()) and status = 'active' and (select public.is_active()))
  with check (author_id = (select auth.uid()));
create policy comments_delete on public.comments for delete to authenticated using (
  author_id = (select auth.uid())
  or exists (select 1 from public.prompts p where p.id = prompt_id and p.creator_id = (select auth.uid())));

create policy comment_likes_read   on public.comment_likes for select to authenticated using (user_id = (select auth.uid()));
create policy comment_likes_insert on public.comment_likes for insert to authenticated
  with check (user_id = (select auth.uid()) and exists (select 1 from public.comments c where c.id = comment_id));
create policy comment_likes_delete on public.comment_likes for delete to authenticated using (user_id = (select auth.uid()));

create policy notifications_read   on public.notifications for select to authenticated using (recipient_id = (select auth.uid()));
create policy notifications_update on public.notifications for update to authenticated
  using (recipient_id = (select auth.uid())) with check (recipient_id = (select auth.uid()));
create policy notifications_delete on public.notifications for delete to authenticated using (recipient_id = (select auth.uid()));

create policy fcm_tokens_read   on public.fcm_tokens for select to authenticated using (user_id = (select auth.uid()));
create policy fcm_tokens_delete on public.fcm_tokens for delete to authenticated using (user_id = (select auth.uid()));

create policy reports_insert on public.reports for insert to authenticated
  with check (reporter_id = (select auth.uid()) and status = 'pending' and (select public.is_active()));
create policy reports_read on public.reports for select to authenticated
  using (reporter_id = (select auth.uid()) or (select public.is_admin()));

create policy admin_actions_read on public.admin_actions for select to authenticated using ((select public.is_admin()));
-- prompt_views: RLS on, no policy → unreachable except through the SECURITY DEFINER functions above.

-- ---------------------------------------------------------------------
-- 8. Privileges. Column-level grants replace rules like "counters / status / role are never client-writable".
-- ---------------------------------------------------------------------
revoke all on all tables    in schema public from anon, authenticated;
revoke all on all functions in schema public from public, anon, authenticated;
grant usage on schema public to anon, authenticated, service_role;
grant all on all tables    in schema public to service_role;
grant all on all functions in schema public to service_role;

grant select on public.profiles, public.categories, public.prompts, public.comments to anon, authenticated;
grant select on public.likes, public.bookmarks, public.follows, public.comment_likes,
                public.notifications, public.fcm_tokens, public.reports, public.admin_actions to authenticated;

grant update (name, username, bio, avatar_url) on public.profiles to authenticated;

grant insert (creator_id, title, description, prompt_content, category_id, tags, ai_model, visibility,
              thumbnail_url, thumbnail_path, remixed_from_id) on public.prompts to authenticated;
grant update (title, description, prompt_content, category_id, tags, ai_model, visibility,
              thumbnail_url, thumbnail_path) on public.prompts to authenticated;
grant delete on public.prompts to authenticated;

grant insert (user_id, prompt_id) on public.likes, public.bookmarks to authenticated;
grant delete on public.likes, public.bookmarks to authenticated;
grant insert (follower_id, followed_id) on public.follows to authenticated;
grant delete on public.follows to authenticated;
grant insert (user_id, comment_id) on public.comment_likes to authenticated;
grant delete on public.comment_likes to authenticated;

grant insert (prompt_id, parent_id, author_id, content) on public.comments to authenticated;
grant update (content) on public.comments to authenticated;
grant delete on public.comments to authenticated;

grant update (is_read) on public.notifications to authenticated;
grant delete on public.notifications to authenticated;
grant delete on public.fcm_tokens to authenticated;
grant insert (reporter_id, target_type, target_id, reason, details) on public.reports to authenticated;

grant execute on function public.is_admin()                              to anon, authenticated;
grant execute on function public.is_active()                             to authenticated;
grant execute on function public.copy_prompt(uuid)                       to anon, authenticated;
grant execute on function public.record_view(uuid, text)                 to anon, authenticated;
grant execute on function public.search_prompts(text, int)               to anon, authenticated;
grant execute on function public.prompts_by_tag(text, int, timestamptz, uuid) to anon, authenticated;
grant execute on function public.register_fcm_token(text, text)          to authenticated;
grant execute on function public.unregister_fcm_token(text)              to authenticated;

-- ---------------------------------------------------------------------
-- 9. Realtime (replaces Firestore snapshots()). RLS still applies to every change event.
-- ---------------------------------------------------------------------
alter publication supabase_realtime add table public.notifications, public.comments, public.prompts, public.profiles;

-- ---------------------------------------------------------------------
-- 10. Storage buckets + policies (replaces storage.rules). Path = {uid}/{file}.
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('avatars',    'avatars',    true, 5242880, array['image/jpeg', 'image/png', 'image/webp']),
  ('thumbnails', 'thumbnails', true, 8388608, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy "avatars: public read" on storage.objects for select
  using (bucket_id = 'avatars');
create policy "avatars: owner insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text
              and name !~ '(^|/)\.\.(/|$)' and name ~* '\.(jpe?g|png|webp)$');
create policy "avatars: owner update" on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text
              and name !~ '(^|/)\.\.(/|$)' and name ~* '\.(jpe?g|png|webp)$');
create policy "avatars: owner delete" on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "thumbnails: public read" on storage.objects for select
  using (bucket_id = 'thumbnails');
create policy "thumbnails: owner insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'thumbnails' and (storage.foldername(name))[1] = (select auth.uid())::text
              and name !~ '(^|/)\.\.(/|$)' and name ~* '\.(jpe?g|png|webp)$');
create policy "thumbnails: owner update" on storage.objects for update to authenticated
  using (bucket_id = 'thumbnails' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'thumbnails' and (storage.foldername(name))[1] = (select auth.uid())::text
              and name !~ '(^|/)\.\.(/|$)' and name ~* '\.(jpe?g|png|webp)$');
create policy "thumbnails: owner delete" on storage.objects for delete to authenticated
  using (bucket_id = 'thumbnails' and (storage.foldername(name))[1] = (select auth.uid())::text);
