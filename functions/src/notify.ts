/**
 * One function, two side effects: every in-app `notifications` doc is created
 * here and the same call also fans out an FCM push using the recipient's
 * stored device tokens. There is deliberately no second, parallel system to
 * keep in sync.
 */
import { getMessaging } from "firebase-admin/messaging";
import {
  db,
  now,
  NotificationType,
} from "./config";

export interface NotificationInput {
  recipientId: string;
  actorId: string;
  type: NotificationType;
  promptId?: string;
  commentId?: string;
  /** Never sent as a push body — routing/deeplink payload for the client. */
  data?: Record<string, string>;
}

interface ActorProfile {
  name?: string;
  username?: string;
  avatar_url?: string;
}

async function actorProfile(actorId: string): Promise<ActorProfile> {
  try {
    const snap = await db.doc(`users/${actorId}`).get();
    return (snap.data() ?? {}) as ActorProfile;
  } catch {
    return {};
  }
}

async function deviceTokens(uid: string): Promise<string[]> {
  try {
    const snap = await db
      .collection(`users/${uid}/fcm_tokens`)
      .limit(10)
      .get();
    return snap.docs
      .map((d) => String(d.get("token") ?? ""))
      .filter((t) => t.length > 0);
  } catch {
    return [];
  }
}

function pushBody(
  type: NotificationType,
  actorName: string,
  data?: Record<string, string>,
): { title: string; body: string } {
  switch (type) {
    case "like":
      return { title: "New like", body: `${actorName} liked your prompt` };
    case "comment":
      return { title: "New comment", body: `${actorName} commented on your prompt` };
    case "reply":
      return {
        title: "New reply",
        body: `${actorName} replied to your comment` +
          (data?.excerpt ? `: “${data.excerpt}”` : ""),
      };
    case "comment_like":
      return { title: "New like", body: `${actorName} liked your comment` };
    case "follow":
      return { title: "New follower", body: `${actorName} started following you` };
    case "remix":
      return { title: "Your prompt was remixed", body: `${actorName} remixed your prompt` };
    case "report_resolved":
      return { title: "Report update", body: "Your report has been reviewed" };
    default:
      return { title: "PromptIndo", body: "You have a new notification" };
  }
}

/**
 * Writes the in-app notification doc and sends the FCM push.
 * Self-actions (actor == recipient) are silently skipped, exactly like the
 * PHP backend's triggers did.
 */
export async function createNotification(
  input: NotificationInput,
): Promise<void> {
  if (!input.recipientId || input.recipientId === input.actorId) return;

  const actor = await actorProfile(input.actorId);
  const actorName = actor.username || actor.name || "Someone";

  const doc = {
    recipient_id: input.recipientId,
    actor_id: input.actorId,
    actor_username: actor.username ?? "",
    actor_name: actor.name ?? "",
    actor_avatar: actor.avatar_url ?? "",
    type: input.type,
    prompt_id: input.promptId ?? null,
    comment_id: input.commentId ?? null,
    is_read: false,
    data: input.data ?? {},
    created_at: now(),
  };

  await db.collection("notifications").add(doc);

  // Push side effect (best effort — a failed push must not fail the trigger).
  try {
    const tokens = await deviceTokens(input.recipientId);
    if (tokens.length === 0) return;

    const { title, body } = pushBody(input.type, actorName, input.data);
    const res = await getMessaging().sendEachForMulticast({
      tokens,
      notification: { title, body },
      data: {
        type: input.type,
        notification_id: "",
        prompt_id: input.promptId ?? "",
        comment_id: input.commentId ?? "",
        actor_id: input.actorId,
      },
      android: {
        priority: "high",
        notification: { channelId: "promptindo", clickAction: "FLUTTER_NOTIFICATION_CLICK" },
      },
      apns: { payload: { aps: { sound: "default", badge: 1 } } },
    });

    // Prune tokens that Firebase reports as dead (unregistered/invalid).
    const dead: string[] = [];
    res.responses.forEach((r, i) => {
      const err = r.error;
      if (
        err &&
        (err.code === "messaging/registration-token-not-registered" ||
          err.code === "messaging/invalid-registration-token")
      ) {
        dead.push(tokens[i]);
      }
    });
    if (dead.length > 0) {
      const uid = input.recipientId;
      const batch = db.batch();
      for (const token of dead) {
        const q = await db
          .collection(`users/${uid}/fcm_tokens`)
          .where("token", "==", token)
          .limit(5)
          .get();
        q.docs.forEach((d) => batch.delete(d.ref));
      }
      await batch.commit();
    }
  } catch (err) {
    console.warn("FCM send failed", err);
  }
}
