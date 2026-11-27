import { handleRoute, okResponse, ApiError } from "@/lib/http";
import { getSupabaseAdmin } from "@/lib/supabase-admin";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(req: Request) {
  return handleRoute("/api/health", req, async () => {
    const { error } = await getSupabaseAdmin()
      .from("categories")
      .select("id", { head: true, count: "exact" })
      .limit(1);

    if (error) {
      throw new ApiError(
        503,
        "service_unavailable",
        "Database connectivity check failed.",
      );
    }

    return okResponse({ ts: new Date().toISOString() });
  });
}
