import { audit } from "@/lib/audit";
import { requireAdmin } from "@/lib/auth";
import {
  ApiError,
  handleRoute,
  okResponse,
  parseJsonBody,
  parseUuidParam,
} from "@/lib/http";
import { adminReportResolveSchema } from "@/lib/schemas";
import { getSupabaseAdmin } from "@/lib/supabase-admin";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function PATCH(
  req: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  return handleRoute("/api/admin/reports/[id]", req, async (ctx) => {
    const { uid: adminId } = await requireAdmin(req, ctx);
    const { id } = await params;
    const reportId = parseUuidParam(id, "id");
    const { status, resolution_note } = await parseJsonBody(
      req,
      adminReportResolveSchema,
    );

    const supabase = getSupabaseAdmin();
    const { data: report, error } = await supabase
      .from("reports")
      .update({
        status,
        resolution_note,
        resolved_by: adminId,
        resolved_at: new Date().toISOString(),
      })
      .eq("id", reportId)
      .select("id, reporter_id")
      .maybeSingle();

    if (error) {
      throw new ApiError(500, "database_error", "Failed to update report.");
    }
    if (!report) {
      throw new ApiError(404, "not_found", "Report not found.");
    }

    await audit(
      adminId,
      `report_${status}`,
      "report",
      reportId,
      resolution_note,
    );

    if (report.reporter_id) {
      const { error: notifErr } = await supabase.rpc("create_notification", {
        p_recipient: report.reporter_id,
        p_actor: adminId,
        p_type: "report_resolved",
        p_prompt: null,
        p_comment: null,
        p_data: { report_id: reportId, status },
      });
      if (notifErr) {
        console.warn(
          JSON.stringify({
            ts: new Date().toISOString(),
            route: "/api/admin/reports/[id]",
            event: "report_resolved_notification_failed",
            reportId,
          }),
        );
      }
    }

    return okResponse({ id: reportId, status });
  });
}
