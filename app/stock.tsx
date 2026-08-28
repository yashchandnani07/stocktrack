import { useMemo, useState } from "react";
import { KeyboardAvoidingView, Platform, StyleSheet, View } from "react-native";
import { router, useLocalSearchParams } from "expo-router";
import { ScreenContainer } from "@/components/screen-container";
import { AppIcon, AppText, Card, EmptyState, Field, IconButton, PrimaryButton, ScreenTitle, palette } from "@/src/components/ui";
import { formatQuantity, parseQuantity, signedDelta } from "@/src/lib/quantity";
import { correctStockLocally, createStockDeltaLocally } from "@/src/data/sync/mutations";
import { useRole, useStockTrack } from "@/src/providers/stocktrack-provider";

export default function StockSheet() {
  const params = useLocalSearchParams<{ id?: string; type?: "IN" | "OUT"; correctionOf?: string }>();
  const id = Array.isArray(params.id) ? params.id[0] : params.id;
  const correctionOf = Array.isArray(params.correctionOf) ? params.correctionOf[0] : params.correctionOf;
  const { activeStore, data, user, refreshLocal } = useStockTrack();
  const role = useRole();
  const originalLog = correctionOf ? data.logs.find((log) => log.id === correctionOf) ?? null : null;
  const eligible = !correctionOf || (originalLog && originalLog.itemId && originalLog.quantityHundredths !== null);
  const itemId = correctionOf ? originalLog?.itemId ?? undefined : id;
  const item = data.items.find((candidate) => candidate.id === itemId);
  // A correction keeps the original entry's direction -- the owner supplies the corrected magnitude, not a fresh movement.
  const originalDirection: "IN" | "OUT" = originalLog?.quantityHundredths != null && originalLog.quantityHundredths < 0 ? "OUT" : "IN";
  const type: "IN" | "OUT" = params.type === "OUT" ? "OUT" : "IN";
  const effectiveType = correctionOf ? originalDirection : type;
  const [quantity, setQuantity] = useState(correctionOf && originalLog?.quantityHundredths != null ? formatQuantity(Math.abs(originalLog.quantityHundredths)) : "");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const parsed = useMemo(() => parseQuantity(quantity), [quantity]);
  if (!activeStore || !user || !item || !role || !eligible) return <ScreenContainer edges={["top", "bottom", "left", "right"]} className="p-5"><EmptyState icon="inventory-2" title="Item unavailable" body="Return to inventory and choose an active item." /></ScreenContainer>;
  const projected = correctionOf && originalLog?.quantityHundredths != null
    ? (parsed === null ? item.quantityHundredths : item.quantityHundredths + (signedDelta(effectiveType, parsed) - originalLog.quantityHundredths))
    : (parsed === null ? item.quantityHundredths : item.quantityHundredths + signedDelta(effectiveType, parsed));
  const confirm = async () => {
    if (parsed === null || parsed <= 0) return setError("Enter a positive quantity with up to two decimal places.");
    setBusy(true);
    setError(null);
    try {
      const actor = { id: user.id, name: String(user.user_metadata.full_name ?? user.email ?? "You"), role };
      if (correctionOf && originalLog) await correctStockLocally(originalLog, signedDelta(effectiveType, parsed), actor);
      else await createStockDeltaLocally(activeStore.id, item.id, effectiveType, parsed, actor);
      await refreshLocal();
      router.back();
    } catch (stockError) {
      setError(stockError instanceof Error ? stockError.message : "Stock update could not be recorded.");
    } finally {
      setBusy(false);
    }
  };
  const color = effectiveType === "IN" ? palette.green : palette.red;
  return <ScreenContainer edges={["top", "bottom", "left", "right"]} className="p-4"><KeyboardAvoidingView behavior={Platform.OS === "ios" ? "padding" : undefined} style={{ flex: 1, justifyContent: "flex-end" }}><Card style={styles.sheet}>
    <ScreenTitle title={correctionOf ? "Correct stock entry" : effectiveType === "IN" ? "Stock in" : "Stock out"} subtitle={item.name} action={<IconButton icon="close" label="Close" onPress={() => router.back()} />} />
    {correctionOf && originalLog?.quantityHundredths != null
      ? <View style={[styles.direction, { backgroundColor: `${palette.purple}15` }]}><AppIcon name="edit" size={22} color={palette.purple} /><AppText size={14} weight="700" color={palette.purple}>Originally recorded as {originalDirection === "IN" ? "+" : "-"}{formatQuantity(Math.abs(originalLog.quantityHundredths))} {item.unit}. Enter the corrected {originalDirection === "IN" ? "stock in" : "stock out"} quantity — only the difference is applied to stock.</AppText></View>
      : <View style={[styles.direction, { backgroundColor: `${color}15` }]}><AppIcon name={effectiveType === "IN" ? "add-circle" : "remove-circle"} size={22} color={color} /><AppText size={14} weight="700" color={color}>{effectiveType === "IN" ? "Add stock" : "Remove stock"}</AppText></View>}
    <View style={styles.quantities}><View><AppText size={12} color={palette.slate}>Current stock</AppText><AppText size={24} weight="700">{formatQuantity(item.quantityHundredths)} {item.unit}</AppText></View><View style={{ alignItems: "flex-end" }}><AppText size={12} color={palette.slate}>Projected stock</AppText><AppText size={24} weight="700" color={color}>{formatQuantity(projected)} {item.unit}</AppText></View></View>
    <Field label={`Quantity in ${item.unit}`} value={quantity} onChangeText={setQuantity} keyboardType="decimal-pad" placeholder="0" error={error ?? undefined} />
    <PrimaryButton label={correctionOf ? "Apply correction" : effectiveType === "IN" ? "Confirm stock in" : "Confirm stock out"} loading={busy} icon={effectiveType === "IN" ? "add" : "remove"} onPress={() => void confirm()} />
  </Card></KeyboardAvoidingView></ScreenContainer>;
}
const styles = StyleSheet.create({ sheet: { gap: 16, borderRadius: 22 }, direction: { flexDirection: "row", alignItems: "center", gap: 8, padding: 11, borderRadius: 12 }, quantities: { flexDirection: "row", justifyContent: "space-between", backgroundColor: palette.subtle, padding: 14, borderRadius: 14 } });
