import * as Network from "expo-network";
import { AppState } from "react-native";
import { createContext, useCallback, useContext, useEffect, useMemo, useState } from "react";
import type { User } from "@supabase/supabase-js";
import type { ActivityLog, Category, InventoryItem, StockSession, Store, StoreMembership, StoreRole, SyncOverview } from "@/src/lib/types";
import { getActiveMembership, getSetting, getSyncOverview, listCategories, listInventory, listLogs, listMembers, listSessions, listStores, setSetting } from "@/src/data/local/repository";
import { initializeLocalDatabase } from "@/src/data/local/database";
import { hydrateAccessibleStores, hydrateStore, retryFailedSync, syncOutbox } from "@/src/data/sync/sync-engine";
import { createStoreLocally } from "@/src/data/sync/mutations";
import { supabase } from "@/src/data/remote/supabase";

export interface StoreData { items: InventoryItem[]; categories: Category[]; logs: ActivityLog[]; sessions: StockSession[]; members: StoreMembership[]; }
interface StockTrackContextValue {
  ready: boolean; user: User | null; stores: Store[]; activeStore: Store | null; membership: StoreMembership | null; data: StoreData; sync: SyncOverview; isOnline: boolean; fontScale: number; error: string | null;
  signIn(email: string, password: string): Promise<void>; signUp(fullName: string, email: string, password: string): Promise<{ requiresConfirmation: boolean }>;
  signOut(): Promise<void>; selectStore(storeId: string): Promise<void>; createStore(name: string): Promise<void>; refresh(): Promise<void>; refreshLocal(): Promise<void>; retrySync(): Promise<void>; setFontScale(scale: number): Promise<void>;
}

const emptyData: StoreData = { items: [], categories: [], logs: [], sessions: [], members: [] };
const StockTrackContext = createContext<StockTrackContextValue | null>(null);

export function StockTrackProvider({ children }: { children: React.ReactNode }) {
  const [ready, setReady] = useState(false); const [user, setUser] = useState<User | null>(null); const [stores, setStores] = useState<Store[]>([]); const [activeStore, setActiveStore] = useState<Store | null>(null); const [membership, setMembership] = useState<StoreMembership | null>(null); const [data, setData] = useState<StoreData>(emptyData); const [sync, setSync] = useState<SyncOverview>({ state: "synced", pendingCount: 0, failedCount: 0, lastSuccessfulSync: null, latestError: null }); const [isOnline, setIsOnline] = useState(true); const [fontScale, setScale] = useState(1); const [error, setError] = useState<string | null>(null);

  const refreshLocal = useCallback(async (userOverride?: User | null) => {
    const activeUser = userOverride ?? user;
    const [allStores, overview] = await Promise.all([listStores(), getSyncOverview()]);
    setStores(allStores); setSync(overview);
    const persistedStoreId = await getSetting("active_store_id");
    const selected = activeStore?.id ? allStores.find((store) => store.id === activeStore.id) ?? null : allStores.find((store) => store.id === persistedStoreId) ?? null;
    if (!selected || !activeUser) { setActiveStore(null); setMembership(null); setData(emptyData); return; }
    const activeMembership = await getActiveMembership(selected.id, activeUser.id);
    if (!activeMembership?.isActive) { setActiveStore(null); setMembership(null); setData(emptyData); return; }
    const [items, categories, logs, sessions, members] = await Promise.all([listInventory(selected.id), listCategories(selected.id), listLogs(selected.id), listSessions(selected.id), listMembers(selected.id)]);
    setActiveStore(selected); setMembership(activeMembership); setData({ items, categories, logs, sessions, members });
  }, [activeStore?.id, user]);

  const resolveSession = useCallback(async () => {
    await initializeLocalDatabase();
    const savedScale = Number(await getSetting("font_scale"));
    if ([0.9, 1, 1.1, 1.2, 1.25].includes(savedScale)) setScale(savedScale);
    const { data: sessionData } = await supabase.auth.getSession();
    const sessionUser = sessionData.session?.user ?? null;
    setUser(sessionUser);
    if (sessionUser) {
      try { await hydrateAccessibleStores(sessionUser.id); } catch (syncError) { setError(syncError instanceof Error ? syncError.message : "Using cached store data while the server is unavailable."); }
    } else { await setSetting("active_store_id", ""); }
    await refreshLocal(sessionUser); setReady(true);
  }, [refreshLocal]);

  const refresh = useCallback(async () => {
    if (!user) { await refreshLocal(); return; }
    setError(null);
    try { await hydrateAccessibleStores(user.id); const candidate = activeStore?.id ?? await getSetting("active_store_id"); if (candidate) await hydrateStore(candidate); setSync(await syncOutbox(candidate)); }
    catch (syncError) { setError(syncError instanceof Error ? syncError.message : "Could not refresh store data."); }
    await refreshLocal();
  }, [activeStore?.id, refreshLocal, user]);

  useEffect(() => { resolveSession(); const { data: listener } = supabase.auth.onAuthStateChange((_event, session) => { setUser(session?.user ?? null); if (session?.user) void resolveSession(); }); return () => listener.subscription.unsubscribe(); }, [resolveSession]);
  useEffect(() => { const subscription = Network.addNetworkStateListener((state) => { const online = Boolean(state.isInternetReachable); setIsOnline(online); if (online && user) void refresh(); }); return () => subscription.remove(); }, [refresh, user]);
  useEffect(() => { const subscription = AppState.addEventListener("change", (state) => { if (state === "active" && user) void refresh(); }); return () => subscription.remove(); }, [refresh, user]);
  useEffect(() => { if (!activeStore?.id || !user) return; const channel = supabase.channel(`stocktrack-${activeStore.id}`).on("postgres_changes", { event: "*", schema: "public", table: "inventory_items", filter: `store_id=eq.${activeStore.id}` }, () => void refresh()).on("postgres_changes", { event: "*", schema: "public", table: "categories", filter: `store_id=eq.${activeStore.id}` }, () => void refresh()).on("postgres_changes", { event: "*", schema: "public", table: "activity_logs", filter: `store_id=eq.${activeStore.id}` }, () => void refresh()).subscribe(); return () => { void supabase.removeChannel(channel); }; }, [activeStore?.id, refresh, user]);

  const signIn = useCallback(async (email: string, password: string) => { setError(null); const { error: signInError } = await supabase.auth.signInWithPassword({ email: email.trim(), password }); if (signInError) throw signInError; }, []);
  const signUp = useCallback(async (fullName: string, email: string, password: string) => { setError(null); const { data: signUpData, error: signUpError } = await supabase.auth.signUp({ email: email.trim(), password, options: { data: { full_name: fullName.trim() } } }); if (signUpError) throw signUpError; return { requiresConfirmation: !signUpData.session }; }, []);
  const signOut = useCallback(async () => { await supabase.auth.signOut(); await setSetting("active_store_id", ""); setUser(null); setActiveStore(null); setMembership(null); setData(emptyData); }, []);
  const selectStore = useCallback(async (storeId: string) => { if (!user) throw new Error("Sign in again to select a store."); const newMembership = await getActiveMembership(storeId, user.id); if (!newMembership?.isActive) throw new Error("Your account has been disabled. Contact the owner."); await setSetting("active_store_id", storeId); setActiveStore((await listStores()).find((store) => store.id === storeId) ?? null); setMembership(newMembership); await hydrateStore(storeId).catch(() => undefined); await refreshLocal(); }, [refreshLocal, user]);
  const createStore = useCallback(async (name: string) => { if (!user) throw new Error("Sign in again to create a store."); if (name.trim().length < 2) throw new Error("Store name must contain at least two characters."); const store = await createStoreLocally(name, { id: user.id, name: String(user.user_metadata.full_name ?? user.email ?? "You"), role: "owner" }); await setSetting("active_store_id", store.id); setActiveStore(store); await syncOutbox(store.id).catch(() => undefined); await refreshLocal(); }, [refreshLocal, user]);
  const retrySync = useCallback(async () => { setSync(await retryFailedSync(activeStore?.id)); await refreshLocal(); }, [activeStore?.id, refreshLocal]);
  const setFontScale = useCallback(async (nextScale: number) => { if (![0.9, 1, 1.1, 1.2, 1.25].includes(nextScale)) return; setScale(nextScale); await setSetting("font_scale", String(nextScale)); }, []);

  const value = useMemo<StockTrackContextValue>(() => ({ ready, user, stores, activeStore, membership, data, sync: isOnline ? sync : { ...sync, state: "offline" }, isOnline, fontScale, error, signIn, signUp, signOut, selectStore, createStore, refresh, refreshLocal, retrySync, setFontScale }), [activeStore, createStore, data, error, fontScale, isOnline, membership, ready, refresh, refreshLocal, retrySync, selectStore, setFontScale, signIn, signOut, signUp, stores, sync, user]);
  return <StockTrackContext.Provider value={value}>{children}</StockTrackContext.Provider>;
}

export function useStockTrack() { const context = useContext(StockTrackContext); if (!context) throw new Error("useStockTrack must be used inside StockTrackProvider"); return context; }
export function useRole(): StoreRole | null { const { membership } = useStockTrack(); return membership?.isActive ? membership.role : null; }
