export const STORE_ROLES = ["staff", "manager", "owner"] as const;
export type StoreRole = (typeof STORE_ROLES)[number];

export const SESSION_TYPES = ["IN", "OUT"] as const;
export type SessionType = (typeof SESSION_TYPES)[number];

export const ACTIVITY_ACTIONS = [
  "stock_in",
  "stock_out",
  "stock_correction",
  "item_created",
  "item_edited",
  "item_deleted",
  "category_created",
  "category_deleted",
  "bulk_import",
  "user_added",
  "user_removed",
  "role_changed",
  "user_enabled",
  "user_disabled",
] as const;
export type ActivityAction = (typeof ACTIVITY_ACTIONS)[number];

export type SyncState = "synced" | "offline" | "pending" | "syncing" | "failed";
export type OutboxEntity = "store" | "category" | "item" | "stock_delta" | "session" | "member" | "invitation" | "activity";
export type OutboxOperation = "create" | "update" | "delete" | "stock_delta" | "bulk_session" | "correct";

export interface Store {
  id: string;
  name: string;
  ownerId: string;
  allowNegativeStock: boolean;
  createdAt: string;
  updatedAt: string;
  localDeleted?: boolean;
}

export interface StoreMembership {
  id: string;
  storeId: string;
  userId: string;
  role: StoreRole;
  isActive: boolean;
  fullName?: string;
  email?: string;
  createdAt: string;
  updatedAt: string;
  localDeleted?: boolean;
}

export interface Category {
  id: string;
  storeId: string;
  name: string;
  colorValue: string;
  iconCode: string;
  createdAt: string;
  updatedAt: string;
  localDeleted?: boolean;
}

export interface InventoryItem {
  id: string;
  storeId: string;
  name: string;
  categoryId: string | null;
  categoryName: string;
  quantityHundredths: number;
  lowStockThresholdHundredths: number;
  unit: string;
  barcode: string | null;
  updatedBy: string | null;
  createdAt: string;
  updatedAt: string;
  localDeleted?: boolean;
}

export interface ActivityLog {
  id: string;
  storeId: string;
  userId: string;
  userName: string;
  userRole: StoreRole;
  actionType: ActivityAction;
  itemId: string | null;
  itemName: string | null;
  quantityHundredths: number | null;
  unit: string | null;
  details: string | null;
  sessionId: string | null;
  correctionMeta?: Record<string, unknown> | null;
  createdAt: string;
  updatedAt: string;
  localDeleted?: boolean;
}

export interface StockSession {
  id: string;
  storeId: string;
  sessionType: SessionType;
  performerId: string;
  performerName: string;
  performerRole: StoreRole;
  totalItems: number;
  notes: string | null;
  createdAt: string;
  updatedAt: string;
  localDeleted?: boolean;
}

export interface StockSessionItem {
  id: string;
  sessionId: string;
  storeId: string;
  itemId: string;
  itemName: string;
  category: string;
  quantityHundredths: number;
  unit: string;
  activityLogId: string;
  createdAt: string;
  updatedAt: string;
  localDeleted?: boolean;
}

export interface OutboxEntry {
  id: string;
  operationKey: string;
  storeId: string | null;
  entity: OutboxEntity;
  operation: OutboxOperation;
  payload: Record<string, unknown>;
  dependencies: string[];
  createdAt: string;
  attemptCount: number;
  status: "pending" | "syncing" | "failed";
  lastError: string | null;
  lastAttemptAt: string | null;
}

export interface InventoryDraft {
  id?: string;
  name: string;
  categoryId: string | null;
  categoryName: string;
  quantityHundredths: number;
  lowStockThresholdHundredths: number;
  unit: string;
  barcode: string | null;
}

export interface BulkSessionLine {
  item: InventoryItem;
  quantityHundredths: number;
}

export interface SyncOverview {
  state: SyncState;
  pendingCount: number;
  failedCount: number;
  lastSuccessfulSync: string | null;
  latestError: string | null;
}
