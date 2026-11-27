import { cert, getApp, getApps, initializeApp } from "firebase-admin/app";
import { getMessaging, type Messaging } from "firebase-admin/messaging";
import { getEnv } from "./env";

let cachedMessaging: Messaging | null = null;

interface ServiceAccountJson {
  project_id: string;
  client_email: string;
  private_key: string;
}

function parseServiceAccount(base64: string): ServiceAccountJson {
  const decoded = Buffer.from(base64, "base64").toString("utf8");
  const parsed = JSON.parse(decoded) as Partial<ServiceAccountJson>;
  if (!parsed.project_id || !parsed.client_email || !parsed.private_key) {
    throw new Error(
      "FIREBASE_SERVICE_ACCOUNT_BASE64 must decode to valid service account JSON",
    );
  }
  return {
    project_id: parsed.project_id,
    client_email: parsed.client_email,
    private_key: parsed.private_key,
  };
}

/**
 * Module-scope singleton Firebase Messaging client (FCM only).
 */
export function getFcmMessaging(): Messaging {
  if (cachedMessaging && process.env.NODE_ENV !== "test") {
    return cachedMessaging;
  }

  const env = getEnv();
  const sa = parseServiceAccount(env.FIREBASE_SERVICE_ACCOUNT_BASE64);
  const app =
    getApps().length > 0
      ? getApp()
      : initializeApp({
          credential: cert({
            projectId: sa.project_id,
            clientEmail: sa.client_email,
            privateKey: sa.private_key,
          }),
        });

  cachedMessaging = getMessaging(app);
  return cachedMessaging;
}

export function resetFcmForTests(): void {
  cachedMessaging = null;
}
