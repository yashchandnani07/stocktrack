import { useMemo, useState } from "react";
import { FlatList, Pressable, ScrollView, StyleSheet, TextInput, View } from "react-native";
import { router } from "expo-router";
import { ScreenContainer } from "@/components/screen-container";
import { AppIcon, AppText, Card, EmptyState, IconButton, OutlineButton, PrimaryButton, ScreenTitle, SyncChip, palette } from "@/src/components/ui";
import { can } from "@/src/lib/permissions";
import { formatQuantity, stockState } from "@/src/lib/quantity";
import { useRole, useStockTrack } from "@/src/providers/stocktrack-provider";
import type { InventoryItem } from "@/src/lib/types";

function InventoryCard({ item }: { item: InventoryItem }) {
  const role = useRole();
  const state = stockState(item);
  const config = state === "in_stock" ? { label: "In stock", color: palette.green } : state === "low_stock" ? { label: "Low stock", color: palette.amber } : { label: "Out of stock", color: palette.red };
  return <Card style={{ gap: 12 }}>
    <Pressable accessibilityRole="button" accessibilityLabel={`Open ${item.name}`} onPress={() => { if (can(role, "editItems")) router.push({ pathname: "/item" as never, params: { id: item.id } }); }} style={({ pressed }) => [styles.cardTop, pressed && can(role, "editItems") && { opacity: 0.7 }]}>
      <View style={[styles.categoryMark, { backgroundColor: item.categoryName === "General" ? "#E6EEFE" : "#F3EFFF" }]}><AppIcon name="inventory-2" size={20} color={palette.indigo} /></View>
      <View style={{ flex: 1, gap: 2 }}><AppText size={16} weight="700" numberOfLines={1}>{item.name}</AppText><AppText size={13} color={palette.slate}>{item.categoryName}{item.barcode ? ` · ${item.barcode}` : ""}</AppText></View>
      <View style={{ alignItems: "flex-end" }}><AppText size={21} weight="700">{formatQuantity(item.quantityHundredths)}</AppText><AppText size={12} color={palette.slate}>{item.unit}</AppText></View>
    </Pressable>
    <View style={styles.cardFooter}>
      <View style={[styles.stockBadge, { backgroundColor: `${config.color}18` }]}><AppText size={12} weight="700" color={config.color}>{config.label}</AppText></View>
      <View style={{ flexDirection: "row", gap: 8 }}>
        <IconButton icon="remove" label={`Stock out ${item.name}`} color={palette.red} onPress={() => router.push({ pathname: "/stock" as never, params: { id: item.id, type: "OUT" } })} />
        <IconButton icon="add" label={`Stock in ${item.name}`} color={palette.green} onPress={() => router.push({ pathname: "/stock" as never, params: { id: item.id, type: "IN" } })} />
      </View>
    </View>
  </Card>;
}

export default function InventoryScreen() {
  const { activeStore, data, sync, refresh } = useStockTrack();
  const role = useRole();
  const [search, setSearch] = useState("");
  const [category, setCategory] = useState("All");
  const filtered = useMemo(() => data.items.filter((item) => (category === "All" || item.categoryName === category) && (`${item.name} ${item.barcode ?? ""}`).toLowerCase().includes(search.trim().toLowerCase())), [category, data.items, search]);
  const categories = ["All", ...Array.from(new Set(data.items.map((item) => item.categoryName)))];
  const total = data.items.length;
  const out = data.items.filter((item) => stockState(item) === "out_of_stock").length;
  const low = data.items.filter((item) => stockState(item) === "low_stock").length;
  if (!activeStore) return <ScreenContainer className="p-5"><EmptyState icon="storefront" title="No store selected" body="Choose a store before managing inventory." action={<PrimaryButton label="Select store" onPress={() => router.replace("/stores" as never)} />} /></ScreenContainer>;
  const header = <>
    <ScreenTitle title="Inventory" subtitle={`${activeStore.name} · ${role ?? "Member"}`} action={<View style={{ flexDirection: "row", gap: 8 }}>{can(role, "editItems") ? <IconButton icon="upload-file" label="Import CSV" onPress={() => router.push("/csv-import" as never)} /> : null}<IconButton icon="history" label="Session history" onPress={() => router.push("/sessions" as never)} /><IconButton icon="swap-horiz" label="Switch store" onPress={() => router.replace("/stores" as never)} /></View>} />
    <SyncChip sync={sync} onPress={() => router.push("/sync-details" as never)} />
    <View style={styles.bulkActions}><View style={{ flex: 1 }}><PrimaryButton label="Stock in" icon="add-circle-outline" onPress={() => router.push({ pathname: "/bulk-session" as never, params: { type: "IN" } })} /></View><View style={{ flex: 1 }}><PrimaryButton label="Stock out" icon="remove-circle-outline" secondary onPress={() => router.push({ pathname: "/bulk-session" as never, params: { type: "OUT" } })} /></View></View>
    <View style={styles.search}><AppIcon name="search" size={21} color={palette.slate} /><TextInput value={search} onChangeText={setSearch} placeholder="Search by name or barcode…" placeholderTextColor="#98A2B3" accessibilityLabel="Search inventory" style={styles.searchInput} /></View>
    <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.chips}>{categories.map((name) => <Pressable key={name} accessibilityRole="button" accessibilityState={{ selected: category === name }} onPress={() => setCategory(name)} style={[styles.chip, category === name && styles.chipActive]}><AppText size={13} weight="600" color={category === name ? palette.paper : palette.slate}>{name}</AppText></Pressable>)}</ScrollView>
    <View style={styles.summary}>{[{ label: "Items", value: total, color: palette.blue }, { label: "Out", value: out, color: palette.red }, { label: "Low", value: low, color: palette.amber }, { label: "In", value: total - out - low, color: palette.green }].map((metric) => <View key={metric.label} style={styles.metric}><AppText size={18} weight="700" color={metric.color}>{metric.value}</AppText><AppText size={11} color={palette.slate}>{metric.label}</AppText></View>)}</View>
    {can(role, "editItems") ? <OutlineButton label="Add item" icon="add" onPress={() => router.push("/item" as never)} /> : null}
  </>;
  return <ScreenContainer className="p-4"><FlatList data={filtered} keyExtractor={(item) => item.id} renderItem={({ item }) => <InventoryCard item={item} />} contentContainerStyle={styles.list} refreshing={false} onRefresh={() => void refresh()} ListHeaderComponent={header} ListEmptyComponent={<EmptyState icon="inventory-2" title={data.items.length ? "No matching items" : "Your inventory is empty"} body={data.items.length ? "Try another search term or category." : can(role, "editItems") ? "Add the first item to begin tracking stock." : "Ask a manager to add items, then you can record stock movements."} />} /></ScreenContainer>;
}

const styles = StyleSheet.create({ list: { gap: 12, paddingBottom: 30 }, bulkActions: { flexDirection: "row", gap: 10, marginTop: 2 }, search: { height: 48, borderWidth: 1, borderColor: palette.border, backgroundColor: palette.paper, borderRadius: 14, paddingHorizontal: 13, flexDirection: "row", alignItems: "center", gap: 8 }, searchInput: { flex: 1, color: palette.ink, fontSize: 15, paddingVertical: 0 }, chips: { gap: 8 }, chip: { paddingHorizontal: 13, minHeight: 34, borderRadius: 17, justifyContent: "center", backgroundColor: palette.paper, borderWidth: 1, borderColor: palette.border }, chipActive: { backgroundColor: palette.indigo, borderColor: palette.indigo }, summary: { flexDirection: "row", backgroundColor: palette.paper, borderRadius: 15, borderWidth: 1, borderColor: palette.border, paddingVertical: 11 }, metric: { flex: 1, alignItems: "center", gap: 1 }, cardTop: { flexDirection: "row", alignItems: "center", gap: 10 }, categoryMark: { height: 42, width: 42, borderRadius: 13, alignItems: "center", justifyContent: "center" }, cardFooter: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", borderTopWidth: 1, borderTopColor: "#F0F2F5", paddingTop: 10 }, stockBadge: { paddingHorizontal: 10, minHeight: 27, justifyContent: "center", borderRadius: 14 } });
