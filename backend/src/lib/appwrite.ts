import { Client, Storage } from "node-appwrite";

import { getEnv } from "./env";

export interface AppwriteConfig {
  endpoint: string;
  projectId: string;
  bucketId: string;
  apiKey: string;
}

let cachedStorage: Storage | null = null;

/**
 * Returns the server-only Appwrite config, failing clearly when a required
 * Vercel env var is missing. The API key never leaves the backend.
 */
export function getAppwriteConfig(): AppwriteConfig {
  const env = getEnv();
  const config = {
    endpoint: env.APPWRITE_ENDPOINT.replace(/\/+$/, ""),
    projectId: env.APPWRITE_PROJECT_ID,
    bucketId: env.APPWRITE_BUCKET_ID,
    apiKey: env.APPWRITE_API_KEY,
  };

  if (
    !config.endpoint ||
    !config.projectId ||
    !config.bucketId ||
    !config.apiKey
  ) {
    throw new Error(
      "Appwrite is not configured: APPWRITE_ENDPOINT, APPWRITE_PROJECT_ID, APPWRITE_BUCKET_ID and APPWRITE_API_KEY are required.",
    );
  }

  return config;
}

export function getAppwriteStorage(): Storage {
  if (cachedStorage) return cachedStorage;
  const config = getAppwriteConfig();
  const client = new Client()
    .setEndpoint(config.endpoint)
    .setProject(config.projectId)
    .setKey(config.apiKey);
  cachedStorage = new Storage(client);
  return cachedStorage;
}

/**
 * Public view URL for a file. Appwrite buckets are configured with
 * `read("any")`; this URL is safe to store on the prompt row.
 */
export function appwriteFileUrl(fileId: string): string {
  const config = getAppwriteConfig();
  return `${config.endpoint}/storage/buckets/${config.bucketId}/files/${fileId}/view?project=${config.projectId}`;
}

/** Only server-generated Appwrite IDs are ever passed to the delete API. */
export function isSafeAppwriteFileId(fileId: string): boolean {
  return /^[A-Za-z0-9][A-Za-z0-9._-]{0,35}$/.test(fileId);
}

/**
 * Deletes the Appwrite object referenced by `appwrite:<fileId>`.
 * Returns false for legacy Supabase paths. Missing files are treated as
 * already deleted so retries/triggers stay idempotent.
 */
export async function deleteAppwriteRef(ref: string): Promise<boolean> {
  if (!ref.startsWith("appwrite:")) return false;
  const fileId = ref.slice("appwrite:".length);
  if (!isSafeAppwriteFileId(fileId)) {
    throw new Error("Invalid Appwrite file reference.");
  }
  try {
    const config = getAppwriteConfig();
    await getAppwriteStorage().deleteFile(config.bucketId, fileId);
  } catch (err) {
    const code = String((err as { code?: number | string }).code ?? "");
    const message = String(
      (err as { message?: string }).message ?? "",
    ).toLowerCase();
    if (code === "404" || message.includes("not found")) return false;
    throw err;
  }
  return true;
}

export function resetAppwriteForTests(): void {
  cachedStorage = null;
}
