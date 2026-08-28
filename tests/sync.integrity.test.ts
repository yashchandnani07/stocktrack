import { describe, expect, it } from "vitest";
import { orderOutboxEntries, projectBulkSession } from "../src/data/sync/integrity";
import { correctionDelta } from "../src/lib/quantity";
import type { OutboxEntry } from "../src/lib/types";

function entry(entity: OutboxEntry["entity"], createdAt: string): Pick<OutboxEntry, "entity" | "createdAt"> {
  return { entity, createdAt };
}

describe("outbox dependency ordering", () => {
  it("groups entries store -> category/item -> stock/session/log -> member/invitation regardless of input order", () => {
    const scrambled = [entry("member", "1"), entry("invitation", "2"), entry("stock_delta", "3"), entry("item", "4"), entry("store", "5"), entry("category", "6"), entry("session", "7"), entry("activity", "8")];
    const result = orderOutboxEntries(scrambled).map((item) => item.entity);
    expect(result).toEqual(["store", "category", "item", "stock_delta", "session", "activity", "member", "invitation"]);
  });

  it("keeps entries within the same dependency group in original enqueue order", () => {
    const sameGroup = [entry("item", "2024-01-03T00:00:00.000Z"), entry("item", "2024-01-01T00:00:00.000Z"), entry("item", "2024-01-02T00:00:00.000Z")];
    expect(orderOutboxEntries(sameGroup).map((item) => item.createdAt)).toEqual(["2024-01-01T00:00:00.000Z", "2024-01-02T00:00:00.000Z", "2024-01-03T00:00:00.000Z"]);
  });

  it("does not mutate the input array", () => {
    const original = [entry("member", "2"), entry("store", "1")];
    const copy = [...original];
    orderOutboxEntries(original);
    expect(original).toEqual(copy);
  });
});

describe("batch stock session projections", () => {
  it("projects a stock-in session as additive deltas per item", () => {
    const result = projectBulkSession("IN", [{ itemId: "a", currentQuantityHundredths: 500, quantityHundredths: 250 }, { itemId: "b", currentQuantityHundredths: 0, quantityHundredths: 100 }]);
    expect(result).toEqual([{ itemId: "a", previousQuantityHundredths: 500, nextQuantityHundredths: 750, deltaHundredths: 250 }, { itemId: "b", previousQuantityHundredths: 0, nextQuantityHundredths: 100, deltaHundredths: 100 }]);
  });

  it("projects a stock-out session as subtractive deltas, allowing negative results per the default policy", () => {
    const result = projectBulkSession("OUT", [{ itemId: "a", currentQuantityHundredths: 500, quantityHundredths: 250 }, { itemId: "b", currentQuantityHundredths: 50, quantityHundredths: 100 }]);
    expect(result).toEqual([{ itemId: "a", previousQuantityHundredths: 500, nextQuantityHundredths: 250, deltaHundredths: -250 }, { itemId: "b", previousQuantityHundredths: 50, nextQuantityHundredths: -50, deltaHundredths: -100 }]);
  });
});

describe("stock-correction math", () => {
  it("computes only the difference between the corrected and originally recorded signed quantity", () => {
    expect(correctionDelta(1000, 700)).toBe(-300);
    expect(correctionDelta(-500, -800)).toBe(-300);
    expect(correctionDelta(200, 200)).toBe(0);
    expect(correctionDelta(-100, 100)).toBe(200);
  });
});
