import { deleteAppwriteRef } from "@/lib/appwrite";
import { audit } from "@/lib/audit";
import { requireAdmin } from "@/lib/auth";
import {
  ApiError,
  handleRoute,
  okResponse,
  parseOptionalJsonBody,
  parseUuidParam,
} from "@/lib/http";
import { adminNotesBodySchema } from "@/lib/schemas";
import { getSupabaseAdmin } from "@/lib/supabase-admin";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function DELETE(
  req: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  return handleRoute("/api/admin/prompts/[id]", req, async (ctx) => {
    const { uid: adminId } = await requireAdmin(req, ctx);
    const { id } = await params;
    const promptId = parseUuidParam(id, "id");
    const body = await parseOptionalJsonBody(req, adminNotesBodySchema);

    const { data: prompt, error: lookupError } = await getSupabaseAdmin()
      .from("prompts")
      .select("id, thumbnail_path")
      .eq("id", promptId)
      .maybeSingle();

    if (lookupError) {
      throw new ApiError(500, "database_error", "Failed to load prompt.");
    }
    if (!prompt) {
      throw new ApiError(404, "not_found", "Prompt not found.");
    }

    // Remove the Appwrite object before the row disappears. The DB webhook
    // also tries this, but a missing Vault secret must not orphan media.
    try {
      await deleteAppwriteRef(String(prompt.thumbnail_path ?? ""));
    } catch {
      throw new ApiError(
        500,
        "media_delete_failed",
        "Failed to remove the prompt image. Try again.",
      );
    }

    const { data: deleted, error } = await getSupabaseAdmin()
      .from("prompts")
      .delete()
      .eq("id", promptId)
      .select("id")
      .maybeSingle();

    if (error) {
      throw new ApiError(500, "database_error", "Failed to delete prompt.");
    }
    if (!deleted) {
      throw new ApiError(404, "not_found", "Prompt not found.");
    }

    await audit(
      adminId,
      "delete_prompt",
      "prompt",
      promptId,
      body?.notes ?? "",
    );
    return okResponse({ id: promptId });
  });
}
