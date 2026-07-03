import { supabase } from "@/integrations/supabase/client";
import { isMissingTable } from "@/lib/supabase-errors";

const completedOnboardingUserIds = new Set<string>();

export function isMissingOnboardingProgressTable(error: unknown): boolean {
  return isMissingTable(error, "onboarding_progress");
}

function rememberOnboardingComplete(userId: string): void {
  completedOnboardingUserIds.add(userId);
}

function parseProfileMetadata(metadata: unknown): Record<string, unknown> {
  if (metadata && typeof metadata === "object" && !Array.isArray(metadata)) {
    return metadata as Record<string, unknown>;
  }
  return {};
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

async function writeProfileMetadata(
  userId: string,
  metadata: Record<string, unknown>
): Promise<void> {
  const { error } = await supabase.from("profiles").update({ metadata }).eq("id", userId);

  if (error) {
    throw error;
  }
}

async function hasCompletedUserOnboardingFromProfile(userId: string): Promise<boolean> {
  const metadata = await readProfileMetadata(userId);
  const completed = Boolean(metadata.onboarding_completed_at);
  if (completed) {
    rememberOnboardingComplete(userId);
  }
  return completed;
}

export async function hasCompletedUserOnboarding(userId: string): Promise<boolean> {
  if (completedOnboardingUserIds.has(userId)) {
    return true;
  }

  const { data: progress, error } = await (supabase as any)
    .from("onboarding_progress")
    .select("completed_at")
    .eq("user_id", userId)
    .maybeSingle();

  if (error) {
    if (isMissingOnboardingProgressTable(error)) {
      return hasCompletedUserOnboardingFromProfile(userId);
    }
    console.error("Error loading onboarding progress:", error);
    return false;
  }

  const completed = Boolean(progress?.completed_at);
  if (completed) {
    rememberOnboardingComplete(userId);
    return true;
  }

  return hasCompletedUserOnboardingFromProfile(userId);
}

export async function saveOnboardingStep(
  userId: string,
  currentStep: number,
  nextStep: number,
  completed = false
): Promise<void> {
  const completedAt = completed ? new Date().toISOString() : null;

  const { error } = await (supabase as any).from("onboarding_progress").upsert(
    {
      user_id: userId,
      current_step: nextStep,
      steps_completed: { [`step_${currentStep}`]: true },
      completed_at: completedAt,
      updated_at: new Date().toISOString(),
    },
    { onConflict: "user_id" }
  );

  if (!error) {
    if (completed) {
      rememberOnboardingComplete(userId);
    }
    return;
  }

  if (!isMissingOnboardingProgressTable(error)) {
    throw error;
  }

  const metadata = await readProfileMetadata(userId);
  await writeProfileMetadata(userId, {
    ...metadata,
    onboarding_current_step: nextStep,
    onboarding_completed_at: completedAt ?? metadata.onboarding_completed_at ?? null,
    [`onboarding_step_${currentStep}_completed`]: true,
  });

  if (completed) {
    rememberOnboardingComplete(userId);
  }
}

export async function markUserOnboardingComplete(userId: string): Promise<void> {
  const completedAt = new Date().toISOString();

  const { error } = await (supabase as any).from("onboarding_progress").upsert(
    {
      user_id: userId,
      current_step: 5,
      completed_at: completedAt,
      updated_at: completedAt,
    },
    { onConflict: "user_id" }
  );

  if (!error) {
    rememberOnboardingComplete(userId);
    return;
  }

  if (!isMissingOnboardingProgressTable(error)) {
    throw error;
  }

  const metadata = await readProfileMetadata(userId);
  await writeProfileMetadata(userId, {
    ...metadata,
    onboarding_current_step: 5,
    onboarding_completed_at: completedAt,
  });

  rememberOnboardingComplete(userId);
}

export async function loadOnboardingState(userId: string): Promise<{
  completed: boolean;
  currentStep: number | null;
}> {
  const { data: progress, error } = await (supabase as any)
    .from("onboarding_progress")
    .select("completed_at, current_step")
    .eq("user_id", userId)
    .maybeSingle();

  if (!error) {
    return {
      completed: Boolean(progress?.completed_at),
      currentStep: progress?.current_step ?? null,
    };
  }

  if (!isMissingOnboardingProgressTable(error)) {
    throw error;
  }

  const metadata = await readProfileMetadata(userId);
  const stepValue = metadata.onboarding_current_step;
  const currentStep = typeof stepValue === "number" ? stepValue : null;

  return {
    completed: Boolean(metadata.onboarding_completed_at),
    currentStep,
  };
}
