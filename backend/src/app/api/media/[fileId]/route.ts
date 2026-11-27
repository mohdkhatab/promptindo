import { deleteAppwriteRef, isSafeAppwriteFileId } from "@/lib/appwrite";
import { requireUser } from "@/lib/auth";
import { ApiError, handleRoute, okResponse } from "@/lib/http";
import { getSupabaseAdmin } from "@/lib/supabase-admin";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * Deletes a post image owned by the signed-in user. The file must already be
 * referenced by one of their prompts, so a leaked id cannot be used to delete
 * someone else's media.
 */
export async function DELETE(
  req: Request,
  { params }: { params: Promise<{ fileId: string }> },
) {
  return handleRoute("/api/media/[fileId]", req, async (ctx) => {
    const { uid } = await requireUser(req, ctx);
    const { fileId } = await params;
    if (!isSafeAppwriteFileId(fileId)) {
      throw new ApiError(400, "invalid_file_id", "Invalid media id.");
    }

    const ref = `appwrite:${fileId}`;
    const { data: prompt, error } = await getSupabaseAdmin()
      .from("prompts")
      .select("id")
      .eq("creator_id", uid)
      .eq("thumbnail_path", ref)
      .maybeSingle();

    if (error) {
      throw new ApiError(500, "database_error", "Failed to verify media owner.");
    }
    if (!prompt) {
      throw new ApiError(404, "not_found", "Media not found.");
    }

    try {
      await deleteAppwriteRef(ref);
    } catch {
      throw new ApiError(
        500,
        "media_delete_failed",
        "Failed to remove the image.",
      );
    }

    return okResponse({ fileId });
  });
}
