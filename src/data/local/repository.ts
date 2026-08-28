import * as Crypto from "expo-crypto";
import { getDatabase, initializeLocalDatabase } from "./database";
import type { ActivityAction, ActivityLog, Category, InventoryDraft, InventoryItem, OutboxEntry, OutboxOperation, StockSession, StockSessionItem, Store, StoreMembership, StoreRole, SyncOverview } from "@/src/lib/types";

const now = () => new Date().toISOString();
const bool = (value: number | string | boolean | null | undefined) => value === 1 || value === "1" || value === true;

type DatabaseRow = Record<string, string | number | null>;

function storeFrom(row: DatabaseRow): Store {
  return { id: String(row.id), name: String(row.name), ownerId: String(row.owner_id), allowNegativeStock: bool(row.allow_negative_stock), createdAt: String(row.created_at), updatedAt: String(row.updated_at), localDeleted: bool(row.local_deleted) };
}

function itemFrom(row: DatabaseRow): InventoryItem {
  return { id: String(row.id), storeId: String(row.store_id), name: String(row.name), categoryId: row.category_id ? String(row.category_id) : null, categoryName: String(row.category_name), quantityHundredths: Number(row.quantity_hundredths), lowStockThresholdHundredths: Number(row.low_stock_threshold_hundredths), unit: String(row.unit), barcode: row.barcode ? String(row.barcode) : null, updatedBy: row.updated_by ? String(row.updated_by) : null, createdAt: String(row.created_at), updatedAt: String(row.updated_at), localDeleted: bool(row.local_deleted) };
}

function categoryFrom(row: DatabaseRow): Category {
  return { id: String(row.id), storeId: String(row.store_id), name: String(row.name), colorValue: String(row.color_value), iconCode: String(row.icon_code), createdAt: String(row.created_at), updatedAt: String(row.updated_at), localDeleted: bool(row.local_deleted) };
}

function logFrom(row: DatabaseRow): ActivityLog {
  return { id: String(row.id), storeId: String(row.store_id), userId: String(row.user_id), userName: String(row.user_name), userRole: row.user_role as StoreRole, actionType: row.action_type as ActivityAction, itemId: row.item_id ? String(row.item_id) : null, itemName: row.item_name ? String(row.item_name) : null, quantityHundredths: row.quantity_hundredths === null ? null : Number(row.quantity_hundredths), unit: row.unit ? String(row.unit) : null, details: row.details ? String(row.details) : null, sessionId: row.session_id ? String(row.session_id) : null, correctionMeta: row.correction_meta_json ? JSON.parse(String(row.correction_meta_json)) as Record<string, unknown> : null, createdAt: String(row.created_at), updatedAt: String(row.updated_at), localDeleted: bool(row.local_deleted) };
}

function sessionFrom(row: DatabaseRow): StockSession {
  return { id: String(row.id), storeId: String(row.store_id), sessionType: row.session_type as "IN" | "OUT", performerId: String(row.performer_id), performerName: String(row.performer_name), performerRole: row.performer_role as StoreRole, totalItems: Number(row.total_items), notes: row.notes ? String(row.notes) : null, createdAt: String(row.created_at), updatedAt: String(row.updated_at), localDeleted: bool(row.local_deleted) };
}

function sessionItemFrom(row: DatabaseRow): StockSessionItem {
  return { id: String(row.id), sessionId: String(row.session_id), storeId: String(row.store_id), itemId: String(row.item_id), itemName: String(row.item_name), category: String(row.category), quantityHundredths: Number(row.quantity_hundredths), unit: String(row.unit), activityLogId: String(row.activity_log_id), createdAt: String(row.created_at), updatedAt: String(row.updated_at), localDeleted: bool(row.local_deleted) };
}

function outboxFrom(row: DatabaseRow): OutboxEntry {
  return { id: String(row.id), operationKey: String(row.operation_key), storeId: row.store_id ? String(row.store_id) : null, entity: row.entity as OutboxEntry["entity"], operation: row.operation as OutboxOperation, payload: JSON.parse(String(row.payload_json)) as Record<string, unknown>, dependencies: JSON.parse(String(row.dependencies_json)) as string[], createdAt: String(row.created_at), attemptCount: Number(row.attempt_count), status: row.status as OutboxEntry["status"], lastError: row.last_error ? String(row.last_error) : null, lastAttemptAt: row.last_attempt_at ? String(row.last_attempt_at) : null };
}

async function ready() { await initializeLocalDatabase(); return getDatabase(); }

export async function getSetting(key: string): Promise<string | null> {
  const db = await ready();
  const row = await db.getFirstAsync<DatabaseRow>("SELECT value FROM local_settings WHERE key = ?", [key]);
  return row?.value ? String(row.value) : null;
}

export async function setSetting(key: string, value: string): Promise<void> {
  const db = await ready();
  await db.runAsync("INSERT INTO local_settings (key, value, updated_at) VALUES (?, ?, ?) ON CONFLICT(key) DO UPDATE SET value=excluded.value, updated_at=excluded.updated_at", [key, value, now()]);
}

export async function listStores(): Promise<Store[]> {
  const db = await ready();
  return (await db.getAllAsync<DatabaseRow>("SELECT * FROM stores WHERE local_deleted = 0 ORDER BY updated_at DESC")).map(storeFrom);
}

export async function getStore(id: string): Promise<Store | null> {
  const db = await ready();
  const row = await db.getFirstAsync<DatabaseRow>("SELECT * FROM stores WHERE id = ? AND local_deleted = 0", [id]);
  return row ? storeFrom(row) : null;
}

export async function upsertStore(store: Store): Promise<void> {
  const db = await ready();
  await db.runAsync(`INSERT INTO stores (id,name,owner_id,allow_negative_stock,created_at,updated_at,local_deleted) VALUES (?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET name=excluded.name,owner_id=excluded.owner_id,allow_negative_stock=excluded.allow_negative_stock,updated_at=excluded.updated_at,local_deleted=excluded.local_deleted`, [store.id, store.name, store.ownerId, store.allowNegativeStock ? 1 : 0, store.createdAt, store.updatedAt, store.localDeleted ? 1 : 0]);
}

export async function listInventory(storeId: string): Promise<InventoryItem[]> {
  const db = await ready();
  return (await db.getAllAsync<DatabaseRow>("SELECT * FROM inventory_items WHERE store_id = ? AND local_deleted = 0 ORDER BY updated_at DESC", [storeId])).map(itemFrom);
}

export async function getItem(id: string): Promise<InventoryItem | null> {
  const db = await ready();
  const row = await db.getFirstAsync<DatabaseRow>("SELECT * FROM inventory_items WHERE id = ? AND local_deleted = 0", [id]);
  return row ? itemFrom(row) : null;
}

export async function upsertItem(item: InventoryItem): Promise<void> {
  const db = await ready();
  await db.runAsync(`INSERT INTO inventory_items (id,store_id,name,category_id,category_name,quantity_hundredths,low_stock_threshold_hundredths,unit,barcode,updated_by,created_at,updated_at,local_deleted) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET store_id=excluded.store_id,name=excluded.name,category_id=excluded.category_id,category_name=excluded.category_name,quantity_hundredths=excluded.quantity_hundredths,low_stock_threshold_hundredths=excluded.low_stock_threshold_hundredths,unit=excluded.unit,barcode=excluded.barcode,updated_by=excluded.updated_by,updated_at=excluded.updated_at,local_deleted=excluded.local_deleted`, [item.id,item.storeId,item.name,item.categoryId,item.categoryName,item.quantityHundredths,item.lowStockThresholdHundredths,item.unit,item.barcode,item.updatedBy,item.createdAt,item.updatedAt,item.localDeleted ? 1 : 0]);
}

export async function listCategories(storeId: string): Promise<Category[]> {
  const db = await ready();
  return (await db.getAllAsync<DatabaseRow>("SELECT * FROM categories WHERE store_id = ? AND local_deleted = 0 ORDER BY name COLLATE NOCASE", [storeId])).map(categoryFrom);
}

export async function upsertCategory(category: Category): Promise<void> {
  const db = await ready();
  await db.runAsync(`INSERT INTO categories (id,store_id,name,color_value,icon_code,created_at,updated_at,local_deleted) VALUES (?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET store_id=excluded.store_id,name=excluded.name,color_value=excluded.color_value,icon_code=excluded.icon_code,updated_at=excluded.updated_at,local_deleted=excluded.local_deleted`, [category.id,category.storeId,category.name,category.colorValue,category.iconCode,category.createdAt,category.updatedAt,category.localDeleted ? 1 : 0]);
}

export async function listLogs(storeId: string, limit = 200): Promise<ActivityLog[]> {
  const db = await ready();
  return (await db.getAllAsync<DatabaseRow>("SELECT * FROM activity_logs WHERE store_id = ? AND local_deleted = 0 ORDER BY created_at DESC LIMIT ?", [storeId, limit])).map(logFrom);
}

export async function upsertLog(log: ActivityLog): Promise<void> {
  const db = await ready();
  await db.runAsync(`INSERT INTO activity_logs (id,store_id,user_id,user_name,user_role,action_type,item_id,item_name,quantity_hundredths,unit,details,session_id,correction_meta_json,created_at,updated_at,local_deleted) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET quantity_hundredths=excluded.quantity_hundredths,details=excluded.details,correction_meta_json=excluded.correction_meta_json,updated_at=excluded.updated_at,local_deleted=excluded.local_deleted`, [log.id,log.storeId,log.userId,log.userName,log.userRole,log.actionType,log.itemId,log.itemName,log.quantityHundredths,log.unit,log.details,log.sessionId,log.correctionMeta ? JSON.stringify(log.correctionMeta) : null,log.createdAt,log.updatedAt,log.localDeleted ? 1 : 0]);
}

export async function listSessions(storeId: string, limit = 100): Promise<StockSession[]> {
  const db = await ready();
  return (await db.getAllAsync<DatabaseRow>("SELECT * FROM stock_sessions WHERE store_id = ? AND local_deleted = 0 ORDER BY created_at DESC LIMIT ?", [storeId, limit])).map(sessionFrom);
}

export async function listSessionItems(sessionId: string): Promise<StockSessionItem[]> {
  const db = await ready();
  return (await db.getAllAsync<DatabaseRow>("SELECT * FROM stock_session_items WHERE session_id = ? AND local_deleted = 0 ORDER BY item_name COLLATE NOCASE", [sessionId])).map(sessionItemFrom);
}

export async function upsertSession(session: StockSession): Promise<void> {
  const db = await ready();
  await db.runAsync(`INSERT INTO stock_sessions (id,store_id,session_type,performer_id,performer_name,performer_role,total_items,notes,created_at,updated_at,local_deleted) VALUES (?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET total_items=excluded.total_items,notes=excluded.notes,updated_at=excluded.updated_at,local_deleted=excluded.local_deleted`, [session.id,session.storeId,session.sessionType,session.performerId,session.performerName,session.performerRole,session.totalItems,session.notes,session.createdAt,session.updatedAt,session.localDeleted ? 1 : 0]);
}

export async function upsertSessionItem(line: StockSessionItem): Promise<void> {
  const db = await ready();
  await db.runAsync(`INSERT INTO stock_session_items (id,session_id,store_id,item_id,item_name,category,quantity_hundredths,unit,activity_log_id,created_at,updated_at,local_deleted) VALUES (?,?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET quantity_hundredths=excluded.quantity_hundredths,updated_at=excluded.updated_at,local_deleted=excluded.local_deleted`, [line.id,line.sessionId,line.storeId,line.itemId,line.itemName,line.category,line.quantityHundredths,line.unit,line.activityLogId,line.createdAt,line.updatedAt,line.localDeleted ? 1 : 0]);
}

export async function upsertMembership(member: StoreMembership): Promise<void> {
  const db = await ready();
  await db.runAsync(`INSERT INTO store_members (id,store_id,user_id,role,is_active,full_name,email,created_at,updated_at,local_deleted) VALUES (?,?,?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET role=excluded.role,is_active=excluded.is_active,full_name=excluded.full_name,email=excluded.email,updated_at=excluded.updated_at,local_deleted=excluded.local_deleted`, [member.id,member.storeId,member.userId,member.role,member.isActive ? 1 : 0,member.fullName ?? null,member.email ?? null,member.createdAt,member.updatedAt,member.localDeleted ? 1 : 0]);
}

export async function listMembers(storeId: string): Promise<StoreMembership[]> {
  const db = await ready();
  const rows = await db.getAllAsync<DatabaseRow>("SELECT * FROM store_members WHERE store_id = ? AND local_deleted = 0 ORDER BY CASE role WHEN 'owner' THEN 0 WHEN 'manager' THEN 1 ELSE 2 END, full_name", [storeId]);
  return rows.map((row) => ({ id: String(row.id), storeId: String(row.store_id), userId: String(row.user_id), role: row.role as StoreRole, isActive: bool(row.is_active), fullName: row.full_name ? String(row.full_name) : undefined, email: row.email ? String(row.email) : undefined, createdAt: String(row.created_at), updatedAt: String(row.updated_at), localDeleted: bool(row.local_deleted) }));
}

export async function getActiveMembership(storeId: string, userId: string): Promise<StoreMembership | null> {
  const db = await ready();
  const row = await db.getFirstAsync<DatabaseRow>("SELECT * FROM store_members WHERE store_id = ? AND user_id = ? AND local_deleted = 0", [storeId, userId]);
  if (!row) return null;
  return { id: String(row.id), storeId: String(row.store_id), userId: String(row.user_id), role: row.role as StoreRole, isActive: bool(row.is_active), fullName: row.full_name ? String(row.full_name) : undefined, email: row.email ? String(row.email) : undefined, createdAt: String(row.created_at), updatedAt: String(row.updated_at), localDeleted: bool(row.local_deleted) };
}

export async function enqueue(operation: Omit<OutboxEntry, "id" | "operationKey" | "createdAt" | "attemptCount" | "status" | "lastError" | "lastAttemptAt"> & { id?: string; operationKey?: string }): Promise<OutboxEntry> {
  const db = await ready();
  const entry: OutboxEntry = { id: operation.id ?? Crypto.randomUUID(), operationKey: operation.operationKey ?? Crypto.randomUUID(), storeId: operation.storeId, entity: operation.entity, operation: operation.operation, payload: operation.payload, dependencies: operation.dependencies, createdAt: now(), attemptCount: 0, status: "pending", lastError: null, lastAttemptAt: null };
  await db.runAsync(`INSERT INTO outbox_operations (id,operation_key,store_id,entity,operation,payload_json,dependencies_json,created_at,attempt_count,status,last_error,last_attempt_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)`, [entry.id,entry.operationKey,entry.storeId,entry.entity,entry.operation,JSON.stringify(entry.payload),JSON.stringify(entry.dependencies),entry.createdAt,entry.attemptCount,entry.status,entry.lastError,entry.lastAttemptAt]);
  return entry;
}

export async function listOutbox(statuses: OutboxEntry["status"][] = ["pending", "failed"]): Promise<OutboxEntry[]> {
  const db = await ready();
  const placeholders = statuses.map(() => "?").join(",");
  return (await db.getAllAsync<DatabaseRow>(`SELECT * FROM outbox_operations WHERE status IN (${placeholders}) ORDER BY created_at ASC`, statuses)).map(outboxFrom);
}

export async function updateOutbox(entry: OutboxEntry, patch: Partial<Pick<OutboxEntry, "status" | "attemptCount" | "lastError" | "lastAttemptAt">>): Promise<void> {
  const db = await ready();
  await db.runAsync("UPDATE outbox_operations SET status=?,attempt_count=?,last_error=?,last_attempt_at=? WHERE id=?", [patch.status ?? entry.status,patch.attemptCount ?? entry.attemptCount,patch.lastError ?? entry.lastError,patch.lastAttemptAt ?? entry.lastAttemptAt,entry.id]);
}

export async function removeOutbox(id: string): Promise<void> { const db = await ready(); await db.runAsync("DELETE FROM outbox_operations WHERE id = ?", [id]); }

export async function getSyncOverview(): Promise<SyncOverview> {
  const db = await ready();
  const counts = await db.getFirstAsync<DatabaseRow>("SELECT SUM(CASE WHEN status IN ('pending','syncing') THEN 1 ELSE 0 END) as pending, SUM(CASE WHEN status='failed' THEN 1 ELSE 0 END) as failed, MAX(last_error) as error FROM outbox_operations");
  const lastSuccessfulSync = await getSetting("last_successful_sync");
  const pendingCount = Number(counts?.pending ?? 0);
  const failedCount = Number(counts?.failed ?? 0);
  return { state: failedCount > 0 ? "failed" : pendingCount > 0 ? "pending" : "synced", pendingCount, failedCount, lastSuccessfulSync, latestError: counts?.error ? String(counts.error) : null };
}

export async function saveItemDraft(storeId: string, actor: { id: string; name: string; role: StoreRole }, draft: InventoryDraft, existing: InventoryItem | null): Promise<InventoryItem> {
  const db = await ready();
  const timestamp = now();
  const item: InventoryItem = { id: existing?.id ?? Crypto.randomUUID(), storeId, name: draft.name.trim(), categoryId: draft.categoryId, categoryName: draft.categoryName, quantityHundredths: existing?.quantityHundredths ?? draft.quantityHundredths, lowStockThresholdHundredths: draft.lowStockThresholdHundredths, unit: draft.unit, barcode: draft.barcode || null, updatedBy: actor.id, createdAt: existing?.createdAt ?? timestamp, updatedAt: timestamp, localDeleted: false };
  const action: ActivityAction = existing ? "item_edited" : "item_created";
  const log: ActivityLog = { id: Crypto.randomUUID(), storeId, userId: actor.id, userName: actor.name, userRole: actor.role, actionType: action, itemId: item.id, itemName: item.name, quantityHundredths: null, unit: null, details: existing ? "Item details updated" : "Item created", sessionId: null, createdAt: timestamp, updatedAt: timestamp, localDeleted: false };
  await db.withTransactionAsync(async () => { await upsertItem(item); await upsertLog(log); await enqueue({ storeId, entity: "item", operation: existing ? "update" : "create", payload: { item, activity: log }, dependencies: [] }); });
  return item;
}
