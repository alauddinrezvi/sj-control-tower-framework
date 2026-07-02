import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { getCorsHeaders, handleCorsPreflight } from "../_shared/cors.ts";

function validatePasswordPolicy(password: string) {
  const errors: string[] = [];
  const warnings: string[] = [];
  let score = 0;
  if (!password || password.length < 8) errors.push("Password must be at least 8 characters");
  else score += 20;
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
  if (["password", "123456", "qwerty", "letmein", "welcome"].some((p) => lower.includes(p))) {
    errors.push("Password contains a commonly used phrase");
    score = Math.max(0, score - 30);
  }
  return { valid: errors.length === 0, score: Math.min(100, score), errors, warnings };
}

async function checkHibpPassword(password: string) {
  const hashBuffer = await crypto.subtle.digest("SHA-1", new TextEncoder().encode(password));
  const hashHex = Array.from(new Uint8Array(hashBuffer))
    .map((b) => b.toString(16).toUpperCase().padStart(2, "0"))
    .join("");
  const prefix = hashHex.slice(0, 5);
  const suffix = hashHex.slice(5);
  const response = await fetch(`https://api.pwnedpasswords.com/range/${prefix}`, {
    headers: { "Add-Padding": "true" },
  });
  if (!response.ok) throw new Error(`HIBP API error: ${response.status}`);
  for (const line of (await response.text()).split("\n")) {
    const [hashSuffix, countStr] = line.trim().split(":");
    if (hashSuffix === suffix) return { compromised: true, count: parseInt(countStr, 10) || 0 };
  }
  return { compromised: false, count: 0 };
}

const DEFAULT_ORG = "00000000-0000-0000-0000-000000000001";

serve(async (req) => {
  const corsHeaders = getCorsHeaders(req.headers.get("Origin"));

  if (req.method === "OPTIONS") {
    return handleCorsPreflight(req.headers.get("Origin"));
  }

  try {
    const body = await req.json().catch(() => ({}));
    const password = String(body.password ?? "");

    if (!password) {
      return new Response(JSON.stringify({ valid: false, errors: ["Password is required"] }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const policy = validatePasswordPolicy(password);

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const { data: config } = await supabase
      .from("security_configurations")
      .select("hibp_check_enabled")
      .eq("org_id", DEFAULT_ORG)
      .maybeSingle();

    let hibpCompromised = false;
    let hibpCount = 0;

    if (config?.hibp_check_enabled !== false) {
      try {
        const hibp = await checkHibpPassword(password);
        hibpCompromised = hibp.compromised;
        hibpCount = hibp.count;
        if (hibp.compromised) {
          policy.errors.push(
            `This password has appeared in ${hibp.count.toLocaleString()} known data breaches`
          );
          policy.valid = false;
        }
      } catch (hibpError) {
        console.warn("HIBP check failed:", hibpError);
        policy.warnings.push("Could not verify password against breach database");
      }
    }

    return new Response(
      JSON.stringify({
        valid: policy.valid,
        score: policy.score,
        errors: policy.errors,
        warnings: policy.warnings,
        hibpCompromised,
        hibpCount,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : "Unknown error";
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
