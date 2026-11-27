/**
 * comments/{commentId} triggers: comment_count + notifications.
 *
 * Top-level comment → notify the prompt owner.
 * Reply (parent_id set)  → notify the parent comment's author.
 */
import { onDocumentCreated, onDocumentDeleted } from "firebase-functions/v2/firestore";
import { db, adjustCounter, deleteQueryBatch } from "../config";
import { createNotification } from "../notify";

interface CommentDoc {
  prompt_id: string;
  parent_id: string | null;
  author_id: string;
  content: string;
}

export const onCommentCreate = onDocumentCreated(
  "comments/{commentId}",
  async (event) => {
    const comment = event.data?.data() as CommentDoc | undefined;
    if (!comment?.prompt_id || !comment.author_id) return;

    const promptRef = db.doc(`prompts/${comment.prompt_id}`);
    const promptSnap = await promptRef.get();
    if (!promptSnap.exists) return;
    const prompt = promptSnap.data()!;

    await adjustCounter(promptRef, "comment_count", 1);

    const excerpt = comment.content.slice(0, 80);

    if (comment.parent_id) {
      const parentSnap = await db.doc(`comments/${comment.parent_id}`).get();
      const parentAuthor = parentSnap.exists
        ? String(parentSnap.data()!.author_id ?? "")
        : "";
      if (parentAuthor) {
        await createNotification({
          recipientId: parentAuthor,
          actorId: comment.author_id,
          type: "reply",
          promptId: comment.prompt_id,
          commentId: comment.parent_id,
          data: { excerpt },
        });
      }
      return;
    }

    await createNotification({
      recipientId: String(prompt.creator_id),
      actorId: comment.author_id,
      type: "comment",
      promptId: comment.prompt_id,
      commentId: event.params.commentId,
      data: { excerpt },
    });
  },
);

export const onCommentDelete = onDocumentDeleted(
  "comments/{commentId}",
  async (event) => {
    const comment = event.data?.data() as CommentDoc | undefined;
    if (!comment) return;

    if (comment.prompt_id) {
      await adjustCounter(db.doc(`prompts/${comment.prompt_id}`), "comment_count", -1);
    }

    // Orphaned likes on the deleted comment.
    await deleteQueryBatch(
      db.collection("comment_likes").where("comment_id", "==", event.params.commentId),
    ).catch(() => 0);

    // Replies to the deleted comment keep their parent_id (rendered as
    // "comment removed") — matching the PHP backend's behaviour.
  },
);
