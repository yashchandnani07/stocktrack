import { Platform } from "react-native";

type Row = Record<string, string | number | null>;
type DatabaseAdapter = {
  execAsync(sql: string): Promise<void>;
  getFirstAsync<T>(sql: string, params?: (string | number | null)[]): Promise<T | null>;
  getAllAsync<T>(sql: string, params?: (string | number | null)[]): Promise<T[]>;
  runAsync(sql: string, params?: (string | number | null)[]): Promise<void>;
  withTransactionAsync(callback: () => Promise<void>): Promise<void>;
};

const memoryTables: Record<string, Row[]> = { local_settings: [], stores: [], store_members: [], categories: [], inventory_items: [], activity_logs: [], stock_sessions: [], stock_session_items: [], outbox_operations: [] };
const memoryDb: DatabaseAdapter = {
  async execAsync() {},
  async withTransactionAsync(callback) { await callback(); },
  async runAsync(sql, params = []) {
    const value = (index: number) => params[index] ?? null;
    const upsert = (table: keyof typeof memoryTables, row: Row, key: string) => { const index = memoryTables[table].findIndex((candidate) => candidate[key] === row[key]); if (index >= 0) memoryTables[table][index] = { ...memoryTables[table][index], ...row }; else memoryTables[table].push(row); };
    if (sql.includes("INSERT INTO local_settings")) return upsert("local_settings", { key: value(0), value: value(1), updated_at: value(2) }, "key");
    if (sql.includes("INSERT INTO stores")) return upsert("stores", { id: value(0), name: value(1), owner_id: value(2), allow_negative_stock: value(3), created_at: value(4), updated_at: value(5), local_deleted: value(6) }, "id");
    if (sql.includes("INSERT INTO inventory_items")) return upsert("inventory_items", { id: value(0), store_id: value(1), name: value(2), category_id: value(3), category_name: value(4), quantity_hundredths: value(5), low_stock_threshold_hundredths: value(6), unit: value(7), barcode: value(8), updated_by: value(9), created_at: value(10), updated_at: value(11), local_deleted: value(12) }, "id");
    if (sql.includes("INSERT INTO categories")) return upsert("categories", { id: value(0), store_id: value(1), name: value(2), color_value: value(3), icon_code: value(4), created_at: value(5), updated_at: value(6), local_deleted: value(7) }, "id");
    if (sql.includes("INSERT INTO activity_logs")) return upsert("activity_logs", { id: value(0), store_id: value(1), user_id: value(2), user_name: value(3), user_role: value(4), action_type: value(5), item_id: value(6), item_name: value(7), quantity_hundredths: value(8), unit: value(9), details: value(10), session_id: value(11), correction_meta_json: value(12), created_at: value(13), updated_at: value(14), local_deleted: value(15) }, "id");
    if (sql.includes("INSERT INTO stock_sessions")) return upsert("stock_sessions", { id: value(0), store_id: value(1), session_type: value(2), performer_id: value(3), performer_name: value(4), performer_role: value(5), total_items: value(6), notes: value(7), created_at: value(8), updated_at: value(9), local_deleted: value(10) }, "id");
    if (sql.includes("INSERT INTO stock_session_items")) return upsert("stock_session_items", { id: value(0), session_id: value(1), store_id: value(2), item_id: value(3), item_name: value(4), category: value(5), quantity_hundredths: value(6), unit: value(7), activity_log_id: value(8), created_at: value(9), updated_at: value(10), local_deleted: value(11) }, "id");
    if (sql.includes("INSERT INTO store_members")) return upsert("store_members", { id: value(0), store_id: value(1), user_id: value(2), role: value(3), is_active: value(4), full_name: value(5), email: value(6), created_at: value(7), updated_at: value(8), local_deleted: value(9) }, "id");
    if (sql.includes("INSERT INTO outbox_operations")) return upsert("outbox_operations", { id: value(0), operation_key: value(1), store_id: value(2), entity: value(3), operation: value(4), payload_json: value(5), dependencies_json: value(6), created_at: value(7), attempt_count: value(8), status: value(9), last_error: value(10), last_attempt_at: value(11) }, "id");
    if (sql.startsWith("UPDATE inventory_items SET category_id")) { memoryTables.inventory_items.forEach((row) => { if (row.store_id === value(3) && row.category_id === value(4)) Object.assign(row, { category_id: value(0), category_name: value(1), updated_at: value(2) }); }); return; }
    if (sql.startsWith("UPDATE categories SET local_deleted")) { const row = memoryTables.categories.find((candidate) => candidate.id === value(1)); if (row) Object.assign(row, { local_deleted: 1, updated_at: value(0) }); return; }
    if (sql.startsWith("UPDATE outbox_operations SET")) { const row = memoryTables.outbox_operations.find((candidate) => candidate.id === value(4)); if (row) Object.assign(row, { status: value(0), attempt_count: value(1), last_error: value(2), last_attempt_at: value(3) }); return; }
    if (sql.startsWith("DELETE FROM outbox_operations")) { memoryTables.outbox_operations.splice(memoryTables.outbox_operations.findIndex((candidate) => candidate.id === value(0)), 1); }
  },
  async getAllAsync<T>(sql: string, params: (string | number | null)[] = []) {
    const live = (table: keyof typeof memoryTables) => memoryTables[table].filter((row) => row.local_deleted !== 1);
    const sortUpdated = (rows: Row[]) => [...rows].sort((a, b) => String(b.updated_at ?? b.created_at).localeCompare(String(a.updated_at ?? a.created_at)));
    if (sql.includes("FROM stores")) return sortUpdated(live("stores")) as T[];
    if (sql.includes("FROM inventory_items")) return sortUpdated(live("inventory_items").filter((row) => row.store_id === params[0])) as T[];
    if (sql.includes("FROM categories")) return [...live("categories").filter((row) => row.store_id === params[0])].sort((a, b) => String(a.name).localeCompare(String(b.name))) as T[];
    if (sql.includes("FROM activity_logs")) return [...live("activity_logs").filter((row) => row.store_id === params[0])].sort((a, b) => String(b.created_at).localeCompare(String(a.created_at))).slice(0, Number(params[1] ?? 200)) as T[];
    if (sql.includes("FROM stock_sessions")) return [...live("stock_sessions").filter((row) => row.store_id === params[0])].sort((a, b) => String(b.created_at).localeCompare(String(a.created_at))).slice(0, Number(params[1] ?? 100)) as T[];
    if (sql.includes("FROM stock_session_items")) return [...live("stock_session_items").filter((row) => row.session_id === params[0])].sort((a, b) => String(a.item_name).localeCompare(String(b.item_name))) as T[];
    if (sql.includes("FROM store_members")) return live("store_members").filter((row) => row.store_id === params[0]) as T[];
    if (sql.includes("FROM outbox_operations")) return memoryTables.outbox_operations.filter((row) => params.some((value) => value === row.status)).sort((a, b) => String(a.created_at).localeCompare(String(b.created_at))) as T[];
    return [];
  },
  async getFirstAsync<T>(sql: string, params: (string | number | null)[] = []) {
    if (sql.includes("SUM(CASE WHEN status")) { const rows = memoryTables.outbox_operations; const failed = rows.filter((row) => row.status === "failed"); return { pending: rows.filter((row) => row.status === "pending" || row.status === "syncing").length, failed: failed.length, error: failed.at(-1)?.last_error ?? null } as T; }
    if (sql.includes("FROM local_settings")) return (memoryTables.local_settings.find((row) => row.key === params[0]) ?? null) as T | null;
    if (sql.includes("FROM stores")) return (memoryTables.stores.find((row) => row.id === params[0] && row.local_deleted !== 1) ?? null) as T | null;
    if (sql.includes("FROM inventory_items")) return (memoryTables.inventory_items.find((row) => row.id === params[0] && row.local_deleted !== 1) ?? null) as T | null;
    if (sql.includes("FROM store_members")) return (memoryTables.store_members.find((row) => row.store_id === params[0] && row.user_id === params[1] && row.local_deleted !== 1) ?? null) as T | null;
    return null;
  },
};

const db: DatabaseAdapter = Platform.OS === "web" ? memoryDb : (() => { // eslint-disable-next-line @typescript-eslint/no-require-imports -- prevents Metro web from evaluating the native-only SQLite module.
  const SQLite = require("expo-sqlite") as typeof import("expo-sqlite"); return SQLite.openDatabaseSync("stocktrack.db") as unknown as DatabaseAdapter; })();
let initialized = false;

export async function initializeLocalDatabase(): Promise<void> {
  if (initialized) return;
  await db.execAsync(`
    PRAGMA journal_mode = WAL;
    PRAGMA foreign_keys = ON;
    CREATE TABLE IF NOT EXISTS stores (id TEXT PRIMARY KEY NOT NULL, name TEXT NOT NULL, owner_id TEXT NOT NULL, allow_negative_stock INTEGER NOT NULL DEFAULT 1, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, local_deleted INTEGER NOT NULL DEFAULT 0);
    CREATE TABLE IF NOT EXISTS store_members (id TEXT PRIMARY KEY NOT NULL, store_id TEXT NOT NULL, user_id TEXT NOT NULL, role TEXT NOT NULL, is_active INTEGER NOT NULL DEFAULT 1, full_name TEXT, email TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, local_deleted INTEGER NOT NULL DEFAULT 0);
    CREATE INDEX IF NOT EXISTS store_members_store_user_idx ON store_members(store_id, user_id);
    CREATE TABLE IF NOT EXISTS categories (id TEXT PRIMARY KEY NOT NULL, store_id TEXT NOT NULL, name TEXT NOT NULL, color_value TEXT NOT NULL, icon_code TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, local_deleted INTEGER NOT NULL DEFAULT 0);
    CREATE INDEX IF NOT EXISTS categories_store_name_idx ON categories(store_id, name);
    CREATE TABLE IF NOT EXISTS inventory_items (id TEXT PRIMARY KEY NOT NULL, store_id TEXT NOT NULL, name TEXT NOT NULL, category_id TEXT, category_name TEXT NOT NULL, quantity_hundredths INTEGER NOT NULL, low_stock_threshold_hundredths INTEGER NOT NULL, unit TEXT NOT NULL, barcode TEXT, updated_by TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, local_deleted INTEGER NOT NULL DEFAULT 0);
    CREATE INDEX IF NOT EXISTS inventory_items_store_updated_idx ON inventory_items(store_id, updated_at DESC);
    CREATE INDEX IF NOT EXISTS inventory_items_store_name_idx ON inventory_items(store_id, name);
    CREATE TABLE IF NOT EXISTS activity_logs (id TEXT PRIMARY KEY NOT NULL, store_id TEXT NOT NULL, user_id TEXT NOT NULL, user_name TEXT NOT NULL, user_role TEXT NOT NULL, action_type TEXT NOT NULL, item_id TEXT, item_name TEXT, quantity_hundredths INTEGER, unit TEXT, details TEXT, session_id TEXT, correction_meta_json TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, local_deleted INTEGER NOT NULL DEFAULT 0);
    CREATE INDEX IF NOT EXISTS activity_logs_store_created_idx ON activity_logs(store_id, created_at DESC);
    CREATE TABLE IF NOT EXISTS stock_sessions (id TEXT PRIMARY KEY NOT NULL, store_id TEXT NOT NULL, session_type TEXT NOT NULL, performer_id TEXT NOT NULL, performer_name TEXT NOT NULL, performer_role TEXT NOT NULL, total_items INTEGER NOT NULL, notes TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, local_deleted INTEGER NOT NULL DEFAULT 0);
    CREATE INDEX IF NOT EXISTS stock_sessions_store_created_idx ON stock_sessions(store_id, created_at DESC);
    CREATE TABLE IF NOT EXISTS stock_session_items (id TEXT PRIMARY KEY NOT NULL, session_id TEXT NOT NULL, store_id TEXT NOT NULL, item_id TEXT NOT NULL, item_name TEXT NOT NULL, category TEXT NOT NULL, quantity_hundredths INTEGER NOT NULL, unit TEXT NOT NULL, activity_log_id TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, local_deleted INTEGER NOT NULL DEFAULT 0);
    CREATE INDEX IF NOT EXISTS session_items_session_idx ON stock_session_items(session_id);
    CREATE TABLE IF NOT EXISTS outbox_operations (id TEXT PRIMARY KEY NOT NULL, operation_key TEXT NOT NULL UNIQUE, store_id TEXT, entity TEXT NOT NULL, operation TEXT NOT NULL, payload_json TEXT NOT NULL, dependencies_json TEXT NOT NULL DEFAULT '[]', created_at TEXT NOT NULL, attempt_count INTEGER NOT NULL DEFAULT 0, status TEXT NOT NULL DEFAULT 'pending', last_error TEXT, last_attempt_at TEXT);
    CREATE INDEX IF NOT EXISTS outbox_status_created_idx ON outbox_operations(status, created_at);
    CREATE TABLE IF NOT EXISTS local_settings (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL, updated_at TEXT NOT NULL);
  `);
  initialized = true;
}

export function getDatabase(): DatabaseAdapter { return db; }
