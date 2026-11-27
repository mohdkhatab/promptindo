import { audit } from "@/lib/audit";
import { requireAdmin } from "@/lib/auth";
import {
  ApiError,
  handleRoute,
  okResponse,
  parseJsonBody,
  parseUuidParam,
} from "@/lib/http";
import { adminUserStatusSchema } from "@/lib/schemas";
import { getSupabaseAdmin } from "@/lib/supabase-admin";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function PATCH(
  req: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  return handleRoute("/api/admin/users/[id]/status", req, async (ctx) => {
    const { uid: adminId } = await requireAdmin(req, ctx);
    const { id } = await params;
    const targetId = parseUuidParam(id, "id");
    const { status, notes } = await parseJsonBody(req, adminUserStatusSchema);

    const supabase = getSupabaseAdmin();
    const { data: updated, error: profileErr } = await supabase
      .from("profiles")
      .update({ status })
      .eq("id", targetId)
      .select("id")
      .maybeSingle();

    if (profileErr) {
      throw new ApiError(
        500,
        "database_error",
        "Failed to update user status.",
      );
    }
    if (!updated) {
      throw new ApiError(404, "not_found", "User not found.");
    }

    const { error: authErr } = await supabase.auth.admin.updateUserById(
      targetId,
      { ban_duration: status === "banned" ? "876000h" : "none" },
    );
    if (authErr) {
      throw new ApiError(
        500,
        "auth_admin_error",
        "Failed to update auth ban state.",
      );
    }

    await audit(
      adminId,
      status === "banned" ? "ban_user" : "unban_user",
      "user",
      targetId,
      notes,
    );

    return okResponse({ id: targetId, status });
  });
}
