import AsyncStorage from "@react-native-async-storage/async-storage";
import { AppState, Platform } from "react-native";
import { createClient } from "@supabase/supabase-js";

const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL ?? "https://unconfigured.supabase.co";
const supabasePublishableKey = process.env.EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? "unconfigured";

export const isSupabaseConfigured = !supabaseUrl.includes("unconfigured") && supabasePublishableKey !== "unconfigured";
// Native (iOS/Android, including Expo Go) persists the session with AsyncStorage so sign-in survives an app restart.
// Web uses the browser's own localStorage; the no-op fallback only covers SSR/static-export passes where `window` is absent.
const unavailableWebStorage = { getItem: async (_key: string) => null, setItem: async (_key: string, _value: string) => undefined, removeItem: async (_key: string) => undefined };
const authStorage = Platform.OS === "web" ? (typeof window === "undefined" ? unavailableWebStorage : window.localStorage) : AsyncStorage;

export const supabase = createClient(supabaseUrl, supabasePublishableKey, {
  auth: { storage: authStorage, autoRefreshToken: true, persistSession: true, detectSessionInUrl: false },
});

AppState.addEventListener("change", (state) => {
  if (state === "active") supabase.auth.startAutoRefresh();
  else supabase.auth.stopAutoRefresh();
});
