import { z } from "zod";

import { requireUser } from "@/lib/auth";
import { ApiError, handleRoute, okResponse, parseJsonBody } from "@/lib/http";
import { getSupabaseAdmin } from "@/lib/supabase-admin";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const bodySchema = z
  .object({
    name: z.string().trim().min(1).max(60),
  })
  .strict();

function slugify(raw: string): string {
  const slug = raw
    .toLowerCase()
    .normalize("NFKD")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 60);
  return slug || `category-${Date.now().toString(36)}`;
}

/**
 * Free-text categories: any signed-in user can name their own category.
 * The backend creates the row on demand (service role) and returns its id.
 * There is no built-in category picker in the app.
 */
export async function POST(req: Request) {
  return handleRoute("/api/categories/resolve", req, async (ctx) => {
    await requireUser(req, ctx);
    const { name } = await parseJsonBody(req, bodySchema);
    const slug = slugify(name);
    const supabase = getSupabaseAdmin();

    const existing = await supabase
      .from("categories")
      .select("id, name, slug")
      .eq("slug", slug)
      .maybeSingle();

    if (existing.error) {
      throw new ApiError(500, "database_error", "Failed to resolve category.");
    }
    if (existing.data) {
      return okResponse({ category: existing.data });
    }

    const inserted = await supabase
      .from("categories")
      .insert({
        name,
        slug,
        icon: "",
        description: "",
        sort_order: 0,
      })
      .select("id, name, slug")
      .single();

    if (inserted.error) {
      // A concurrent request may have created the same slug.
      if (inserted.error.code === "23505") {
        const raced = await supabase
          .from("categories")
          .select("id, name, slug")
          .eq("slug", slug)
          .maybeSingle();
        if (!raced.error && raced.data) {
          return okResponse({ category: raced.data });
        }
      }
      throw new ApiError(500, "database_error", "Failed to create category.");
    }

    return okResponse({ category: inserted.data }, 201);
  });
}
