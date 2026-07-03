import { supabase } from "@/integrations/supabase/client";
import type { AgencyRole } from "@/hooks/useAgencyRole";
import { isMissingTable } from "@/lib/supabase-errors";

const TABLE = "user_role_preferences";

export interface AgencyPreferences {
  agencyRole?: AgencyRole;
  isEosUser: boolean;
}

export interface DashboardPreferencesRecord {
  ai_digest_enabled: boolean;
  ai_digest_frequency: "weekly" | "daily";
  hide_completed_tasks: boolean;
  primary_pod_id: string | null;
}

export const DEFAULT_DASHBOARD_PREFERENCES: DashboardPreferencesRecord = {
  ai_digest_enabled: true,
  ai_digest_frequency: "weekly",
  hide_completed_tasks: false,
  primary_pod_id: null,
};

interface RolePreferencesMetadata {
  agency_role?: AgencyRole;
  is_eos_user?: boolean;
  ai_digest_enabled?: boolean;
  ai_digest_frequency?: "weekly" | "daily";
  hide_completed_tasks?: boolean;
  primary_pod_id?: string | null;
}

const prefsCache = new Map<string, RolePreferencesMetadata>();

function parseProfileMetadata(metadata: unknown): Record<string, unknown> {
  if (metadata && typeof metadata === "object" && !Array.isArray(metadata)) {
    return metadata as Record<string, unknown>;
  }
  return {};
}

function readRolePrefsFromMetadata(metadata: unknown): RolePreferencesMetadata {
  const root = parseProfileMetadata(metadata);
  const nested = parseProfileMetadata(root.role_preferences);
  return {
    agency_role: (nested.agency_role ?? root.agency_role) as AgencyRole | undefined,
    is_eos_user: (nested.is_eos_user ?? root.is_eos_user) as boolean | undefined,
    ai_digest_enabled: (nested.ai_digest_enabled ?? root.ai_digest_enabled) as boolean | undefined,
    ai_digest_frequency: (nested.ai_digest_frequency ?? root.ai_digest_frequency) as
      | "weekly"
      | "daily"
      | undefined,
    hide_completed_tasks: (nested.hide_completed_tasks ?? root.hide_completed_tasks) as
      | boolean
      | undefined,
    primary_pod_id: (nested.primary_pod_id ?? root.primary_pod_id) as string | null | undefined,
  };
}

function toAgencyPreferences(prefs: RolePreferencesMetadata): AgencyPreferences {
  return {
    agencyRole: prefs.agency_role,
    isEosUser: prefs.is_eos_user ?? false,
  };
}

function toDashboardPreferences(prefs: RolePreferencesMetadata): DashboardPreferencesRecord {
  return {
    ai_digest_enabled: prefs.ai_digest_enabled ?? DEFAULT_DASHBOARD_PREFERENCES.ai_digest_enabled,
    ai_digest_frequency:
      prefs.ai_digest_frequency ?? DEFAULT_DASHBOARD_PREFERENCES.ai_digest_frequency,
    hide_completed_tasks:
      prefs.hide_completed_tasks ?? DEFAULT_DASHBOARD_PREFERENCES.hide_completed_tasks,
    primary_pod_id: prefs.primary_pod_id ?? DEFAULT_DASHBOARD_PREFERENCES.primary_pod_id,
  };
}

async function readProfileMetadata(userId: string): Promise<Record<string, unknown>> {
  const { data, error } = await supabase
    .from("profiles")
    .select("metadata")
    .eq("id", userId)
    .maybeSingle();

  if (error) {
    throw error;
  }

  return parseProfileMetadata(data?.metadata);
}

async function writeRolePrefsToProfile(
  userId: string,
  patch: RolePreferencesMetadata
): Promise<void> {
  const metadata = await readProfileMetadata(userId);
  const existing = readRolePrefsFromMetadata(metadata);
  const nextPrefs: RolePreferencesMetadata = { ...existing, ...patch };

  const { error } = await supabase
    .from("profiles")
    .update({
      metadata: {
        ...metadata,
        role_preferences: nextPrefs,
        agency_role: nextPrefs.agency_role ?? null,
        is_eos_user: nextPrefs.is_eos_user ?? false,
      },
    })
    .eq("id", userId);

  if (error) {
    throw error;
  }

  prefsCache.set(userId, nextPrefs);
}

function readCachedPrefs(userId: string): RolePreferencesMetadata | null {
  return prefsCache.get(userId) ?? null;
}

async function readPrefsFromProfile(userId: string): Promise<RolePreferencesMetadata> {
  const cached = readCachedPrefs(userId);
  if (cached) return cached;

  const metadata = await readProfileMetadata(userId);
  const prefs = readRolePrefsFromMetadata(metadata);
  prefsCache.set(userId, prefs);
  return prefs;
}

async function readPrefsFromTable(userId: string): Promise<RolePreferencesMetadata | null> {
  const { data, error } = await (supabase as any)
    .from(TABLE)
    .select(
      "agency_role, is_eos_user, ai_digest_enabled, ai_digest_frequency, hide_completed_tasks, primary_pod_id"
    )
    .eq("user_id", userId)
    .limit(1)
    .maybeSingle();

  if (error) {
    if (isMissingTable(error, TABLE)) {
      return readPrefsFromProfile(userId);
    }
    throw error;
  }

  if (!data) {
    return readPrefsFromProfile(userId);
  }

  const prefs: RolePreferencesMetadata = {
    agency_role: data.agency_role as AgencyRole | undefined,
    is_eos_user: data.is_eos_user,
    ai_digest_enabled: data.ai_digest_enabled,
    ai_digest_frequency: data.ai_digest_frequency,
    hide_completed_tasks: data.hide_completed_tasks,
    primary_pod_id: data.primary_pod_id,
  };
  prefsCache.set(userId, prefs);
  return prefs;
}

export async function getAgencyPreferences(userId: string): Promise<AgencyPreferences> {
  const prefs = await readPrefsFromTable(userId);
  return toAgencyPreferences(prefs ?? {});
}

export async function getDashboardPreferences(
  userId: string
): Promise<DashboardPreferencesRecord> {
  const prefs = await readPrefsFromTable(userId);
  return toDashboardPreferences(prefs ?? {});
}

export async function saveAgencyRolePreferences(
  userId: string,
  agencyRole: AgencyRole,
  isEosUser: boolean
): Promise<void> {
  const payload = {
    user_id: userId,
    role: "user" as const,
    agency_role: agencyRole,
    is_eos_user: isEosUser,
  };

  const { error } = await (supabase as any)
    .from(TABLE)
    .upsert(payload, { onConflict: "user_id,role" });

  if (!error) {
    prefsCache.set(userId, {
      ...(readCachedPrefs(userId) ?? {}),
      agency_role: agencyRole,
      is_eos_user: isEosUser,
    });
    return;
  }

  if (!isMissingTable(error, TABLE)) {
    throw error;
  }

  await writeRolePrefsToProfile(userId, {
    agency_role: agencyRole,
    is_eos_user: isEosUser,
  });
}

export async function saveDashboardPreferences(
  userId: string,
  patch: Partial<DashboardPreferencesRecord>
): Promise<void> {
  const { error } = await (supabase as any).from(TABLE).upsert(
    { user_id: userId, role: "user", ...patch },
    { onConflict: "user_id,role" }
  );

  if (!error) {
    prefsCache.set(userId, {
      ...(readCachedPrefs(userId) ?? {}),
      ...patch,
    });
    return;
  }

  if (!isMissingTable(error, TABLE)) {
    throw error;
  }

  await writeRolePrefsToProfile(userId, patch);
}

export async function listAgencyRolePreferences(): Promise<
  Array<{
    user_id: string;
    agency_role: AgencyRole | null;
    is_eos_user: boolean;
  }>
> {
  const { data, error } = await (supabase as any)
    .from(TABLE)
    .select("user_id, agency_role, is_eos_user");

  if (!error) {
    return (data ?? []) as Array<{
      user_id: string;
      agency_role: AgencyRole | null;
      is_eos_user: boolean;
    }>;
  }

  if (!isMissingTable(error, TABLE)) {
    throw error;
  }

  const { data: profiles, error: profilesError } = await supabase
    .from("profiles")
    .select("id, metadata");

  if (profilesError) {
    throw profilesError;
  }

  return (profiles ?? []).map((profile) => {
    const prefs = readRolePrefsFromMetadata(profile.metadata);
    return {
      user_id: profile.id,
      agency_role: prefs.agency_role ?? null,
      is_eos_user: prefs.is_eos_user ?? false,
    };
  });
}

export async function adminSaveAgencyRolePreferences(
  userId: string,
  agencyRole: AgencyRole | null,
  isEosUser = false
): Promise<void> {
  if (agencyRole) {
    await saveAgencyRolePreferences(userId, agencyRole, isEosUser);
    return;
  }

  const { error } = await (supabase as any)
    .from(TABLE)
    .delete()
    .eq("user_id", userId)
    .eq("role", "user");

  if (error && !isMissingTable(error, TABLE)) {
    throw error;
  }

  const metadata = await readProfileMetadata(userId);
  const existing = readRolePrefsFromMetadata(metadata);
  const nextPrefs: RolePreferencesMetadata = { ...existing, is_eos_user: false };
  delete nextPrefs.agency_role;

  const { error: profileError } = await supabase
    .from("profiles")
    .update({
      metadata: {
        ...metadata,
        role_preferences: nextPrefs,
        agency_role: null,
        is_eos_user: false,
      },
    })
    .eq("id", userId);

  if (profileError) {
    throw profileError;
  }

  prefsCache.set(userId, nextPrefs);
}
