#!/usr/bin/env node
/**
 * PromptIndo — §5.6 Performance Gate
 *
 * Seeds >= 50,000 prompts, >= 500,000 likes, >= 50,000 comments, and >= 100,000 notifications
 * into `promptindo_test`, runs ANALYZE, and executes EXPLAIN (ANALYZE, BUFFERS) for all 10
 * hot-path queries under real RLS roles (`anon` / `authenticated`).
 *
 * Usage:
 *   node supabase/tests/perf_gate.mjs
 *   node supabase/tests/perf_gate.mjs --keep   (leave large dataset in promptindo_test)
 */

import { execFileSync } from 'node:child_process';
import assert from 'node:assert/strict';

const DB = process.env.PG_TEST_DB || 'promptindo_test';
const keepData = process.argv.includes('--keep');

function psql(sql) {
  return execFileSync(
    'sudo',
    ['-u', 'postgres', 'psql', '-d', DB, '-P', 'pager=off', '-v', 'ON_ERROR_STOP=1', '-At'],
    { input: sql, encoding: 'utf8', maxBuffer: 50 * 1024 * 1024 },
  );
}

console.log('1. Resetting promptindo_test with clean schema + seed...');
execFileSync('sudo', ['-u', 'postgres', 'psql', '-P', 'pager=off', '-v', 'ON_ERROR_STOP=1',
  '-c', `drop database if exists ${DB};`, '-c', `create database ${DB};`], { stdio: 'inherit' });

const fs = await import('node:fs');
const path = await import('node:path');
const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');

for (const rel of [
  'tests/stub_supabase.sql',
  'migrations/20261127000001_init.sql',
  'migrations/20261127000002_pg_cron.sql',
  'seed.sql',
]) {
  const sql = fs.readFileSync(path.join(root, rel), 'utf8');
  psql(sql);
}

console.log('2. Seeding 500 users, 50,000 prompts, 500,000 likes, 50,000 comments, 100,000 notifications...');
const t0 = performance.now();
psql(`
set session_replication_role = replica;

-- 500 users + profiles
insert into auth.users (id, email, raw_user_meta_data)
select
  ('00000000-0000-4000-9000-' || lpad(i::text, 12, '0'))::uuid,
  'perf_user_' || i || '@example.com',
  jsonb_build_object('name', 'Perf User ' || i)
from generate_series(1, 500) as s(i);

insert into public.profiles (id, name, username)
select
  ('00000000-0000-4000-9000-' || lpad(i::text, 12, '0'))::uuid,
  'Perf User ' || i,
  'perf_user_' || i
from generate_series(1, 500) as s(i);

-- 50,000 prompts across 8 categories & 500 creators
with cats as (
  select array_agg(id order by sort_order) as ids from public.categories
),
tag_pool as (
  select array[
    'ai','python','writing','marketing','coding','sql','react','flutter',
    'design','seo','business','education','productivity','fun','gpt','claude',
    'prompting','copywriting','story','automation'
  ] as t
)
insert into public.prompts (
  id, creator_id, creator_username, title, description, prompt_content,
  category_id, tags, ai_model, visibility, status,
  like_count, copy_count, view_count, comment_count, is_featured, trend_score,
  created_at, updated_at
)
select
  ('10000000-0000-4000-a000-' || lpad(i::text, 12, '0'))::uuid,
  ('00000000-0000-4000-9000-' || lpad((((i - 1) % 500) + 1)::text, 12, '0'))::uuid,
  'perf_user_' || (((i - 1) % 500) + 1),
  case
    when i % 200 = 0 then 'Assistant prompt #' || i || ' for engineering'
    when i % 50  = 0 then 'Code review helper #' || i
    else 'Creative prompt #' || i || ' for workflow optimization'
  end,
  'Benchmark description for prompt ' || i,
  'You are a helpful AI assistant for task #' || i,
  cats.ids[((i - 1) % array_length(cats.ids, 1)) + 1],
  array[
    tag_pool.t[((i - 1) % array_length(tag_pool.t, 1)) + 1],
    tag_pool.t[((i + 5) % array_length(tag_pool.t, 1)) + 1]
  ] || case when i % 3000 = 0 then array['raretag'] else '{}'::text[] end,
  case when i % 2 = 0 then 'gpt-4o' else 'claude-3.7' end,
  case when (i + 7) % 25 = 0 then 'private' when (i + 13) % 50 = 0 then 'unlisted' else 'public' end,
  case when (i + 19) % 50 = 0 then 'hidden' else 'active' end,
  (i % 40),
  (i % 20),
  (i % 200),
  (i % 10),
  (i % 20 = 0),
  (i % 300),
  now() - ((i % 720) || ' hours')::interval - ((i % 60) || ' seconds')::interval,
  now() - ((i % 720) || ' hours')::interval
from generate_series(1, 50000) as s(i), cats, tag_pool;

-- 500,000 likes (50,000 prompts * 10 distinct users each)
insert into public.likes (user_id, prompt_id, created_at)
select
  ('00000000-0000-4000-9000-' || lpad((((p + u * 7) % 500) + 1)::text, 12, '0'))::uuid,
  ('10000000-0000-4000-a000-' || lpad(p::text, 12, '0'))::uuid,
  now() - ((p % 500) || ' minutes')::interval
from generate_series(1, 50000) as p,
     generate_series(1, 10) as u;

-- 50,000 comments (100 comments on prompt #1, rest distributed)
insert into public.comments (prompt_id, author_id, author_username, content, status, created_at)
select
  case when i <= 100
    then '10000000-0000-4000-a000-000000000003'::uuid
    else ('10000000-0000-4000-a000-' || lpad((((i - 1) % 50000) + 1)::text, 12, '0'))::uuid
  end,
  ('00000000-0000-4000-9000-' || lpad((((i - 1) % 500) + 1)::text, 12, '0'))::uuid,
  'perf_user_' || (((i - 1) % 500) + 1),
  'Great prompt #' || i,
  'active',
  now() - ((i % 1000) || ' minutes')::interval
from generate_series(1, 50000) as s(i);

-- 100,000 notifications (200 for user #1, 10 unread)
insert into public.notifications (recipient_id, actor_id, actor_username, type, prompt_id, is_read, created_at)
select
  case when i <= 200
    then '00000000-0000-4000-9000-000000000001'::uuid
    else ('00000000-0000-4000-9000-' || lpad((((i - 1) % 500) + 1)::text, 12, '0'))::uuid
  end,
  ('00000000-0000-4000-9000-' || lpad((((i) % 500) + 1)::text, 12, '0'))::uuid,
  'perf_user_' || (((i) % 500) + 1),
  'like',
  '10000000-0000-4000-a000-000000000003'::uuid,
  case when i <= 10 then false else true end,
  now() - ((i % 2000) || ' minutes')::interval
from generate_series(1, 100000) as s(i);

set session_replication_role = DEFAULT;
`);
// Flush GIN pending lists and update visibility map + planner stats after bulk load
for (const tbl of ['profiles', 'categories', 'prompts', 'likes', 'comments', 'notifications']) {
  psql(`vacuum analyze public.${tbl};`);
}
console.log(`Seeded & vacuum-analyzed in ${((performance.now() - t0) / 1000).toFixed(2)}s`);

const counts = psql(`
  select (select count(*) from public.prompts) || ',' ||
         (select count(*) from public.likes) || ',' ||
         (select count(*) from public.comments) || ',' ||
         (select count(*) from public.notifications);
`).trim();
console.log('Row counts (prompts,likes,comments,notifications):', counts);

const USER1 = '00000000-0000-4000-9000-000000000001';
const PROMPT3 = '10000000-0000-4000-a000-000000000003';
const CAT1 = '11111111-1111-4111-8111-111111111101';

const queries = [
  {
    name: '1. Latest feed (anon, limit 12)',
    role: 'anon',
    jwt: '{}',
    sql: `select id, creator_id, creator_username, title, category_id, tags, like_count, created_at
          from public.prompts
          where status = 'active' and visibility = 'public'
          order by created_at desc, id desc
          limit 12`,
    expectIndex: /prompts_latest_idx/,
  },
  {
    name: '2. Trending feed (anon, limit 12)',
    role: 'anon',
    jwt: '{}',
    sql: `select id, creator_id, title, trend_score, created_at
          from public.prompts
          where status = 'active' and visibility = 'public'
          order by trend_score desc, created_at desc, id desc
          limit 12`,
    expectIndex: /prompts_trending_idx/,
  },
  {
    name: '3. By category (anon, limit 12)',
    role: 'anon',
    jwt: '{}',
    sql: `select id, title, category_id, created_at
          from public.prompts
          where status = 'active' and visibility = 'public' and category_id = '${CAT1}'::uuid
          order by created_at desc, id desc
          limit 12`,
    expectIndex: /prompts_category_idx/,
  },
  {
    name: '4a. By common tag via RLS (anon, limit 12)',
    role: 'anon',
    jwt: '{}',
    sql: `select id, title, tags, created_at
          from public.prompts
          where status = 'active' and visibility = 'public' and tags @> array['python']
          order by created_at desc, id desc
          limit 12`,
    expectIndex: /prompts_tags_idx|prompts_latest_idx/,
  },
  {
    name: '4b. By rare tag via prompts_by_tag RPC (anon, limit 12)',
    role: 'anon',
    jwt: '{}',
    sql: `select id, title, tags, created_at from public.prompts_by_tag('raretag', 12)`,
    expectIndex: null,
  },
  {
    name: '4c. By rare tag inner query plan (GIN index check)',
    role: 'postgres',
    jwt: '{}',
    prepare: `prepare tag_plan(text, int) as
      select id, title, tags, created_at
      from public.prompts
      where status = 'active' and visibility = 'public' and tags @> array[$1]
      order by created_at desc, id desc
      limit $2`,
    sql: `execute tag_plan('raretag', 12)`,
    expectIndex: /prompts_tags_idx/,
  },
  {
    name: '5. By creator (anon, limit 12)',
    role: 'anon',
    jwt: '{}',
    sql: `select id, title, creator_id, created_at
          from public.prompts
          where creator_id = '${USER1}'::uuid and status = 'active' and visibility = 'public'
          order by created_at desc, id desc
          limit 12`,
    expectIndex: /prompts_creator_idx/,
  },
  {
    name: '6. Featured feed (anon, limit 12)',
    role: 'anon',
    jwt: '{}',
    sql: `select id, title, is_featured, created_at
          from public.prompts
          where is_featured and status = 'active' and visibility = 'public'
          order by created_at desc, id desc
          limit 12`,
    expectIndex: /prompts_featured_idx/,
  },
  {
    name: '7a. search_prompts("assistant", 12) RPC (anon)',
    role: 'anon',
    jwt: '{}',
    sql: `select id, title, tags, created_at from public.search_prompts('assistant', 12)`,
    expectIndex: null,
  },
  {
    name: '7b. search_prompts inner query plan (GIN trgm + tags)',
    role: 'postgres',
    jwt: '{}',
    prepare: `prepare sp_plan(text, text, int) as
      select p.id, p.title, p.tags, p.created_at
      from public.prompts p
      where p.status = 'active'
        and p.visibility = 'public'
        and (p.title ilike '%' || $1 || '%' or p.tags @> array[lower($2)])
      order by (p.title ilike $1 || '%') desc, p.created_at desc
      limit $3`,
    sql: `execute sp_plan('assistant', 'assistant', 12)`,
    expectIndex: /prompts_title_trgm_idx|prompts_tags_idx/,
  },
  {
    name: '8. Comments of a prompt (anon, limit 20)',
    role: 'anon',
    jwt: '{}',
    sql: `select id, author_id, author_username, content, like_count, created_at
          from public.comments
          where prompt_id = '${PROMPT3}'::uuid and status = 'active'
          order by created_at asc
          limit 20`,
    expectIndex: /comments_prompt_idx/,
  },
  {
    name: '9. Notifications of a user (authenticated, limit 20)',
    role: 'authenticated',
    jwt: JSON.stringify({ sub: USER1, role: 'authenticated' }),
    sql: `select id, actor_id, type, prompt_id, is_read, created_at
          from public.notifications
          where recipient_id = '${USER1}'::uuid
          order by created_at desc
          limit 20`,
    expectIndex: /notifications_recipient_idx/,
  },
  {
    name: '10. Unread notifications count (authenticated)',
    role: 'authenticated',
    jwt: JSON.stringify({ sub: USER1, role: 'authenticated' }),
    sql: `select count(*)
          from public.notifications
          where recipient_id = '${USER1}'::uuid and not is_read`,
    expectIndex: /notifications_unread_idx/,
  },
];

console.log('\n3. Running EXPLAIN (ANALYZE, BUFFERS) across all queries...');
const results = [];
for (const q of queries) {
  const prep = q.prepare ? `${q.prepare};` : '';
  const planOut = psql(`
    begin;
    ${prep}
    set local request.jwt.claims = '${q.jwt}';
    set local role ${q.role};
    explain (analyze, buffers) ${q.sql};
    rollback;
  `);
  const execMatch = planOut.match(/Execution Time:\s*([0-9.]+)\s*ms/);
  const planMatch = planOut.match(/Planning Time:\s*([0-9.]+)\s*ms/);
  const execMs = execMatch ? parseFloat(execMatch[1]) : NaN;
  const planMs = planMatch ? parseFloat(planMatch[1]) : NaN;
  const hasSeqScan = /Seq Scan on (prompts|comments|notifications)/.test(planOut);
  const indexOk = q.expectIndex ? q.expectIndex.test(planOut) : true;

  results.push({ name: q.name, execMs, planMs, hasSeqScan, indexOk, planOut });
  console.log(`\n--- ${q.name} ---`);
  console.log(`Planning: ${planMs} ms | Execution: ${execMs} ms | SeqScan: ${hasSeqScan} | ExpectedIdx: ${indexOk}`);
  console.log(planOut.trim());

  assert.ok(!Number.isNaN(execMs), `Missing execution time for ${q.name}`);
  assert.ok(execMs < 20, `${q.name} exceeded 20 ms budget: ${execMs} ms`);
  assert.ok(!hasSeqScan, `${q.name} unexpectedly used Seq Scan`);
  assert.ok(indexOk, `${q.name} did not use expected index ${q.expectIndex}`);
}

console.log('\n=== PERFORMANCE GATE SUMMARY ===');
for (const r of results) {
  console.log(`${r.name.padEnd(55)} ${r.execMs.toFixed(3)} ms (plan ${r.planMs.toFixed(3)} ms) [OK]`);
}

if (!keepData) {
  console.log('\n4. Resetting promptindo_test to clean seeded state...');
  execFileSync('sudo', ['-u', 'postgres', 'psql', '-P', 'pager=off', '-v', 'ON_ERROR_STOP=1',
    '-c', `drop database if exists ${DB};`, '-c', `create database ${DB};`]);
  for (const rel of [
    'tests/stub_supabase.sql',
    'migrations/20261127000001_init.sql',
    'migrations/20261127000002_pg_cron.sql',
    'seed.sql',
  ]) {
    psql(fs.readFileSync(path.join(root, rel), 'utf8'));
  }
}
