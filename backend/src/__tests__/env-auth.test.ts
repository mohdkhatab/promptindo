import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { getEnv, resetEnvCacheForTests } from "@/lib/env";
import { ApiError } from "@/lib/http";

const mockGetClaims = vi.fn();
const mockGetUser = vi.fn();
const mockProfileMaybeSingle = vi.fn();

vi.mock("@/lib/supabase-admin", () => ({
  getSupabaseAdmin: () => ({
    auth: {
      getClaims: mockGetClaims,
      getUser: mockGetUser,
    },
    from: () => ({
      select: () => ({
        eq: () => ({
          maybeSingle: mockProfileMaybeSingle,
        }),
      }),
    }),
  }),
}));

import { requireAdmin, requireUser, requireWebhookSecret } from "@/lib/auth";

const ORIGINAL_ENV = { ...process.env };

function setValidEnv() {
  process.env.SUPABASE_URL = "https://example.supabase.co";
  process.env.SUPABASE_SERVICE_ROLE_KEY = "service-role-secret";
  process.env.SUPABASE_ANON_KEY = "anon-public-key";
  process.env.WEBHOOK_SECRET = "super-secret-webhook-value-32bytes!";
  process.env.FIREBASE_SERVICE_ACCOUNT_BASE64 = Buffer.from(
    JSON.stringify({
      project_id: "promptindo-test",
      client_email: "fcm@promptindo-test.iam.gserviceaccount.com",
      private_key: "-----BEGIN PRIVATE KEY-----\nTEST\n-----END PRIVATE KEY-----\n",
    }),
  ).toString("base64");
  process.env.SITE_URL = "https://www.promptindo.app";
}

describe("env & auth helpers", () => {
  beforeEach(() => {
    resetEnvCacheForTests();
    setValidEnv();
  });

  afterEach(() => {
    process.env = { ...ORIGINAL_ENV };
    resetEnvCacheForTests();
  });

  it("fails fast when required server env vars are missing or invalid", () => {
    delete process.env.SUPABASE_SERVICE_ROLE_KEY;
    expect(() => getEnv()).toThrow(/SUPABASE_SERVICE_ROLE_KEY/);

    setValidEnv();
    process.env.SUPABASE_URL = "not-a-url";
    expect(() => getEnv()).toThrow(/SUPABASE_URL/);
  });

  it("validates webhook secret in constant time and rejects missing/wrong", () => {
    expect(() =>
      requireWebhookSecret(new Request("http://localhost/api/webhooks/push")),
    ).toThrowError(ApiError);

    expect(() =>
      requireWebhookSecret(
        new Request("http://localhost/api/webhooks/push", {
          headers: { "x-webhook-secret": "wrong" },
        }),
      ),
    ).toThrowError(ApiError);

    expect(() =>
      requireWebhookSecret(
        new Request("http://localhost/api/webhooks/push", {
          headers: {
            "x-webhook-secret": "super-secret-webhook-value-32bytes!",
          },
        }),
      ),
    ).not.toThrow();
  });

  it("requireUser rejects missing Bearer token and returns uid/claims on valid token", async () => {
    await expect(
      requireUser(new Request("http://localhost/api/account/delete")),
    ).rejects.toMatchObject({ status: 401 });

    mockGetClaims.mockResolvedValueOnce({
      data: {
        claims: {
          sub: "11111111-1111-4111-8111-111111111111",
          app_metadata: { role: "user" },
        },
      },
      error: null,
    });

    const user = await requireUser(
      new Request("http://localhost/api/account/delete", {
        headers: { authorization: "Bearer valid-jwt" },
      }),
    );
    expect(user.uid).toBe("11111111-1111-4111-8111-111111111111");
  });

  it("requireAdmin rejects non-admins, demoted admins, and banned admins", async () => {
    const req = () =>
      new Request("http://localhost/api/admin/reports", {
        headers: { authorization: "Bearer jwt-token" },
      });

    // Non-admin JWT
    mockGetClaims.mockResolvedValueOnce({
      data: {
        claims: {
          sub: "11111111-1111-4111-8111-111111111111",
          app_metadata: { role: "user" },
        },
      },
      error: null,
    });
    await expect(requireAdmin(req())).rejects.toMatchObject({ status: 403 });

    // Demoted admin (JWT still has role=admin, DB has role=user)
    mockGetClaims.mockResolvedValueOnce({
      data: {
        claims: {
          sub: "11111111-1111-4111-8111-111111111111",
          app_metadata: { role: "admin" },
        },
      },
      error: null,
    });
    mockProfileMaybeSingle.mockResolvedValueOnce({
      data: { role: "user", status: "active" },
      error: null,
    });
    await expect(requireAdmin(req())).rejects.toMatchObject({ status: 403 });

    // Banned admin (DB has role=admin, status=banned)
    mockGetClaims.mockResolvedValueOnce({
      data: {
        claims: {
          sub: "11111111-1111-4111-8111-111111111111",
          app_metadata: { role: "admin" },
        },
      },
      error: null,
    });
    mockProfileMaybeSingle.mockResolvedValueOnce({
      data: { role: "admin", status: "banned" },
      error: null,
    });
    await expect(requireAdmin(req())).rejects.toMatchObject({ status: 403 });

    // Active admin in both JWT and DB
    mockGetClaims.mockResolvedValueOnce({
      data: {
        claims: {
          sub: "11111111-1111-4111-8111-111111111111",
          app_metadata: { role: "admin" },
        },
      },
      error: null,
    });
    mockProfileMaybeSingle.mockResolvedValueOnce({
      data: { role: "admin", status: "active" },
      error: null,
    });
    const admin = await requireAdmin(req());
    expect(admin.uid).toBe("11111111-1111-4111-8111-111111111111");
  });
});
