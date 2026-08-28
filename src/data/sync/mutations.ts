import * as Crypto from "expo-crypto";
import { correctionDelta, signedDelta } from "@/src/lib/quantity";
import type { ActivityLog, BulkSessionLine, Category, InventoryItem, SessionType, StockSession, StockSessionItem, Store, StoreMembership, StoreRole } from "@/src/lib/types";
import { enqueue, getItem, listSessionItems, upsertCategory, upsertItem, upsertLog, upsertMembership, upsertSession, upsertSessionItem, upsertStore } from "@/src/data/local/repository";
import { getDatabase, initializeLocalDatabase } from "@/src/data/local/database";

const now = () => new Date().toISOString();

export interface Actor { id: string; name: string; role: StoreRole; }

export async function createStoreLocally(name: string, actor: Actor): Promise<Store> {
  await initializeLocalDatabase();
  const timestamp = now();
  const store: Store = { id: Crypto.randomUUID(), name: name.trim(), ownerId: actor.id, allowNegativeStock: true, createdAt: timestamp, updatedAt: timestamp, localDeleted: false };
  const member: StoreMembership = { id: Crypto.randomUUID(), storeId: store.id, userId: actor.id, role: "owner", isActive: true, fullName: actor.name, createdAt: timestamp, updatedAt: timestamp, localDeleted: false };
  const general: Category = { id: Crypto.randomUUID(), storeId: store.id, name: "General", colorValue: "#3568D4", iconCode: "inventory", createdAt: timestamp, updatedAt: timestamp, localDeleted: false };
  const db = getDatabase();
  await db.withTransactionAsync(async () => { await upsertStore(store); await upsertMembership(member); await upsertCategory(general); await enqueue({ storeId: store.id, entity: "store", operation: "create", payload: { store, member, category: general }, dependencies: [] }); });
  return store;
}

export async function renameStoreLocally(store: Store, name: string): Promise<Store> {
  const updated = { ...store, name: name.trim(), updatedAt: now() };
  const db = getDatabase();
  await db.withTransactionAsync(async () => { await upsertStore(updated); await enqueue({ storeId: store.id, entity: "store", operation: "update", payload: { store: updated }, dependencies: [] }); });
  return updated;
}

export async function createCategoryLocally(storeId: string, actor: Actor, name: string, colorValue: string, iconCode: string): Promise<Category> {
  const timestamp = now();
  const category: Category = { id: Crypto.randomUUID(), storeId, name: name.trim(), colorValue, iconCode, createdAt: timestamp, updatedAt: timestamp, localDeleted: false };
  const log: ActivityLog = { id: Crypto.randomUUID(), storeId, userId: actor.id, userName: actor.name, userRole: actor.role, actionType: "category_created", itemId: null, itemName: category.name, quantityHundredths: null, unit: null, details: "Category created", sessionId: null, createdAt: timestamp, updatedAt: timestamp, localDeleted: false };
  const db = getDatabase();
  await db.withTransactionAsync(async () => { await upsertCategory(category); await upsertLog(log); await enqueue({ storeId, entity: "category", operation: "create", payload: { category, activity: log }, dependencies: [] }); });
  return category;
}

export async function deleteCategoryLocally(category: Category, generalCategory: Category, actor: Actor): Promise<void> {
  if (category.id === generalCategory.id) throw new Error("The General category cannot be deleted.");
  const timestamp = now();
  const log: ActivityLog = { id: Crypto.randomUUID(), storeId: category.storeId, userId: actor.id, userName: actor.name, userRole: actor.role, actionType: "category_deleted", itemId: null, itemName: category.name, quantityHundredths: null, unit: null, details: `Items reassigned to ${generalCategory.name}`, sessionId: null, createdAt: timestamp, updatedAt: timestamp, localDeleted: false };
  const db = getDatabase();
  await db.withTransactionAsync(async () => { await db.runAsync("UPDATE inventory_items SET category_id=?, category_name=?, updated_at=? WHERE store_id=? AND category_id=?", [generalCategory.id, generalCategory.name, timestamp, category.storeId, category.id]); await db.runAsync("UPDATE categories SET local_deleted=1, updated_at=? WHERE id=?", [timestamp, category.id]); await upsertLog(log); await enqueue({ storeId: category.storeId, entity: "category", operation: "delete", payload: { categoryId: category.id, generalCategoryId: generalCategory.id, activity: log }, dependencies: [] }); });
}

export async function createStockDeltaLocally(storeId: string, itemId: string, type: SessionType, quantityHundredths: number, actor: Actor, sessionId: string | null = null, detail = ""): Promise<ActivityLog> {
  const item = await getItem(itemId);
  if (!item || item.storeId !== storeId) throw new Error("This item is no longer available in the active store.");
  if (!Number.isInteger(quantityHundredths) || quantityHundredths <= 0) throw new Error("Enter a positive quantity with up to two decimal places.");
  const timestamp = now();
  const delta = signedDelta(type, quantityHundredths);
  const updated: InventoryItem = { ...item, quantityHundredths: item.quantityHundredths + delta, updatedBy: actor.id, updatedAt: timestamp };
  const log: ActivityLog = { id: Crypto.randomUUID(), storeId, userId: actor.id, userName: actor.name, userRole: actor.role, actionType: type === "IN" ? "stock_in" : "stock_out", itemId: item.id, itemName: item.name, quantityHundredths: delta, unit: item.unit, details: detail || null, sessionId, createdAt: timestamp, updatedAt: timestamp, localDeleted: false };
  const db = getDatabase();
  await db.withTransactionAsync(async () => { await upsertItem(updated); await upsertLog(log); await enqueue({ storeId, entity: "stock_delta", operation: "stock_delta", payload: { itemId, deltaHundredths: delta, activity: log }, dependencies: [] }); });
  return log;
}

// Owner-only correction of an existing stock log line. Per spec this recomputes only the delta between the
// original recorded quantity and the corrected quantity -- it does not treat the new value as a fresh movement --
// then updates the original log row (and its matching session line, if any) in place rather than creating a
// disconnected new entry. The original id/createdAt are preserved; correctionMeta records who changed it and from what.
export async function correctStockLocally(originalLog: ActivityLog, newSignedQuantityHundredths: number, actor: Actor): Promise<ActivityLog> {
  if (actor.role !== "owner") throw new Error("Only the store owner can correct a stock entry.");
  if (!originalLog.itemId || originalLog.quantityHundredths === null) throw new Error("This entry cannot be corrected.");
  const item = await getItem(originalLog.itemId);
  if (!item || item.storeId !== originalLog.storeId) throw new Error("This item is no longer available in the active store.");
  const delta = correctionDelta(originalLog.quantityHundredths, newSignedQuantityHundredths);
  if (delta === 0) throw new Error("Enter a different quantity to record a correction.");
  const timestamp = now();
  const correctionMeta = { correctedBy: actor.id, correctedByName: actor.name, correctedAt: timestamp, previousQuantityHundredths: originalLog.quantityHundredths };
  const updatedItem: InventoryItem = { ...item, quantityHundredths: item.quantityHundredths + delta, updatedBy: actor.id, updatedAt: timestamp };
  const updatedLog: ActivityLog = { ...originalLog, quantityHundredths: newSignedQuantityHundredths, correctionMeta, updatedAt: timestamp };
  const db = getDatabase();
  await db.withTransactionAsync(async () => {
    await upsertItem(updatedItem);
    await upsertLog(updatedLog);
    if (originalLog.sessionId) {
      const lines = await listSessionItems(originalLog.sessionId);
      const match = lines.find((line) => line.activityLogId === originalLog.id);
      if (match) await upsertSessionItem({ ...match, quantityHundredths: newSignedQuantityHundredths, updatedAt: timestamp });
    }
    await enqueue({ storeId: originalLog.storeId, entity: "stock_delta", operation: "correct", payload: { logId: originalLog.id, newQuantityHundredths: newSignedQuantityHundredths, correctionMeta }, dependencies: [] });
  });
  return updatedLog;
}

export async function createBulkSessionLocally(storeId: string, type: SessionType, lines: BulkSessionLine[], actor: Actor, notes: string | null = null): Promise<StockSession> {
  if (!lines.length) throw new Error("Select at least one item.");
  if (lines.some((line) => line.item.storeId !== storeId || line.quantityHundredths <= 0 || !Number.isInteger(line.quantityHundredths))) throw new Error("Review every selected item quantity before submitting.");
  const timestamp = now();
  const session: StockSession = { id: Crypto.randomUUID(), storeId, sessionType: type, performerId: actor.id, performerName: actor.name, performerRole: actor.role, totalItems: lines.length, notes, createdAt: timestamp, updatedAt: timestamp, localDeleted: false };
  const records = lines.map((line) => {
    const delta = signedDelta(type, line.quantityHundredths);
    const activity: ActivityLog = { id: Crypto.randomUUID(), storeId, userId: actor.id, userName: actor.name, userRole: actor.role, actionType: type === "IN" ? "stock_in" : "stock_out", itemId: line.item.id, itemName: line.item.name, quantityHundredths: delta, unit: line.item.unit, details: "Bulk session", sessionId: session.id, createdAt: timestamp, updatedAt: timestamp, localDeleted: false };
    const sessionItem: StockSessionItem = { id: Crypto.randomUUID(), sessionId: session.id, storeId, itemId: line.item.id, itemName: line.item.name, category: line.item.categoryName, quantityHundredths: delta, unit: line.item.unit, activityLogId: activity.id, createdAt: timestamp, updatedAt: timestamp, localDeleted: false };
    const item: InventoryItem = { ...line.item, quantityHundredths: line.item.quantityHundredths + delta, updatedBy: actor.id, updatedAt: timestamp };
    return { item, activity, sessionItem };
  });
  const db = getDatabase();
  await db.withTransactionAsync(async () => { for (const record of records) { await upsertItem(record.item); await upsertLog(record.activity); await upsertSessionItem(record.sessionItem); } await upsertSession(session); await enqueue({ storeId, entity: "session", operation: "bulk_session", payload: { session, lines: records }, dependencies: [] }); });
  return session;
}

export async function inviteMemberLocally(storeId: string, actor: Actor, fullName: string, email: string, role: Extract<StoreRole, "staff" | "manager">): Promise<void> {
  const timestamp = now();
  const log: ActivityLog = { id: Crypto.randomUUID(), storeId, userId: actor.id, userName: actor.name, userRole: actor.role, actionType: "user_added", itemId: null, itemName: fullName, quantityHundredths: null, unit: null, details: `Invitation prepared for ${email} as ${role}`, sessionId: null, createdAt: timestamp, updatedAt: timestamp, localDeleted: false };
  const db = getDatabase();
  await db.withTransactionAsync(async () => { await upsertLog(log); await enqueue({ storeId, entity: "invitation", operation: "create", payload: { fullName: fullName.trim(), email: email.trim().toLowerCase(), role, activity: log }, dependencies: [] }); });
}

export async function updateMemberLocally(member: StoreMembership, actor: Actor, update: { role?: Extract<StoreRole, "staff" | "manager">; isActive?: boolean; remove?: boolean }): Promise<void> {
  if (member.role === "owner") throw new Error("The store owner cannot be changed, disabled, or removed.");
  const timestamp = now();
  const action: ActivityLog["actionType"] = update.remove ? "user_removed" : update.isActive === false ? "user_disabled" : update.isActive === true ? "user_enabled" : "role_changed";
  const log: ActivityLog = { id: Crypto.randomUUID(), storeId: member.storeId, userId: actor.id, userName: actor.name, userRole: actor.role, actionType: action, itemId: null, itemName: member.fullName ?? member.email ?? "Team member", quantityHundredths: null, unit: null, details: update.remove ? "Member access removed" : update.role ? `Role changed to ${update.role}` : update.isActive ? "Member access enabled" : "Member access disabled", sessionId: null, createdAt: timestamp, updatedAt: timestamp, localDeleted: false };
  const updated: StoreMembership = { ...member, role: update.role ?? member.role, isActive: update.isActive ?? member.isActive, updatedAt: timestamp, localDeleted: Boolean(update.remove) };
  const db = getDatabase();
  await db.withTransactionAsync(async () => { await upsertMembership(updated); await upsertLog(log); await enqueue({ storeId: member.storeId, entity: "member", operation: "update", payload: { memberId: member.id, role: update.role ?? null, isActive: update.isActive ?? null, remove: Boolean(update.remove), activity: log }, dependencies: [] }); });
}

export async function deleteItemLocally(item: InventoryItem, actor: Actor): Promise<void> {
  const timestamp = now();
  const log: ActivityLog = { id: Crypto.randomUUID(), storeId: item.storeId, userId: actor.id, userName: actor.name, userRole: actor.role, actionType: "item_deleted", itemId: item.id, itemName: item.name, quantityHundredths: null, unit: null, details: "Item deleted", sessionId: null, createdAt: timestamp, updatedAt: timestamp, localDeleted: false };
  const db = getDatabase();
  await db.withTransactionAsync(async () => { await upsertItem({ ...item, localDeleted: true, updatedAt: timestamp }); await upsertLog(log); await enqueue({ storeId: item.storeId, entity: "item", operation: "delete", payload: { itemId: item.id, activity: log }, dependencies: [] }); });
}
