/**
 * prompts/{promptId} triggers.
 *
 * onPromptCreate: prompt_count on the creator, prompt_count on the category,
 *                 and the "your prompt was remixed" notification.
 * onPromptDelete: unwind both counters, remove the Storage thumbnail and
 *                 cascade-delete every doc that pointed at this prompt.
 *
 * Note: deleting a prompt doc from *anywhere* (owner, admin callable, account
 * deletion) fires this same cascade, which is exactly why deletion of another
 * user's data is routed through callables instead of client writes.
 */
import {
  onDocumentCreated,
  onDocumentDeleted,
} from "firebase-functions/v2/firestore";
import {
  db,
  adjustCounter,
  deleteObjectSafe,
  deleteQueryBatch,
} from "../config";
import { createNotification } from "../notify";

interface PromptDoc {
  creator_id: string;
  title?: string;
  category_id?: string;
  remixed_from_id?: string | null;
  like_count?: number;
  visibility?: string;
  status?: string;
  thumbnail_path?: string | null;
}

/**
 * The client stores `thumbnail_path` so we can clean Storage up later, but a
 * client could write any string there — only ever delete objects that live in
 * a folder owned by this prompt (its creator uid or the prompt id itself).
 */
function safeThumbnailPath(path: unknown, creatorId: string, promptId: string): string | null {
  if (typeof path !== "string" || path.length === 0) return null;
  const allowedPrefixes = [`thumbnails/${creatorId}/`, `thumbnails/${promptId}/`];
  return allowedPrefixes.some((p) => path.startsWith(p)) ? path : null;
}

export const onPromptCreate = onDocumentCreated(
  "prompts/{promptId}",
  async (event) => {
    const prompt = event.data?.data() as PromptDoc | undefined;
    if (!prompt?.creator_id) return;

    await adjustCounter(db.doc(`users/${prompt.creator_id}`), "prompt_count", 1);

    if (prompt.category_id) {
      await adjustCounter(db.doc(`categories/${prompt.category_id}`), "prompt_count", 1);
    }

    if (prompt.remixed_from_id) {
      const source = await db.doc(`prompts/${prompt.remixed_from_id}`).get();
      if (source.exists) {
        await createNotification({
          recipientId: String(source.data()!.creator_id),
          actorId: prompt.creator_id,
          type: "remix",
          promptId: prompt.remixed_from_id,
          data: {
            remix_prompt_id: event.params.promptId,
            title: String(prompt.title ?? "").slice(0, 80),
          },
        });
      }
    }
  },
);

export const onPromptDelete = onDocumentDeleted(
  "prompts/{promptId}",
  async (event) => {
    const prompt = event.data?.data() as PromptDoc | undefined;
    if (!prompt) return;
    const promptId = event.params.promptId;
    const creatorId = String(prompt.creator_id ?? "");

    // --- counters ---------------------------------------------------------
    if (creatorId) {
      await adjustCounter(db.doc(`users/${creatorId}`), "prompt_count", -1);
      const likedOutstanding = Number(prompt.like_count ?? 0);
      if (likedOutstanding > 0) {
        await adjustCounter(
          db.doc(`users/${creatorId}`),
          "total_likes_received",
          -likedOutstanding,
        );
      }
    }
    if (prompt.category_id) {
      await adjustCounter(db.doc(`categories/${prompt.category_id}`), "prompt_count", -1);
    }

    // --- storage ----------------------------------------------------------
    const thumbPath = safeThumbnailPath(prompt.thumbnail_path, creatorId, promptId);
    if (thumbPath) await deleteObjectSafe(thumbPath);

    // --- cascade ----------------------------------------------------------
    await deleteQueryBatch(db.collection("likes").where("prompt_id", "==", promptId)).catch(() => 0);
    await deleteQueryBatch(db.collection("bookmarks").where("prompt_id", "==", promptId)).catch(() => 0);
    await deleteQueryBatch(db.collection("views").where("prompt_id", "==", promptId)).catch(() => 0);
    await deleteQueryBatch(
      db.collection("notifications").where("prompt_id", "==", promptId),
    ).catch(() => 0);

    // Comments first (so their comment_likes can be cleaned up too), then
    // anything else that referenced the prompt.
    const comments = await db
      .collection("comments")
      .where("prompt_id", "==", promptId)
      .limit(500)
      .get()
      .catch(() => null);

    if (comments) {
      for (const comment of comments.docs) {
        await deleteQueryBatch(
          db.collection("comment_likes").where("comment_id", "==", comment.id),
        ).catch(() => 0);
      }
      const batch = db.batch();
      comments.docs.forEach((d) => batch.delete(d.ref));
      await batch.commit();
      if (comments.size === 500) {
        await deleteQueryBatch(
          db.collection("comments").where("prompt_id", "==", promptId),
        ).catch(() => 0);
      }
    }

    // Reports about this prompt become moot.
    await deleteQueryBatch(
      db.collection("reports").where("target_type", "==", "prompt").where("target_id", "==", promptId),
    ).catch(() => 0);
  },
);
