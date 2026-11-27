import { audit } from "@/lib/audit";
import { requireAdmin } from "@/lib/auth";
import {
  ApiError,
  handleRoute,
  okResponse,
  parseJsonBody,
  parseUuidParam,
} from "@/lib/http";
import { adminPromptStatusSchema } from "@/lib/schemas";
import { getSupabaseAdmin } from "@/lib/supabase-admin";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function PATCH(
  req: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  return handleRoute("/api/admin/prompts/[id]/status", req, async (ctx) => {
    const { uid: adminId } = await requireAdmin(req, ctx);
    const { id } = await params;
    const promptId = parseUuidParam(id, "id");
    const { status, notes } = await parseJsonBody(req, adminPromptStatusSchema);

    const { data: updated, error } = await getSupabaseAdmin()
      .from("prompts")
      .update({ status })
      .eq("id", promptId)
      .select("id")
      .maybeSingle();

    if (error) {
      throw new ApiError(
        500,
        "database_error",
        "Failed to update prompt status.",
      );
    }
    if (!updated) {
      throw new ApiError(404, "not_found", "Prompt not found.");
    }

    await audit(adminId, `prompt_${status}`, "prompt", promptId, notes);
    return okResponse({ id: promptId, status });
  });
}
