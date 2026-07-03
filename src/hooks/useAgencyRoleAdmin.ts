import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { supabase } from "@/integrations/supabase/client";
import { cacheConfig } from "@/lib/cache";
import type { AgencyRole } from "@/hooks/useAgencyRole";
import {
  adminSaveAgencyRolePreferences,
  listAgencyRolePreferences,
} from "@/lib/role-preferences-storage";

export interface UserAgencyRow {
  user_id: string;
  full_name: string | null;
  email: string | null;
  avatar_url: string | null;
  agency_role: AgencyRole | null;
  is_eos_user: boolean;
  has_prefs: boolean;
}

const ADMIN_AGENCY_ROLES_KEY = ["admin", "agencyRoles"] as const;

export function useAgencyRoleAdmin() {
  return useQuery<UserAgencyRow[]>({
    queryKey: ADMIN_AGENCY_ROLES_KEY,
    queryFn: async (): Promise<UserAgencyRow[]> => {
      const { data: profiles, error: profErr } = await supabase
        .from("profiles")
        .select("id, full_name, email, avatar_url")
        .order("full_name", { ascending: true });

      if (profErr) throw profErr;

      const prefs = await listAgencyRolePreferences();
      const prefsMap = new Map(prefs.map((p) => [p.user_id, p]));

      return (profiles ?? []).map((prof) => {
        const pref = prefsMap.get(prof.id);
        return {
          user_id: prof.id,
          full_name: prof.full_name ?? null,
          email: prof.email ?? null,
          avatar_url: prof.avatar_url ?? null,
          agency_role: pref?.agency_role ?? null,
          is_eos_user: pref?.is_eos_user ?? false,
          has_prefs: !!pref?.agency_role,
        };
      });
    },
    staleTime: cacheConfig.staleTime.medium,
  });
}

export interface UpsertAgencyRolePayload {
  user_id: string;
  agency_role: AgencyRole | null;
  is_eos_user?: boolean;
}

export function useUpsertAgencyRole() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({ user_id, agency_role, is_eos_user = false }: UpsertAgencyRolePayload) => {
      await adminSaveAgencyRolePreferences(user_id, agency_role, is_eos_user);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ADMIN_AGENCY_ROLES_KEY });
    },
    onError: () => {
      toast.error("Failed to update agency role.");
    },
  });
}
