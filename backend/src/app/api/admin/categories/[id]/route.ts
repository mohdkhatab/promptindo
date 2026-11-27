import { audit } from "@/lib/audit";
import { requireAdmin } from "@/lib/auth";
import {
  ApiError,
  handleRoute,
  okResponse,
  parseJsonBody,
  parseUuidParam,
} from "@/lib/http";
import { adminCategorySchema } from "@/lib/schemas";
import { getSupabaseAdmin } from "@/lib/supabase-admin";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function PUT(
  req: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  return handleRoute("/api/admin/categories/[id]", req, async (ctx) => {
    const { uid: adminId } = await requireAdmin(req, ctx);
    const { id } = await params;
    const categoryId = parseUuidParam(id, "id");
    const input = await parseJsonBody(req, adminCategorySchema);

    const { data: updated, error } = await getSupabaseAdmin()
      .from("categories")
      .update({
        name: input.name,
        slug: input.slug,
        icon: input.icon,
        description: input.description,
        sort_order: input.sort_order,
        updated_at: new Date().toISOString(),
      })
      .eq("id", categoryId)
      .select()
      .maybeSingle();

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
        "Failed to update category.",
      );
    }
    if (!updated) {
      throw new ApiError(404, "not_found", "Category not found.");
    }

    await audit(
      adminId,
      "update_category",
      "category",
      categoryId,
      input.name,
    );
    return okResponse({ category: updated });
  });
}

export async function DELETE(
  req: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  return handleRoute("/api/admin/categories/[id]", req, async (ctx) => {
    const { uid: adminId } = await requireAdmin(req, ctx);
    const { id } = await params;
    const categoryId = parseUuidParam(id, "id");

    const { data: deleted, error } = await getSupabaseAdmin()
      .from("categories")
      .delete()
      .eq("id", categoryId)
      .select("id")
      .maybeSingle();

    if (error) {
      throw new ApiError(
        500,
        "database_error",
        "Failed to delete category.",
      );
    }
    if (!deleted) {
      throw new ApiError(404, "not_found", "Category not found.");
    }

    await audit(adminId, "delete_category", "category", categoryId, "");
    return okResponse({ id: categoryId });
  });
}
