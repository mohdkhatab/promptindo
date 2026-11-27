/**
 * Admin callables.
 *
 * Every moderation action the PHP backend exposed as an admin controller
 * endpoint is mirrored here as a callable, because the same server-side
 * effects have to happen every time: audit logging into `admin_actions`,
 * refresh-token revocation on ban, and cascading prompt state changes.
 *
 * Authorization uses the `role: "admin"` custom claim ONLY — never a
 * client-writable Firestore field.
 */
import { HttpsError, onCall, CallableRequest } from "firebase-functions/v2/https";
import { getAuth } from "firebase-admin/auth";
import { db, now, adjustCounter, deleteObjectSafe } from "../config";
import { createNotification } from "../notify";

function requireAuth(request: CallableRequest): string {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  return request.auth.uid;
}

async function requireAdmin(request: CallableRequest): Promise<string> {
  const uid = requireAuth(request);
  if (request.auth!.token?.role !== "admin") {
    throw new HttpsError("permission-denied", "Admin only.");
  }
  return uid;
}

function requireString(data: any, key: string, max = 200): string {
  const value = data?.[key];
  if (typeof value !== "string" || value.trim().length === 0 || value.length > max) {
    throw new HttpsError("invalid-argument", `${key} is required.`);
  }
  return value;
}

async function audit(
  adminId: string,
  actionType: string,
  targetType: string,
  targetId: string,
  notes = "",
): Promise<void> {
  await db.collection("admin_actions").add({
    admin_id: adminId,
    action_type: actionType,
    target_type: targetType,
    target_id: targetId,
    notes: notes.slice(0, 1000),
    created_at: now(),
  });
}

function safeThumbPath(path: unknown, creatorId: string, promptId: string): string | null {
  if (typeof path !== "string" || !path) return null;
  const prefixes = [`thumbnails/${creatorId}/`, `thumbnails/${promptId}/`];
  return prefixes.some((p) => path.startsWith(p)) ? path : null;
}

// ---------------------------------------------------------------------------
// Users
// ---------------------------------------------------------------------------

/**
 * ban / unban. Banning also revokes every refresh token (mirrors PHP's
 * "revoke everything") so the session dies immediately instead of at next
 * token refresh, and the Flutter client double-checks `users.status` on start.
 */
export const adminSetUserStatus = onCall(async (request) => {
  const adminId = await requireAdmin(request);
  const uid = requireString(request.data, "uid", 128);
  const status = requireString(request.data, "status", 16);
  const notes = typeof request.data?.notes === "string" ? request.data.notes : "";

  if (!["active", "banned"].includes(status)) {
    throw new HttpsError("invalid-argument", "status must be active or banned.");
  }

  const userRef = db.doc(`users/${uid}`);
  const snap = await userRef.get();
  if (!snap.exists) throw new HttpsError("not-found", "User not found.");

  await userRef.update({ status, updated_at: now() });

  if (status === "banned") {
    await getAuth().revokeRefreshTokens(uid).catch((err) => {
      console.warn("revokeRefreshTokens failed", err);
    });
  }

  await audit(adminId, status === "banned" ? "ban_user" : "unban_user", "user", uid, notes);
  return { ok: true, uid, status };
});

/** Promote/demote via custom claim (never a client-writable field). */
export const adminSetRole = onCall(async (request) => {
  const adminId = await requireAdmin(request);
  const uid = requireString(request.data, "uid", 128);
  const role = requireString(request.data, "role", 16);
  if (!["user", "admin"].includes(role)) {
    throw new HttpsError("invalid-argument", "role must be user or admin.");
  }
  const existing = await getAuth().getUser(uid).catch(() => null);
  if (!existing) throw new HttpsError("not-found", "Auth user not found.");

  const claims: Record<string, string> = { ...(existing.customClaims ?? {}) };
  if (role === "admin") claims.role = "admin";
  else delete claims.role;
  await getAuth().setCustomUserClaims(uid, claims);
  await db.doc(`users/${uid}`).set({ role, updated_at: now() }, { merge: true });
  await audit(adminId, `set_role_${role}`, "user", uid, "");
  return { ok: true, uid, role };
});

// ---------------------------------------------------------------------------
// Prompts
// ---------------------------------------------------------------------------

export const adminSetPromptStatus = onCall(async (request) => {
  const adminId = await requireAdmin(request);
  const promptId = requireString(request.data, "promptId", 64);
  const status = requireString(request.data, "status", 16);
  const notes = typeof request.data?.notes === "string" ? request.data.notes : "";

  if (!["active", "hidden", "removed"].includes(status)) {
    throw new HttpsError("invalid-argument", "Invalid status.");
  }
  const ref = db.doc(`prompts/${promptId}`);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError("not-found", "Prompt not found.");

  await ref.update({ status, updated_at: now() });
  await audit(adminId, `prompt_${status}`, "prompt", promptId, notes);
  return { ok: true, promptId, status };
});

export const adminSetPromptFeatured = onCall(async (request) => {
  const adminId = await requireAdmin(request);
  const promptId = requireString(request.data, "promptId", 64);
  const featured = request.data?.featured === true;
  const notes = typeof request.data?.notes === "string" ? request.data.notes : "";

  const ref = db.doc(`prompts/${promptId}`);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError("not-found", "Prompt not found.");

  await ref.update({ is_featured: featured, updated_at: now() });
  await audit(adminId, featured ? "feature_prompt" : "unfeature_prompt", "prompt", promptId, notes);
  return { ok: true, promptId, featured };
});

/**
 * Hard-delete a prompt (report resolution / Takedown). Deleting the doc fires
 * onPromptDelete, which performs the cascade + Storage cleanup.
 */
export const adminDeletePrompt = onCall(async (request) => {
  const adminId = await requireAdmin(request);
  const promptId = requireString(request.data, "promptId", 64);
  const notes = typeof request.data?.notes === "string" ? request.data.notes : "";

  const ref = db.doc(`prompts/${promptId}`);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError("not-found", "Prompt not found.");

  const prompt = snap.data()!;
  const thumbPath = safeThumbPath(
    prompt.thumbnail_path,
    String(prompt.creator_id ?? ""),
    promptId,
  );
  if (thumbPath) await deleteObjectSafe(thumbPath);

  await ref.delete(); // → onPromptDelete cascade
  await audit(adminId, "delete_prompt", "prompt", promptId, notes);
  return { ok: true, promptId };
});

// ---------------------------------------------------------------------------
// Comments
// ---------------------------------------------------------------------------

/** Soft-delete: status becomes `removed`, rules stop serving it. */
export const adminDeleteComment = onCall(async (request) => {
  const adminId = await requireAdmin(request);
  const commentId = requireString(request.data, "commentId", 64);
  const notes = typeof request.data?.notes === "string" ? request.data.notes : "";

  const ref = db.doc(`comments/${commentId}`);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError("not-found", "Comment not found.");

  const comment = snap.data()!;
  await db.runTransaction(async (tx) => {
    const fresh = await tx.get(ref);
    if (!fresh.exists) return;
    tx.update(ref, { status: "removed" });
  });
  if (comment.prompt_id) {
    await adjustCounter(db.doc(`prompts/${comment.prompt_id}`), "comment_count", -1);
  }
  await audit(adminId, "delete_comment", "comment", commentId, notes);
  return { ok: true, commentId };
});

// ---------------------------------------------------------------------------
// Reports
// ---------------------------------------------------------------------------

export const adminResolveReport = onCall(async (request) => {
  const adminId = await requireAdmin(request);
  const reportId = requireString(request.data, "reportId", 64);
  const status = requireString(request.data, "status", 16);
  const resolutionNote =
    typeof request.data?.resolution_note === "string" ? request.data.resolution_note : "";

  if (!["resolved", "rejected"].includes(status)) {
    throw new HttpsError("invalid-argument", "status must be resolved or rejected.");
  }

  const ref = db.doc(`reports/${reportId}`);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError("not-found", "Report not found.");

  await ref.update({
    status,
    resolution_note: resolutionNote.slice(0, 1000),
    resolved_by: adminId,
    resolved_at: now(),
  });

  await audit(adminId, `report_${status}`, "report", reportId, resolutionNote);

  const reporterId = String(snap.data()!.reporter_id ?? "");
  if (reporterId) {
    await createNotification({
      recipientId: reporterId,
      actorId: adminId,
      type: "report_resolved",
      data: { report_id: reportId, status },
    });
  }

  return { ok: true, reportId, status };
});

// ---------------------------------------------------------------------------
// Categories
// ---------------------------------------------------------------------------

export const adminSaveCategory = onCall(async (request) => {
  const adminId = await requireAdmin(request);
  const name = requireString(request.data, "name", 60);
  const slug = requireString(request.data, "slug", 60).toLowerCase();
  const icon = typeof request.data?.icon === "string" ? request.data.icon : "";
  const description =
    typeof request.data?.description === "string" ? request.data.description : "";
  const sortOrder = Number(request.data?.sort_order ?? 0);

  const dupes = await db
    .collection("categories")
    .where("slug", "==", slug)
    .limit(2)
    .get();
  const id = typeof request.data?.id === "string" && request.data.id ? request.data.id : "";
  const existing = dupes.docs.find((d) => d.id !== id);
  if (existing) throw new HttpsError("already-exists", "Slug already in use.");

  const ref = id ? db.doc(`categories/${id}`) : db.collection("categories").doc();
  await ref.set({
    name,
    slug,
    icon,
    description: description.slice(0, 500),
    sort_order: Number.isFinite(sortOrder) ? sortOrder : 0,
    updated_at: now(),
  }, { merge: id.length > 0 });

  await audit(adminId, id ? "update_category" : "create_category", "category", ref.id, name);
  return { ok: true, id: ref.id };
});

export const adminDeleteCategory = onCall(async (request) => {
  const adminId = await requireAdmin(request);
  const id = requireString(request.data, "id", 64);
  const ref = db.doc(`categories/${id}`);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError("not-found", "Category not found.");

  // Prompts keep their `category_id`; the client renders a missing category
  // gracefully and the category-filtered feed simply returns nothing new.
  await ref.delete();
  await audit(adminId, "delete_category", "category", id, "");
  return { ok: true, id };
});
