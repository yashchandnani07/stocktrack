import MaterialIcons from "@expo/vector-icons/MaterialIcons";
import { Tabs } from "expo-router";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Platform } from "react-native";
import { useRole } from "@/src/providers/stocktrack-provider";
import { palette } from "@/src/components/ui";

export default function TabLayout() {
  const role = useRole(); const insets = useSafeAreaInsets(); const bottom = Platform.OS === "web" ? 12 : Math.max(insets.bottom, 8);
  return <Tabs screenOptions={{ headerShown: false, tabBarActiveTintColor: palette.indigo, tabBarInactiveTintColor: palette.slate, tabBarStyle: { height: 58 + bottom, paddingTop: 6, paddingBottom: bottom, backgroundColor: palette.paper, borderTopColor: palette.border } }}>
    <Tabs.Screen name="index" options={{ title: "Inventory", tabBarIcon: ({ color, size }) => <MaterialIcons name="inventory-2" size={size} color={color} /> }} />
    <Tabs.Screen name="categories" options={{ title: "Categories", tabBarIcon: ({ color, size }) => <MaterialIcons name="category" size={size} color={color} /> }} />
    {role !== "staff" ? <Tabs.Screen name="activity" options={{ title: "Activity", tabBarIcon: ({ color, size }) => <MaterialIcons name="timeline" size={size} color={color} /> }} /> : null}
    {role === "owner" ? <Tabs.Screen name="team" options={{ title: "Team", tabBarIcon: ({ color, size }) => <MaterialIcons name="group" size={size} color={color} /> }} /> : null}
    {role === "owner" ? <Tabs.Screen name="settings" options={{ title: "Settings", tabBarIcon: ({ color, size }) => <MaterialIcons name="settings" size={size} color={color} /> }} /> : null}
  </Tabs>;
}
