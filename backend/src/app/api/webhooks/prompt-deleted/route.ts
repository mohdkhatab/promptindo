import { deleteAppwriteRef } from "@/lib/appwrite";
import { requireWebhookSecret } from "@/lib/auth";
import { ApiError, handleRoute, okResponse, parseJsonBody } from "@/lib/http";
import { promptDeletedWebhookSchema } from "@/lib/schemas";
import { getSupabaseAdmin } from "@/lib/supabase-admin";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

function isSafeThumbnailPath(
  path: string,
  creatorId: string,
  promptId: string,
): boolean {
  if (!path || path.includes("%")) {
    return false;
  }

  let decoded = path;
  for (let i = 0; i < 3; i += 1) {
    let next: string;
    try {
      next = decodeURIComponent(decoded);
    } catch {
      return false;
    }
    if (next === decoded) break;
    decoded = next;
  }

  for (const candidate of [path, decoded]) {
    if (
      !candidate ||
      candidate.startsWith("/") ||
      candidate.includes("..") ||
      candidate.includes("\\") ||
      candidate.includes("\0") ||
      candidate.includes("%")
    ) {
      return false;
    }
    const segments = candidate.split("/");
    if (segments.some((seg) => seg === "" || seg === "." || seg === "..")) {
      return false;
    }
  }

  return path.startsWith(`${creatorId}/`) || path.startsWith(`${promptId}/`);
}

function isNotFoundError(err: { message?: string; statusCode?: string | number }): boolean {
  const status = String(err.statusCode ?? "");
  const msg = (err.message ?? "").toLowerCase();
  return status === "404" || msg.includes("not found");
}

export async function POST(req: Request) {
  return handleRoute("/api/webhooks/prompt-deleted", req, async () => {
    requireWebhookSecret(req);
    const body = await parseJsonBody(req, promptDeletedWebhookSchema);

    // New post images live in Appwrite; the row stores `appwrite:<fileId>`.
    if (body.thumbnail_path.startsWith("appwrite:")) {
      try {
        await deleteAppwriteRef(body.thumbnail_path);
      } catch {
        throw new ApiError(
          500,
          "media_delete_failed",
          "Failed to remove the Appwrite post image.",
        );
      }
      return okResponse({ deleted: true });
    }

    if (!isSafeThumbnailPath(body.thumbnail_path, body.creator_id, body.id)) {
      throw new ApiError(
        400,
        "invalid_path",
        "thumbnail_path must reside inside the owner or prompt folder.",
      );
    }

    const { error } = await getSupabaseAdmin()
      .storage.from("thumbnails")
      .remove([body.thumbnail_path]);

    if (error && !isNotFoundError(error as { message?: string; statusCode?: string | number })) {
      throw new ApiError(
        500,
        "storage_error",
        "Failed to remove prompt thumbnail.",
      );
    }

    return okResponse({ deleted: !error });
  });
}
