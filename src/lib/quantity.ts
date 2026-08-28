const HUNDREDTHS = 100;

export function parseQuantity(input: string | number): number | null {
  const normalized = String(input).trim();
  if (!/^\d+(?:\.\d{1,2})?$/.test(normalized)) return null;
  const [whole, fraction = ""] = normalized.split(".");
  const value = Number(whole) * HUNDREDTHS + Number((fraction + "00").slice(0, 2));
  return Number.isSafeInteger(value) && value <= 999_999 * HUNDREDTHS ? value : null;
}

export function formatQuantity(hundredths: number): string {
  const sign = hundredths < 0 ? "-" : "";
  const absolute = Math.abs(Math.trunc(hundredths));
  const whole = Math.floor(absolute / HUNDREDTHS);
  const fraction = absolute % HUNDREDTHS;
  return fraction === 0 ? `${sign}${whole}` : `${sign}${whole}.${String(fraction).padStart(2, "0").replace(/0$/, "")}`;
}

export function numericStringFromHundredths(hundredths: number): string {
  return formatQuantity(hundredths);
}

export function stockState(item: { quantityHundredths: number; lowStockThresholdHundredths: number }): "out_of_stock" | "low_stock" | "in_stock" {
  if (item.quantityHundredths === 0) return "out_of_stock";
  if (item.quantityHundredths > 0 && item.quantityHundredths <= item.lowStockThresholdHundredths) return "low_stock";
  return "in_stock";
}

export function signedDelta(type: "IN" | "OUT", quantityHundredths: number): number {
  return type === "IN" ? quantityHundredths : -quantityHundredths;
}

export function correctionDelta(previousSignedQuantity: number, nextSignedQuantity: number): number {
  return nextSignedQuantity - previousSignedQuantity;
}
