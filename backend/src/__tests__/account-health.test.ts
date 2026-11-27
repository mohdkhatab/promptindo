import { beforeEach, describe, expect, it, vi } from "vitest";

const UID = "11111111-1111-4111-8111-111111111111";

const mockGetClaims = vi.fn();
const mockDeleteUser = vi.fn();
const mockHealthLimit = vi.fn();
const mockStorageList = vi.fn();
const mockStorageRemove = vi.fn();

vi.mock("@/lib/supabase-admin", () => ({
  getSupabaseAdmin: () => ({
    auth: {
      getClaims: mockGetClaims,
      admin: {
        deleteUser: mockDeleteUser,
      },
    },
    from: (table: string) => {
      if (table === "prompts") {
        return {
          select: () => ({
            eq: () => ({
              like: () => ({
                range: async () => ({ data: [], error: null }),
              }),
            }),
          }),
        };
      }
      return {
        select: () => ({
          limit: mockHealthLimit,
        }),
      };
    },
    storage: {
      from: (bucket: string) => ({
        list: (prefix: string, opts: { limit: number; offset: number }) =>
          mockStorageList(bucket, prefix, opts),
        remove: (paths: string[]) => mockStorageRemove(bucket, paths),
      }),
    },
  }),
}));

import { GET as healthGet } from "@/app/api/health/route";
import { POST as accountDeletePost } from "@/app/api/account/delete/route";

describe("health and account delete routes", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe("GET /api/health", () => {
    it("returns 200 ok with timestamp when Supabase responds", async () => {
      mockHealthLimit.mockResolvedValueOnce({ error: null });
      const res = await healthGet(new Request("http://localhost/api/health"));
      expect(res.status).toBe(200);
      const json = await res.json();
      expect(json.ok).toBe(true);
      expect(typeof json.ts).toBe("string");
    });

    it("returns 503 when Supabase check fails", async () => {
      mockHealthLimit.mockResolvedValueOnce({
        error: { message: "connection refused" },
      });
      const res = await healthGet(new Request("http://localhost/api/health"));
      expect(res.status).toBe(503);
      const json = await res.json();
      expect(json.ok).toBe(false);
      expect(json.error.code).toBe("service_unavailable");
    });
  });

  describe("POST /api/account/delete", () => {
    it("rejects unauthenticated callers with 401", async () => {
      const res = await accountDeletePost(
        new Request("http://localhost/api/account/delete", { method: "POST" }),
      );
      expect(res.status).toBe(401);
      expect(mockDeleteUser).not.toHaveBeenCalled();
    });

    it("paginates and deletes avatars & thumbnails before deleting auth user", async () => {
      mockGetClaims.mockResolvedValueOnce({
        data: { claims: { sub: UID } },
        error: null,
      });

      const callOrder: string[] = [];

      mockStorageList.mockImplementation(async (bucket: string, prefix: string) => {
        if (bucket === "avatars" && prefix === UID) {
          // Simulate 100 items on first page, then 1 item on second page
          const callsForAvatars = mockStorageList.mock.calls.filter(
            (c) => c[0] === "avatars",
          ).length;
          if (callsForAvatars === 1) {
            return {
              data: Array.from({ length: 100 }, (_, i) => ({
                id: `id-${i}`,
                name: `avatar-${i}.jpg`,
              })),
              error: null,
            };
          }
          return {
            data: [{ id: "id-last", name: "avatar-last.jpg" }],
            error: null,
          };
        }

        if (bucket === "thumbnails" && prefix === UID) {
          return {
            data: [{ id: "t-1", name: "thumb-1.webp" }],
            error: null,
          };
        }

        return { data: [], error: null };
      });

      mockStorageRemove.mockImplementation(async (bucket: string, paths: string[]) => {
        callOrder.push(`remove:${bucket}:${paths.length}`);
        return { data: [], error: null };
      });

      mockDeleteUser.mockImplementation(async (uid: string) => {
        callOrder.push(`deleteUser:${uid}`);
        return { data: {}, error: null };
      });

      const res = await accountDeletePost(
        new Request("http://localhost/api/account/delete", {
          method: "POST",
          headers: { authorization: "Bearer user-jwt" },
        }),
      );

      expect(res.status).toBe(200);
      expect(await res.json()).toEqual({ ok: true });
      expect(callOrder).toEqual([
        "remove:avatars:100",
        "remove:avatars:1",
        "remove:thumbnails:1",
        `deleteUser:${UID}`,
      ]);
    });

    it("is idempotent (200) if auth user was already deleted", async () => {
      mockGetClaims.mockResolvedValueOnce({
        data: { claims: { sub: UID } },
        error: null,
      });
      mockStorageList.mockResolvedValue({ data: [], error: null });
      mockDeleteUser.mockResolvedValueOnce({
        data: null,
        error: { status: 404, code: "user_not_found", message: "User not found" },
      });

      const res = await accountDeletePost(
        new Request("http://localhost/api/account/delete", {
          method: "POST",
          headers: { authorization: "Bearer user-jwt" },
        }),
      );

      expect(res.status).toBe(200);
      expect(await res.json()).toEqual({ ok: true });
    });
  });
});
