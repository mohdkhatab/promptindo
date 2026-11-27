import { audit } from "@/lib/audit";
import { requireAdmin } from "@/lib/auth";
import { ApiError, handleRoute, okResponse, parseJsonBody } from "@/lib/http";
import { adminCategorySchema } from "@/lib/schemas";
import { getSupabaseAdmin } from "@/lib/supabase-admin";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(req: Request) {
  return handleRoute("/api/admin/categories", req, async (ctx) => {
    const { uid: adminId } = await requireAdmin(req, ctx);
    const input = await parseJsonBody(req, adminCategorySchema);

    const { data: created, error } = await getSupabaseAdmin()
      .from("categories")
      .insert({
        name: input.name,
        slug: input.slug,
        icon: input.icon,
        description: input.description,
        sort_order: input.sort_order,
      })
      .select()
      .single();

    if (error) {
      if (error.code === "23505") {
        throw new ApiError(
          409,
          "slug_conflict",
          "Category slug already exists.",
        );
      }
      throw new ApiError(
        500,
        "database_error",
        "Failed to create category.",
      );
    }

    await audit(
      adminId,
      "create_category",
      "category",
      created.id,
      input.name,
    );
    return okResponse({ category: created }, 201);
  });
}
