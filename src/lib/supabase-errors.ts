interface PostgrestErrorLike {
  code?: string;
  message?: string;
}

export function isMissingTable(error: unknown, tableName: string): boolean {
  if (!error || typeof error !== "object") return false;
  const postgrestError = error as PostgrestErrorLike;
  return (
    postgrestError.code === "PGRST205" &&
    (postgrestError.message?.includes(tableName) ?? false)
  );
}

export function getMissingColumnName(error: unknown): string | null {
  if (!error || typeof error !== "object") return null;
  const postgrestError = error as PostgrestErrorLike;
  if (postgrestError.code !== "PGRST204") return null;
  const match = postgrestError.message?.match(/Could not find the '([^']+)' column/);
  return match?.[1] ?? null;
}

export function omitPayloadColumn<T extends Record<string, unknown>>(
  payload: T,
  column: string
): T {
  const next = { ...payload };
  delete next[column];
  return next;
}
