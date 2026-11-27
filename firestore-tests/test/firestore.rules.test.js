/**
 * PromptIndo — Firestore security-rules unit tests (Emulator Suite).
 *
 * Run from the repo root:
 *   cd firestore-tests && npm install
 *   cd .. && ./firestore-tests/node_modules/.bin/firebase emulators:exec \
 *     --only firestore,auth --project prompindo-test \
 *     "node --test firestore-tests/test/"
 *
 * Every rule in ../firestore.rules that guards a client-reachable path has at
 * least one allow case and one deny case here.
 */
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { test, before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';

import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  doc,
  setDoc,
  getDoc,
  getDocs,
  updateDoc,
  deleteDoc,
  collection,
  query,
  where,
  limit,
} from 'firebase/firestore';

const __dirname = dirname(fileURLToPath(import.meta.url));
const PROJECT = 'prompindo-test';

let env;

/** Contexts used across tests. */
const anon = () => env.unauthenticatedContext();
const alice = () => env.authenticatedContext('alice');
const bob = () => env.authenticatedContext('bob');
const admin = () => env.authenticatedContext('root', { role: 'admin' });

/** Minimal valid documents matching the shapes the app writes. */
const userDoc = (uid, username) => ({
  uid,
  username,
  username_lower: username.toLowerCase(),
  name: username,
  bio: '',
  avatar_url: '',
  role: 'user',
  status: 'active',
  follower_count: 0,
  following_count: 0,
  prompt_count: 0,
  total_likes_received: 0,
  created_at: '2026-01-01T00:00:00Z',
});

const promptDoc = (id, creatorId, overrides = {}) => ({
  id,
  creator_id: creatorId,
  creator_username: 'alice',
  creator_avatar: '',
  title: 'A prompt',
  description: 'desc',
  prompt_content: 'You are a helpful assistant.',
  tags: ['ai'],
  category_id: 'writing',
  ai_model: 'gpt',
  thumbnail_url: '',
  visibility: 'public',
  status: 'active',
  like_count: 0,
  copy_count: 0,
  view_count: 0,
  comment_count: 0,
  bookmark_count: 0,
  is_featured: false,
  trend_score: 0,
  remixed_from_id: null,
  created_at: '2026-01-01T00:00:00Z',
  updated_at: '2026-01-01T00:00:00Z',
  ...overrides,
});

const commentDoc = (id, promptId, authorId, overrides = {}) => ({
  id,
  prompt_id: promptId,
  parent_id: null,
  author_id: authorId,
  author_username: 'alice',
  author_avatar: '',
  content: 'nice prompt',
  like_count: 0,
  status: 'active',
  created_at: '2026-01-01T00:00:00Z',
  ...overrides,
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT,
    firestore: {
      rules: readFileSync(join(__dirname, '..', '..', 'firestore.rules'), 'utf8'),
    },
  });
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
});

// ------------------------------------------------------------------ users

test('users: anyone can read a public profile', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users/alice'), userDoc('alice', 'alice_1'));
  });
  await assertSucceeds(getDoc(doc(anon().firestore(), 'users/alice')));
});

test('users: a client may create ONLY its own locked-down profile doc', async () => {
  const base = () => ({
    uid: 'alice', name: 'Alice', username: 'alice_1', username_lower: 'alice_1',
    avatar_url: '', bio: '', role: 'user', status: 'active',
    follower_count: 0, following_count: 0, prompt_count: 0,
    total_likes_received: 0, created_at: new Date(), updated_at: new Date(),
  });
  await assertSucceeds(setDoc(doc(alice().firestore(), 'users/alice'), base()));
});

test('users: client cannot self-create as admin / banned / with counters / for someone else', async () => {
  const mk = (over) => ({
    uid: 'alice', name: 'Alice', username: 'alice_1', username_lower: 'alice_1',
    avatar_url: '', bio: '', role: 'user', status: 'active',
    follower_count: 0, following_count: 0, prompt_count: 0,
    total_likes_received: 0, created_at: new Date(), updated_at: new Date(), ...over,
  });
  await assertFails(setDoc(doc(alice().firestore(), 'users/alice'), mk({ role: 'admin' })));
  await assertFails(setDoc(doc(alice().firestore(), 'users/alice'), mk({ follower_count: 999 })));
  await assertFails(setDoc(doc(alice().firestore(), 'users/alice'), mk({ extra_field: true })));
  await assertFails(setDoc(doc(bob().firestore(), 'users/alice'), mk({})));
});

test('users: owner may update bio/name/avatar but not role/status/counters', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users/alice'), userDoc('alice', 'alice_1'));
  });

  await assertSucceeds(updateDoc(doc(alice().firestore(), 'users/alice'), { bio: 'hi' }));
  await assertFails(updateDoc(doc(alice().firestore(), 'users/alice'), { role: 'admin' }));
  await assertFails(updateDoc(doc(alice().firestore(), 'users/alice'), { status: 'banned' }));
  await assertFails(updateDoc(doc(alice().firestore(), 'users/alice'), { follower_count: 999 }));
  await assertFails(updateDoc(doc(alice().firestore(), 'users/alice'), { email: 'x@y.z' }));
});

test('users: strangers cannot update someone else profile', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users/alice'), userDoc('alice', 'alice_1'));
  });
  await assertFails(updateDoc(doc(bob().firestore(), 'users/alice'), { bio: 'pwned' }));
});

test('users_private: only the owner (or admin) can read/write email', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users_private/alice'), { email: 'a@example.com' });
  });

  await assertSucceeds(getDoc(doc(alice().firestore(), 'users_private/alice')));
  await assertSucceeds(updateDoc(doc(alice().firestore(), 'users_private/alice'), { email: 'b@example.com' }));
  await assertFails(getDoc(doc(bob().firestore(), 'users_private/alice')));
  await assertSucceeds(getDoc(doc(admin().firestore(), 'users_private/alice')));
});

test('fcm_tokens: only the owning device account manages its tokens', async () => {
  const tok = { token: 'fcm-1', created_at: '2026-01-01T00:00:00Z' };
  await assertSucceeds(setDoc(doc(alice().firestore(), 'users/alice/fcm_tokens/t1'), tok));
  await assertFails(setDoc(doc(bob().firestore(), 'users/alice/fcm_tokens/t2'), tok));
  await assertSucceeds(deleteDoc(doc(alice().firestore(), 'users/alice/fcm_tokens/t1')));
  await assertFails(deleteDoc(doc(bob().firestore(), 'users/alice/fcm_tokens/t1')));
});

// ---------------------------------------------------------------- prompts

test('prompts: public active prompt is world-readable', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'prompts/p1'), promptDoc('p1', 'alice'));
  });
  await assertSucceeds(getDoc(doc(anon().firestore(), 'prompts/p1')));
});

test('prompts: unlisted/private prompt readable by owner, denied to strangers', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'prompts/pv'), promptDoc('pv', 'alice', { visibility: 'private' }));
    await setDoc(doc(ctx.firestore(), 'prompts/pu'), promptDoc('pu', 'alice', { visibility: 'unlisted' }));
  });
  await assertSucceeds(getDoc(doc(alice().firestore(), 'prompts/pv')));
  await assertFails(getDoc(doc(anon().firestore(), 'prompts/pv')));
  // Unlisted is link-only — still denied to anonymous clients by rules.
  await assertFails(getDoc(doc(anon().firestore(), 'prompts/pu')));
  await assertSucceeds(getDoc(doc(alice().firestore(), 'prompts/pu')));
});

test('prompts: suspended prompt disappears for everyone but admins', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'prompts/ps'), promptDoc('ps', 'alice', { status: 'suspended' }));
  });
  await assertFails(getDoc(doc(anon().firestore(), 'prompts/ps')));
  await assertFails(getDoc(doc(alice().firestore(), 'prompts/ps')));
  await assertSucceeds(getDoc(doc(admin().firestore(), 'prompts/ps')));
});

test('prompts: create requires own creator_id, zeroed counters and sane sizes', async () => {
  const db = alice().firestore();

  // The rules look up users/alice to verify the denormalised
  // creator_username — seed the profile the way onUserCreate would.
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users/alice'), userDoc('alice', 'alice'));
  });

  await assertSucceeds(setDoc(doc(db, 'prompts/p2'), promptDoc('p2', 'alice')));
  await env.withSecurityRulesDisabled((ctx) => deleteDoc(doc(ctx.firestore(), 'prompts/p2')));

  // Forged creator
  await assertFails(setDoc(doc(db, 'prompts/p3'), promptDoc('p3', 'bob')));
  // Inflated counter
  await assertFails(setDoc(doc(db, 'prompts/p4'), promptDoc('p4', 'alice', { like_count: 50 })));
  // Non-zero trend/featured
  await assertFails(setDoc(doc(db, 'prompts/p5'), promptDoc('p5', 'alice', { trend_score: 100 })));
  // Missing content
  await assertFails(setDoc(doc(db, 'prompts/p6'), promptDoc('p6', 'alice', { prompt_content: '' })));
  // Too many tags
  await assertFails(setDoc(doc(db, 'prompts/p7'), promptDoc('p7', 'alice', { tags: ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm'] })));
  // Denormalised username mismatch
  await assertFails(setDoc(doc(db, 'prompts/p8'), promptDoc('p8', 'alice', { creator_username: 'someone_else' })));
  // Anonymous
  await assertFails(setDoc(doc(anon().firestore(), 'prompts/p9'), promptDoc('p9', 'alice')));
});

test('prompts: owner can edit content but never counters/creator/status', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'prompts/p1'), promptDoc('p1', 'alice'));
  });

  await assertSucceeds(updateDoc(doc(alice().firestore(), 'prompts/p1'), { title: 'New title' }));
  await assertFails(updateDoc(doc(alice().firestore(), 'prompts/p1'), { like_count: 999 }));
  await assertFails(updateDoc(doc(alice().firestore(), 'prompts/p1'), { creator_id: 'bob' }));
  await assertFails(updateDoc(doc(alice().firestore(), 'prompts/p1'), { status: 'suspended' }));
  await assertFails(updateDoc(doc(alice().firestore(), 'prompts/p1'), { trend_score: 42 }));
  await assertFails(updateDoc(doc(bob().firestore(), 'prompts/p1'), { title: 'hacked' }));
});

test('prompts: only the owner (or admin) can delete', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'prompts/p1'), promptDoc('p1', 'alice'));
  });
  await assertFails(deleteDoc(doc(bob().firestore(), 'prompts/p1')));
  await assertSucceeds(deleteDoc(doc(alice().firestore(), 'prompts/p1')));
});

test('prompts: feed queries only return world-readable prompts', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'prompts/pub'), promptDoc('pub', 'alice'));
    await setDoc(doc(ctx.firestore(), 'prompts/priv'), promptDoc('priv', 'bob', { visibility: 'private' }));
    await setDoc(doc(ctx.firestore(), 'prompts/susp'), promptDoc('susp', 'bob', { status: 'suspended' }));
  });

  const q = query(
    collection(anon().firestore(), 'prompts'),
    where('status', '==', 'active'),
    where('visibility', '==', 'public'),
    limit(10),
  );
  const snap = await assertSucceeds(getDocs(q));
  assert.equal(snap.docs.length, 1);
  assert.equal(snap.docs[0].id, 'pub');
});

// ------------------------------------------------------------------ likes

test('likes: composite doc id must be {uid}_{promptId} and match user_id', async () => {
  await assertSucceeds(setDoc(doc(alice().firestore(), 'likes/alice_p1'), {
    user_id: 'alice', prompt_id: 'p1', created_at: '2026-01-01T00:00:00Z',
  }));
  await env.withSecurityRulesDisabled((ctx) => deleteDoc(doc(ctx.firestore(), 'likes/alice_p1')));

  // Forged id (somebody else's like)
  await assertFails(setDoc(doc(alice().firestore(), 'likes/bob_p1'), {
    user_id: 'alice', prompt_id: 'p1', created_at: '2026-01-01T00:00:00Z',
  }));
  // user_id mismatch with the id prefix
  await assertFails(setDoc(doc(alice().firestore(), 'likes/alice_p2'), {
    user_id: 'bob', prompt_id: 'p2', created_at: '2026-01-01T00:00:00Z',
  }));
  // Extra fields are rejected (keys().hasOnly)
  await assertFails(setDoc(doc(alice().firestore(), 'likes/alice_p3'), {
    user_id: 'alice', prompt_id: 'p3', created_at: '2026-01-01T00:00:00Z', forged: true,
  }));
});

test('likes: never updatable; only owner can delete; owner list readable', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'likes/alice_p1'), {
      user_id: 'alice', prompt_id: 'p1', created_at: '2026-01-01T00:00:00Z',
    });
  });

  await assertFails(updateDoc(doc(alice().firestore(), 'likes/alice_p1'), { prompt_id: 'p2' }));
  await assertFails(deleteDoc(doc(bob().firestore(), 'likes/alice_p1')));
  await assertSucceeds(deleteDoc(doc(alice().firestore(), 'likes/alice_p1')));
});

// -------------------------------------------------------------- bookmarks

test('bookmarks: same composite-id discipline as likes', async () => {
  await assertSucceeds(setDoc(doc(alice().firestore(), 'bookmarks/alice_p1'), {
    user_id: 'alice', prompt_id: 'p1', created_at: '2026-01-01T00:00:00Z',
  }));
  await env.withSecurityRulesDisabled((ctx) => deleteDoc(doc(ctx.firestore(), 'bookmarks/alice_p1')));

  await assertFails(setDoc(doc(alice().firestore(), 'bookmarks/bob_p1'), {
    user_id: 'alice', prompt_id: 'p1', created_at: '2026-01-01T00:00:00Z',
  }));
  await assertFails(updateDoc(doc(alice().firestore(), 'bookmarks/alice_p1'), { user_id: 'bob' }));
});

// ---------------------------------------------------------------- follows

test('follows: valid follow works, self-follow and forged ids do not', async () => {
  await assertSucceeds(setDoc(doc(alice().firestore(), 'follows/alice_bob'), {
    follower_id: 'alice', followed_id: 'bob', created_at: '2026-01-01T00:00:00Z',
  }));
  await env.withSecurityRulesDisabled((ctx) => deleteDoc(doc(ctx.firestore(), 'follows/alice_bob')));

  await assertFails(setDoc(doc(alice().firestore(), 'follows/alice_alice'), {
    follower_id: 'alice', followed_id: 'alice', created_at: '2026-01-01T00:00:00Z',
  }));
  await assertFails(setDoc(doc(alice().firestore(), 'follows/bob_carol'), {
    follower_id: 'alice', followed_id: 'bob', created_at: '2026-01-01T00:00:00Z',
  }));
});

// -------------------------------------------------------------- comments

test('comments: author creates with matching denormalised username', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users/alice'), userDoc('alice', 'alice_1'));
    await setDoc(doc(ctx.firestore(), 'prompts/p1'), promptDoc('p1', 'alice'));
  });

  const ok = commentDoc('c1', 'p1', 'alice', { author_username: 'alice_1' });
  await assertSucceeds(setDoc(doc(alice().firestore(), 'comments/c1'), ok));
  await env.withSecurityRulesDisabled((ctx) => deleteDoc(doc(ctx.firestore(), 'comments/c1')));

  // Forged author + mismatched username + empty content all denied.
  await assertFails(setDoc(doc(alice().firestore(), 'comments/c2'), commentDoc('c2', 'p1', 'bob')));
  await assertFails(setDoc(doc(alice().firestore(), 'comments/c3'), commentDoc('c3', 'p1', 'alice', { author_username: 'not_me' })));
  await assertFails(setDoc(doc(alice().firestore(), 'comments/c4'), commentDoc('c4', 'p1', 'alice', { author_username: 'alice_1', content: '' })));
});

test('comments: moderated comments are unreadable by clients', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'comments/hidden'), commentDoc('hidden', 'p1', 'alice', { status: 'removed' }));
  });
  await assertFails(getDoc(doc(anon().firestore(), 'comments/hidden')));
  await assertFails(getDoc(doc(alice().firestore(), 'comments/hidden')));
});

test('comments: delete allowed for author OR prompt owner (get-on-parent), denied otherwise', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    // Prompt owned by alice, comment written by bob.
    await setDoc(doc(ctx.firestore(), 'prompts/p1'), promptDoc('p1', 'alice'));
    await setDoc(doc(ctx.firestore(), 'comments/bobs_says'), commentDoc('bobs_says', 'p1', 'bob', { author_username: 'bob' }));
    // Second prompt owned by bob, comment by alice.
    await setDoc(doc(ctx.firestore(), 'prompts/p2'), promptDoc('p2', 'bob', { creator_username: 'bob' }));
    await setDoc(doc(ctx.firestore(), 'comments/alices_says'), commentDoc('alices_says', 'p2', 'alice'));
  });

  // The prompt owner may moderate comments under their own prompt.
  await assertSucceeds(deleteDoc(doc(alice().firestore(), 'comments/bobs_says')));
  // The comment author may delete their own comment.
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'comments/bobs_says'), commentDoc('bobs_says', 'p1', 'bob', { author_username: 'bob' }));
  });
  await assertSucceeds(deleteDoc(doc(bob().firestore(), 'comments/bobs_says')));
  // A stranger (neither the author nor the prompt owner) may not.
  // (bob owns p2, so a third account is needed for a true stranger.)
  const carol = () => env.authenticatedContext('carol');
  await assertFails(deleteDoc(doc(carol().firestore(), 'comments/alices_says')));
});

test('comments: author can edit content but not counters/parent/status', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'comments/c1'), commentDoc('c1', 'p1', 'alice'));
  });

  await assertSucceeds(updateDoc(doc(alice().firestore(), 'comments/c1'), { content: 'edited' }));
  await assertFails(updateDoc(doc(alice().firestore(), 'comments/c1'), { like_count: 50 }));
  await assertFails(updateDoc(doc(alice().firestore(), 'comments/c1'), { status: 'removed' }));
  await assertFails(updateDoc(doc(alice().firestore(), 'comments/c1'), { prompt_id: 'p2' }));
});

// --------------------------------------------------------- comment_likes

test('comment_likes: composite id discipline mirrors likes', async () => {
  await assertSucceeds(setDoc(doc(alice().firestore(), 'comment_likes/alice_c1'), {
    user_id: 'alice', comment_id: 'c1', created_at: '2026-01-01T00:00:00Z',
  }));
  await env.withSecurityRulesDisabled((ctx) => deleteDoc(doc(ctx.firestore(), 'comment_likes/alice_c1')));

  await assertFails(setDoc(doc(alice().firestore(), 'comment_likes/bob_c1'), {
    user_id: 'alice', comment_id: 'c1', created_at: '2026-01-01T00:00:00Z',
  }));
  await assertFails(updateDoc(doc(alice().firestore(), 'comment_likes/alice_c1'), { comment_id: 'c2' }));
});

// --------------------------------------------------------- notifications

test('notifications: nobody but Cloud Functions creates them (client create denied)', async () => {
  const n = {
    recipient_id: 'alice', type: 'like', actor_id: 'bob', actor_username: 'bob',
    prompt_id: 'p1', is_read: false, created_at: '2026-01-01T00:00:00Z',
  };
  await assertFails(setDoc(doc(alice().firestore(), 'notifications/n1'), n));
  await assertFails(setDoc(doc(admin().firestore(), 'notifications/n1'), n));
});

test('notifications: recipient reads own list and flips is_read only', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'notifications/n1'), {
      recipient_id: 'alice', type: 'like', actor_id: 'bob', actor_username: 'bob',
      prompt_id: 'p1', is_read: false, created_at: '2026-01-01T00:00:00Z',
    });
  });

  await assertSucceeds(getDoc(doc(alice().firestore(), 'notifications/n1')));
  await assertFails(getDoc(doc(bob().firestore(), 'notifications/n1')));
  await assertSucceeds(updateDoc(doc(alice().firestore(), 'notifications/n1'), { is_read: true }));
  await assertFails(updateDoc(doc(alice().firestore(), 'notifications/n1'), { is_read: true, type: 'deleted' }));
  await assertFails(updateDoc(doc(bob().firestore(), 'notifications/n1'), { is_read: true }));

  const inbox = query(
    collection(alice().firestore(), 'notifications'),
    where('recipient_id', '==', 'alice'),
    limit(5),
  );
  await assertSucceeds(getDocs(inbox));
  const strangerInbox = query(
    collection(bob().firestore(), 'notifications'),
    where('recipient_id', '==', 'alice'),
    limit(5),
  );
  await assertFails(getDocs(strangerInbox));
});

// ------------------------------------------------------------ categories

test('categories: world-readable, writes admin-claim only', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'categories/writing'), {
      id: 'writing', name: 'Writing', icon: '✍️', sort_order: 1,
      created_at: '2026-01-01T00:00:00Z',
    });
  });

  await assertSucceeds(getDoc(doc(anon().firestore(), 'categories/writing')));
  await assertFails(updateDoc(doc(alice().firestore(), 'categories/writing'), { name: 'Hacked' }));
  await assertSucceeds(updateDoc(doc(admin().firestore(), 'categories/writing'), { name: 'Writing' }));
  await assertFails(setDoc(doc(alice().firestore(), 'categories/new'), {
    id: 'new', name: 'New', icon: '✨', sort_order: 9,
  }));
  await assertSucceeds(setDoc(doc(admin().firestore(), 'categories/new'), {
    id: 'new', name: 'New', icon: '✨', sort_order: 9,
  }));
});

// -------------------------------------------------------------- reports

test('reports: signed-in users can create with their own reporter_id', async () => {
  const report = (reporter) => ({
    reporter_id: reporter,
    target_type: 'prompt',
    target_id: 'p1',
    reason: 'Spam or misleading',
    details: '',
    status: 'pending',
    created_at: '2026-01-01T00:00:00Z',
  });

  await assertSucceeds(setDoc(doc(alice().firestore(), 'reports/r1'), report('alice')));
  await env.withSecurityRulesDisabled((ctx) => deleteDoc(doc(ctx.firestore(), 'reports/r1')));

  await assertFails(setDoc(doc(alice().firestore(), 'reports/r2'), report('bob')));
  await assertFails(setDoc(doc(anon().firestore(), 'reports/r3'), report('alice')));
  await assertFails(setDoc(doc(alice().firestore(), 'reports/r4'), { ...report('alice'), status: 'resolved' }));
});

test('reports: admin-claim reads/writes; plain users get nothing', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'reports/r1'), {
      reporter_id: 'alice', target_type: 'prompt', target_id: 'p1',
      reason: 'Spam', details: '', status: 'pending',
      created_at: '2026-01-01T00:00:00Z',
    });
  });

  await assertFails(getDoc(doc(alice().firestore(), 'reports/r1')));
  await assertSucceeds(getDoc(doc(admin().firestore(), 'reports/r1')));
  await assertSucceeds(updateDoc(doc(admin().firestore(), 'reports/r1'), { status: 'resolved' }));
  await assertFails(updateDoc(doc(alice().firestore(), 'reports/r1'), { status: 'resolved' }));
});

// --------------------------------------------------------- admin_actions

test('admin_actions: admin-claim read, client write always denied', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'admin_actions/a1'), {
      actor_id: 'root', action: 'ban_user', target_id: 'bob',
      created_at: '2026-01-01T00:00:00Z',
    });
  });

  await assertFails(getDoc(doc(alice().firestore(), 'admin_actions/a1')));
  await assertSucceeds(getDoc(doc(admin().firestore(), 'admin_actions/a1')));
  // Even an admin-tokened *client* cannot write the audit log — only the
  // Admin SDK inside the audited callables may.
  await assertFails(setDoc(doc(admin().firestore(), 'admin_actions/a2'), {
    actor_id: 'root', action: 'forged', target_id: 'bob',
    created_at: '2026-01-01T00:00:00Z',
  }));
  await assertFails(updateDoc(doc(admin().firestore(), 'admin_actions/a1'), { action: 'tampered' }));
});

// ----------------------------------------------------------------- views

test('views: deny-by-default for every client (Cloud Function only)', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'views/alice_p1'), { prompt_id: 'p1', expires_at: 0 });
  });

  await assertFails(getDoc(doc(alice().firestore(), 'views/alice_p1')));
  await assertFails(setDoc(doc(alice().firestore(), 'views/alice_p2'), { prompt_id: 'p2', expires_at: 0 }));
  await assertFails(setDoc(doc(admin().firestore(), 'views/alice_p3'), { prompt_id: 'p3', expires_at: 0 }));
  await assertFails(deleteDoc(doc(alice().firestore(), 'views/alice_p1')));
});

// ------------------------------------------------------ unknown paths

test('unknown collections fall through to the deny-all catch-all', async () => {
  await assertFails(setDoc(doc(alice().firestore(), 'secret_things/x'), { a: 1 }));
  await assertFails(getDoc(doc(anon().firestore(), 'secret_things/x')));
  await assertFails(setDoc(doc(alice().firestore(), 'users/alice/forged/nested'), { a: 1 }));
});
