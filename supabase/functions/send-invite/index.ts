// @ts-expect-error This URL import is resolved by the Supabase Deno Edge runtime, not the Expo compiler.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type InviteRequest = { storeId: string; email: string };
declare const Deno: { env: { get(name: string): string | undefined }; serve(handler: (request: Request) => Response | Promise<Response>): void };
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);
  const authHeader = request.headers.get("Authorization");
  if (!authHeader) return json({ error: "Authentication required" }, 401);
  const url = Deno.env.get("SUPABASE_URL")!; const publishableKey = Deno.env.get("SUPABASE_ANON_KEY")!; const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const caller = createClient(url, publishableKey, { global: { headers: { Authorization: authHeader } } });
  const { data: { user }, error: userError } = await caller.auth.getUser();
  if (userError || !user) return json({ error: "Invalid session" }, 401);
  const body = await request.json() as InviteRequest;
  if (!body.storeId || !body.email) return json({ error: "storeId and email are required" }, 400);
  const admin = createClient(url, serviceKey);
  const { data: membership, error: membershipError } = await admin.from("store_members").select("role,is_active").eq("store_id", body.storeId).eq("user_id", user.id).eq("is_active", true).maybeSingle();
  if (membershipError || membership?.role !== "owner") return json({ error: "Owner access is required" }, 403);
  const email = body.email.trim().toLowerCase();
  const { data: invitation, error: invitationError } = await admin.from("invitations").select("id,role,status,expires_at").eq("store_id", body.storeId).eq("email", email).eq("status", "pending").gt("expires_at", new Date().toISOString()).order("created_at", { ascending: false }).limit(1).maybeSingle();
  if (invitationError || !invitation) return json({ error: "No active pending invitation exists for this address" }, 404);
  const redirectTo = `${request.headers.get("origin") ?? "https://stocktrack.example.com"}/auth`;
  const { data: invited, error: inviteError } = await admin.auth.admin.inviteUserByEmail(email, { redirectTo, data: { full_name: email.split("@")[0], stocktrack_store_id: body.storeId } });
  if (inviteError) return json({ error: inviteError.message }, 422);
  if (!invited.user) return json({ error: "Authentication provider did not return an invited user" }, 502);
  const { error: addMemberError } = await admin.from("store_members").upsert({ store_id: body.storeId, user_id: invited.user.id, role: invitation.role, is_active: true, invited_by: user.id }, { onConflict: "store_id,user_id" });
  if (addMemberError) return json({ error: addMemberError.message }, 422);
  return json({ success: true, invitationId: invitation.id, userId: invited.user.id });
});
