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
  return handleRoute("/api/admin/comments/[id]", req, async (ctx) => {
    const { uid: adminId } = await requireAdmin(req, ctx);
    const { id } = await params;
    const commentId = parseUuidParam(id, "id");
    const body = await parseOptionalJsonBody(req, adminNotesBodySchema);

    const { data: updated, error } = await getSupabaseAdmin()
      .from("comments")
      .update({ status: "removed" })
      .eq("id", commentId)
      .select("id")
      .maybeSingle();

    if (error) {
      throw new ApiError(500, "database_error", "Failed to remove comment.");
    }
    if (!updated) {
      throw new ApiError(404, "not_found", "Comment not found.");
    }

    await audit(
      adminId,
      "delete_comment",
      "comment",
      commentId,
      body?.notes ?? "",
    );
    return okResponse({ id: commentId });
  });
}
