import { requireAdmin } from "@/lib/auth";
import { ApiError, handleRoute, okResponse } from "@/lib/http";
import { decodeCursor, encodeCursor, parseSearchParams } from "@/lib/pagination";
import { adminReportsQuerySchema } from "@/lib/schemas";
import { getSupabaseAdmin } from "@/lib/supabase-admin";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(req: Request) {
  return handleRoute("/api/admin/reports", req, async (ctx) => {
    await requireAdmin(req, ctx);
    const { status, limit, cursor } = parseSearchParams(
      req,
      adminReportsQuerySchema,
    );

    let query = getSupabaseAdmin()
      .from("reports")
      .select("*")
      .order("created_at", { ascending: false })
      .order("id", { ascending: false })
      .limit(limit + 1);

    if (status !== "all") {
      query = query.eq("status", status);
    }

    if (cursor) {
      const c = decodeCursor(cursor);
      query = query.or(
        `created_at.lt.${c.created_at},and(created_at.eq.${c.created_at},id.lt.${c.id})`,
      );
    }

    const { data, error } = await query;
    if (error) {
      throw new ApiError(500, "database_error", "Failed to fetch reports.");
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
