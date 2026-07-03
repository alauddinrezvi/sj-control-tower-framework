import { supabase } from "@/integrations/supabase/client";
import { isMissingRpc } from "@/lib/supabase-errors";

const ADMIN_PERMISSION_FALLBACK = [
  "settings.admin",
  "users.admin",
  "integrations.admin",
  "ai_hub.admin",
  "knowledge.admin",
  "settings.view",
  "users.view",
  "integrations.view",
  "ai_hub.view",
] as const;

const MODERATOR_PERMISSION_FALLBACK = [
  "settings.view",
  "users.view",
  "integrations.view",
  "ai_hub.view",
] as const;

async function fetchLegacyRolePermissions(userId: string): Promise<string[]> {
  const { data, error } = await supabase
    .from("user_roles")
    .select("role")
    .eq("user_id", userId);

  if (error) {
    console.warn("user_roles fallback unavailable:", error.message);
    return [];
  }

  const roles = (data ?? []).map((row) => row.role);
  if (roles.includes("admin")) {
    return [...ADMIN_PERMISSION_FALLBACK];
  }
  if (roles.includes("moderator")) {
    return [...MODERATOR_PERMISSION_FALLBACK];
  }
  return [];
}

export async function fetchUserPermissions(userId: string): Promise<string[]> {
  const { data, error } = await supabase.rpc("get_user_permissions", {
    _user_id: userId,
  });

  if (!error) {
    return (data ?? []) as string[];
  }

  if (isMissingRpc(error, "get_user_permissions")) {
    console.warn("get_user_permissions RPC missing — using user_roles fallback");
    return fetchLegacyRolePermissions(userId);
  }

  throw error;
}
