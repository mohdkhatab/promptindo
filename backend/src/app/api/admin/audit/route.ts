import { requireAdmin } from "@/lib/auth";
import { ApiError, handleRoute, okResponse } from "@/lib/http";
import { decodeCursor, encodeCursor, parseSearchParams } from "@/lib/pagination";
import { adminAuditQuerySchema } from "@/lib/schemas";
import { getSupabaseAdmin } from "@/lib/supabase-admin";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(req: Request) {
  return handleRoute("/api/admin/audit", req, async (ctx) => {
    await requireAdmin(req, ctx);
    const { limit, cursor } = parseSearchParams(req, adminAuditQuerySchema);

    let query = getSupabaseAdmin()
      .from("admin_actions")
      .select("*")
      .order("created_at", { ascending: false })
      .order("id", { ascending: false })
      .limit(limit + 1);

    if (cursor) {
      const c = decodeCursor(cursor);
      query = query.or(
        `created_at.lt.${c.created_at},and(created_at.eq.${c.created_at},id.lt.${c.id})`,
      );
    }

    const { data, error } = await query;
    if (error) {
      throw new ApiError(
        500,
        "database_error",
        "Failed to fetch audit log.",
      );
    }

    const rows = data ?? [];
    const hasMore = rows.length > limit;
    const items = hasMore ? rows.slice(0, limit) : rows;
    const last = items[items.length - 1];
    const nextCursor =
      hasMore && last
        ? encodeCursor({
            created_at: String(last.created_at),
            id: String(last.id),
          })
        : null;

    return okResponse({ items, next_cursor: nextCursor });
  });
}
