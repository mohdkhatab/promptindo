import { requireWebhookSecret } from "@/lib/auth";
import { getFcmMessaging } from "@/lib/fcm";
import { handleRoute, okResponse, parseJsonBody } from "@/lib/http";
import { pushWebhookSchema } from "@/lib/schemas";
import { getSupabaseAdmin } from "@/lib/supabase-admin";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const DEAD_TOKEN_CODES = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
]);

function buildPushText(
  type: string,
  actorName: string,
  data: Record<string, unknown>,
): { title: string; body: string } {
  const excerpt =
    typeof data.excerpt === "string" && data.excerpt.length > 0
      ? data.excerpt
      : "";

  switch (type) {
    case "like":
      return { title: "New like", body: `${actorName} liked your prompt` };
    case "comment":
      return {
        title: "New comment",
        body: `${actorName} commented on your prompt`,
      };
    case "reply":
      return {
        title: "New reply",
        body:
          `${actorName} replied to your comment` +
          (excerpt ? `: “${excerpt}”` : ""),
      };
    case "comment_like":
      return { title: "New like", body: `${actorName} liked your comment` };
    case "follow":
      return {
        title: "New follower",
        body: `${actorName} started following you`,
      };
    case "remix":
      return {
        title: "Your prompt was remixed",
        body: `${actorName} remixed your prompt`,
      };
    case "report_resolved":
      return {
        title: "Report update",
        body: "Your report has been reviewed",
      };
    default:
      return { title: "PromptIndo", body: "You have a new notification" };
  }
}

export async function POST(req: Request) {
  return handleRoute("/api/webhooks/push", req, async () => {
    requireWebhookSecret(req);
    const notif = await parseJsonBody(req, pushWebhookSchema);

    try {
      const supabase = getSupabaseAdmin();
      const { data: rows, error: tokenErr } = await supabase
        .from("fcm_tokens")
        .select("token")
        .eq("user_id", notif.recipient_id)
        .order("updated_at", { ascending: false })
        .limit(10);

      if (tokenErr || !rows || rows.length === 0) {
        return okResponse({ sent: 0 });
      }

      const tokens = rows
        .map((r) => String(r.token ?? ""))
        .filter((t) => t.length > 0);
      if (tokens.length === 0) {
        return okResponse({ sent: 0 });
      }

      const actorName = notif.actor_username || notif.actor_name || "Someone";
      const { title, body } = buildPushText(
        notif.type,
        actorName,
        notif.data ?? {},
      );

      const res = await getFcmMessaging().sendEachForMulticast({
        tokens,
        notification: { title, body },
        data: {
          type: notif.type,
          notification_id: notif.id,
          prompt_id: notif.prompt_id ?? "",
          comment_id: notif.comment_id ?? "",
          actor_id: notif.actor_id ?? "",
        },
        android: {
          priority: "high",
          notification: {
            channelId: "promptindo",
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      });

      const deadTokens: string[] = [];
      res.responses.forEach((resp, idx) => {
        const code = resp.error?.code;
        if (code && DEAD_TOKEN_CODES.has(code)) {
          deadTokens.push(tokens[idx]);
        }
      });

      if (deadTokens.length > 0) {
        await supabase
          .from("fcm_tokens")
          .delete()
          .eq("user_id", notif.recipient_id)
          .in("token", deadTokens);
      }

      return okResponse({
        sent: res.successCount,
        pruned: deadTokens.length,
      });
    } catch {
      // Push delivery is best-effort; never fail the DB webhook because FCM errored.
      console.warn(
        JSON.stringify({
          ts: new Date().toISOString(),
          route: "/api/webhooks/push",
          event: "fcm_delivery_error",
          notificationId: notif.id,
        }),
      );
      return okResponse({ sent: 0, degraded: true });
    }
  });
}
