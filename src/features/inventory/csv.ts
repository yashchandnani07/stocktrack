import Papa from "papaparse";
import { parseQuantity } from "../../lib/quantity";

export interface ParsedImportRow { rowNumber: number; name: string; quantityHundredths: number; categoryName: string | null; }
export interface ImportIssue { rowNumber: number; reason: string; }
export interface ParsedImport { validRows: ParsedImportRow[]; issues: ImportIssue[]; }
const aliases = { name: ["item_name", "name", "item"], quantity: ["quantity", "qty", "stock"], category: ["category", "cat"] };
function valueFor(row: Record<string, string>, names: string[]): string { const key = Object.keys(row).find((candidate) => names.includes(candidate.trim().toLowerCase())); return key ? String(row[key] ?? "").trim() : ""; }
export function parseInventoryCsv(text: string): ParsedImport {
  const parsed = Papa.parse<Record<string, string>>(text, { header: true, skipEmptyLines: "greedy", transformHeader: (header) => header.trim().toLowerCase() });
  const validRows: ParsedImportRow[] = []; const issues: ImportIssue[] = [];
  const headers = parsed.meta.fields ?? [];
  if (!headers.some((header) => aliases.name.includes(header))) return { validRows, issues: [{ rowNumber: 1, reason: "Missing an item name header (item_name, name, or item)." }] };
  if (!headers.some((header) => aliases.quantity.includes(header))) return { validRows, issues: [{ rowNumber: 1, reason: "Missing a quantity header (quantity, qty, or stock)." }] };
  parsed.data.forEach((row, index) => { const rowNumber = index + 2; const name = valueFor(row, aliases.name); const quantityHundredths = parseQuantity(valueFor(row, aliases.quantity)); const categoryName = valueFor(row, aliases.category) || null; if (!name) issues.push({ rowNumber, reason: "Item name is required." }); else if (name.length > 120) issues.push({ rowNumber, reason: "Item name must be 120 characters or fewer." }); else if (quantityHundredths === null) issues.push({ rowNumber, reason: "Quantity must be a number with no more than two decimals." }); else validRows.push({ rowNumber, name, quantityHundredths, categoryName }); });
  parsed.errors.forEach((issue) => issues.push({ rowNumber: Number(issue.row) + 2, reason: issue.message }));
  return { validRows, issues };
}
