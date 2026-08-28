import { ActivityIndicator, View } from "react-native";
import { Redirect } from "expo-router";
import { useStockTrack } from "@/src/providers/stocktrack-provider";
import { palette } from "@/src/components/ui";

export default function LaunchScreen() { const { ready, user, stores, activeStore } = useStockTrack(); if (!ready) return <View style={{ flex: 1, alignItems: "center", justifyContent: "center", backgroundColor: palette.background }}><ActivityIndicator size="large" color={palette.indigo} /></View>; if (!user) return <Redirect href={"/auth" as never} />; if (!stores.length || !activeStore) return <Redirect href={"/stores" as never} />; return <Redirect href="/(tabs)" />; }
