/**
 * follows/{followerUid_followedUid} triggers.
 *
 * Two counters move on create (followers on one user, following on the other)
 * and both unwind on delete.
 */
import { onDocumentCreated, onDocumentDeleted } from "firebase-functions/v2/firestore";
import { db, adjustCounter } from "../config";
import { createNotification } from "../notify";

interface FollowDoc {
  follower_id: string;
  followed_id: string;
}

export const onFollowCreate = onDocumentCreated(
  "follows/{followId}",
  async (event) => {
    const follow = event.data?.data() as FollowDoc | undefined;
    if (!follow?.follower_id || !follow.followed_id) return;
    if (follow.follower_id === follow.followed_id) return;

    await adjustCounter(db.doc(`users/${follow.followed_id}`), "follower_count", 1);
    await adjustCounter(db.doc(`users/${follow.follower_id}`), "following_count", 1);

    await createNotification({
      recipientId: follow.followed_id,
      actorId: follow.follower_id,
      type: "follow",
      data: {},
    });
  },
);

export const onFollowDelete = onDocumentDeleted(
  "follows/{followId}",
  async (event) => {
    const follow = event.data?.data() as FollowDoc | undefined;
    if (!follow?.follower_id || !follow.followed_id) return;
    if (follow.follower_id === follow.followed_id) return;

    await adjustCounter(db.doc(`users/${follow.followed_id}`), "follower_count", -1);
    await adjustCounter(db.doc(`users/${follow.follower_id}`), "following_count", -1);
  },
);
