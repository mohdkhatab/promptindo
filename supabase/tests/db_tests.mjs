#!/usr/bin/env node
/**
 * PromptIndo — Comprehensive Supabase PostgreSQL Security, Rules & Trigger Tests
 *
 * Ports all ~30 cases from firestore-tests/test/firestore.rules.test.js plus
 * every requirement from §5.5, §6.2 (#11), and §11 of the migration spec.
 *
 * Runs against a fresh local `promptindo_test` database using `psql` with
 * `SET LOCAL ROLE anon|authenticated|service_role` + `request.jwt.claims`.
 *
 * Usage:
 *   node --test supabase/tests/db_tests.mjs
 */

import { test, before, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

const DB = process.env.PG_TEST_DB || 'promptindo_test';
const ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');

const ALICE_ID = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const BOB_ID   = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const CAROL_ID = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const ADMIN_ID = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
const CAT_WRITING = '11111111-1111-4111-8111-111111111101';
const CAT_CODING  = '11111111-1111-4111-8111-111111111102';

function runPsqlRaw(sql) {
  const prefix = `\\set VERBOSITY verbose\n\\set ON_ERROR_STOP on\n`;
  try {
    return execFileSync(
      'sudo',
      ['-u', 'postgres', 'psql', '-d', DB, '-q', '-P', 'pager=off', '-At'],
      { input: prefix + sql, encoding: 'utf8', maxBuffer: 10 * 1024 * 1024 },
    );
  } catch (err) {
    const stderr = (err.stderr || err.stdout || err.message || '').toString();
    const m = stderr.match(/ERROR:\s+([0-9A-Z]{5}):\s+([^\n]+)/);
    const e = new Error(m ? `${m[1]}: ${m[2]}` : stderr);
    e.code = m ? m[1] : 'UNKNOWN';
    e.raw = stderr;
    throw e;
  }
}

function execAs(role, claims, sql) {
  const jwt = JSON.stringify(claims ?? {}).replace(/'/g, "''");
  const wrapped = `
begin;
set local request.jwt.claims = '${jwt}';
set local role ${role};
${sql}
commit;
`;
  return runPsqlRaw(wrapped).trim();
}

function queryJsonAs(role, claims, selectSql) {
  const jwt = JSON.stringify(claims ?? {}).replace(/'/g, "''");
  const wrapped = `
begin;
set local request.jwt.claims = '${jwt}';
set local role ${role};
with _q as (${selectSql}) select coalesce(json_agg(_q), '[]'::json) from _q;
commit;
`;
  const out = runPsqlRaw(wrapped).trim();
  return JSON.parse(out);
}

function queryScalarAs(role, claims, exprSql) {
  const rows = queryJsonAs(role, claims, `select (${exprSql}) as val`);
  return rows[0]?.val ?? null;
}

function insertPromptAs(uid, { title = 'P', body = 'body', categoryId = null, visibility = 'public', tags = null, thumbnailPath = '' } = {}) {
  const catSql = categoryId ? `'${categoryId}'::uuid` : 'null';
  const tagsSql = tags ? `array[${tags.map((t) => `'${t.replace(/'/g, "''")}'`).join(',')}]::text[]` : `'{}'::text[]`;
  const row = queryJsonAs('authenticated', userClaims(uid), `
    insert into public.prompts (creator_id, title, prompt_content, category_id, visibility, tags, thumbnail_path)
    values ('${uid}', '${title.replace(/'/g, "''")}', '${body.replace(/'/g, "''")}', ${catSql}, '${visibility}', ${tagsSql}, '${thumbnailPath}')
    returning id
  `);
  return row[0].id;
}

function insertCommentAs(uid, promptId, content, parentId = null) {
  const parentSql = parentId ? `'${parentId}'::uuid` : 'null';
  const row = queryJsonAs('authenticated', userClaims(uid), `
    insert into public.comments (prompt_id, parent_id, author_id, content)
    values ('${promptId}', ${parentSql}, '${uid}', '${content.replace(/'/g, "''")}')
    returning id
  `);
  return row[0].id;
}

const anonClaims = {};
const userClaims = (id, extra = {}) => ({ sub: id, role: 'authenticated', ...extra });
const adminClaims = (id = ADMIN_ID) => ({
  sub: id,
  role: 'authenticated',
  app_metadata: { role: 'admin' },
});

function seedUsers() {
  runPsqlRaw(`
    insert into auth.users (id, email, raw_user_meta_data) values
      ('${ALICE_ID}', 'alice@example.com', '{"name":"Alice"}'),
      ('${BOB_ID}',   'bob@example.com',   '{"name":"Bob"}'),
      ('${CAROL_ID}', 'carol@example.com', '{"name":"Carol"}'),
      ('${ADMIN_ID}', 'root@example.com',  '{"name":"RootAdmin"}');
    update public.profiles set role = 'admin' where id = '${ADMIN_ID}';
  `);
}

function cleanData() {
  runPsqlRaw(`
    begin;
    set local client_min_messages = warning;
    truncate auth.users, public.categories, public.admin_actions, vault.decrypted_secrets, net._http_requests restart identity cascade;
    insert into public.categories (id, name, slug, icon, description, sort_order) values
      ('${CAT_WRITING}', 'Writing', 'writing', '✍️', 'Writing prompts', 1),
      ('${CAT_CODING}',  'Coding',  'coding',  '💻', 'Coding prompts', 2);
    commit;
  `);
}

before(() => {
  execFileSync('sudo', [
    '-u', 'postgres', 'psql', '-P', 'pager=off', '-v', 'ON_ERROR_STOP=1',
    '-c', `drop database if exists ${DB};`,
    '-c', `create database ${DB};`,
  ]);
  for (const rel of [
    'tests/stub_supabase.sql',
    'migrations/20261127000001_init.sql',
    'migrations/20261127000002_pg_cron.sql',
    'seed.sql',
  ]) {
    runPsqlRaw(fs.readFileSync(path.join(ROOT, rel), 'utf8'));
  }
});

beforeEach(() => {
  cleanData();
});

// =========================================================================
// §11 Structural Security Checks
// =========================================================================

test('security: RLS enabled on EVERY table in public schema', () => {
  const rows = queryJsonAs('postgres', {}, `
    select c.relname, c.relrowsecurity
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r'
  `);
  assert.ok(rows.length >= 13);
  for (const r of rows) {
    assert.equal(r.relrowsecurity, true, `Table public.${r.relname} must have RLS enabled`);
  }
});

test('security: every SECURITY DEFINER function in public sets search_path = ""', () => {
  const rows = queryJsonAs('postgres', {}, `
    select p.proname, p.proconfig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prosecdef = true
  `);
  assert.ok(rows.length > 0);
  for (const r of rows) {
    assert.ok(
      Array.isArray(r.proconfig) && r.proconfig.includes('search_path=""'),
      `SECURITY DEFINER function public.${r.proname} must set search_path = ''`,
    );
  }
});

test('security: internal helpers revoked from anon/authenticated and granted to service_role', () => {
  const canAnonCreateNotif = queryScalarAs(
    'postgres', {},
    `has_function_privilege('anon', 'public.create_notification(uuid,uuid,text,uuid,uuid,jsonb)', 'EXECUTE')`,
  );
  const canAuthCreateNotif = queryScalarAs(
    'postgres', {},
    `has_function_privilege('authenticated', 'public.create_notification(uuid,uuid,text,uuid,uuid,jsonb)', 'EXECUTE')`,
  );
  const canSvcCreateNotif = queryScalarAs(
    'postgres', {},
    `has_function_privilege('service_role', 'public.create_notification(uuid,uuid,text,uuid,uuid,jsonb)', 'EXECUTE')`,
  );
  assert.equal(canAnonCreateNotif, false);
  assert.equal(canAuthCreateNotif, false);
  assert.equal(canSvcCreateNotif, true);

  for (const fn of [
    'public.call_webhook(text,jsonb)',
    'public.recompute_trending()',
    'public.handle_new_user()',
  ]) {
    assert.equal(
      queryScalarAs('postgres', {}, `has_function_privilege('authenticated', '${fn}', 'EXECUTE')`),
      false,
      `${fn} must not be executable by authenticated`,
    );
  }
});

test('security: is_admin() honours app_metadata and ignores user_metadata', () => {
  assert.equal(queryScalarAs('anon', anonClaims, 'public.is_admin()'), false);
  assert.equal(queryScalarAs('authenticated', userClaims(ALICE_ID), 'public.is_admin()'), false);
  // Forged user_metadata.role must be ignored!
  assert.equal(
    queryScalarAs('authenticated', userClaims(ALICE_ID, { user_metadata: { role: 'admin' } }), 'public.is_admin()'),
    false,
  );
  assert.equal(queryScalarAs('authenticated', adminClaims(ADMIN_ID), 'public.is_admin()'), true);
});

test('seed & pg_cron: 8 starter categories & 2 scheduled cron jobs exist', () => {
  // Re-apply seed.sql cleanly (idempotent on conflict)
  runPsqlRaw(fs.readFileSync(path.join(ROOT, 'seed.sql'), 'utf8'));
  const cats = queryJsonAs('anon', anonClaims, `select slug, icon from public.categories order by sort_order`);
  assert.equal(cats.length, 8);
  assert.deepEqual(cats.map((c) => c.slug), [
    'writing', 'coding', 'design-art', 'marketing', 'business', 'education', 'productivity', 'fun',
  ]);
  const jobs = queryJsonAs('postgres', {}, `select jobname, schedule from cron.job order by jobname`);
  assert.deepEqual(jobs, [
    { jobname: 'cleanup-prompt-views', schedule: '17 * * * *' },
    { jobname: 'recompute-trending', schedule: '*/15 * * * *' },
  ]);
});

// =========================================================================
// Profiles / Users (ported from firestore.rules.test.js + §5.5)
// =========================================================================

test('profiles: auth.users insert provisions profile with unique username & collision suffix', () => {
  runPsqlRaw(`
    insert into auth.users (id, email, raw_user_meta_data) values
      ('${ALICE_ID}', 'alice@example.com', '{"name":"Alice"}'),
      ('${BOB_ID}',   'alice2@example.com', '{"name":"Alice"}'),
      ('${CAROL_ID}', 'x@example.com', '{"name":"a"}');
  `);
  const rows = queryJsonAs('anon', anonClaims, `select id, username, role, status from public.profiles order by id`);
  assert.equal(rows.length, 3);
  assert.equal(rows[0].username, 'alice');
  assert.match(rows[1].username, /^alice[0-9]{3}$/);
  assert.equal(rows[2].username, 'user_x');
  assert.equal(rows[0].role, 'user');
  assert.equal(rows[0].status, 'active');
});

test('profiles: anyone can read public profile; client cannot INSERT directly or read auth.users', () => {
  seedUsers();
  const res = queryJsonAs('anon', anonClaims, `select id, username from public.profiles where id = '${ALICE_ID}'`);
  assert.equal(res.length, 1);

  assert.throws(
    () => execAs('authenticated', userClaims(ALICE_ID), `
      insert into public.profiles (id, username) values ('${ALICE_ID}', 'hacked');
    `),
    (e) => e.code === '42501',
  );
  assert.throws(
    () => queryJsonAs('authenticated', userClaims(ALICE_ID), `select email from auth.users`),
    (e) => e.code === '42501',
  );
});

test('profiles: owner may update bio/name/avatar/username but never role/status/counters (42501)', () => {
  seedUsers();
  execAs('authenticated', userClaims(ALICE_ID), `
    update public.profiles set bio = 'hi', name = 'Alice M', avatar_url = 'https://img/a.png' where id = '${ALICE_ID}';
  `);
  const p = queryJsonAs('anon', anonClaims, `select bio, name, avatar_url from public.profiles where id = '${ALICE_ID}'`)[0];
  assert.equal(p.bio, 'hi');
  assert.equal(p.name, 'Alice M');

  for (const colExpr of [
    `role = 'admin'`,
    `status = 'banned'`,
    `follower_count = 999`,
    `following_count = 999`,
    `prompt_count = 999`,
    `total_likes_received = 999`,
  ]) {
    assert.throws(
      () => execAs('authenticated', userClaims(ALICE_ID), `update public.profiles set ${colExpr} where id = '${ALICE_ID}';`),
      (e) => e.code === '42501',
      `Updating ${colExpr} should fail with 42501`,
    );
  }
});

test('profiles: strangers cannot update someone else profile; username unique case-insensitively', () => {
  seedUsers();
  execAs('authenticated', userClaims(BOB_ID), `
    update public.profiles set bio = 'pwned' where id = '${ALICE_ID}';
  `);
  const bio = queryScalarAs('anon', anonClaims, `select bio from public.profiles where id = '${ALICE_ID}'`);
  assert.equal(bio, '');

  // Case-insensitive username uniqueness
  assert.throws(
    () => execAs('authenticated', userClaims(BOB_ID), `
      update public.profiles set username = 'ALICE' where id = '${BOB_ID}';
    `),
    (e) => e.code === '23505',
  );
});

// =========================================================================
// FCM Tokens
// =========================================================================

test('fcm_tokens: only owning device account registers, reads, and unregisters tokens', () => {
  seedUsers();
  execAs('authenticated', userClaims(ALICE_ID), `select public.register_fcm_token('fcm-tok-1', 'android');`);
  assert.equal(
    queryJsonAs('authenticated', userClaims(ALICE_ID), `select token from public.fcm_tokens`).length,
    1,
  );
  // Bob cannot see Alice's token
  assert.equal(
    queryJsonAs('authenticated', userClaims(BOB_ID), `select token from public.fcm_tokens`).length,
    0,
  );
  // Anon cannot register (42501: not granted), authenticated without sub rejected (28000)
  assert.throws(
    () => execAs('anon', anonClaims, `select public.register_fcm_token('fcm-tok-anon', 'android');`),
    (e) => e.code === '42501',
  );
  assert.throws(
    () => execAs('authenticated', {}, `select public.register_fcm_token('fcm-tok-nosub', 'android');`),
    (e) => e.code === '28000',
  );
  // Direct insert denied
  assert.throws(
    () => execAs('authenticated', userClaims(ALICE_ID), `
      insert into public.fcm_tokens (token, user_id) values ('t2', '${ALICE_ID}');
    `),
    (e) => e.code === '42501',
  );
  // Bob cannot delete Alice's token
  execAs('authenticated', userClaims(BOB_ID), `delete from public.fcm_tokens where token = 'fcm-tok-1';`);
  assert.equal(
    queryJsonAs('authenticated', userClaims(ALICE_ID), `select token from public.fcm_tokens`).length,
    1,
  );
  // Alice can unregister
  execAs('authenticated', userClaims(ALICE_ID), `select public.unregister_fcm_token('fcm-tok-1');`);
  assert.equal(
    queryJsonAs('authenticated', userClaims(ALICE_ID), `select token from public.fcm_tokens`).length,
    0,
  );
});

// =========================================================================
// Prompts
// =========================================================================

test('prompts: visibility (public/unlisted/private) and moderation status (hidden/removed)', () => {
  seedUsers();
  runPsqlRaw(`
    insert into public.prompts (id, creator_id, title, prompt_content, visibility, status) values
      ('10000000-0000-0000-0000-000000000001', '${ALICE_ID}', 'Public',   'body', 'public',   'active'),
      ('10000000-0000-0000-0000-000000000002', '${ALICE_ID}', 'Private',  'body', 'private',  'active'),
      ('10000000-0000-0000-0000-000000000003', '${ALICE_ID}', 'Unlisted', 'body', 'unlisted', 'active'),
      ('10000000-0000-0000-0000-000000000004', '${ALICE_ID}', 'Hidden',   'body', 'public',   'hidden');
  `);

  // Anon sees only Public
  assert.deepEqual(
    queryJsonAs('anon', anonClaims, `select title from public.prompts order by title`).map((r) => r.title),
    ['Public'],
  );
  // Bob (stranger) sees only Public
  assert.deepEqual(
    queryJsonAs('authenticated', userClaims(BOB_ID), `select title from public.prompts order by title`).map((r) => r.title),
    ['Public'],
  );
  // Alice (owner) sees Public, Private, Unlisted, NOT Hidden
  assert.deepEqual(
    queryJsonAs('authenticated', userClaims(ALICE_ID), `select title from public.prompts order by title`).map((r) => r.title),
    ['Private', 'Public', 'Unlisted'],
  );
  // Admin sees all 4 including Hidden
  assert.deepEqual(
    queryJsonAs('authenticated', adminClaims(), `select title from public.prompts order by title`).map((r) => r.title),
    ['Hidden', 'Private', 'Public', 'Unlisted'],
  );
});

test('prompts: create enforces creator_id, active status, column grants, CHECKs, and trigger normalization', () => {
  seedUsers();
  // Valid create normalizes tags & fills creator_username
  execAs('authenticated', userClaims(ALICE_ID), `
    insert into public.prompts (creator_id, title, prompt_content, category_id, tags)
    values ('${ALICE_ID}', 'My Prompt', 'You are helpful.', '${CAT_WRITING}', array['  AI ', 'GPT', '']);
  `);
  const created = queryJsonAs('anon', anonClaims, `select creator_username, tags from public.prompts`)[0];
  assert.equal(created.creator_username, 'alice');
  assert.deepEqual(created.tags, ['ai', 'gpt']);
  assert.equal(queryScalarAs('anon', anonClaims, `select prompt_count from public.profiles where id = '${ALICE_ID}'`), 1);
  assert.equal(queryScalarAs('anon', anonClaims, `select prompt_count from public.categories where id = '${CAT_WRITING}'`), 1);

  // Forged creator_id
  assert.throws(
    () => execAs('authenticated', userClaims(ALICE_ID), `
      insert into public.prompts (creator_id, title, prompt_content) values ('${BOB_ID}', 'Forged', 'body');
    `),
    (e) => e.code === '42501',
  );
  // Anon insert
  assert.throws(
    () => execAs('anon', anonClaims, `
      insert into public.prompts (creator_id, title, prompt_content) values ('${ALICE_ID}', 'Anon', 'body');
    `),
    (e) => e.code === '42501',
  );
  // Spoofed counter / trend_score / is_featured / status / creator_username -> 42501
  for (const [col, val] of [
    ['like_count', '50'],
    ['trend_score', '100'],
    ['is_featured', 'true'],
    ['status', `'hidden'`],
    ['creator_username', `'someone_else'`],
  ]) {
    assert.throws(
      () => execAs('authenticated', userClaims(ALICE_ID), `
        insert into public.prompts (creator_id, title, prompt_content, ${col})
        values ('${ALICE_ID}', 'Spoof', 'body', ${val});
      `),
      (e) => e.code === '42501',
      `Setting ${col} on insert must fail with 42501`,
    );
  }
  // Empty prompt_content -> 23514
  assert.throws(
    () => execAs('authenticated', userClaims(ALICE_ID), `
      insert into public.prompts (creator_id, title, prompt_content) values ('${ALICE_ID}', 'Empty', '');
    `),
    (e) => e.code === '23514',
  );
  // >12 tags -> 23514
  assert.throws(
    () => execAs('authenticated', userClaims(ALICE_ID), `
      insert into public.prompts (creator_id, title, prompt_content, tags)
      values ('${ALICE_ID}', 'Tags', 'body', array['a','b','c','d','e','f','g','h','i','j','k','l','m']);
    `),
    (e) => e.code === '23514',
  );
});

test('prompts: owner edits content (and category count updates), never counters/creator/status; only owner deletes', () => {
  seedUsers();
  const pid = insertPromptAs(ALICE_ID, { title: 'Old Title', categoryId: CAT_WRITING });
  // Move category from Writing -> Coding
  execAs('authenticated', userClaims(ALICE_ID), `
    update public.prompts set title = 'New Title', category_id = '${CAT_CODING}' where id = '${pid}';
  `);
  assert.equal(queryScalarAs('anon', anonClaims, `select prompt_count from public.categories where id = '${CAT_WRITING}'`), 0);
  assert.equal(queryScalarAs('anon', anonClaims, `select prompt_count from public.categories where id = '${CAT_CODING}'`), 1);

  // Spoofed updates rejected (42501)
  for (const expr of [`like_count = 999`, `creator_id = '${BOB_ID}'`, `status = 'hidden'`, `trend_score = 42`, `is_featured = true`]) {
    assert.throws(
      () => execAs('authenticated', userClaims(ALICE_ID), `update public.prompts set ${expr} where id = '${pid}';`),
      (e) => e.code === '42501',
    );
  }
  // Stranger edit/delete affects 0 rows
  execAs('authenticated', userClaims(BOB_ID), `update public.prompts set title = 'Hacked' where id = '${pid}';`);
  execAs('authenticated', userClaims(BOB_ID), `delete from public.prompts where id = '${pid}';`);
  assert.equal(queryScalarAs('anon', anonClaims, `select title from public.prompts where id = '${pid}'`), 'New Title');

  // Owner deletes
  execAs('authenticated', userClaims(ALICE_ID), `delete from public.prompts where id = '${pid}';`);
  assert.equal(queryScalarAs('anon', anonClaims, `select count(*) from public.prompts where id = '${pid}'`), 0);
  assert.equal(queryScalarAs('anon', anonClaims, `select prompt_count from public.categories where id = '${CAT_CODING}'`), 0);
});

test('prompts: profile username/avatar update propagates to prompts & comments without bumping prompt updated_at', () => {
  seedUsers();
  const pid = insertPromptAs(ALICE_ID, { title: 'Title' });
  // Set updated_at explicitly as postgres so we can test it isn't bumped
  runPsqlRaw(`update public.prompts set updated_at = '2025-01-01T00:00:00Z' where id = '${pid}';`);
  insertCommentAs(ALICE_ID, pid, 'First!');

  execAs('authenticated', userClaims(ALICE_ID), `
    update public.profiles set username = 'alice_new', avatar_url = 'https://img/new.png' where id = '${ALICE_ID}';
  `);
  const pr = queryJsonAs('anon', anonClaims, `select creator_username, creator_avatar, updated_at from public.prompts where id = '${pid}'`)[0];
  const cm = queryJsonAs('anon', anonClaims, `select author_username, author_avatar from public.comments where prompt_id = '${pid}'`)[0];
  assert.equal(pr.creator_username, 'alice_new');
  assert.equal(pr.creator_avatar, 'https://img/new.png');
  assert.ok(pr.updated_at.startsWith('2025-01-01'));
  assert.equal(cm.author_username, 'alice_new');
  assert.equal(cm.author_avatar, 'https://img/new.png');
});

// =========================================================================
// Likes & Bookmarks
// =========================================================================

test('likes: composite PK, RLS target visibility, counter/trend/notification triggers, no update, owner delete', () => {
  seedUsers();
  const pubId = insertPromptAs(ALICE_ID, { title: 'Pub', visibility: 'public' });
  const privId = insertPromptAs(ALICE_ID, { title: 'Priv', visibility: 'private' });

  // Bob likes Alice's public prompt
  execAs('authenticated', userClaims(BOB_ID), `
    insert into public.likes (user_id, prompt_id) values ('${BOB_ID}', '${pubId}');
  `);
  const pr = queryJsonAs('anon', anonClaims, `select like_count, trend_score from public.prompts where id = '${pubId}'`)[0];
  assert.equal(pr.like_count, 1);
  assert.equal(pr.trend_score, 3);
  assert.equal(queryScalarAs('anon', anonClaims, `select total_likes_received from public.profiles where id = '${ALICE_ID}'`), 1);
  assert.equal(queryJsonAs('authenticated', userClaims(ALICE_ID), `select type from public.notifications`)[0].type, 'like');

  // Forged user_id rejected
  assert.throws(
    () => execAs('authenticated', userClaims(BOB_ID), `insert into public.likes (user_id, prompt_id) values ('${ALICE_ID}', '${pubId}');`),
    (e) => e.code === '42501',
  );
  // Bob cannot like Alice's private prompt
  assert.throws(
    () => execAs('authenticated', userClaims(BOB_ID), `insert into public.likes (user_id, prompt_id) values ('${BOB_ID}', '${privId}');`),
    (e) => e.code === '42501',
  );
  // Never updatable
  assert.throws(
    () => execAs('authenticated', userClaims(BOB_ID), `update public.likes set prompt_id = '${privId}' where user_id = '${BOB_ID}';`),
    (e) => e.code === '42501',
  );
  // Stranger cannot delete Bob's like
  execAs('authenticated', userClaims(CAROL_ID), `delete from public.likes where user_id = '${BOB_ID}';`);
  assert.equal(queryScalarAs('anon', anonClaims, `select like_count from public.prompts where id = '${pubId}'`), 1);

  // Bob unlikes -> counters unwind
  execAs('authenticated', userClaims(BOB_ID), `delete from public.likes where user_id = '${BOB_ID}' and prompt_id = '${pubId}';`);
  assert.equal(queryScalarAs('anon', anonClaims, `select like_count from public.prompts where id = '${pubId}'`), 0);
  assert.equal(queryScalarAs('anon', anonClaims, `select trend_score from public.prompts where id = '${pubId}'`), 0);
  assert.equal(queryScalarAs('anon', anonClaims, `select total_likes_received from public.profiles where id = '${ALICE_ID}'`), 0);
});

test('bookmarks: composite PK, counter triggers, no update, forged/private rejected', () => {
  seedUsers();
  const pubId = insertPromptAs(ALICE_ID, { title: 'Pub', visibility: 'public' });
  const privId = insertPromptAs(ALICE_ID, { title: 'Priv', visibility: 'private' });

  execAs('authenticated', userClaims(BOB_ID), `insert into public.bookmarks (user_id, prompt_id) values ('${BOB_ID}', '${pubId}');`);
  assert.equal(queryScalarAs('anon', anonClaims, `select bookmark_count from public.prompts where id = '${pubId}'`), 1);

  assert.throws(
    () => execAs('authenticated', userClaims(BOB_ID), `insert into public.bookmarks (user_id, prompt_id) values ('${ALICE_ID}', '${pubId}');`),
    (e) => e.code === '42501',
  );
  assert.throws(
    () => execAs('authenticated', userClaims(BOB_ID), `insert into public.bookmarks (user_id, prompt_id) values ('${BOB_ID}', '${privId}');`),
    (e) => e.code === '42501',
  );
  assert.throws(
    () => execAs('authenticated', userClaims(BOB_ID), `update public.bookmarks set user_id = '${ALICE_ID}';`),
    (e) => e.code === '42501',
  );

  execAs('authenticated', userClaims(BOB_ID), `delete from public.bookmarks where user_id = '${BOB_ID}' and prompt_id = '${pubId}';`);
  assert.equal(queryScalarAs('anon', anonClaims, `select bookmark_count from public.prompts where id = '${pubId}'`), 0);
});

// =========================================================================
// Follows
// =========================================================================

test('follows: valid follow/unfollow updates counters & notification; self-follow & forged ids rejected', () => {
  seedUsers();
  execAs('authenticated', userClaims(ALICE_ID), `
    insert into public.follows (follower_id, followed_id) values ('${ALICE_ID}', '${BOB_ID}');
  `);
  assert.equal(queryScalarAs('anon', anonClaims, `select following_count from public.profiles where id = '${ALICE_ID}'`), 1);
  assert.equal(queryScalarAs('anon', anonClaims, `select follower_count from public.profiles where id = '${BOB_ID}'`), 1);
  assert.equal(queryJsonAs('authenticated', userClaims(BOB_ID), `select type from public.notifications`)[0].type, 'follow');
  // Carol cannot see Alice->Bob follow
  assert.equal(queryJsonAs('authenticated', userClaims(CAROL_ID), `select * from public.follows`).length, 0);

  // Self-follow rejected
  assert.throws(
    () => execAs('authenticated', userClaims(ALICE_ID), `insert into public.follows (follower_id, followed_id) values ('${ALICE_ID}', '${ALICE_ID}');`),
    (e) => e.code === '42501' || e.code === '23514',
  );
  // Forged follower_id rejected
  assert.throws(
    () => execAs('authenticated', userClaims(ALICE_ID), `insert into public.follows (follower_id, followed_id) values ('${BOB_ID}', '${CAROL_ID}');`),
    (e) => e.code === '42501',
  );

  execAs('authenticated', userClaims(ALICE_ID), `delete from public.follows where follower_id = '${ALICE_ID}' and followed_id = '${BOB_ID}';`);
  assert.equal(queryScalarAs('anon', anonClaims, `select following_count from public.profiles where id = '${ALICE_ID}'`), 0);
  assert.equal(queryScalarAs('anon', anonClaims, `select follower_count from public.profiles where id = '${BOB_ID}'`), 0);
});

// =========================================================================
// Comments & Comment Likes
// =========================================================================

test('comments: author create, replies survive deleted parent, prompt owner moderation delete, soft-delete, edit restrictions', () => {
  seedUsers();
  const pAlice = insertPromptAs(ALICE_ID, { title: 'Alice P' });
  const pBob   = insertPromptAs(BOB_ID,   { title: 'Bob P' });

  // Bob comments on Alice's prompt
  const cParent = insertCommentAs(BOB_ID, pAlice, 'Nice prompt!');
  assert.equal(queryScalarAs('anon', anonClaims, `select comment_count from public.prompts where id = '${pAlice}'`), 1);
  assert.equal(queryJsonAs('authenticated', userClaims(ALICE_ID), `select type from public.notifications`)[0].type, 'comment');

  // Carol replies to Bob's comment
  const cReply = insertCommentAs(CAROL_ID, pAlice, 'Agreed!', cParent);
  assert.equal(queryScalarAs('anon', anonClaims, `select comment_count from public.prompts where id = '${pAlice}'`), 2);
  assert.equal(queryJsonAs('authenticated', userClaims(BOB_ID), `select type from public.notifications`)[0].type, 'reply');

  // Cross-prompt parent_id rejected
  assert.throws(
    () => execAs('authenticated', userClaims(CAROL_ID), `
      insert into public.comments (prompt_id, parent_id, author_id, content) values ('${pBob}', '${cParent}', '${CAROL_ID}', 'cross');
    `),
    (e) => e.code === '23514',
  );
  // Forged author, spoofed author_username, empty content rejected
  assert.throws(
    () => execAs('authenticated', userClaims(ALICE_ID), `
      insert into public.comments (prompt_id, author_id, content) values ('${pAlice}', '${BOB_ID}', 'forged');
    `),
    (e) => e.code === '42501',
  );
  assert.throws(
    () => execAs('authenticated', userClaims(ALICE_ID), `
      insert into public.comments (prompt_id, author_id, author_username, content) values ('${pAlice}', '${ALICE_ID}', 'not_me', 'hi');
    `),
    (e) => e.code === '42501',
  );
  assert.throws(
    () => execAs('authenticated', userClaims(ALICE_ID), `
      insert into public.comments (prompt_id, author_id, content) values ('${pAlice}', '${ALICE_ID}', '');
    `),
    (e) => e.code === '23514',
  );

  // Author can edit content only
  execAs('authenticated', userClaims(CAROL_ID), `update public.comments set content = 'Edited!' where id = '${cReply}';`);
  for (const expr of [`like_count = 50`, `status = 'removed'`, `prompt_id = '${pBob}'`]) {
    assert.throws(
      () => execAs('authenticated', userClaims(CAROL_ID), `update public.comments set ${expr} where id = '${cReply}';`),
      (e) => e.code === '42501',
    );
  }

  // Stranger (Bob) cannot delete Carol's reply on Alice's prompt
  execAs('authenticated', userClaims(BOB_ID), `delete from public.comments where id = '${cReply}';`);
  assert.equal(queryScalarAs('anon', anonClaims, `select count(*) from public.comments where id = '${cReply}'`), 1);

  // Prompt owner (Alice) deletes Bob's parent comment -> reply survives!
  execAs('authenticated', userClaims(ALICE_ID), `delete from public.comments where id = '${cParent}';`);
  assert.equal(queryScalarAs('anon', anonClaims, `select count(*) from public.comments where id = '${cParent}'`), 0);
  assert.equal(queryScalarAs('anon', anonClaims, `select count(*) from public.comments where id = '${cReply}'`), 1);
  assert.equal(queryScalarAs('anon', anonClaims, `select comment_count from public.prompts where id = '${pAlice}'`), 1);

  // Admin soft-deletes Carol's reply (status -> 'removed') -> hidden from clients, visible to admin, count decremented
  runPsqlRaw(`update public.comments set status = 'removed' where id = '${cReply}';`);
  assert.equal(queryScalarAs('anon', anonClaims, `select count(*) from public.comments where id = '${cReply}'`), 0);
  assert.equal(queryScalarAs('authenticated', userClaims(CAROL_ID), `select count(*) from public.comments where id = '${cReply}'`), 0);
  assert.equal(queryScalarAs('authenticated', adminClaims(), `select count(*) from public.comments where id = '${cReply}'`), 1);
  assert.equal(queryScalarAs('anon', anonClaims, `select comment_count from public.prompts where id = '${pAlice}'`), 0);
});

test('comment_likes: composite PK, counter + notification, no update, forged rejected', () => {
  seedUsers();
  const pid = insertPromptAs(ALICE_ID, { title: 'P' });
  const cid = insertCommentAs(ALICE_ID, pid, 'C');

  execAs('authenticated', userClaims(BOB_ID), `insert into public.comment_likes (user_id, comment_id) values ('${BOB_ID}', '${cid}');`);
  assert.equal(queryScalarAs('anon', anonClaims, `select like_count from public.comments where id = '${cid}'`), 1);
  assert.equal(queryJsonAs('authenticated', userClaims(ALICE_ID), `select type from public.notifications`)[0].type, 'comment_like');

  assert.throws(
    () => execAs('authenticated', userClaims(BOB_ID), `insert into public.comment_likes (user_id, comment_id) values ('${ALICE_ID}', '${cid}');`),
    (e) => e.code === '42501',
  );
  assert.throws(
    () => execAs('authenticated', userClaims(BOB_ID), `update public.comment_likes set comment_id = '${cid}';`),
    (e) => e.code === '42501',
  );

  execAs('authenticated', userClaims(BOB_ID), `delete from public.comment_likes where user_id = '${BOB_ID}' and comment_id = '${cid}';`);
  assert.equal(queryScalarAs('anon', anonClaims, `select like_count from public.comments where id = '${cid}'`), 0);
});

// =========================================================================
// Notifications & service_role create_notification (§6.2 #11)
// =========================================================================

test('notifications: client insert denied (even admin), recipient flips is_read only, service_role create_notification works', () => {
  seedUsers();
  assert.throws(
    () => execAs('authenticated', userClaims(ALICE_ID), `
      insert into public.notifications (recipient_id, actor_id, type) values ('${ALICE_ID}', '${BOB_ID}', 'like');
    `),
    (e) => e.code === '42501',
  );
  assert.throws(
    () => execAs('authenticated', adminClaims(), `
      insert into public.notifications (recipient_id, actor_id, type) values ('${ALICE_ID}', '${BOB_ID}', 'like');
    `),
    (e) => e.code === '42501',
  );

  // service_role calls create_notification (admin report resolution §6.2 #11)
  execAs('service_role', {}, `
    select public.create_notification(
      '${ALICE_ID}'::uuid,
      '${ADMIN_ID}'::uuid,
      'report_resolved',
      null,
      null,
      '{"status":"resolved"}'::jsonb
    );
  `);
  // Self-notification skipped
  execAs('service_role', {}, `
    select public.create_notification('${ALICE_ID}'::uuid, '${ALICE_ID}'::uuid, 'like');
  `);

  const aliceNotifs = queryJsonAs('authenticated', userClaims(ALICE_ID), `select id, type, is_read from public.notifications`);
  assert.equal(aliceNotifs.length, 1);
  assert.equal(aliceNotifs[0].type, 'report_resolved');
  assert.equal(aliceNotifs[0].is_read, false);

  // Bob cannot see Alice's notification
  assert.equal(queryJsonAs('authenticated', userClaims(BOB_ID), `select id from public.notifications`).length, 0);

  // Alice flips is_read only
  execAs('authenticated', userClaims(ALICE_ID), `update public.notifications set is_read = true where id = '${aliceNotifs[0].id}';`);
  assert.equal(queryScalarAs('authenticated', userClaims(ALICE_ID), `select is_read from public.notifications where id = '${aliceNotifs[0].id}'`), true);

  assert.throws(
    () => execAs('authenticated', userClaims(ALICE_ID), `update public.notifications set type = 'system' where id = '${aliceNotifs[0].id}';`),
    (e) => e.code === '42501',
  );
  // Bob cannot update or delete Alice's notification
  execAs('authenticated', userClaims(BOB_ID), `delete from public.notifications where id = '${aliceNotifs[0].id}';`);
  assert.equal(queryJsonAs('authenticated', userClaims(ALICE_ID), `select id from public.notifications`).length, 1);

  // Alice deletes own notification
  execAs('authenticated', userClaims(ALICE_ID), `delete from public.notifications where id = '${aliceNotifs[0].id}';`);
  assert.equal(queryJsonAs('authenticated', userClaims(ALICE_ID), `select id from public.notifications`).length, 0);
});

// =========================================================================
// Categories, Reports, Admin Actions, Prompt Views
// =========================================================================

test('categories: world-readable, client writes denied even for admin JWT, service_role writes allowed', () => {
  seedUsers();
  assert.equal(queryJsonAs('anon', anonClaims, `select slug from public.categories`).length, 2);

  for (const claims of [userClaims(ALICE_ID), adminClaims()]) {
    assert.throws(
      () => execAs('authenticated', claims, `update public.categories set name = 'Hacked' where id = '${CAT_WRITING}';`),
      (e) => e.code === '42501',
    );
    assert.throws(
      () => execAs('authenticated', claims, `insert into public.categories (name, slug) values ('New', 'new');`),
      (e) => e.code === '42501',
    );
  }
  execAs('service_role', {}, `insert into public.categories (name, slug, icon, sort_order) values ('New', 'new', '✨', 9);`);
  assert.equal(queryJsonAs('anon', anonClaims, `select slug from public.categories where slug = 'new'`).length, 1);
});

test('reports: active users create pending report; invalid/duplicate silently dropped; owner & admin read; client update denied', () => {
  seedUsers();
  const pid = insertPromptAs(ALICE_ID, { title: 'P' });

  // Valid report
  execAs('authenticated', userClaims(BOB_ID), `
    insert into public.reports (reporter_id, target_type, target_id, reason) values ('${BOB_ID}', 'prompt', '${pid}', 'Spam');
  `);
  assert.equal(queryJsonAs('authenticated', userClaims(BOB_ID), `select id from public.reports`).length, 1);
  // Duplicate within 1h silently dropped
  execAs('authenticated', userClaims(BOB_ID), `
    insert into public.reports (reporter_id, target_type, target_id, reason) values ('${BOB_ID}', 'prompt', '${pid}', 'Spam again');
  `);
  assert.equal(queryJsonAs('authenticated', userClaims(BOB_ID), `select id from public.reports`).length, 1);
  // Non-existent target silently dropped
  execAs('authenticated', userClaims(CAROL_ID), `
    insert into public.reports (reporter_id, target_type, target_id, reason)
    values ('${CAROL_ID}', 'prompt', '99999999-9999-4999-8999-999999999999', 'Ghost');
  `);
  assert.equal(queryJsonAs('authenticated', adminClaims(), `select id from public.reports`).length, 1);

  // Carol cannot see Bob's report; Admin can
  assert.equal(queryJsonAs('authenticated', userClaims(CAROL_ID), `select id from public.reports`).length, 0);
  assert.equal(queryJsonAs('authenticated', adminClaims(), `select id from public.reports`).length, 1);

  // Forged reporter, anon insert, setting status, client update all denied
  assert.throws(
    () => execAs('authenticated', userClaims(BOB_ID), `
      insert into public.reports (reporter_id, target_type, target_id, reason) values ('${CAROL_ID}', 'prompt', '${pid}', 'x');
    `),
    (e) => e.code === '42501',
  );
  assert.throws(
    () => execAs('anon', anonClaims, `
      insert into public.reports (reporter_id, target_type, target_id, reason) values ('${BOB_ID}', 'prompt', '${pid}', 'x');
    `),
    (e) => e.code === '42501',
  );
  assert.throws(
    () => execAs('authenticated', userClaims(BOB_ID), `
      insert into public.reports (reporter_id, target_type, target_id, reason, status) values ('${BOB_ID}', 'prompt', '${pid}', 'x', 'resolved');
    `),
    (e) => e.code === '42501',
  );
  assert.throws(
    () => execAs('authenticated', adminClaims(), `update public.reports set status = 'resolved';`),
    (e) => e.code === '42501',
  );
});

test('admin_actions: admin JWT reads only; client write always denied; service_role writes allowed', () => {
  seedUsers();
  execAs('service_role', {}, `
    insert into public.admin_actions (admin_id, action_type, target_type, target_id)
    values ('${ADMIN_ID}', 'ban_user', 'user', '${BOB_ID}');
  `);

  assert.equal(queryJsonAs('authenticated', userClaims(ALICE_ID), `select id from public.admin_actions`).length, 0);
  assert.equal(queryJsonAs('authenticated', adminClaims(), `select id from public.admin_actions`).length, 1);

  assert.throws(
    () => execAs('authenticated', adminClaims(), `
      insert into public.admin_actions (admin_id, action_type, target_type, target_id) values ('${ADMIN_ID}', 'forged', 'user', 'x');
    `),
    (e) => e.code === '42501',
  );
  assert.throws(
    () => execAs('authenticated', adminClaims(), `update public.admin_actions set action_type = 'tampered';`),
    (e) => e.code === '42501',
  );
});

test('prompt_views: completely unreachable from clients (even admin JWT)', () => {
  seedUsers();
  for (const [role, claims] of [
    ['anon', anonClaims],
    ['authenticated', userClaims(ALICE_ID)],
    ['authenticated', adminClaims()],
  ]) {
    assert.throws(() => queryJsonAs(role, claims, `select * from public.prompt_views`), (e) => e.code === '42501');
    assert.throws(
      () => execAs(role, claims, `insert into public.prompt_views (viewer_key, prompt_id) values ('x', gen_random_uuid());`),
      (e) => e.code === '42501',
    );
  }
});

// =========================================================================
// Banned User Enforcement (§5.5)
// =========================================================================

test('banned user: cannot update profile or insert prompts, comments, or reports', () => {
  seedUsers();
  const pid = insertPromptAs(ALICE_ID, { title: 'P' });
  // Ban Bob
  execAs('service_role', {}, `update public.profiles set status = 'banned' where id = '${BOB_ID}';`);

  assert.throws(
    () => execAs('authenticated', userClaims(BOB_ID), `insert into public.prompts (creator_id, title, prompt_content) values ('${BOB_ID}', 'X', 'Y');`),
    (e) => e.code === '42501',
  );
  assert.throws(
    () => execAs('authenticated', userClaims(BOB_ID), `insert into public.comments (prompt_id, author_id, content) values ('${pid}', '${BOB_ID}', 'spam');`),
    (e) => e.code === '42501',
  );
  assert.throws(
    () => execAs('authenticated', userClaims(BOB_ID), `insert into public.reports (reporter_id, target_type, target_id, reason) values ('${BOB_ID}', 'prompt', '${pid}', 'spam');`),
    (e) => e.code === '42501',
  );
  // Updating own profile when banned affects 0 rows
  execAs('authenticated', userClaims(BOB_ID), `update public.profiles set bio = 'still here' where id = '${BOB_ID}';`);
  assert.equal(queryScalarAs('anon', anonClaims, `select bio from public.profiles where id = '${BOB_ID}'`), '');
});

// =========================================================================
// RPCs: copy_prompt, record_view, search_prompts, recompute_trending
// =========================================================================

test('RPCs: copy_prompt, record_view (24h dedupe + guest + invalid anonId), search_prompts (% escaping), trending = 34', () => {
  seedUsers();
  const pid    = insertPromptAs(ALICE_ID, { title: '100% SQL Assistant', visibility: 'public',  tags: ['sql', 'ai'] });
  const privId = insertPromptAs(ALICE_ID, { title: 'Secret Prompt',      visibility: 'private', tags: ['secret'] });

  // copy_prompt
  execAs('anon', anonClaims, `select public.copy_prompt('${pid}');`);
  assert.equal(queryScalarAs('anon', anonClaims, `select copy_count from public.prompts where id = '${pid}'`), 1);
  assert.equal(queryScalarAs('anon', anonClaims, `select trend_score from public.prompts where id = '${pid}'`), 5);
  assert.throws(
    () => execAs('anon', anonClaims, `select public.copy_prompt('${privId}');`),
    (e) => e.code === 'P0002',
  );

  // record_view: guest dedupe 24h
  assert.equal(queryScalarAs('anon', anonClaims, `public.record_view('${pid}', 'guest-device-1234')`), true);
  assert.equal(queryScalarAs('anon', anonClaims, `public.record_view('${pid}', 'guest-device-1234')`), false);
  assert.equal(queryScalarAs('anon', anonClaims, `select view_count from public.prompts where id = '${pid}'`), 1);

  // invalid anonId rejected
  assert.throws(
    () => execAs('anon', anonClaims, `select public.record_view('${pid}', 'bad');`),
    (e) => e.code === '22023',
  );
  // private prompt returns false
  assert.equal(queryScalarAs('anon', anonClaims, `public.record_view('${privId}', 'guest-device-1234')`), false);

  // signed-in user view + 24h expiry refresh
  assert.equal(queryScalarAs('authenticated', userClaims(BOB_ID), `public.record_view('${pid}')`), true);
  assert.equal(queryScalarAs('authenticated', userClaims(BOB_ID), `public.record_view('${pid}')`), false);
  runPsqlRaw(`update public.prompt_views set created_at = now() - interval '25 hours' where viewer_key = '${BOB_ID}';`);
  assert.equal(queryScalarAs('authenticated', userClaims(BOB_ID), `public.record_view('${pid}')`), true);
  assert.equal(queryScalarAs('anon', anonClaims, `select view_count from public.prompts where id = '${pid}'`), 3);

  // search_prompts: % escaping (must NOT match 'Secret Prompt' or unrelated prompts when searching '%')
  execAs('authenticated', userClaims(ALICE_ID), `
    insert into public.prompts (creator_id, title, prompt_content) values ('${ALICE_ID}', 'Plain Title', 'body');
  `);
  const pctResults = queryJsonAs('anon', anonClaims, `select title from public.search_prompts('%', 20)`);
  assert.deepEqual(pctResults.map((r) => r.title), ['100% SQL Assistant']);
  const tagResults = queryJsonAs('anon', anonClaims, `select title from public.search_prompts('sql', 20)`);
  assert.equal(tagResults.length, 1);

  // prompts_by_tag RPC must enforce active+public and never leak private prompts
  assert.deepEqual(
    queryJsonAs('anon', anonClaims, `select title from public.prompts_by_tag('sql', 12)`).map((r) => r.title),
    ['100% SQL Assistant'],
  );
  assert.equal(
    queryJsonAs('anon', anonClaims, `select title from public.prompts_by_tag('secret', 12)`).length,
    0,
  );

  // Trending formula reference case = 34:
  // likes=2 (6) + copies=1 (5) + views=3 (3) + recency at age 24h (round(40 * 0.5) = 20) => 34
  execAs('authenticated', userClaims(BOB_ID), `insert into public.likes (user_id, prompt_id) values ('${BOB_ID}', '${pid}');`);
  execAs('authenticated', userClaims(CAROL_ID), `insert into public.likes (user_id, prompt_id) values ('${CAROL_ID}', '${pid}');`);
  runPsqlRaw(`update public.prompts set created_at = now() - interval '24 hours', trend_score = 0 where id = '${pid}';`);
  const updatedCount = queryScalarAs('postgres', {}, `public.recompute_trending()`);
  assert.ok(updatedCount >= 1);
  assert.equal(queryScalarAs('anon', anonClaims, `select trend_score from public.prompts where id = '${pid}'`), 34);
});

// =========================================================================
// Webhooks & Account Cascade Deletion
// =========================================================================

test('call_webhook: fires pg_net when vault secrets exist and NEVER raises on network failure', () => {
  seedUsers();
  // 1. Healthy webhook secrets -> records HTTP request
  runPsqlRaw(`
    insert into vault.decrypted_secrets (name, decrypted_secret) values
      ('api_base_url', 'https://api.promptindo.test'),
      ('webhook_secret', 'super-secret-32-bytes-minimum-key');
  `);
  const pid = insertPromptAs(ALICE_ID, { title: 'Thumb', thumbnailPath: `${ALICE_ID}/t.png` });
  execAs('authenticated', userClaims(BOB_ID), `insert into public.likes (user_id, prompt_id) values ('${BOB_ID}', '${pid}');`);
  execAs('authenticated', userClaims(ALICE_ID), `delete from public.prompts where id = '${pid}';`);

  const reqs = queryJsonAs('postgres', {}, `select url, headers->>'x-webhook-secret' as sec from net._http_requests order by id`);
  assert.deepEqual(reqs.map((r) => r.url), [
    'https://api.promptindo.test/api/webhooks/push',
    'https://api.promptindo.test/api/webhooks/prompt-deleted',
  ]);
  assert.equal(reqs[0].sec, 'super-secret-32-bytes-minimum-key');

  // 2. Failing network call -> warning only, transaction MUST still commit!
  runPsqlRaw(`update vault.decrypted_secrets set decrypted_secret = 'http://raise.test' where name = 'api_base_url';`);
  execAs('authenticated', userClaims(ALICE_ID), `
    insert into public.follows (follower_id, followed_id) values ('${ALICE_ID}', '${BOB_ID}');
  `);
  assert.equal(queryScalarAs('anon', anonClaims, `select follower_count from public.profiles where id = '${BOB_ID}'`), 1);
});

test('account deletion: deleting auth.users cascades all data and unwinds counters on others', () => {
  seedUsers();
  const pBob = insertPromptAs(BOB_ID, { title: 'Bob Prompt', categoryId: CAT_WRITING });
  const cBob = insertCommentAs(BOB_ID, pBob, 'Bob comment');
  const pAlice = insertPromptAs(ALICE_ID, { title: 'Alice Prompt', categoryId: CAT_CODING });
  execAs('authenticated', userClaims(ALICE_ID), `
    insert into public.likes (user_id, prompt_id) values ('${ALICE_ID}', '${pBob}');
    insert into public.bookmarks (user_id, prompt_id) values ('${ALICE_ID}', '${pBob}');
    insert into public.follows (follower_id, followed_id) values ('${ALICE_ID}', '${BOB_ID}');
    insert into public.comments (prompt_id, author_id, content) values ('${pBob}', '${ALICE_ID}', 'Alice comment');
    insert into public.comment_likes (user_id, comment_id) values ('${ALICE_ID}', '${cBob}');
  `);
  execAs('authenticated', userClaims(BOB_ID), `
    insert into public.follows (follower_id, followed_id) values ('${BOB_ID}', '${ALICE_ID}');
  `);

  // Verify pre-delete counters on Bob
  const beforeBob = queryJsonAs('anon', anonClaims, `
    select follower_count, following_count, total_likes_received from public.profiles where id = '${BOB_ID}'
  `)[0];
  assert.deepEqual(beforeBob, { follower_count: 1, following_count: 1, total_likes_received: 1 });

  // Delete Alice from auth.users
  runPsqlRaw(`delete from auth.users where id = '${ALICE_ID}';`);

  // Alice's profile & prompts gone; Coding category count unwound
  assert.equal(queryScalarAs('anon', anonClaims, `select count(*) from public.profiles where id = '${ALICE_ID}'`), 0);
  assert.equal(queryScalarAs('anon', anonClaims, `select count(*) from public.prompts where id = '${pAlice}'`), 0);
  assert.equal(queryScalarAs('anon', anonClaims, `select prompt_count from public.categories where id = '${CAT_CODING}'`), 0);

  // All of Alice's interactions on Bob's content unwound cleanly!
  const afterBob = queryJsonAs('anon', anonClaims, `
    select follower_count, following_count, total_likes_received from public.profiles where id = '${BOB_ID}'
  `)[0];
  assert.deepEqual(afterBob, { follower_count: 0, following_count: 0, total_likes_received: 0 });

  const afterPBob = queryJsonAs('anon', anonClaims, `
    select like_count, bookmark_count, comment_count, trend_score from public.prompts where id = '${pBob}'
  `)[0];
  assert.deepEqual(afterPBob, { like_count: 0, bookmark_count: 0, comment_count: 1, trend_score: 0 });
  assert.equal(queryScalarAs('anon', anonClaims, `select like_count from public.comments where id = '${cBob}'`), 0);
});

// =========================================================================
// Storage Buckets & Policies
// =========================================================================

test('storage: buckets configured (5MB avatars, 8MB thumbnails) and folder/extension RLS enforced', () => {
  seedUsers();
  const buckets = queryJsonAs('anon', anonClaims, `select id, public, file_size_limit from storage.buckets order by id`);
  assert.deepEqual(buckets, [
    { id: 'avatars', public: true, file_size_limit: 5242880 },
    { id: 'thumbnails', public: true, file_size_limit: 8388608 },
  ]);

  // Owner can insert/update/delete in own <uid>/ folder with valid image extension
  execAs('authenticated', userClaims(ALICE_ID), `
    insert into storage.objects (bucket_id, name, owner) values ('avatars', '${ALICE_ID}/pic.webp', '${ALICE_ID}');
    insert into storage.objects (bucket_id, name, owner) values ('thumbnails', '${ALICE_ID}/thumb.jpg', '${ALICE_ID}');
    update storage.objects set metadata = '{"v":1}' where name = '${ALICE_ID}/pic.webp';
  `);
  // Bad extension rejected
  assert.throws(
    () => execAs('authenticated', userClaims(ALICE_ID), `
      insert into storage.objects (bucket_id, name, owner) values ('avatars', '${ALICE_ID}/evil.svg', '${ALICE_ID}');
    `),
    (e) => e.code === '42501',
  );
  // Path traversal rejected on insert and update (plus bad extension on update)
  assert.throws(
    () => execAs('authenticated', userClaims(ALICE_ID), `
      insert into storage.objects (bucket_id, name, owner) values ('avatars', '${ALICE_ID}/../evil.png', '${ALICE_ID}');
    `),
    (e) => e.code === '42501',
  );
  assert.throws(
    () => execAs('authenticated', userClaims(ALICE_ID), `
      insert into storage.objects (bucket_id, name, owner) values ('thumbnails', '${ALICE_ID}/sub/../evil.png', '${ALICE_ID}');
    `),
    (e) => e.code === '42501',
  );
  assert.throws(
    () => execAs('authenticated', userClaims(ALICE_ID), `
      update storage.objects set name = '${ALICE_ID}/../evil.png' where name = '${ALICE_ID}/pic.webp';
    `),
    (e) => e.code === '42501',
  );
  assert.throws(
    () => execAs('authenticated', userClaims(ALICE_ID), `
      update storage.objects set name = '${ALICE_ID}/evil.svg' where name = '${ALICE_ID}/pic.webp';
    `),
    (e) => e.code === '42501',
  );
  // Missing folder or wrong uid folder rejected
  assert.throws(
    () => execAs('authenticated', userClaims(ALICE_ID), `
      insert into storage.objects (bucket_id, name, owner) values ('avatars', 'root.png', '${ALICE_ID}');
    `),
    (e) => e.code === '42501',
  );
  assert.throws(
    () => execAs('authenticated', userClaims(BOB_ID), `
      insert into storage.objects (bucket_id, name, owner) values ('thumbnails', '${ALICE_ID}/x.png', '${BOB_ID}');
    `),
    (e) => e.code === '42501',
  );
  // Stranger cannot delete Alice's object
  execAs('authenticated', userClaims(BOB_ID), `delete from storage.objects where name = '${ALICE_ID}/pic.webp';`);
  assert.equal(queryScalarAs('anon', anonClaims, `select count(*) from storage.objects where name = '${ALICE_ID}/pic.webp'`), 1);

  // Owner deletes
  execAs('authenticated', userClaims(ALICE_ID), `delete from storage.objects where name = '${ALICE_ID}/pic.webp';`);
  assert.equal(queryScalarAs('anon', anonClaims, `select count(*) from storage.objects where name = '${ALICE_ID}/pic.webp'`), 0);
});
