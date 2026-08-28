import * as Network from "expo-network";
import type { OutboxEntry, SyncOverview } from "@/src/lib/types";
import { activityPayload, categoryPayload, itemPayload, remoteErrorMessage, toCategory, toItem, toLog, toMember, toSession, toSessionItem, toStore } from "@/src/data/remote/remote-store";
import { orderOutboxEntries } from "@/src/data/sync/integrity";
import { supabase } from "@/src/data/remote/supabase";
import { getSyncOverview, listOutbox, removeOutbox, setSetting, updateOutbox, upsertCategory, upsertItem, upsertLog, upsertMembership, upsertSession, upsertSessionItem, upsertStore } from "@/src/data/local/repository";

let synchronizing = false;

// P0001 is the default SQLSTATE for a plpgsql `raise exception` with no explicit code -- every role/validation/
// business-rule rejection in the StockTrack RPCs (e.g. "Owner access is required", "Item no longer exists") uses it.
// Treating it as permanent stops the outbox from silently retrying a rejection forever instead of surfacing it.
function permanent(error: { code?: string; message?: string } | null) { return Boolean(error?.code === "42501" || error?.code === "23505" || error?.code === "P0001" || /permission|not authorized|validation|does not exist/i.test(error?.message ?? "")); }

async function execute(entry: OutboxEntry): Promise<void> {
  const payload = entry.payload as Record<string, any>;
  if (entry.entity === "store") {
    if (entry.operation === "create") {
      const { error } = await supabase.rpc("create_store", { p_store_id: payload.store.id, p_name: payload.store.name, p_general_category_id: payload.category.id, p_operation_key: entry.operationKey });
      if (error) throw error;
    } else {
      const { error } = await supabase.rpc("rename_store", { p_operation_key: entry.operationKey, p_store_id: payload.store.id, p_name: payload.store.name });
      if (error) throw error;
    }
    return;
  }
  if (entry.entity === "category") {
    const { error } = entry.operation === "delete"
      ? await supabase.rpc("delete_category", { p_operation_key: entry.operationKey, p_store_id: entry.storeId, p_category_id: payload.categoryId, p_general_category_id: payload.generalCategoryId, p_activity: activityPayload(payload.activity) })
      : await supabase.rpc("upsert_category", { p_operation_key: entry.operationKey, p_category: categoryPayload(payload.category), p_activity: activityPayload(payload.activity) });
    if (error) throw error;
    return;
  }
  if (entry.entity === "item") {
    if (entry.operation === "delete") { const { error } = await supabase.rpc("delete_inventory_item", { p_operation_key: entry.operationKey, p_item_id: payload.itemId, p_activity: activityPayload(payload.activity) }); if (error) throw error; }
    else { const { error } = await supabase.rpc("upsert_inventory_item", { p_operation_key: entry.operationKey, p_item: itemPayload(payload.item), p_activity: activityPayload(payload.activity) }); if (error) throw error; }
    return;
  }
  if (entry.entity === "stock_delta") {
    if (entry.operation === "correct") {
      const { error } = await supabase.rpc("correct_stock", { p_operation_key: entry.operationKey, p_log_id: payload.logId, p_new_quantity: String(payload.newQuantityHundredths / 100), p_correction_meta: payload.correctionMeta });
      if (error) throw error;
      return;
    }
    const { error } = await supabase.rpc("apply_stock_delta", { p_operation_key: entry.operationKey, p_item_id: payload.itemId, p_delta: String(payload.deltaHundredths / 100), p_activity: activityPayload(payload.activity) });
    if (error) throw error;
    return;
  }
  if (entry.entity === "session") {
    const { error } = await supabase.rpc("record_stock_session", { p_operation_key: entry.operationKey, p_session: payload.session, p_lines: payload.lines.map((line: any) => ({ item_id: line.item.id, quantity: String((line.sessionItem.quantityHundredths) / 100), activity: activityPayload(line.activity), session_item: line.sessionItem })) });
    if (error) throw error;
    return;
  }
  if (entry.entity === "invitation") { const { data, error } = await supabase.rpc("invite_member", { p_operation_key: entry.operationKey, p_store_id: entry.storeId, p_full_name: payload.fullName, p_email: payload.email, p_role: payload.role, p_activity: activityPayload(payload.activity) }); if (error) throw error; if (data?.invitation_created || data?.invitation_id) { const { error: emailError } = await supabase.functions.invoke("send-invite", { body: { storeId: entry.storeId, email: payload.email } }); if (emailError) throw new Error(`Invitation recorded but email could not be sent: ${emailError.message}`); } return; }
  if (entry.entity === "member") { const { error } = await supabase.rpc("manage_member", { p_operation_key: entry.operationKey, p_member_id: payload.memberId, p_role: payload.role, p_is_active: payload.isActive, p_remove: payload.remove, p_activity: activityPayload(payload.activity) }); if (error) throw error; return; }
  if (entry.entity === "activity") { const { error } = await supabase.rpc("record_generic_activity", { p_operation_key: entry.operationKey, p_activity: activityPayload(payload.activity) }); if (error) throw error; return; }
  throw new Error(`Unsupported queued operation: ${entry.entity}`);
}

export async function hydrateStore(storeId: string): Promise<void> {
  const [stores, categories, items, logs, sessions, sessionItems, members] = await Promise.all([
    supabase.from("stores").select("*").eq("id", storeId), supabase.from("categories").select("*").eq("store_id", storeId), supabase.from("inventory_items").select("*").eq("store_id", storeId), supabase.from("activity_logs").select("*").eq("store_id", storeId).order("created_at", { ascending: false }).limit(200), supabase.from("stock_sessions").select("*").eq("store_id", storeId).order("created_at", { ascending: false }).limit(100), supabase.from("stock_session_items").select("*").eq("store_id", storeId), supabase.from("store_members").select("*, profiles(full_name,email)").eq("store_id", storeId),
  ]);
  const errors = [stores, categories, items, logs, sessions, sessionItems, members].map((result) => result.error).filter(Boolean);
  if (errors.length) throw errors[0];
  await Promise.all([
    ...(stores.data ?? []).map((row: Record<string, unknown>) => upsertStore(toStore(row))), ...(categories.data ?? []).map((row: Record<string, unknown>) => upsertCategory(toCategory(row))), ...(items.data ?? []).map((row: Record<string, unknown>) => upsertItem(toItem(row))), ...(logs.data ?? []).map((row: Record<string, unknown>) => upsertLog(toLog(row))), ...(sessions.data ?? []).map((row: Record<string, unknown>) => upsertSession(toSession(row))), ...(sessionItems.data ?? []).map((row: Record<string, unknown>) => upsertSessionItem(toSessionItem(row))), ...(members.data ?? []).map((row: Record<string, unknown>) => upsertMembership(toMember(row))),
  ]);
}

export async function hydrateAccessibleStores(userId: string): Promise<string[]> {
  const { data, error } = await supabase.from("store_members").select("store_id, stores(*)").eq("user_id", userId).eq("is_active", true);
  if (error) throw error;
  const stores = (data ?? []).map((row: any) => row.stores).filter(Boolean);
  await Promise.all([...(data ?? []).map((row: any) => upsertMembership(toMember(row))), ...stores.map((store: any) => upsertStore(toStore(store)))]);
  return stores.map((store: any) => String(store.id));
}

export async function syncOutbox(activeStoreId?: string | null): Promise<SyncOverview> {
  const state = await Network.getNetworkStateAsync();
  if (!state.isInternetReachable) { const overview = await getSyncOverview(); return { ...overview, state: "offline" }; }
  if (synchronizing) return { ...(await getSyncOverview()), state: "syncing" };
  synchronizing = true;
  try {
    const entries = orderOutboxEntries(await listOutbox(["pending"]));
    for (const entry of entries) {
      await updateOutbox(entry, { status: "syncing", lastAttemptAt: new Date().toISOString(), attemptCount: entry.attemptCount + 1, lastError: null });
      try { await execute(entry); await removeOutbox(entry.id); }
      catch (error) { const message = await remoteErrorMessage(error); await updateOutbox(entry, { status: permanent(error as { code?: string; message?: string }) ? "failed" : "pending", lastError: message, lastAttemptAt: new Date().toISOString(), attemptCount: entry.attemptCount + 1 }); }
    }
    if (activeStoreId) await hydrateStore(activeStoreId);
    await setSetting("last_successful_sync", new Date().toISOString());
  } finally { synchronizing = false; }
  return getSyncOverview();
}

export async function retryFailedSync(activeStoreId?: string | null): Promise<SyncOverview> {
  const failed = await listOutbox(["failed"]);
  await Promise.all(failed.map((entry) => updateOutbox(entry, { status: "pending", lastError: null })));
  return syncOutbox(activeStoreId);
}
