/**
 * Shared configuration + small helpers for every PromptIndo Cloud Function.
 *
 * Everything that must NOT run on the Flutter client lives behind these
 * helpers: counters, notifications, moderation state and admin actions.
 */
import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { getApps, initializeApp } from "firebase-admin/app";

if (getApps().length === 0) {
  initializeApp();
}

export const db = getFirestore();
export const bucket = getStorage().bucket();

// ---------------------------------------------------------------------------
// Tunables (mirroring the PHP backend's constants)
// ---------------------------------------------------------------------------

/** Hours during which a repeat view from the same viewer is ignored. */
export const VIEW_DEDUPE_HOURS = 24;

/** trend_score = likes*3 + copies*5 + views*1 + recency_bonus */
export const TREND_WEIGHTS = {
  like: 3,
  copy: 5,
  view: 1,
  /** Full recency bonus at publish time, decaying linearly over this window. */
  recencyWindowHours: 48,
  recencyBonusMax: 40,
};

/** One report per reporter per target inside this window is rejected. */
export const REPORT_DUPLICATE_WINDOW_HOURS = 1;

/** Hard cap per scheduled recompute run so a huge corpus cannot time out. */
export const TREND_RECOMPUTE_LIMIT = 3000;

/**
 * App Check enforcement for callable functions. Flip to `false` only while you
 * are still enrolling the Play Integrity provider (README → "App Check"), then
 * flip back — this is the Firebase equivalent of the PHP backend's rate
 * limiting/CORS hardening.
 */
// Keep this off for sideloaded/debug builds. Re-enable after Play Integrity is
// enrolled and verified on the Play-distributed release build.
export const APP_CHECK_ENFORCED = false;

export const NOTIFICATION_TYPES = [
  "like",
  "comment",
  "reply",
  "comment_like",
  "follow",
  "remix",
  "report_resolved",
  "system",
] as const;
export type NotificationType = (typeof NOTIFICATION_TYPES)[number];

// ---------------------------------------------------------------------------
// Small utilities
// ---------------------------------------------------------------------------

export function now() {
  return new Date();
}

export function serverTimestamp() {
  return new Date();
}

export function isNonEmptyString(v: unknown, max: number): v is string {
  return typeof v === "string" && v.trim().length > 0 && v.length <= max;
}

export function promptIdFromLikeId(likeId: string): string | null {
  const i = likeId.indexOf("_");
  return i > 0 && i < likeId.length - 1 ? likeId.slice(i + 1) : null;
}

export class HttpsErrorLike extends Error {
  constructor(
    public code: string,
    message: string,
  ) {
    super(message);
  }
}

/**
 * Increment/decrement an integer counter without ever letting it go negative.
 * `FieldValue.increment` alone can drift below zero if data was ever edited
 * out-of-band, so we clamp inside a transaction.
 */
export async function adjustCounter(
  ref: FirebaseFirestore.DocumentReference,
  field: string,
  delta: number,
): Promise<number> {
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return 0;
    const current = Number(snap.get(field) ?? 0);
    const next = Math.max(0, current + delta);
    tx.update(ref, { [field]: next });
    return next;
  });
}

/** Best-effort delete of a storage object, never throwing. */
export async function deleteObjectSafe(path: string): Promise<void> {
  try {
    await bucket.file(path).delete({ ignoreNotFound: true });
  } catch (err) {
    // Storage cleanup is never worth failing a trigger over.
    console.warn(`deleteObjectSafe(${path}) failed`, err);
  }
}

/** Page through a query and delete every doc (used by account deletion). */
export async function deleteQueryBatch(
  query: FirebaseFirestore.Query,
  pageSize = 400,
): Promise<number> {
  let deleted = 0;
  for (;;) {
    const snap = await query.limit(pageSize).get();
    if (snap.empty) break;
    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
    deleted += snap.size;
    if (snap.size < pageSize) break;
  }
  return deleted;
}
