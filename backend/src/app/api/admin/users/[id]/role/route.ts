import { audit } from "@/lib/audit";
import { requireAdmin } from "@/lib/auth";
import {
  ApiError,
  handleRoute,
  okResponse,
  parseJsonBody,
  parseUuidParam,
} from "@/lib/http";
import { adminUserRoleSchema } from "@/lib/schemas";
import { getSupabaseAdmin } from "@/lib/supabase-admin";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function PATCH(
  req: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  return handleRoute("/api/admin/users/[id]/role", req, async (ctx) => {
    const { uid: adminId } = await requireAdmin(req, ctx);
    const { id } = await params;
    const targetId = parseUuidParam(id, "id");
    const { role } = await parseJsonBody(req, adminUserRoleSchema);

    const supabase = getSupabaseAdmin();
    const { data: existingAuth, error: getErr } =
      await supabase.auth.admin.getUserById(targetId);

    if (getErr || !existingAuth?.user) {
      throw new ApiError(404, "not_found", "Auth user not found.");
    }

    const existingAppMeta =
      (existingAuth.user.app_metadata as Record<string, unknown> | undefined) ??
      {};
    const { error: authErr } = await supabase.auth.admin.updateUserById(
      targetId,
      {
        app_metadata: {
          ...existingAppMeta,
          role: role === "admin" ? "admin" : null,
        },
      },
    );
    if (authErr) {
      throw new ApiError(
        500,
        "auth_admin_error",
        "Failed to update user app_metadata.",
      );
    }

    const { data: updated, error: profileErr } = await supabase
      .from("profiles")
      .update({ role })
      .eq("id", targetId)
      .select("id")
      .maybeSingle();

    if (profileErr) {
      throw new ApiError(
        500,
        "database_error",
        "Failed to update profile role.",
      );
    }
    if (!updated) {
      throw new ApiError(404, "not_found", "User profile not found.");
    }

    await audit(adminId, `set_role_${role}`, "user", targetId, "");

    return okResponse({ id: targetId, role });
  });
}
