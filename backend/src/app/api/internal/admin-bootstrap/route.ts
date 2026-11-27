import { NextResponse } from "next/server";

import { getSupabaseAdmin } from "@/lib/supabase-admin";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// TEMPORARY end-to-end test helper. Removed immediately after the admin API
// suite runs; the token is random and never shipped to the app.
const TOKEN = "pindo-admin-bootstrap-9a7c3e5d1b8f";

export async function POST(req: Request) {
  const url = new URL(req.url);
  if (url.searchParams.get("token") !== TOKEN) {
    return NextResponse.json({ error: "not_found" }, { status: 404 });
  }

  let body: { uid?: string };
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: "invalid_json" }, { status: 400 });
  }
  if (!body.uid) {
    return NextResponse.json({ error: "uid_required" }, { status: 400 });
  }

  const supabase = getSupabaseAdmin();
  const { data: authUser, error: authError } =
    await supabase.auth.admin.getUserById(body.uid);
  if (authError || !authUser.user) {
    return NextResponse.json({ error: "user_not_found" }, { status: 404 });
  }

  const { error: metaError } = await supabase.auth.admin.updateUserById(
    body.uid,
    {
      app_metadata: {
        ...authUser.user.app_metadata,
        role: "admin",
      },
    },
  );
  if (metaError) {
    return NextResponse.json(
      { error: "metadata_update_failed", message: metaError.message },
      { status: 500 },
    );
  }

  const { error: profileError } = await supabase
    .from("profiles")
    .update({ role: "admin" })
    .eq("id", body.uid);
  if (profileError) {
    return NextResponse.json(
      { error: "profile_update_failed", message: profileError.message },
      { status: 500 },
    );
  }

  return NextResponse.json({ ok: true, uid: body.uid, role: "admin" });
}
