import { ID, Permission, Role } from "node-appwrite";
import { InputFile } from "node-appwrite/file";

import {
  appwriteFileUrl,
  getAppwriteConfig,
  getAppwriteStorage,
} from "@/lib/appwrite";
import { requireUser } from "@/lib/auth";
import { ApiError, handleRoute, okResponse } from "@/lib/http";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const MAX_BYTES = 4 * 1024 * 1024; // stay under Vercel's ~4.5 MB body limit
const ALLOWED_TYPES = new Set(["image/jpeg", "image/png", "image/webp"]);

function safeFileName(raw: string | null): string {
  const name = (raw ?? "prompt-image.jpg").split(/[\\/]/).pop() ?? "";
  const cleaned = name.replace(/[^A-Za-z0-9._-]/g, "_").slice(0, 120);
  return cleaned || "prompt-image.jpg";
}

/**
 * Authenticated, backend-mediated post-image upload.
 *
 * The Flutter client sends the compressed image bytes as the raw request body
 * (no Appwrite SDK, no server key in the app). The backend stores the file in
 * the Appwrite `media` bucket with public-read permission and returns the
 * stable file id + public view URL.
 */
export async function POST(req: Request) {
  return handleRoute("/api/media/upload", req, async (ctx) => {
    const { uid } = await requireUser(req, ctx);

    const contentType = (req.headers.get("content-type") ?? "")
      .split(";")[0]
      .trim()
      .toLowerCase();
    if (!ALLOWED_TYPES.has(contentType)) {
      throw new ApiError(
        400,
        "invalid_media_type",
        "Only JPEG, PNG, and WebP images are allowed.",
      );
    }

    const declaredLength = Number(req.headers.get("content-length") ?? "0");
    if (declaredLength > MAX_BYTES) {
      throw new ApiError(413, "media_too_large", "Image must be 4 MB or less.");
    }

    const bytes = Buffer.from(await req.arrayBuffer());
    if (bytes.length === 0) {
      throw new ApiError(400, "empty_media", "Image body is empty.");
    }
    if (bytes.length > MAX_BYTES) {
      throw new ApiError(413, "media_too_large", "Image must be 4 MB or less.");
    }

    const fileName = safeFileName(req.headers.get("x-file-name"));
    const config = getAppwriteConfig();

    try {
      const created = await getAppwriteStorage().createFile(
        config.bucketId,
        ID.unique(),
        InputFile.fromBuffer(bytes, fileName),
        [Permission.read(Role.any())],
      );

      return okResponse(
        {
          fileId: created.$id,
          url: appwriteFileUrl(created.$id),
          uploadedBy: uid,
        },
        201,
      );
    } catch (err) {
      const message =
        err instanceof Error ? err.message : "Appwrite upload failed.";
      throw new ApiError(502, "media_upload_failed", message);
    }
  });
}
