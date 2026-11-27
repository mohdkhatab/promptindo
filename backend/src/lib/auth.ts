import crypto from "node:crypto";
import { getEnv } from "./env";
import { ApiError, type RequestLogContext } from "./http";
import { getSupabaseAdmin } from "./supabase-admin";

export interface AuthenticatedUser {
  uid: string;
  claims: Record<string, unknown>;
}

function extractBearerToken(req: Request): string {
  const header = req.headers.get("authorization");
  if (!header) {
    throw new ApiError(401, "unauthorized", "Missing Authorization header.");
  }
  const match = /^Bearer\s+(\S+)$/i.exec(header.trim());
  if (!match?.[1]) {
    throw new ApiError(
      401,
      "unauthorized",
      "Authorization header must be a Bearer token.",
    );
  }
  return match[1];
}

/**
 * Verifies the Supabase access token from `Authorization: Bearer <token>`.
 * Uses `auth.getClaims(token)` (local JWKS verification) when available,
 * falling back to `auth.getUser(token)`.
 */
export async function requireUser(
  req: Request,
  logCtx?: RequestLogContext,
): Promise<AuthenticatedUser> {
  const token = extractBearerToken(req);
  const supabase = getSupabaseAdmin();

  let uid: string | undefined;
  let claims: Record<string, unknown> = {};

  if (typeof supabase.auth.getClaims === "function") {
    const { data, error } = await supabase.auth.getClaims(token);
    if (error || !data?.claims?.sub) {
      throw new ApiError(401, "unauthorized", "Invalid or expired token.");
    }
    uid = String(data.claims.sub);
    claims = data.claims as Record<string, unknown>;
  } else {
    const { data, error } = await supabase.auth.getUser(token);
    if (error || !data?.user?.id) {
      throw new ApiError(401, "unauthorized", "Invalid or expired token.");
    }
    uid = data.user.id;
    claims = {
      sub: data.user.id,
      app_metadata: data.user.app_metadata ?? {},
      user_metadata: data.user.user_metadata ?? {},
    };
  }

  if (logCtx) {
    logCtx.userId = uid;
  }

  return { uid, claims };
}

/**
 * Requires both `app_metadata.role === "admin"` on the JWT AND a fresh DB
 * check confirming `profiles.role === "admin"` and `profiles.status === "active"`.
 */
export async function requireAdmin(
  req: Request,
  logCtx?: RequestLogContext,
): Promise<AuthenticatedUser> {
  const user = await requireUser(req, logCtx);
  const appMeta = user.claims.app_metadata;
  const jwtRole =
    appMeta && typeof appMeta === "object"
      ? (appMeta as Record<string, unknown>).role
      : undefined;

  if (jwtRole !== "admin") {
    throw new ApiError(403, "forbidden", "Admin access required.");
  }

  const { data: profile, error } = await getSupabaseAdmin()
    .from("profiles")
    .select("role, status")
    .eq("id", user.uid)
    .maybeSingle();

  if (error) {
    throw new ApiError(
      500,
      "internal_error",
      "Failed to verify administrator status.",
    );
  }

  if (!profile || profile.role !== "admin" || profile.status !== "active") {
    throw new ApiError(403, "forbidden", "Admin access required.");
  }

  return user;
}

/**
 * Verifies the `x-webhook-secret` header using `crypto.timingSafeEqual`
 * over fixed-length SHA-256 digests so lengths are never leaked.
 */
export function requireWebhookSecret(req: Request): void {
  const provided = req.headers.get("x-webhook-secret");
  if (!provided) {
    throw new ApiError(401, "unauthorized", "Missing webhook secret.");
  }

  const expected = getEnv().WEBHOOK_SECRET;
  const providedDigest = crypto
    .createHash("sha256")
    .update(provided, "utf8")
    .digest();
  const expectedDigest = crypto
    .createHash("sha256")
    .update(expected, "utf8")
    .digest();

  if (!crypto.timingSafeEqual(providedDigest, expectedDigest)) {
    throw new ApiError(401, "unauthorized", "Invalid webhook secret.");
  }
}
