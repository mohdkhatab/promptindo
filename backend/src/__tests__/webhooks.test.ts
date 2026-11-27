import { beforeEach, describe, expect, it, vi } from "vitest";

const SECRET = "webhook-test-secret-0123456789abcdef";

const mockSendEachForMulticast = vi.fn();
const mockTokenLimit = vi.fn();
const mockTokenDeleteIn = vi.fn();
const mockStorageRemove = vi.fn();

vi.mock("@/lib/env", () => ({
  getEnv: () => ({
    SUPABASE_URL: "https://example.supabase.co",
    SUPABASE_SERVICE_ROLE_KEY: "service-role",
    SUPABASE_ANON_KEY: "anon",
    WEBHOOK_SECRET: SECRET,
    FIREBASE_SERVICE_ACCOUNT_BASE64: "dGVzdA==",
    SITE_URL: "https://promptindo.vercel.app",
  }),
}));

vi.mock("@/lib/fcm", () => ({
  getFcmMessaging: () => ({
    sendEachForMulticast: mockSendEachForMulticast,
  }),
}));

vi.mock("@/lib/supabase-admin", () => ({
  getSupabaseAdmin: () => ({
    from: (table: string) => {
      if (table === "fcm_tokens") {
        return {
          select: () => ({
            eq: () => ({
              order: () => ({
                limit: mockTokenLimit,
              }),
            }),
          }),
          delete: () => ({
            eq: () => ({
              in: mockTokenDeleteIn,
            }),
          }),
        };
      }
      throw new Error(`Unexpected table: ${table}`);
    },
    storage: {
      from: () => ({
        remove: mockStorageRemove,
      }),
    },
  }),
}));

import { POST as pushPost } from "@/app/api/webhooks/push/route";
import { POST as promptDeletedPost } from "@/app/api/webhooks/prompt-deleted/route";

const NOTIF_ID = "11111111-1111-4111-8111-111111111111";
const RECIPIENT_ID = "22222222-2222-4222-8222-222222222222";
const ACTOR_ID = "33333333-3333-4333-8333-333333333333";
const PROMPT_ID = "44444444-4444-4444-8444-444444444444";
const COMMENT_ID = "55555555-5555-4555-8555-555555555555";

describe("webhook routes", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockTokenDeleteIn.mockResolvedValue({ error: null });
    mockStorageRemove.mockResolvedValue({ data: [], error: null });
  });

  describe("POST /api/webhooks/push", () => {
    it("rejects missing or wrong webhook secret with 401", async () => {
      const payload = {
        id: NOTIF_ID,
        recipient_id: RECIPIENT_ID,
        type: "like",
      };

      const resMissing = await pushPost(
        new Request("http://localhost/api/webhooks/push", {
          method: "POST",
          body: JSON.stringify(payload),
        }),
      );
      expect(resMissing.status).toBe(401);

      const resWrong = await pushPost(
        new Request("http://localhost/api/webhooks/push", {
          method: "POST",
          headers: { "x-webhook-secret": "wrong-secret" },
          body: JSON.stringify(payload),
        }),
      );
      expect(resWrong.status).toBe(401);
      expect(mockSendEachForMulticast).not.toHaveBeenCalled();
    });

    it.each([
      {
        type: "like",
        actor_username: "alice",
        actor_name: "Alice",
        data: {},
        expectedTitle: "New like",
        expectedBody: "alice liked your prompt",
      },
      {
        type: "comment",
        actor_username: "",
        actor_name: "Bob",
        data: {},
        expectedTitle: "New comment",
        expectedBody: "Bob commented on your prompt",
      },
      {
        type: "reply",
        actor_username: "carol",
        actor_name: "Carol",
        data: { excerpt: "Nice prompt!" },
        expectedTitle: "New reply",
        expectedBody: "carol replied to your comment: “Nice prompt!”",
      },
      {
        type: "reply",
        actor_username: "",
        actor_name: "",
        data: {},
        expectedTitle: "New reply",
        expectedBody: "Someone replied to your comment",
      },
      {
        type: "comment_like",
        actor_username: "dan",
        actor_name: "",
        data: {},
        expectedTitle: "New like",
        expectedBody: "dan liked your comment",
      },
      {
        type: "follow",
        actor_username: "erin",
        actor_name: "",
        data: {},
        expectedTitle: "New follower",
        expectedBody: "erin started following you",
      },
      {
        type: "remix",
        actor_username: "frank",
        actor_name: "",
        data: {},
        expectedTitle: "Your prompt was remixed",
        expectedBody: "frank remixed your prompt",
      },
      {
        type: "report_resolved",
        actor_username: "admin",
        actor_name: "Admin",
        data: {},
        expectedTitle: "Report update",
        expectedBody: "Your report has been reviewed",
      },
    ])(
      "builds exact push notification text for $type",
      async ({
        type,
        actor_username,
        actor_name,
        data,
        expectedTitle,
        expectedBody,
      }) => {
        mockTokenLimit.mockResolvedValueOnce({
          data: [{ token: "fcm-tok-1" }],
          error: null,
        });
        mockSendEachForMulticast.mockResolvedValueOnce({
          successCount: 1,
          failureCount: 0,
          responses: [{ success: true }],
        });

        const res = await pushPost(
          new Request("http://localhost/api/webhooks/push", {
            method: "POST",
            headers: {
              "content-type": "application/json",
              "x-webhook-secret": SECRET,
            },
            body: JSON.stringify({
              id: NOTIF_ID,
              recipient_id: RECIPIENT_ID,
              actor_id: ACTOR_ID,
              actor_username,
              actor_name,
              type,
              prompt_id: PROMPT_ID,
              comment_id: COMMENT_ID,
              data,
            }),
          }),
        );

        expect(res.status).toBe(200);
        expect(mockSendEachForMulticast).toHaveBeenCalledWith(
          expect.objectContaining({
            tokens: ["fcm-tok-1"],
            notification: { title: expectedTitle, body: expectedBody },
            data: {
              type,
              notification_id: NOTIF_ID,
              prompt_id: PROMPT_ID,
              comment_id: COMMENT_ID,
              actor_id: ACTOR_ID,
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
                aps: { sound: "default", badge: 1 },
              },
            },
          }),
        );
      },
    );

    it("prunes dead FCM tokens and still returns 200 if FCM throws", async () => {
      mockTokenLimit.mockResolvedValueOnce({
        data: [
          { token: "alive-token" },
          { token: "dead-unregistered" },
          { token: "dead-invalid" },
        ],
        error: null,
      });
      mockSendEachForMulticast.mockResolvedValueOnce({
        successCount: 1,
        failureCount: 2,
        responses: [
          { success: true },
          {
            success: false,
            error: { code: "messaging/registration-token-not-registered" },
          },
          {
            success: false,
            error: { code: "messaging/invalid-registration-token" },
          },
        ],
      });

      const res = await pushPost(
        new Request("http://localhost/api/webhooks/push", {
          method: "POST",
          headers: {
            "content-type": "application/json",
            "x-webhook-secret": SECRET,
          },
          body: JSON.stringify({
            id: NOTIF_ID,
            recipient_id: RECIPIENT_ID,
            type: "like",
          }),
        }),
      );

      expect(res.status).toBe(200);
      expect(mockTokenDeleteIn).toHaveBeenCalledWith("token", [
        "dead-unregistered",
        "dead-invalid",
      ]);

      // FCM failure must still return 200
      mockTokenLimit.mockResolvedValueOnce({
        data: [{ token: "alive-token" }],
        error: null,
      });
      mockSendEachForMulticast.mockRejectedValueOnce(new Error("FCM outage"));

      const resDegraded = await pushPost(
        new Request("http://localhost/api/webhooks/push", {
          method: "POST",
          headers: {
            "content-type": "application/json",
            "x-webhook-secret": SECRET,
          },
          body: JSON.stringify({
            id: NOTIF_ID,
            recipient_id: RECIPIENT_ID,
            type: "like",
          }),
        }),
      );
      expect(resDegraded.status).toBe(200);
      expect(await resDegraded.json()).toMatchObject({
        ok: true,
        degraded: true,
      });
    });
  });

  describe("POST /api/webhooks/prompt-deleted", () => {
    it("rejects missing/wrong secret and unknown fields", async () => {
      const res = await promptDeletedPost(
        new Request("http://localhost/api/webhooks/prompt-deleted", {
          method: "POST",
          headers: { "x-webhook-secret": "bad" },
          body: JSON.stringify({}),
        }),
      );
      expect(res.status).toBe(401);

      const resExtra = await promptDeletedPost(
        new Request("http://localhost/api/webhooks/prompt-deleted", {
          method: "POST",
          headers: { "x-webhook-secret": SECRET },
          body: JSON.stringify({
            id: PROMPT_ID,
            creator_id: ACTOR_ID,
            thumbnail_path: `${ACTOR_ID}/thumb.webp`,
            extra: true,
          }),
        }),
      );
      expect(resExtra.status).toBe(400);
    });

    it("refuses paths outside owner or prompt folder and path traversal", async () => {
      const badPaths = [
        `other-user/thumb.jpg`,
        `../${ACTOR_ID}/thumb.jpg`,
        `/${ACTOR_ID}/thumb.jpg`,
        `${ACTOR_ID}/../other/thumb.jpg`,
        `${ACTOR_ID}\\thumb.jpg`,
        `${ACTOR_ID}/%2e%2e/other/thumb.jpg`,
        `${ACTOR_ID}/%2E%2E/other/thumb.jpg`,
        `${ACTOR_ID}%2fthumb.jpg`,
        `${ACTOR_ID}%5cthumb.jpg`,
        `${ACTOR_ID}/thumb.jpg%00.png`,
        `${ACTOR_ID}/%ZZbad`,
      ];

      for (const thumbnail_path of badPaths) {
        const res = await promptDeletedPost(
          new Request("http://localhost/api/webhooks/prompt-deleted", {
            method: "POST",
            headers: { "x-webhook-secret": SECRET },
            body: JSON.stringify({
              id: PROMPT_ID,
              creator_id: ACTOR_ID,
              thumbnail_path,
            }),
          }),
        );
        expect(res.status).toBe(400);
      }
      expect(mockStorageRemove).not.toHaveBeenCalled();
    });

    it("deletes valid thumbnail path and ignores not-found errors", async () => {
      const validPath = `${ACTOR_ID}/thumb.webp`;
      const resOk = await promptDeletedPost(
        new Request("http://localhost/api/webhooks/prompt-deleted", {
          method: "POST",
          headers: { "x-webhook-secret": SECRET },
          body: JSON.stringify({
            id: PROMPT_ID,
            creator_id: ACTOR_ID,
            thumbnail_path: validPath,
          }),
        }),
      );
      expect(resOk.status).toBe(200);
      expect(mockStorageRemove).toHaveBeenCalledWith([validPath]);

      mockStorageRemove.mockResolvedValueOnce({
        data: null,
        error: { statusCode: "404", message: "Object not found" },
      });
      const resNotFound = await promptDeletedPost(
        new Request("http://localhost/api/webhooks/prompt-deleted", {
          method: "POST",
          headers: { "x-webhook-secret": SECRET },
          body: JSON.stringify({
            id: PROMPT_ID,
            creator_id: ACTOR_ID,
            thumbnail_path: `${PROMPT_ID}/legacy.jpg`,
          }),
        }),
      );
      expect(resNotFound.status).toBe(200);
    });
  });
});
