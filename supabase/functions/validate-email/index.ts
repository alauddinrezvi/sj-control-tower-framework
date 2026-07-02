import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { getCorsHeaders, handleCorsPreflight } from "../_shared/cors.ts";

const EMAIL_REGEX =
  /^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$/;

const DEFAULT_ORG = "00000000-0000-0000-0000-000000000001";

interface ValidationStep {
  step: string;
  passed: boolean;
  message?: string;
}

serve(async (req) => {
  const corsHeaders = getCorsHeaders(req.headers.get("Origin"));

  if (req.method === "OPTIONS") {
    return handleCorsPreflight(req.headers.get("Origin"));
  }

  try {
    const body = await req.json().catch(() => ({}));
    const email = String(body.email ?? "").trim().toLowerCase();
    const steps: ValidationStep[] = [];

    if (!email) {
      return new Response(
        JSON.stringify({ valid: false, steps: [{ step: "syntax", passed: false, message: "Email is required" }] }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const syntaxOk = EMAIL_REGEX.test(email) && email.length <= 254;
    steps.push({
      step: "syntax",
      passed: syntaxOk,
      message: syntaxOk ? "Valid email format" : "Invalid email format",
    });

    if (!syntaxOk) {
      return new Response(JSON.stringify({ valid: false, steps }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const domain = email.split("@")[1];
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const { data: config } = await supabase
      .from("security_configurations")
      .select("disposable_email_blocked, smtp_check_enabled")
      .eq("org_id", DEFAULT_ORG)
      .maybeSingle();

    const blockDisposable = config?.disposable_email_blocked !== false;
    let disposableOk = true;

    if (blockDisposable) {
      const { data: blocked } = await supabase
        .from("disposable_email_domains")
        .select("id")
        .eq("domain", domain)
        .maybeSingle();

      disposableOk = !blocked;
      steps.push({
        step: "disposable",
        passed: disposableOk,
        message: disposableOk
          ? "Domain is not on the disposable blocklist"
          : "Disposable email domains are not allowed",
      });
    } else {
      steps.push({
        step: "disposable",
        passed: true,
        message: "Disposable email blocking is disabled",
      });
    }

    if (!disposableOk) {
      return new Response(JSON.stringify({ valid: false, steps }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const smtpCheckEnabled = config?.smtp_check_enabled === true;
    let mxOk = true;

    if (smtpCheckEnabled) {
      try {
        const records = await Deno.resolveDns(domain, "MX");
        mxOk = Array.isArray(records) && records.length > 0;
        steps.push({
          step: "mx",
          passed: mxOk,
          message: mxOk
            ? `MX records found (${records.length})`
            : "No MX records found for domain",
        });
      } catch {
        mxOk = false;
        steps.push({
          step: "mx",
          passed: false,
          message: "DNS MX lookup failed — domain may not accept email",
        });
      }
    } else {
      steps.push({
        step: "mx",
        passed: true,
        message: "SMTP/MX verification is disabled (skipped)",
      });
    }

    const valid = syntaxOk && disposableOk && mxOk;

    return new Response(JSON.stringify({ valid, steps, domain }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : "Unknown error";
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
