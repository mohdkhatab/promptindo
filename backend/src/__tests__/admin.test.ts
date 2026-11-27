import { beforeEach, describe, expect, it, vi } from "vitest";

const ADMIN_ID = "11111111-1111-4111-8111-111111111111";
const TARGET_ID = "22222222-2222-4222-8222-222222222222";
const REPORTER_ID = "33333333-3333-4333-8333-333333333333";

const mockGetClaims = vi.fn();
const mockGetUserById = vi.fn();
const mockUpdateUserById = vi.fn();
const mockRpc = vi.fn();

const auditInserts: Array<Record<string, unknown>> = [];
const dbState = {
  adminProfile: { role: "admin", status: "active" } as {
    role: string;
    status: string;
  } | null,
  profileUpdateResult: { data: { id: TARGET_ID } as { id: string } | null, error: null as unknown },
  promptUpdateResult: { data: { id: TARGET_ID } as { id: string } | null, error: null as unknown },
  promptDeleteResult: { data: { id: TARGET_ID } as { id: string } | null, error: null as unknown },
  commentUpdateResult: { data: { id: TARGET_ID } as { id: string } | null, error: null as unknown },
  reportUpdateResult: {
    data: { id: TARGET_ID, reporter_id: REPORTER_ID } as {
      id: string;
      reporter_id: string;
    } | null,
    error: null as unknown,
  },
  categoryInsertResult: {
    data: { id: TARGET_ID, name: "Writing", slug: "writing" } as Record<string, unknown> | null,
    error: null as { code?: string; message?: string } | null,
  },
  categoryUpdateResult: {
    data: { id: TARGET_ID, name: "Coding", slug: "coding" } as Record<string, unknown> | null,
    error: null as { code?: string; message?: string } | null,
  },
  categoryDeleteResult: {
    data: { id: TARGET_ID } as { id: string } | null,
    error: null as unknown,
  },
  reportsListResult: { data: [] as Record<string, unknown>[], error: null as unknown },
  auditListResult: { data: [] as Record<string, unknown>[], error: null as unknown },
};

const capturedUpdates: Array<{ table: string; payload: Record<string, unknown> }> = [];

vi.mock("@/lib/supabase-admin", () => ({
  getSupabaseAdmin: () => ({
    auth: {
      getClaims: mockGetClaims,
      admin: {
        getUserById: mockGetUserById,
        updateUserById: mockUpdateUserById,
      },
    },
    rpc: mockRpc,
    from: (table: string) => {
      if (table === "admin_actions") {
        return {
          insert: async (row: Record<string, unknown>) => {
            auditInserts.push(row);
            return { error: null };
          },
          select: () => {
            const chain = {
              order: () => chain,
              limit: () => chain,
              or: () => chain,
              then: (resolve: (val: unknown) => void) =>
                resolve(dbState.auditListResult),
            };
            return chain;
          },
        };
      }

      if (table === "profiles") {
        return {
          select: () => ({
            eq: () => ({
              maybeSingle: async () => ({
                data: dbState.adminProfile,
                error: null,
              }),
            }),
          }),
          update: (payload: Record<string, unknown>) => {
            capturedUpdates.push({ table, payload });
            return {
              eq: () => ({
                select: () => ({
                  maybeSingle: async () => dbState.profileUpdateResult,
                }),
              }),
            };
          },
        };
      }

      if (table === "prompts") {
        return {
          update: (payload: Record<string, unknown>) => {
            capturedUpdates.push({ table, payload });
            return {
              eq: () => ({
                select: () => ({
                  maybeSingle: async () => dbState.promptUpdateResult,
                }),
              }),
            };
          },
          delete: () => ({
            eq: () => ({
              select: () => ({
                maybeSingle: async () => dbState.promptDeleteResult,
              }),
            }),
          }),
        };
      }

      if (table === "comments") {
        return {
          update: (payload: Record<string, unknown>) => {
            capturedUpdates.push({ table, payload });
            return {
              eq: () => ({
                select: () => ({
                  maybeSingle: async () => dbState.commentUpdateResult,
                }),
              }),
            };
          },
        };
      }

      if (table === "reports") {
        return {
          update: (payload: Record<string, unknown>) => {
            capturedUpdates.push({ table, payload });
            return {
              eq: () => ({
                select: () => ({
                  maybeSingle: async () => dbState.reportUpdateResult,
                }),
              }),
            };
          },
          select: () => {
            const chain = {
              order: () => chain,
              limit: () => chain,
              eq: () => chain,
              or: () => chain,
              then: (resolve: (val: unknown) => void) =>
                resolve(dbState.reportsListResult),
            };
            return chain;
          },
        };
      }

      if (table === "categories") {
        return {
          insert: (payload: Record<string, unknown>) => {
            capturedUpdates.push({ table, payload });
            return {
              select: () => ({
                single: async () => dbState.categoryInsertResult,
              }),
            };
          },
          update: (payload: Record<string, unknown>) => {
            capturedUpdates.push({ table, payload });
            return {
              eq: () => ({
                select: () => ({
                  maybeSingle: async () => dbState.categoryUpdateResult,
                }),
              }),
            };
          },
          delete: () => ({
            eq: () => ({
              select: () => ({
                maybeSingle: async () => dbState.categoryDeleteResult,
              }),
            }),
          }),
        };
      }

      throw new Error(`Unexpected table: ${table}`);
    },
  }),
}));

import { PATCH as userStatusPatch } from "@/app/api/admin/users/[id]/status/route";
import { PATCH as userRolePatch } from "@/app/api/admin/users/[id]/role/route";
import { PATCH as promptStatusPatch } from "@/app/api/admin/prompts/[id]/status/route";
import { PATCH as promptFeaturedPatch } from "@/app/api/admin/prompts/[id]/featured/route";
import { DELETE as promptDelete } from "@/app/api/admin/prompts/[id]/route";
import { DELETE as commentDelete } from "@/app/api/admin/comments/[id]/route";
import { PATCH as reportPatch } from "@/app/api/admin/reports/[id]/route";
import { POST as categoryPost } from "@/app/api/admin/categories/route";
import {
  PUT as categoryPut,
  DELETE as categoryDelete,
} from "@/app/api/admin/categories/[id]/route";
import { GET as reportsGet } from "@/app/api/admin/reports/route";
import { GET as auditGet } from "@/app/api/admin/audit/route";

function adminJwt() {
  mockGetClaims.mockResolvedValueOnce({
    data: {
      claims: {
        sub: ADMIN_ID,
        app_metadata: { role: "admin" },
      },
    },
    error: null,
  });
}

function authReq(url: string, method: string, body?: unknown): Request {
  return new Request(url, {
    method,
    headers: {
      authorization: "Bearer admin-jwt",
      ...(body !== undefined ? { "content-type": "application/json" } : {}),
    },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
}

describe("admin API routes", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    auditInserts.length = 0;
    capturedUpdates.length = 0;
    dbState.adminProfile = { role: "admin", status: "active" };
    dbState.profileUpdateResult = { data: { id: TARGET_ID }, error: null };
    dbState.promptUpdateResult = { data: { id: TARGET_ID }, error: null };
    dbState.promptDeleteResult = { data: { id: TARGET_ID }, error: null };
    dbState.commentUpdateResult = { data: { id: TARGET_ID }, error: null };
    dbState.reportUpdateResult = {
      data: { id: TARGET_ID, reporter_id: REPORTER_ID },
      error: null,
    };
    dbState.categoryInsertResult = {
      data: { id: TARGET_ID, name: "Writing", slug: "writing" },
      error: null,
    };
    dbState.categoryUpdateResult = {
      data: { id: TARGET_ID, name: "Coding", slug: "coding" },
      error: null,
    };
    dbState.categoryDeleteResult = { data: { id: TARGET_ID }, error: null };
    dbState.reportsListResult = { data: [], error: null };
    dbState.auditListResult = { data: [], error: null };

    mockUpdateUserById.mockResolvedValue({ data: {}, error: null });
    mockGetUserById.mockResolvedValue({
      data: { user: { id: TARGET_ID, app_metadata: { provider: "email" } } },
      error: null,
    });
    mockRpc.mockResolvedValue({ error: null });
  });

  it("rejects non-admin and demoted-admin across admin endpoints", async () => {
    mockGetClaims.mockResolvedValueOnce({
      data: { claims: { sub: ADMIN_ID, app_metadata: { role: "user" } } },
      error: null,
    });
    const resNonAdmin = await reportsGet(
      authReq("http://localhost/api/admin/reports", "GET"),
    );
    expect(resNonAdmin.status).toBe(403);

    adminJwt();
    dbState.adminProfile = { role: "user", status: "active" };
    const resDemoted = await auditGet(
      authReq("http://localhost/api/admin/audit", "GET"),
    );
    expect(resDemoted.status).toBe(403);
    expect(auditInserts).toHaveLength(0);
  });

  it("bans and unbans users with auth ban_duration and audit log", async () => {
    adminJwt();
    const resBan = await userStatusPatch(
      authReq(`http://localhost/api/admin/users/${TARGET_ID}/status`, "PATCH", {
        status: "banned",
        notes: "spam",
      }),
      { params: Promise.resolve({ id: TARGET_ID }) },
    );
    expect(resBan.status).toBe(200);
    expect(mockUpdateUserById).toHaveBeenCalledWith(TARGET_ID, {
      ban_duration: "876000h",
    });

    adminJwt();
    const resUnban = await userStatusPatch(
      authReq(`http://localhost/api/admin/users/${TARGET_ID}/status`, "PATCH", {
        status: "active",
      }),
      { params: Promise.resolve({ id: TARGET_ID }) },
    );
    expect(resUnban.status).toBe(200);
    expect(mockUpdateUserById).toHaveBeenCalledWith(TARGET_ID, {
      ban_duration: "none",
    });

    expect(auditInserts.map((a) => a.action_type)).toEqual([
      "ban_user",
      "unban_user",
    ]);
  });

  it("updates user role in app_metadata and profiles and audits", async () => {
    adminJwt();
    const resPromote = await userRolePatch(
      authReq(`http://localhost/api/admin/users/${TARGET_ID}/role`, "PATCH", {
        role: "admin",
      }),
      { params: Promise.resolve({ id: TARGET_ID }) },
    );
    expect(resPromote.status).toBe(200);
    expect(mockUpdateUserById).toHaveBeenCalledWith(TARGET_ID, {
      app_metadata: { provider: "email", role: "admin" },
    });

    adminJwt();
    const resDemote = await userRolePatch(
      authReq(`http://localhost/api/admin/users/${TARGET_ID}/role`, "PATCH", {
        role: "user",
      }),
      { params: Promise.resolve({ id: TARGET_ID }) },
    );
    expect(resDemote.status).toBe(200);
    expect(mockUpdateUserById).toHaveBeenCalledWith(TARGET_ID, {
      app_metadata: { provider: "email", role: null },
    });

    expect(auditInserts.map((a) => a.action_type)).toEqual([
      "set_role_admin",
      "set_role_user",
    ]);
  });

  it("updates prompt status, featured flag, deletes prompt, and soft-deletes comment with audit rows", async () => {
    adminJwt();
    const r1 = await promptStatusPatch(
      authReq(`http://localhost/api/admin/prompts/${TARGET_ID}/status`, "PATCH", {
        status: "hidden",
        notes: "review",
      }),
      { params: Promise.resolve({ id: TARGET_ID }) },
    );
    expect(r1.status).toBe(200);

    adminJwt();
    const r2 = await promptFeaturedPatch(
      authReq(
        `http://localhost/api/admin/prompts/${TARGET_ID}/featured`,
        "PATCH",
        { featured: true },
      ),
      { params: Promise.resolve({ id: TARGET_ID }) },
    );
    expect(r2.status).toBe(200);

    adminJwt();
    const r3 = await promptDelete(
      authReq(`http://localhost/api/admin/prompts/${TARGET_ID}`, "DELETE"),
      { params: Promise.resolve({ id: TARGET_ID }) },
    );
    expect(r3.status).toBe(200);

    adminJwt();
    const r4 = await commentDelete(
      authReq(`http://localhost/api/admin/comments/${TARGET_ID}`, "DELETE", {
        notes: "abusive",
      }),
      { params: Promise.resolve({ id: TARGET_ID }) },
    );
    expect(r4.status).toBe(200);
    expect(capturedUpdates).toContainEqual({
      table: "comments",
      payload: { status: "removed" },
    });

    expect(auditInserts.map((a) => a.action_type)).toEqual([
      "prompt_hidden",
      "feature_prompt",
      "delete_prompt",
      "delete_comment",
    ]);
  });

  it("resolves report, writes audit row, and sends report_resolved notification", async () => {
    adminJwt();
    const res = await reportPatch(
      authReq(`http://localhost/api/admin/reports/${TARGET_ID}`, "PATCH", {
        status: "resolved",
        resolution_note: "Handled",
      }),
      { params: Promise.resolve({ id: TARGET_ID }) },
    );
    expect(res.status).toBe(200);
    expect(auditInserts).toHaveLength(1);
    expect(auditInserts[0]).toMatchObject({
      admin_id: ADMIN_ID,
      action_type: "report_resolved",
      target_type: "report",
      target_id: TARGET_ID,
      notes: "Handled",
    });
    expect(mockRpc).toHaveBeenCalledWith("create_notification", {
      p_recipient: REPORTER_ID,
      p_actor: ADMIN_ID,
      p_type: "report_resolved",
      p_prompt: null,
      p_comment: null,
      p_data: { report_id: TARGET_ID, status: "resolved" },
    });
  });

  it("handles category CRUD, 409 slug conflict, and audit rows", async () => {
    adminJwt();
    const createRes = await categoryPost(
      authReq("http://localhost/api/admin/categories", "POST", {
        name: "Writing",
        slug: "writing",
        icon: "✍️",
        description: "Writing prompts",
        sort_order: 1,
      }),
    );
    expect(createRes.status).toBe(201);

    adminJwt();
    dbState.categoryInsertResult = {
      data: null,
      error: { code: "23505", message: "duplicate key" },
    };
    const conflictRes = await categoryPost(
      authReq("http://localhost/api/admin/categories", "POST", {
        name: "Writing",
        slug: "writing",
      }),
    );
    expect(conflictRes.status).toBe(409);

    adminJwt();
    const updateRes = await categoryPut(
      authReq(`http://localhost/api/admin/categories/${TARGET_ID}`, "PUT", {
        name: "Coding",
        slug: "coding",
      }),
      { params: Promise.resolve({ id: TARGET_ID }) },
    );
    expect(updateRes.status).toBe(200);

    adminJwt();
    const deleteRes = await categoryDelete(
      authReq(`http://localhost/api/admin/categories/${TARGET_ID}`, "DELETE"),
      { params: Promise.resolve({ id: TARGET_ID }) },
    );
    expect(deleteRes.status).toBe(200);

    expect(auditInserts.map((a) => a.action_type)).toEqual([
      "create_category",
      "update_category",
      "delete_category",
    ]);
  });

  it("supports paginated GET /api/admin/reports and GET /api/admin/audit", async () => {
    adminJwt();
    dbState.reportsListResult = {
      data: [
        {
          id: TARGET_ID,
          status: "pending",
          created_at: "2026-11-27T00:00:00.000Z",
        },
        {
          id: REPORTER_ID,
          status: "pending",
          created_at: "2026-11-26T00:00:00.000Z",
        },
      ],
      error: null,
    };
    const repRes = await reportsGet(
      authReq(
        "http://localhost/api/admin/reports?status=pending&limit=1",
        "GET",
      ),
    );
    expect(repRes.status).toBe(200);
    const repJson = await repRes.json();
    expect(repJson.items).toHaveLength(1);
    expect(typeof repJson.next_cursor).toBe("string");

    adminJwt();
    dbState.auditListResult = {
      data: [
        {
          id: TARGET_ID,
          action_type: "ban_user",
          created_at: "2026-11-27T00:00:00.000Z",
        },
      ],
      error: null,
    };
    const audRes = await auditGet(
      authReq("http://localhost/api/admin/audit?limit=10", "GET"),
    );
    expect(audRes.status).toBe(200);
    const audJson = await audRes.json();
    expect(audJson.items).toHaveLength(1);
    expect(audJson.next_cursor).toBeNull();

    // Rejects non-ISO cursor timestamp (e.g. PostgREST filter injection attempt)
    adminJwt();
    const badCursor = Buffer.from(
      JSON.stringify({
        created_at: "2026-11-27 (comment)",
        id: TARGET_ID,
      }),
      "utf8",
    ).toString("base64url");
    const badCursorRes = await reportsGet(
      authReq(
        `http://localhost/api/admin/reports?status=pending&cursor=${badCursor}`,
        "GET",
      ),
    );
    expect(badCursorRes.status).toBe(400);
    expect(await badCursorRes.json()).toMatchObject({
      ok: false,
      error: { code: "invalid_cursor" },
    });

    // Accepts valid offset ISO datetime cursor and normalizes it
    adminJwt();
    const offsetCursor = Buffer.from(
      JSON.stringify({
        created_at: "2026-11-27T00:00:00+05:30",
        id: TARGET_ID,
      }),
      "utf8",
    ).toString("base64url");
    const okCursorRes = await reportsGet(
      authReq(
        `http://localhost/api/admin/reports?status=pending&cursor=${offsetCursor}`,
        "GET",
      ),
    );
    expect(okCursorRes.status).toBe(200);
  });
});
