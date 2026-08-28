import * as Crypto from "expo-crypto";
import type { ActivityLog, Category } from "@/src/lib/types";
import { createCategoryLocally, type Actor } from "@/src/data/sync/mutations";
import { enqueue, listCategories, listInventory, saveItemDraft, upsertLog } from "@/src/data/local/repository";
import { getDatabase } from "@/src/data/local/database";
import type { ParsedImportRow } from "./csv";

export async function importInventoryRows(storeId: string, actor: Actor, rows: ParsedImportRow[]): Promise<{ created: number; updated: number }> {
  let items = await listInventory(storeId); let categories = await listCategories(storeId); let created = 0; let updated = 0;
  for (const row of rows) {
    let category: Category | undefined = categories.find((candidate) => candidate.name.localeCompare(row.categoryName ?? "General", undefined, { sensitivity: "accent" }) === 0);
    if (!category) { category = await createCategoryLocally(storeId, actor, row.categoryName ?? "General", "#3568D4", "inventory-2"); categories = await listCategories(storeId); }
    const existing = items.find((item) => item.name.trim().toLowerCase() === row.name.trim().toLowerCase());
    const item = await saveItemDraft(storeId, actor, { name: row.name, categoryId: category.id, categoryName: category.name, quantityHundredths: existing ? existing.quantityHundredths + row.quantityHundredths : row.quantityHundredths, lowStockThresholdHundredths: existing?.lowStockThresholdHundredths ?? 500, unit: existing?.unit ?? "pcs", barcode: existing?.barcode ?? null }, existing ?? null);
    items = existing ? items.map((candidate) => candidate.id === item.id ? item : candidate) : [item, ...items];
    if (existing) updated += 1; else created += 1;
  }
  const timestamp = new Date().toISOString();
  const activity: ActivityLog = { id: Crypto.randomUUID(), storeId, userId: actor.id, userName: actor.name, userRole: actor.role, actionType: "bulk_import", itemId: null, itemName: null, quantityHundredths: null, unit: null, details: `${created} created, ${updated} updated`, sessionId: null, createdAt: timestamp, updatedAt: timestamp, localDeleted: false };
  const db = getDatabase();
  await db.withTransactionAsync(async () => { await upsertLog(activity); await enqueue({ storeId, entity: "activity", operation: "create", payload: { activity }, dependencies: [] }); });
  return { created, updated };
}
