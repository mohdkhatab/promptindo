/**
 * Scheduled functions.
 *
 * recomputeTrending — trend_score is *never* computed or written by the
 * client; the client only reads it.
 *
 * cleanupViews — the `views` collection is a dedupe table, not analytics. It
 * gets swept so it cannot grow without bound.
 */
import { onSchedule } from "firebase-functions/v2/scheduler";
import {
  db,
  TREND_WEIGHTS,
  TREND_RECOMPUTE_LIMIT,
  VIEW_DEDUPE_HOURS,
} from "../config";

function trendScore(input: {
  like_count: number;
  copy_count: number;
  view_count: number;
  created_at: Date | null;
}): number {
  const likes = Math.max(0, input.like_count);
  const copies = Math.max(0, input.copy_count);
  const views = Math.max(0, input.view_count);

  let recency = 0;
  if (input.created_at) {
    const ageHours = Math.max(0, (Date.now() - input.created_at.getTime()) / 3_600_000);
    const remaining = 1 - Math.min(1, ageHours / TREND_WEIGHTS.recencyWindowHours);
    recency = Math.round(TREND_WEIGHTS.recencyBonusMax * remaining);
  }

  return Math.round(
    likes * TREND_WEIGHTS.like +
      copies * TREND_WEIGHTS.copy +
      views * TREND_WEIGHTS.view +
      recency,
  );
}

export const recomputeTrending = onSchedule("every 15 minutes", async () => {
  let processed = 0;
  let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | null = null;

  while (processed < TREND_RECOMPUTE_LIMIT) {
    let query = db
      .collection("prompts")
      .where("status", "==", "active")
      .limit(400);
    if (lastDoc) query = query.startAfter(lastDoc);

    const snap = await query.get();
    if (snap.empty) break;

    const batch = db.batch();
    for (const doc of snap.docs) {
      const data = doc.data();
      const createdAt =
        data.created_at instanceof Date
          ? data.created_at
          : typeof data.created_at?.toDate === "function"
            ? data.created_at.toDate()
            : null;

      const score = trendScore({
        like_count: Number(data.like_count ?? 0),
        copy_count: Number(data.copy_count ?? 0),
        view_count: Number(data.view_count ?? 0),
        created_at: createdAt,
      });

      if (Number(data.trend_score ?? -1) !== score) {
        batch.update(doc.ref, { trend_score: score });
      }
    }
    await batch.commit();

    processed += snap.size;
    lastDoc = snap.docs[snap.docs.length - 1];
    if (snap.size < 400) break;
  }

  console.log(`recomputeTrending: processed ${processed} prompts`);
});

export const cleanupViews = onSchedule("every 1 hours", async () => {
  const cutoff = new Date(Date.now() - VIEW_DEDUPE_HOURS * 60 * 60 * 1000);
  let deleted = 0;

  for (;;) {
    const snap = await db
      .collection("views")
      .where("created_at", "<", cutoff)
      .limit(400)
      .get();
    if (snap.empty) break;

    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
    deleted += snap.size;
    if (snap.size < 400 || deleted > 20000) break;
  }

  console.log(`cleanupViews: deleted ${deleted} dedupe docs`);
});
