import { deleteAppwriteRef } from "@/lib/appwrite";
import { requireUser } from "@/lib/auth";
import { ApiError, handleRoute, okResponse } from "@/lib/http";
import { getSupabaseAdmin } from "@/lib/supabase-admin";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const LIST_PAGE_SIZE = 100;

async function emptyUserFolder(bucket: string, uid: string): Promise<void> {
  const supabase = getSupabaseAdmin();
  const queue: string[] = [uid];

  while (queue.length > 0) {
    const prefix = queue.shift()!;
    let offset = 0;

    for (;;) {
      const { data: items, error: listErr } = await supabase.storage
        .from(bucket)
        .list(prefix, { limit: LIST_PAGE_SIZE, offset });

      if (listErr) {
        throw new ApiError(
          500,
          "storage_error",
          `Failed to list ${bucket} objects.`,
        );
      }

      if (!items || items.length === 0) {
        break;
      }

      const filePaths: string[] = [];
      let subfolderCount = 0;

      for (const item of items) {
        if (!item.name) continue;
        const fullPath = `${prefix}/${item.name}`;
        // In Supabase Storage list(), folder entries have id === null.
        if (item.id === null) {
          queue.push(fullPath);
          subfolderCount += 1;
        } else {
          filePaths.push(fullPath);
        }
      }

      if (filePaths.length > 0) {
        const { error: rmErr } = await supabase.storage
          .from(bucket)
          .remove(filePaths);
        if (rmErr) {
          throw new ApiError(
            500,
            "storage_error",
            `Failed to remove ${bucket} objects.`,
          );
        }
      }

      if (items.length < LIST_PAGE_SIZE) {
        break;
      }

      // Advance offset past any remaining folder entries; deleted files drop out of page 0.
      offset += subfolderCount;
    }
  }
}

function isAuthUserNotFound(err: {
  status?: number;
  code?: string;
  message?: string;
}): boolean {
  const msg = (err.message ?? "").toLowerCase();
  return (
    err.status === 404 ||
    err.code === "user_not_found" ||
    msg.includes("not found")
  );
}

export async function POST(req: Request) {
  return handleRoute("/api/account/delete", req, async (ctx) => {
    const { uid } = await requireUser(req, ctx);

    // Delete Appwrite post images before the auth row cascades. The DB
    // trigger is best-effort and depends on Vault; this guarantees cleanup.
    const supabase = getSupabaseAdmin();
    let from = 0;
    for (;;) {
      const { data: mediaRows, error: mediaError } = await supabase
        .from("prompts")
        .select("thumbnail_path")
        .eq("creator_id", uid)
        .like("thumbnail_path", "appwrite:%")
        .range(from, from + 499);

      if (mediaError) {
        throw new ApiError(
          500,
          "media_delete_failed",
          "Failed to list your post images.",
        );
      }
      if (!mediaRows || mediaRows.length === 0) break;

      for (const row of mediaRows) {
        try {
          await deleteAppwriteRef(String(row.thumbnail_path ?? ""));
        } catch {
          throw new ApiError(
            500,
            "media_delete_failed",
            "Failed to remove a post image. Try again.",
          );
        }
      }

      if (mediaRows.length < 500) break;
      from += 500;
    }

    await emptyUserFolder("avatars", uid);
    await emptyUserFolder("thumbnails", uid);

    const { error } = await getSupabaseAdmin().auth.admin.deleteUser(uid);
    if (error && !isAuthUserNotFound(error)) {
      throw new ApiError(
        500,
        "account_delete_failed",
        "Failed to delete user account.",
      );
    }

    return okResponse();
  });
}
