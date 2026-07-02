export interface LocalPasswordValidationResult {
  valid: boolean;
  score: number;
  errors: string[];
  warnings: string[];
}

export function validatePasswordLocally(password: string): LocalPasswordValidationResult {
  const errors: string[] = [];
  const warnings: string[] = [];
  let score = 0;

  if (!password || password.length < 8) {
    errors.push("Password must be at least 8 characters");
  } else {
    score += 20;
  }

  if (/[a-z]/.test(password)) score += 15;
  else errors.push("Password must include a lowercase letter");

  if (/[A-Z]/.test(password)) score += 15;
  else errors.push("Password must include an uppercase letter");

  if (/[0-9]/.test(password)) score += 15;
  else errors.push("Password must include a number");

  if (/[^A-Za-z0-9]/.test(password)) score += 15;
  else warnings.push("Add a special character for stronger security");

  if (password.length >= 16) score += 10;
  if (password.length >= 20) score += 10;

  const lower = password.toLowerCase();
  if (["password", "123456", "qwerty", "letmein", "welcome"].some((phrase) => lower.includes(phrase))) {
    errors.push("Password contains a commonly used phrase");
    score = Math.max(0, score - 30);
  }

  return {
    valid: errors.length === 0,
    score: Math.min(100, score),
    errors,
    warnings,
  };
}
