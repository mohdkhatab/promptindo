import { z } from "zod";
import { ApiError } from "./http";

const cursorSchema = z
  .object({
    created_at: z.string().datetime({ offset: true }),
    id: z.string().uuid(),
  })
  .strict();

export type KeysetCursor = z.infer<typeof cursorSchema>;

export function encodeCursor(row: { created_at: string; id: string }): string {
  return Buffer.from(
    JSON.stringify({ created_at: row.created_at, id: row.id }),
    "utf8",
  ).toString("base64url");
}

export function decodeCursor(raw: string): KeysetCursor {
  let parsedJson: unknown;
  try {
    const decoded = Buffer.from(raw, "base64url").toString("utf8");
    parsedJson = JSON.parse(decoded);
  } catch {
    throw new ApiError(400, "invalid_cursor", "Invalid pagination cursor.");
  }

  const parsed = cursorSchema.safeParse(parsedJson);
  if (!parsed.success) {
    throw new ApiError(400, "invalid_cursor", "Invalid pagination cursor.");
  }

  const timestamp = Date.parse(parsed.data.created_at);
  if (Number.isNaN(timestamp)) {
    throw new ApiError(400, "invalid_cursor", "Invalid pagination cursor.");
  }

  return {
    created_at: new Date(timestamp).toISOString(),
    id: parsed.data.id,
  };
}

/**
 * Extracts validated query parameters from a URL, rejecting unknown keys.
 */
export function parseSearchParams<T>(
  req: Request,
  schema: z.ZodType<T>,
): T {
  const url = new URL(req.url);
  const rawObj: Record<string, string> = {};
  url.searchParams.forEach((value, key) => {
    rawObj[key] = value;
  });
  const parsed = schema.safeParse(rawObj);
  if (!parsed.success) {
    const first = parsed.error.issues[0];
    const path = first?.path.join(".");
    const detail = first?.message ?? "Invalid query parameters.";
    throw new ApiError(
      400,
      "validation_error",
      path ? `${path}: ${detail}` : detail,
    );
  }
  return parsed.data;
}
