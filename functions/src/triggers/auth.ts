/**
 * Auth triggers.
 *
 * The Flutter client is NEVER allowed to create its own `users/{uid}` doc
 * (firestore.rules: `allow create: if false`). Provisioning happens here so a
 * profile always exists consistently no matter how the user signed in.
 */
import * as functionsV1 from "firebase-functions/v1";
import { HttpsError, onCall, CallableRequest } from "firebase-functions/v2/https";
import { db, now, APP_CHECK_ENFORCED } from "../config";

function sanitizeBase(input: string): string {
  const lowered = input.toLowerCase().replace(/[^a-z0-9_]/g, "");
  return lowered;
}

/** Deterministic-ish first candidate: name → email local-part → "user". */
function candidateBase(displayName?: string | null, email?: string | null): string {
  const fromName = sanitizeBase(displayName ?? "");
  const fromEmail = sanitizeBase((email ?? "").split("@")[0] ?? "");
  let base = fromName.length >= 3 ? fromName : fromEmail;
  if (base.length > 20) base = base.slice(0, 20);
  if (base.length < 3) base = `user_${base}`.slice(0, 20);
  if (base.length < 3) base = "user";
  return base;
}

async function usernameTaken(usernameLower: string): Promise<boolean> {
  const snap = await db
    .collection("users")
    .where("username_lower", "==", usernameLower)
    .limit(1)
    .get();
  return !snap.empty;
}

/**
 * Best-effort unique username. Uniqueness cannot be proven inside Firestore
 * security rules (rules have no query access), so we check here and the
 * client re-checks availability on the register screen. The residual race
 * window is documented in README.
 */
async function uniqueUsername(base: string): Promise<string> {
  for (let attempt = 0; attempt < 8; attempt++) {
    const suffix =
      attempt === 0 ? "" : Math.floor(Math.random() * 900 + 100).toString();
    const candidate = `${base}${suffix}`.slice(0, 24);
    if (!(await usernameTaken(candidate))) return candidate;
  }
  const fallback = `user_${Date.now().toString(36)}`.slice(0, 24);
  return fallback;
}

export const onUserCreate = functionsV1
  .auth
  .user()
  .onCreate(async (user) => {
    const displayName = user.displayName ?? null;
    const email = user.email ?? null;

    const base = candidateBase(displayName, email);
    const username = await uniqueUsername(base);

    // create() (not set): never overwrite a profile the client already
    // self-healed / the user already edited. ALREADY_EXISTS (code 6) is fine.
    const ignoreExists = (err: unknown) => {
      if ((err as { code?: number }).code === 6) return;
      throw err;
    };

    // Public profile doc (no email — that lives in users_private).
    await db.doc(`users/${user.uid}`).create({
      uid: user.uid,
      name: displayName ?? username,
      username,
      username_lower: username.toLowerCase(),
      avatar_url: user.photoURL ?? "",
      bio: "",
      role: "user",
      status: "active",
      follower_count: 0,
      following_count: 0,
      prompt_count: 0,
      total_likes_received: 0,
      created_at: now(),
      updated_at: now(),
    }).catch(ignoreExists);

    // Private doc — readable only by the owner (or an admin).
    await db.doc(`users_private/${user.uid}`).create({
      uid: user.uid,
      email: email ?? "",
      email_verified: user.emailVerified ?? false,
      provider_ids: user.providerData.map((p) => p.providerId),
      created_at: now(),
    }).catch(ignoreExists);
  });

/**
 * Repairs profiles for Auth users created before the trigger was deployed or
 * after an interrupted provisioning attempt. It only creates missing docs and
 * never overwrites an existing public profile or username.
 */
export const ensureUserProfile = onCall(
  { enforceAppCheck: APP_CHECK_ENFORCED },
  async (request: CallableRequest) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "You must be signed in.");
    }

    const uid = request.auth.uid;
    const authName = typeof request.auth.token.name === "string"
      ? request.auth.token.name
      : "";
    const email = typeof request.auth.token.email === "string"
      ? request.auth.token.email
      : "";
    const base = candidateBase(authName, email);
    const publicRef = db.doc(`users/${uid}`);
    const privateRef = db.doc(`users_private/${uid}`);
    const existing = await publicRef.get();

    if (!existing.exists) {
      const username = await uniqueUsername(base);
      await db.runTransaction(async (tx) => {
        const current = await tx.get(publicRef);
        if (!current.exists) {
          tx.create(publicRef, {
            uid,
            name: authName || username,
            username,
            username_lower: username.toLowerCase(),
            avatar_url: "",
            bio: "",
            role: "user",
            status: "active",
            follower_count: 0,
            following_count: 0,
            prompt_count: 0,
            total_likes_received: 0,
            created_at: now(),
            updated_at: now(),
          });
        }
      });
    }

    const privateSnap = await privateRef.get();
    if (!privateSnap.exists) {
      await privateRef.create({
        uid,
        email,
        email_verified: false,
        provider_ids: [],
        created_at: now(),
      });
    }

    return { ok: true };
  },
);

/**
 * Banning revokes refresh tokens server-side (mirrors the PHP backend's
 * "revoke everything"). The trigger itself only handles soft profile state;
 * the actual revoke lives in the adminSetUserStatus callable.
 */
export const onUserDelete = functionsV1
  .auth
  .user()
  .onDelete(async (user) => {
    // Account deletion normally goes through deleteUserAccount (which already
    // cleans Firestore). This is the safety net if an account is deleted from
    // the Firebase console instead.
    await db.doc(`users/${user.uid}`).delete().catch(() => undefined);
    await db.doc(`users_private/${user.uid}`).delete().catch(() => undefined);
  });
