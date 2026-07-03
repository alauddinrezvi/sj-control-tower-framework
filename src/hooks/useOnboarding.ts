import { useState, useEffect } from "react";
import { useLocation } from "react-router-dom";
import { supabase } from "@/integrations/supabase/client";
import { hasCompletedUserOnboarding, markUserOnboardingComplete } from "@/lib/onboarding-storage";

export { hasCompletedUserOnboarding, markUserOnboardingComplete } from "@/lib/onboarding-storage";

export function useOnboarding() {
  const [showOnboarding, setShowOnboarding] = useState(false);
  const [loading, setLoading] = useState(true);
  const [user, setUser] = useState<{ id: string } | null>(null);

  useEffect(() => {
    void checkOnboardingStatus();
  }, []);

  const checkOnboardingStatus = async (): Promise<void> => {
    try {
      setLoading(true);
      const {
        data: { user: currentUser },
      } = await supabase.auth.getUser();

      if (!currentUser) {
        setLoading(false);
        return;
      }

      setUser(currentUser);

      const completed = await hasCompletedUserOnboarding(currentUser.id);
      if (completed) {
        setShowOnboarding(false);
        return;
      }

      const { data: profile } = await supabase
        .from("profiles")
        .select("full_name")
        .eq("id", currentUser.id)
        .single();

      const hasProfile = Boolean(profile?.full_name?.trim());
      setShowOnboarding(!hasProfile);
    } catch (error) {
      console.error("Error checking onboarding status:", error);
      setShowOnboarding(true);
    } finally {
      setLoading(false);
    }
  };

  const completeOnboarding = async (): Promise<void> => {
    if (!user) return;
    try {
      await markUserOnboardingComplete(user.id);
      setShowOnboarding(false);
    } catch (error) {
      console.error("Error completing onboarding:", error);
      throw error;
    }
  };

  const skipOnboarding = (): void => setShowOnboarding(false);

  return {
    showOnboarding,
    loading,
    completeOnboarding,
    skipOnboarding,
    user,
  };
}

/** Returns whether authenticated user should be redirected to /onboarding */
export function useOnboardingRedirect() {
  const [needsOnboarding, setNeedsOnboarding] = useState(false);
  const [loading, setLoading] = useState(true);
  const location = useLocation();

  useEffect(() => {
    let cancelled = false;

    const check = async (): Promise<void> => {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (cancelled) return;

      if (!user) {
        setNeedsOnboarding(false);
        setLoading(false);
        return;
      }

      const completed = await hasCompletedUserOnboarding(user.id);
      if (cancelled) return;

      setNeedsOnboarding(!completed);
      setLoading(false);
    };

    setLoading(true);
    void check();

    return () => {
      cancelled = true;
    };
  }, [location.pathname]);

  return { needsOnboarding, loading };
}
