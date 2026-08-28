import { describe, expect, it } from "vitest";
import { can, canViewActivityAction } from "../src/lib/permissions";
import { formatQuantity, parseQuantity, signedDelta, stockState } from "../src/lib/quantity";
import { parseInventoryCsv } from "../src/features/inventory/csv";

describe("decimal-safe inventory quantities", () => {
  it("parses and formats quantities without floating point drift", () => { expect(parseQuantity("12.34")).toBe(1234); expect(parseQuantity("0.1")).toBe(10); expect(formatQuantity(1234)).toBe("12.34"); expect(formatQuantity(-10)).toBe("-0.1"); });
  it("rejects invalid precision and applies movement direction", () => { expect(parseQuantity("3.456")).toBeNull(); expect(parseQuantity("abc")).toBeNull(); expect(signedDelta("IN", 250)).toBe(250); expect(signedDelta("OUT", 250)).toBe(-250); });
  it("derives the visible low and out stock states", () => { const base = { id: "1", storeId: "s", name: "Paper", categoryId: null, categoryName: "General", lowStockThresholdHundredths: 500, unit: "pcs", barcode: null, updatedBy: "u", createdAt: "", updatedAt: "", localDeleted: false }; expect(stockState({ ...base, quantityHundredths: 600 })).toBe("in_stock"); expect(stockState({ ...base, quantityHundredths: 100 })).toBe("low_stock"); expect(stockState({ ...base, quantityHundredths: 0 })).toBe("out_of_stock"); });
});

describe("role permissions", () => {
  it("limits staff to movement and leaves administration to managers and owners", () => { expect(can("staff", "stock")).toBe(true); expect(can("staff", "editItems")).toBe(false); expect(can("manager", "editItems")).toBe(true); expect(can("manager", "manageTeam")).toBe(false); expect(can("owner", "manageTeam")).toBe(true); expect(can("owner", "deleteItems")).toBe(true); });
  it("shows managers only stock audit records", () => { expect(canViewActivityAction("manager", "stock_in")).toBe(true); expect(canViewActivityAction("manager", "stock_out")).toBe(true); expect(canViewActivityAction("manager", "role_changed")).toBe(false); expect(canViewActivityAction("owner", "role_changed")).toBe(true); });
});

describe("CSV import validation", () => {
  it("accepts valid rows and retains row-level errors", () => { const result = parseInventoryCsv("item_name,quantity,category\nPaper,12.5,Office\n,3,Office\nGloves,3.456,Safety"); expect(result.validRows).toEqual([{ rowNumber: 2, name: "Paper", quantityHundredths: 1250, categoryName: "Office" }]); expect(result.issues).toHaveLength(2); expect(result.issues.map((issue) => issue.rowNumber)).toEqual([3, 4]); });
  it("reports a missing required header before it can import", () => { const result = parseInventoryCsv("item_name,category\nPaper,Office"); expect(result.validRows).toHaveLength(0); expect(result.issues[0].reason).toContain("Missing a quantity header"); });
});
