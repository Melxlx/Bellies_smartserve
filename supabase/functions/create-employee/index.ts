import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const json = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const authorization = request.headers.get("Authorization");
  if (!authorization) return json({ error: "Authentication required" }, 401);

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
  });
  const adminClient = createClient(supabaseUrl, serviceRoleKey);

  const { data: userData, error: userError } = await callerClient.auth.getUser();
  if (userError || !userData.user) return json({ error: "Authentication required" }, 401);

  const { data: callerProfile, error: profileError } = await adminClient
    .from("profiles")
    .select("role")
    .eq("id", userData.user.id)
    .single();
  if (profileError || callerProfile?.role !== "OWNER") {
    return json({ error: "Only an owner can create employee accounts" }, 403);
  }

  let payload: Record<string, unknown>;
  try {
    payload = await request.json();
  } catch (_) {
    return json({ error: "Invalid request body" }, 400);
  }

  const email = typeof payload.email === "string" ? payload.email.trim() : "";
  const password = typeof payload.password === "string" ? payload.password : "";
  const fullName = typeof payload.full_name === "string"
    ? payload.full_name.trim().replace(/\s+/g, " ")
    : "";
  const firstName = typeof payload.first_name === "string"
    ? payload.first_name.trim().replace(/\s+/g, " ")
    : "";
  const middleName = typeof payload.middle_name === "string"
    ? payload.middle_name.trim().replace(/\s+/g, " ")
    : "";
  const lastName = typeof payload.last_name === "string"
    ? payload.last_name.trim().replace(/\s+/g, " ")
    : "";
  const role = typeof payload.role === "string" ? payload.role.toUpperCase() : "";
  const position = typeof payload.position === "string" ? payload.position.trim() : "";
  const dailyRate = typeof payload.daily_rate === "number" ? payload.daily_rate : NaN;
  const allowedRoles = ["CASHIER", "KITCHEN", "RIDER"];

  if (!email || !email.includes("@") || password.length < 6 || !fullName ||
      !/^[A-Za-z]+(?: [A-Za-z]+)*$/.test(fullName) ||
      !position || !allowedRoles.includes(role) || !Number.isFinite(dailyRate) ||
      dailyRate < 0) {
    return json({ error: "Invalid employee details" }, 400);
  }

  const { data: created, error: createError } = await adminClient.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
  });
  if (createError || !created.user) {
    return json({ error: createError?.message ?? "Could not create auth account" }, 400);
  }

  const { error: profileError } = await adminClient.from("profiles").upsert({
    id: created.user.id,
    email,
    full_name: fullName,
    first_name: firstName || null,
    middle_name: middleName || null,
    last_name: lastName || null,
    role,
    account_status: "ACTIVE",
    position,
    daily_rate: dailyRate,
  }, { onConflict: "id" });
  if (profileError) {
    await adminClient.auth.admin.deleteUser(created.user.id);
    return json({ error: profileError.message }, 400);
  }

  return json({ id: created.user.id });
});
