import { NextResponse } from "next/server";

import { getEnv, getSiteUrl } from "@/lib/env";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// TEMPORARY diagnostic route. Removed after verifying the deployed webhook
// route and the runtime env; it never returns the webhook secret itself.
const TOKEN = "pindo-webhook-test-4f9c2a";

export async function POST(req: Request) {
  const url = new URL(req.url);
  if (url.searchParams.get("token") !== TOKEN) {
    return NextResponse.json({ error: "not_found" }, { status: 404 });
  }

  let body: { fileId?: string };
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: "invalid_json" }, { status: 400 });
  }
  if (!body.fileId) {
    return NextResponse.json({ error: "fileId_required" }, { status: 400 });
  }

  const env = getEnv();
  const siteUrl = getSiteUrl();
  const response = await fetch(`${siteUrl}/api/webhooks/prompt-deleted`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-webhook-secret": env.WEBHOOK_SECRET,
    },
    body: JSON.stringify({
      id: "00000000-0000-4000-8000-000000000001",
      creator_id: "00000000-0000-4000-8000-000000000002",
      thumbnail_path: `appwrite:${body.fileId}`,
    }),
  });

  return NextResponse.json({
    status: response.status,
    body: await response.text(),
    siteUrl,
    webhookSecretLength: env.WEBHOOK_SECRET.length,
    appwriteConfigured: Boolean(
      env.APPWRITE_ENDPOINT &&
        env.APPWRITE_PROJECT_ID &&
        env.APPWRITE_BUCKET_ID &&
        env.APPWRITE_API_KEY,
    ),
  });
}
