import { audit } from "@/lib/audit";
import { requireAdmin } from "@/lib/auth";
import {
  ApiError,
  handleRoute,
  okResponse,
  parseJsonBody,
  parseUuidParam,
} from "@/lib/http";
import { adminPromptFeaturedSchema } from "@/lib/schemas";
import { getSupabaseAdmin } from "@/lib/supabase-admin";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function PATCH(
  req: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  return handleRoute("/api/admin/prompts/[id]/featured", req, async (ctx) => {
    const { uid: adminId } = await requireAdmin(req, ctx);
    const { id } = await params;
    const promptId = parseUuidParam(id, "id");
    const { featured, notes } = await parseJsonBody(
      req,
      adminPromptFeaturedSchema,
    );

    const { data: updated, error } = await getSupabaseAdmin()
      .from("prompts")
      .update({ is_featured: featured })
      .eq("id", promptId)
      .select("id")
      .maybeSingle();

    if (error) {
      throw new ApiError(
        500,
        "database_error",
        "Failed to update prompt featured state.",
      );
    }
    if (!updated) {
      throw new ApiError(404, "not_found", "Prompt not found.");
    }

    await audit(
      adminId,
      featured ? "feature_prompt" : "unfeature_prompt",
      "prompt",
      promptId,
      notes,
    );
    return okResponse({ id: promptId, featured });
  });
}
