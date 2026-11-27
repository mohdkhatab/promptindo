/**
 * likes/{uid}_{promptId} triggers.
 *
 * The client's only write is the like doc itself (optimistic UI + revert on
 * failure). Everything that affects *other* people's data — the public
 * like_count and the owner's notification — happens here.
 */
import { onDocumentCreated, onDocumentDeleted } from "firebase-functions/v2/firestore";
import { db, adjustCounter } from "../config";
import { createNotification } from "../notify";

interface LikeDoc {
  user_id: string;
  prompt_id: string;
}

export const onLikeCreate = onDocumentCreated(
  "likes/{likeId}",
  async (event) => {
    const like = event.data?.data() as LikeDoc | undefined;
    if (!like?.prompt_id || !like.user_id) return;

    const promptRef = db.doc(`prompts/${like.prompt_id}`);
    const promptSnap = await promptRef.get();
    if (!promptSnap.exists) return;
    const prompt = promptSnap.data()!;
    const ownerId: string = prompt.creator_id;

    await adjustCounter(promptRef, "like_count", 1);
    await adjustCounter(db.doc(`users/${ownerId}`), "total_likes_received", 1);

    await createNotification({
      recipientId: ownerId,
      actorId: like.user_id,
      type: "like",
      promptId: like.prompt_id,
      data: { title: String(prompt.title ?? "") },
    });
  },
);

export const onLikeDelete = onDocumentDeleted(
  "likes/{likeId}",
  async (event) => {
    const like = event.data?.data() as LikeDoc | undefined;
    if (!like?.prompt_id) return;

    const promptRef = db.doc(`prompts/${like.prompt_id}`);
    const promptSnap = await promptRef.get();
    if (promptSnap.exists) {
      const ownerId: string = promptSnap.data()!.creator_id;
      await adjustCounter(promptRef, "like_count", -1);
      await adjustCounter(db.doc(`users/${ownerId}`), "total_likes_received", -1);
    }
  },
);

/**
 * comment_likes/{uid_commentId} — same shape, smaller blast radius.
 */
export const onCommentLikeCreate = onDocumentCreated(
  "comment_likes/{likeId}",
  async (event) => {
    const like = event.data?.data() as { user_id: string; comment_id: string } | undefined;
    if (!like?.comment_id || !like.user_id) return;

    const commentRef = db.doc(`comments/${like.comment_id}`);
    const commentSnap = await commentRef.get();
    if (!commentSnap.exists) return;
    const data = commentSnap.data()!;

    await adjustCounter(commentRef, "like_count", 1);

    await createNotification({
      recipientId: String(data.author_id),
      actorId: like.user_id,
      type: "comment_like",
      commentId: like.comment_id,
      promptId: String(data.prompt_id ?? ""),
      data: {},
    });
  },
);

export const onCommentLikeDelete = onDocumentDeleted(
  "comment_likes/{likeId}",
  async (event) => {
    const like = event.data?.data() as
      | { user_id: string; comment_id: string }
      | undefined;
    if (!like?.comment_id) return;
    await adjustCounter(db.doc(`comments/${like.comment_id}`), "like_count", -1);
  },
);

/**
 * bookmarks/{uid}_{promptId} — the model exposes an optional `bookmark_count`
 * on prompts (see README "Differences from the PHP version"); the pattern is
 * identical to likes.
 */
export const onBookmarkCreate = onDocumentCreated(
  "bookmarks/{bookmarkId}",
  async (event) => {
    const doc = event.data?.data() as LikeDoc | undefined;
    if (!doc?.prompt_id || !doc.user_id) return;
    await adjustCounter(db.doc(`prompts/${doc.prompt_id}`), "bookmark_count", 1);
  },
);

export const onBookmarkDelete = onDocumentDeleted(
  "bookmarks/{bookmarkId}",
  async (event) => {
    const doc = event.data?.data() as LikeDoc | undefined;
    if (!doc?.prompt_id) return;
    await adjustCounter(db.doc(`prompts/${doc.prompt_id}`), "bookmark_count", -1);
  },
);
