import type { OutboxEntity, OutboxEntry } from "@/src/lib/types";
import { signedDelta } from "@/src/lib/quantity";

// Dependency order mirrors the sync algorithm in the PRD: store -> category/item -> stock/session/log -> member/invitation.
// Entries within the same group keep their original enqueue order (stable sort by createdAt).
export const outboxPriority: Record<OutboxEntity, number> = { store: 0, category: 1, item: 2, stock_delta: 3, session: 3, activity: 3, member: 4, invitation: 4 };

export function orderOutboxEntries<T extends Pick<OutboxEntry, "entity" | "createdAt">>(entries: T[]): T[] {
  return [...entries].sort((a, b) => outboxPriority[a.entity] - outboxPriority[b.entity] || a.createdAt.localeCompare(b.createdAt));
}

export interface BulkSessionProjectionLine { itemId: string; currentQuantityHundredths: number; quantityHundredths: number; }
export interface BulkSessionProjection { itemId: string; previousQuantityHundredths: number; nextQuantityHundredths: number; deltaHundredths: number; }

// Pure projection of what a bulk stock-in/out session will do to each selected item's quantity. Used to render the
// "projected stock" preview and to validate a session before it is committed as one local transaction (see
// createBulkSessionLocally in mutations.ts, which applies exactly this delta to each item).
export function projectBulkSession(type: "IN" | "OUT", lines: BulkSessionProjectionLine[]): BulkSessionProjection[] {
  return lines.map((line) => {
    const delta = signedDelta(type, line.quantityHundredths);
    return { itemId: line.itemId, previousQuantityHundredths: line.currentQuantityHundredths, nextQuantityHundredths: line.currentQuantityHundredths + delta, deltaHundredths: delta };
  });
}
