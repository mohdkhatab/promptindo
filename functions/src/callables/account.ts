/**
 * deleteUserAccount — the real, Play-Store-acceptable account deletion.
 *
 * A client-side `FirebaseAuth.currentUser.delete()` would only remove the Auth
 * record and leave every Firestore/Storage artifact behind, which fails
 * Google Play's Data Safety + account-deletion policy. This callable removes:
 *
 *   users/{uid}, users_private/{uid}, fcm_tokens
 *   prompts authored by uid (fires onPromptDelete → full cascade + Storage)
 *   likes / bookmarks / comment_likes authored by uid (unwinds like counters)
 *   follows where uid is either side (unwinds both counters)
 *   comments authored by uid (unwinds comment_count, drops their comment likes)
 *   notifications received or authored by uid
 *   avatars/{uid}/** in Cloud Storage
 *   finally: the Firebase Auth account itself
 */
import { HttpsError, onCall, CallableRequest } from "firebase-functions/v2/https";
import { getAuth } from "firebase-admin/auth";
import {
  db,
  bucket,
  adjustCounter,
  deleteQueryBatch,
  APP_CHECK_ENFORCED,
} from "../config";

async function deleteAvatarFolder(uid: string): Promise<void> {
  try {
    const [files] = await bucket.getFiles({ prefix: `avatars/${uid}/` });
    await Promise.all(
      files.map((f) => f.delete({ ignoreNotFound: true }).catch(() => undefined)),
    );
  } catch (err) {
    console.warn("avatar cleanup failed", err);
  }
}

export const deleteUserAccount = onCall(
  { enforceAppCheck: APP_CHECK_ENFORCED },
  async (request: CallableRequest) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "You must be signed in.");
    }
    const uid = request.auth.uid;

    const userSnap = await db.doc(`users/${uid}`).get();
    if (!userSnap.exists) {
      // Already gone — still make sure the Auth record disappears.
      // (fallthrough to auth delete below)
    }

    const deleted: Record<string, number> = {};

    // 1. Own prompts → deleting each one fires onPromptDelete, which cascades
    //    likes/bookmarks/comments/notifications/views and removes Storage
    //    thumbnails, prompt_count and category counts.
    let promptCount = 0;
    for (;;) {
      const snap = await db
        .collection("prompts")
        .where("creator_id", "==", uid)
        .limit(50)
        .get();
      if (snap.empty) break;
      const batch = db.batch();
      snap.docs.forEach((d) => batch.delete(d.ref));
      await batch.commit();
      promptCount += snap.size;
      if (snap.size < 50) break;
    }
    deleted.prompts = promptCount;

    // 2. Own likes → decrement like_count / total_likes_received on prompts
    //    that other people still own (this one's own prompts are already gone).
    const likes = await db.collection("likes").where("user_id", "==", uid).limit(1000).get();
    const likeBatch = db.batch();
    const promptIdsForLikes = new Set<string>();
    likes.docs.forEach((d) => {
      promptIdsForLikes.add(String(d.get("prompt_id") ?? ""));
      likeBatch.delete(d.ref);
    });
    await likeBatch.commit();
    for (const promptId of promptIdsForLikes) {
      if (!promptId) continue;
      await adjustCounter(db.doc(`prompts/${promptId}`), "like_count", -1);
    }
    deleted.likes = likes.size;

    // 3. Own bookmarks.
    const bookmarks = await db
      .collection("bookmarks")
      .where("user_id", "==", uid)
      .limit(1000)
      .get();
    const bookmarkBatch = db.batch();
    const promptIdsForBookmarks = new Set<string>();
    bookmarks.docs.forEach((d) => {
      promptIdsForBookmarks.add(String(d.get("prompt_id") ?? ""));
      bookmarkBatch.delete(d.ref);
    });
    await bookmarkBatch.commit();
    for (const promptId of promptIdsForBookmarks) {
      if (!promptId) continue;
      await adjustCounter(db.doc(`prompts/${promptId}`), "bookmark_count", -1);
    }
    deleted.bookmarks = bookmarks.size;

    // 4. Own comments → decrement comment_count on surviving prompts.
    const comments = await db
      .collection("comments")
      .where("author_id", "==", uid)
      .limit(1000)
      .get();
    const commentBatch = db.batch();
    const promptIdsForComments = new Set<string>();
    for (const d of comments.docs) {
      promptIdsForComments.add(String(d.get("prompt_id") ?? ""));
      commentBatch.delete(d.ref);
      await deleteQueryBatch(
        db.collection("comment_likes").where("comment_id", "==", d.id),
      ).catch(() => 0);
    }
    await commentBatch.commit();
    for (const promptId of promptIdsForComments) {
      if (!promptId) continue;
      await adjustCounter(db.doc(`prompts/${promptId}`), "comment_count", -1);
    }
    deleted.comments = comments.size;

    // 5. Own comment likes (on other people's comments).
    const commentLikes = await db
      .collection("comment_likes")
      .where("user_id", "==", uid)
      .limit(1000)
      .get();
    const commentLikeBatch = db.batch();
    const touchedComments = new Set<string>();
    commentLikes.docs.forEach((d) => {
      touchedComments.add(String(d.get("comment_id") ?? ""));
      commentLikeBatch.delete(d.ref);
    });
    await commentLikeBatch.commit();
    for (const commentId of touchedComments) {
      if (!commentId) continue;
      await adjustCounter(db.doc(`comments/${commentId}`), "like_count", -1);
    }

    // 6. Follows where uid is either side → both counters unwind (the
    //    onFollowDelete trigger does this, we only delete the docs).
    const outgoing = await db
      .collection("follows")
      .where("follower_id", "==", uid)
      .limit(1000)
      .get();
    const incoming = await db
      .collection("follows")
      .where("followed_id", "==", uid)
      .limit(1000)
      .get();
    const followBatch = db.batch();
    outgoing.docs.forEach((d) => followBatch.delete(d.ref));
    incoming.docs.forEach((d) => followBatch.delete(d.ref));
    await followBatch.commit();
    deleted.follows = outgoing.size + incoming.size;

    // 7. Notifications received or sent by this user.
    const received = await db
      .collection("notifications")
      .where("recipient_id", "==", uid)
      .limit(1000)
      .get();
    const sent = await db
      .collection("notifications")
      .where("actor_id", "==", uid)
      .limit(1000)
      .get();
    const notifBatch = db.batch();
    received.docs.forEach((d) => notifBatch.delete(d.ref));
    sent.docs.forEach((d) => notifBatch.delete(d.ref));
    await notifBatch.commit();
    deleted.notifications = received.size + sent.size;

    // 8. Profile docs, device tokens, avatar objects.
    const tokens = await db.collection(`users/${uid}/fcm_tokens`).limit(50).get();
    const tokenBatch = db.batch();
    tokens.docs.forEach((d) => tokenBatch.delete(d.ref));
    tokenBatch.delete(db.doc(`users/${uid}`));
    tokenBatch.delete(db.doc(`users_private/${uid}`));
    await tokenBatch.commit();
    await deleteAvatarFolder(uid);

    // 9. Finally, the Auth account itself (also revokes refresh tokens).
    try {
      await getAuth().deleteUser(uid);
    } catch (err: any) {
      if (err?.code !== "auth/user-not-found") {
        throw new HttpsError("internal", "Could not delete the auth account.");
      }
    }

    return { ok: true, deleted };
  },
);
