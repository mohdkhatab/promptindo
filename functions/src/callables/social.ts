/**
 * Guest-safe social callables.
 *
 * copyPrompt and recordView are callable functions (not raw client writes) on
 * purpose: a logged-out visitor must be able to copy a prompt and have the
 * public counter move, but no client is ever allowed to write `prompts` itself
 * for something that affects a public counter.
 */
import { HttpsError, onCall, CallableRequest } from "firebase-functions/v2/https";
import { db, adjustCounter, APP_CHECK_ENFORCED, VIEW_DEDUPE_HOURS } from "../config";

const PROMPT_ID_RE = /^[A-Za-z0-9_-]{6,40}$/;
const ANON_ID_RE = /^[A-Za-z0-9-]{8,64}$/;

function requirePromptId(data: any): string {
  const promptId = data?.promptId;
  if (typeof promptId !== "string" || !PROMPT_ID_RE.test(promptId)) {
    throw new HttpsError("invalid-argument", "A valid promptId is required.");
  }
  return promptId;
}

/**
 * Atomically increments copy_count. Callers copy to the clipboard locally
 * first, then fire this (fire-and-forget with a retry from the client).
 */
export const copyPrompt = onCall(
  { enforceAppCheck: APP_CHECK_ENFORCED },
  async (request: CallableRequest) => {
    const promptId = requirePromptId(request.data);

    const promptRef = db.doc(`prompts/${promptId}`);
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(promptRef);
      if (!snap.exists) throw new HttpsError("not-found", "Prompt not found.");
      const data = snap.data()!;
      if (data.status !== "active" || data.visibility !== "public") {
        throw new HttpsError("failed-precondition", "Prompt is not available.");
      }
      const next = Math.max(0, Number(data.copy_count ?? 0)) + 1;
      tx.update(promptRef, { copy_count: next });
    });

    return { ok: true };
  },
);

/**
 * Deduped view counter — mirrors the PHP backend's VIEW_DEDUPE_HOURS.
 *
 * Dedupe key: authenticated uid, or a client-generated anonymous id that is
 * persisted locally. Views collection is otherwise unreachable from the
 * client (rules: allow read, write: if false).
 */
export const recordView = onCall(
  { enforceAppCheck: APP_CHECK_ENFORCED },
  async (request: CallableRequest) => {
    const promptId = requirePromptId(request.data);

    const authedUid = request.auth?.uid ?? null;
    const anonId = typeof request.data?.anonId === "string" ? request.data.anonId : "";

    let viewerKey: string;
    if (authedUid) {
      viewerKey = authedUid;
    } else if (ANON_ID_RE.test(anonId)) {
      viewerKey = `anon:${anonId}`;
    } else {
      throw new HttpsError("invalid-argument", "A valid anonId is required.");
    }

    const viewId = `${viewerKey}_${promptId}`;
    const viewRef = db.doc(`views/${viewId}`);
    const promptRef = db.doc(`prompts/${promptId}`);
    const dedupeMs = VIEW_DEDUPE_HOURS * 60 * 60 * 1000;

    const counted = await db.runTransaction(async (tx) => {
      const [viewSnap, promptSnap] = await Promise.all([tx.get(viewRef), tx.get(promptRef)]);
      if (!promptSnap.exists) throw new HttpsError("not-found", "Prompt not found.");

      if (viewSnap.exists) {
        const createdAt = viewSnap.get("created_at");
        const ts =
          createdAt instanceof Date
            ? createdAt.getTime()
            : typeof createdAt?.toMillis === "function"
              ? createdAt.toMillis()
              : 0;
        if (ts > 0 && Date.now() - ts < dedupeMs) return false;
      }

      const prompt = promptSnap.data()!;
      const next = Math.max(0, Number(prompt.view_count ?? 0)) + 1;
      tx.set(viewRef, {
        viewer_key: viewerKey,
        prompt_id: promptId,
        created_at: new Date(),
      });
      tx.update(promptRef, { view_count: next });
      return true;
    });

    return { ok: true, counted };
  },
);
