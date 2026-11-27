import { getSupabaseAdmin } from "./supabase-admin";

/**
 * Inserts an immutable audit record into `admin_actions` via service role.
 * Must be called after the admin action succeeds.
 */
export async function audit(
  adminId: string,
  actionType: string,
  targetType: string,
  targetId: string,
  notes = "",
): Promise<void> {
  const { error } = await getSupabaseAdmin()
    .from("admin_actions")
    .insert({
      admin_id: adminId,
      action_type: actionType,
      target_type: targetType,
      target_id: targetId,
      notes: notes.slice(0, 1000),
    });

  if (error) {
    throw new Error(`Failed to write audit log: ${error.message}`);
  }
}
