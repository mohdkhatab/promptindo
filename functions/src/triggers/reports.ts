/**
 * reports/{reportId} trigger — server-side moderation rules that a client
 * check could never be trusted with:
 *   1. no duplicate report for the same target by the same reporter within
 *      REPORT_DUPLICATE_WINDOW_HOURS (mirrors the PHP backend's 1-hour rule)
 *   2. the reported target must actually exist
 */
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { db, REPORT_DUPLICATE_WINDOW_HOURS } from "../config";

interface ReportDoc {
  target_type: "prompt" | "comment" | "user";
  target_id: string;
  reporter_id: string;
  reason?: string;
  status?: string;
  created_at?: Date;
}

function targetRef(target_type: string, target_id: string) {
  switch (target_type) {
    case "prompt":
      return db.doc(`prompts/${target_id}`);
    case "comment":
      return db.doc(`comments/${target_id}`);
    case "user":
      return db.doc(`users/${target_id}`);
    default:
      return null;
  }
}

export const onReportCreate = onDocumentCreated(
  "reports/{reportId}",
  async (event) => {
    const ref = event.data?.ref;
    const report = event.data?.data() as ReportDoc | undefined;
    if (!ref || !report) return;

    // Reject reports against targets that don't exist (and malformed types).
    const target = targetRef(report.target_type, report.target_id);
    if (!target) {
      await ref.delete();
      return;
    }
    const targetSnap = await target.get().catch(() => null);
    if (!targetSnap || !targetSnap.exists) {
      await ref.delete();
      return;
    }

    // Duplicate check: two equality filters (no composite index required),
    // window filtered here because a range filter would need one.
    const cutoff = Date.now() - REPORT_DUPLICATE_WINDOW_HOURS * 60 * 60 * 1000;
    const candidates = await db
      .collection("reports")
      .where("reporter_id", "==", report.reporter_id)
      .where("target_id", "==", report.target_id)
      .limit(10)
      .get();

    const duplicate = candidates.docs.some((d) => {
      if (d.id === event.params.reportId) return false;
      const createdAt = d.get("created_at");
      const ts =
        createdAt instanceof Date
          ? createdAt.getTime()
          : typeof createdAt?.toMillis === "function"
            ? createdAt.toMillis()
            : 0;
      return ts >= cutoff;
    });

    if (duplicate) {
      await ref.delete();
      return;
    }

    await ref.set(
      {
        status: report.status ?? "pending",
        resolution_note: "",
        resolved_by: null,
        resolved_at: null,
      },
      { merge: true },
    );
  },
);
