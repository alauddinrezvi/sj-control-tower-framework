import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { queryKeys, cacheConfig } from "@/lib/cache";
import { useAuth } from "@/contexts/AuthContext";
import {
  DEFAULT_DASHBOARD_PREFERENCES,
  getDashboardPreferences,
  saveDashboardPreferences,
  type DashboardPreferencesRecord,
} from "@/lib/role-preferences-storage";

export type DashboardPreferences = DashboardPreferencesRecord;

export function useDashboardPreferences() {
  const { user } = useAuth();
  const queryClient = useQueryClient();
  const qKey = queryKeys.dashboard.agencyPreferences(user?.id ?? "");

  const query = useQuery<DashboardPreferences>({
    queryKey: qKey,
    queryFn: async (): Promise<DashboardPreferences> => {
      if (!user) return DEFAULT_DASHBOARD_PREFERENCES;
      return getDashboardPreferences(user.id);
    },
    enabled: !!user,
    staleTime: cacheConfig.staleTime.long,
  });

  const mutation = useMutation({
    mutationFn: async (patch: Partial<DashboardPreferences>) => {
      if (!user) return;
      await saveDashboardPreferences(user.id, patch);
    },
    onMutate: async (patch) => {
      await queryClient.cancelQueries({ queryKey: qKey });
      const prev = queryClient.getQueryData<DashboardPreferences>(qKey);
      queryClient.setQueryData<DashboardPreferences>(qKey, (old) => ({
        ...(old ?? DEFAULT_DASHBOARD_PREFERENCES),
        ...patch,
      }));
      return { prev };
    },
    onError: (_err, _vars, ctx) => {
      queryClient.setQueryData(qKey, ctx?.prev);
      toast.error("Failed to save preference.");
    },
    onSuccess: () => {
      toast.success("Preference saved.");
    },
  });

  return {
    preferences: query.data ?? DEFAULT_DASHBOARD_PREFERENCES,
    isLoading: query.isLoading,
    updatePreference: (patch: Partial<DashboardPreferences>) => mutation.mutate(patch),
    isPending: mutation.isPending,
  };
}
