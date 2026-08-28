import { parseQuantity, numericStringFromHundredths } from "@/src/lib/quantity";
import type { ActivityLog, Category, InventoryItem, StockSession, StockSessionItem, Store, StoreMembership, StoreRole } from "@/src/lib/types";
import { supabase } from "./supabase";

type RemoteRow = Record<string, unknown>;
const asString = (value: unknown) => value === null || value === undefined ? "" : String(value);
const asDate = (value: unknown) => asString(value) || new Date().toISOString();
const asQuantity = (value: unknown) => parseQuantity(asString(value)) ?? 0;

export function toStore(row: RemoteRow): Store { return { id: asString(row.id), name: asString(row.name), ownerId: asString(row.owner_id), allowNegativeStock: row.allow_negative_stock !== false, createdAt: asDate(row.created_at), updatedAt: asDate(row.updated_at), localDeleted: false }; }
export function toCategory(row: RemoteRow): Category { return { id: asString(row.id), storeId: asString(row.store_id), name: asString(row.name), colorValue: asString(row.color_value), iconCode: asString(row.icon_code), createdAt: asDate(row.created_at), updatedAt: asDate(row.updated_at), localDeleted: false }; }
export function toItem(row: RemoteRow): InventoryItem { return { id: asString(row.id), storeId: asString(row.store_id), name: asString(row.name), categoryId: row.category_id ? asString(row.category_id) : null, categoryName: asString(row.category_name) || "General", quantityHundredths: asQuantity(row.quantity), lowStockThresholdHundredths: asQuantity(row.low_stock_threshold), unit: asString(row.unit) || "pcs", barcode: row.barcode ? asString(row.barcode) : null, updatedBy: row.updated_by ? asString(row.updated_by) : null, createdAt: asDate(row.created_at), updatedAt: asDate(row.updated_at), localDeleted: false }; }
export function toLog(row: RemoteRow): ActivityLog { return { id: asString(row.id), storeId: asString(row.store_id), userId: asString(row.user_id), userName: asString(row.user_name), userRole: asString(row.user_role) as StoreRole, actionType: asString(row.action_type) as ActivityLog["actionType"], itemId: row.item_id ? asString(row.item_id) : null, itemName: row.item_name ? asString(row.item_name) : null, quantityHundredths: row.quantity === null || row.quantity === undefined ? null : asQuantity(row.quantity), unit: row.unit ? asString(row.unit) : null, details: row.details ? asString(row.details) : null, sessionId: row.session_id ? asString(row.session_id) : null, correctionMeta: (row.correction_meta as Record<string, unknown> | null) ?? null, createdAt: asDate(row.created_at), updatedAt: asDate(row.updated_at), localDeleted: false }; }
export function toSession(row: RemoteRow): StockSession { return { id: asString(row.id), storeId: asString(row.store_id), sessionType: asString(row.session_type) as StockSession["sessionType"], performerId: asString(row.performer_id), performerName: asString(row.performer_name), performerRole: asString(row.performer_role) as StoreRole, totalItems: Number(row.total_items) || 0, notes: row.notes ? asString(row.notes) : null, createdAt: asDate(row.created_at), updatedAt: asDate(row.updated_at), localDeleted: false }; }
export function toSessionItem(row: RemoteRow): StockSessionItem { return { id: asString(row.id), sessionId: asString(row.session_id), storeId: asString(row.store_id), itemId: asString(row.item_id), itemName: asString(row.item_name), category: asString(row.category), quantityHundredths: asQuantity(row.quantity), unit: asString(row.unit), activityLogId: asString(row.activity_log_id), createdAt: asDate(row.created_at), updatedAt: asDate(row.updated_at), localDeleted: false }; }
export function toMember(row: RemoteRow): StoreMembership { const profile = row.profiles as RemoteRow | null; return { id: asString(row.id), storeId: asString(row.store_id), userId: asString(row.user_id), role: asString(row.role) as StoreRole, isActive: row.is_active !== false, fullName: profile?.full_name ? asString(profile.full_name) : undefined, email: profile?.email ? asString(profile.email) : undefined, createdAt: asDate(row.created_at), updatedAt: asDate(row.updated_at), localDeleted: false }; }

export function itemPayload(item: InventoryItem) {
  return { id: item.id, store_id: item.storeId, name: item.name, category_id: item.categoryId, category_name: item.categoryName, quantity: numericStringFromHundredths(item.quantityHundredths), low_stock_threshold: numericStringFromHundredths(item.lowStockThresholdHundredths), unit: item.unit, barcode: item.barcode, updated_by: item.updatedBy };
}

export function categoryPayload(category: Category) { return { id: category.id, store_id: category.storeId, name: category.name, color_value: category.colorValue, icon_code: category.iconCode }; }

export function activityPayload(log: ActivityLog) { return { id: log.id, store_id: log.storeId, user_id: log.userId, user_name: log.userName, user_role: log.userRole, action_type: log.actionType, item_id: log.itemId, item_name: log.itemName, quantity: log.quantityHundredths === null ? null : numericStringFromHundredths(log.quantityHundredths), unit: log.unit, details: log.details, session_id: log.sessionId, correction_meta: log.correctionMeta }; }

export async function remoteErrorMessage(error: unknown): Promise<string> { return error instanceof Error ? error.message : "Supabase synchronization failed"; }

export async function isRemoteOnline(): Promise<boolean> {
  const { error } = await supabase.from("profiles").select("id", { head: true, count: "exact" }).limit(1);
  return !error;
}
