import "@/global.css";
import "react-native-reanimated";
import { Stack } from "expo-router";
import { StatusBar } from "expo-status-bar";
import { GestureHandlerRootView } from "react-native-gesture-handler";
import { SafeAreaProvider } from "react-native-safe-area-context";
import { StockTrackProvider } from "@/src/providers/stocktrack-provider";

export default function RootLayout() {
  return <GestureHandlerRootView style={{ flex: 1 }}><SafeAreaProvider><StockTrackProvider><StatusBar style="dark" /><Stack screenOptions={{ headerShown: false, animation: "fade" }}><Stack.Screen name="index" /><Stack.Screen name="auth" options={{ presentation: "fullScreenModal" }} /><Stack.Screen name="stores" options={{ presentation: "fullScreenModal" }} /><Stack.Screen name="(tabs)" /><Stack.Screen name="item" options={{ presentation: "card" }} /><Stack.Screen name="stock" options={{ presentation: "transparentModal", animation: "slide_from_bottom" }} /><Stack.Screen name="bulk-session" options={{ presentation: "card" }} /><Stack.Screen name="sessions" options={{ presentation: "card" }} /><Stack.Screen name="session-detail" options={{ presentation: "card" }} /><Stack.Screen name="csv-import" options={{ presentation: "card" }} /><Stack.Screen name="sync-details" options={{ presentation: "transparentModal", animation: "slide_from_bottom" }} /></Stack></StockTrackProvider></SafeAreaProvider></GestureHandlerRootView>;
}
