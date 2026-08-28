# Supabase Integration Notes

StockTrack uses `EXPO_PUBLIC_SUPABASE_URL` and `EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY` in its mobile client. Session persistence uses `@react-native-async-storage/async-storage` on iOS/Android and the browser's own `localStorage` on web (see `src/data/remote/supabase.ts`) — an earlier revision eagerly imported `expo-sqlite/localStorage/install` as a side effect, which is the leading suspect for an Expo Go bundling freeze that was seen once before; do not reintroduce that import. The publishable key is intentionally client-visible; data protection comes from Row Level Security and minimal grants rather than a service-role key. The client must never include a database password or service-role secret. [1]

The versioned migration under `supabase/migrations/` enables RLS on every exposed table, revokes public table writes, and grants only selected reads to authenticated users. Mutations flow through security-definer RPCs that check active membership and role, record idempotency keys, and perform stock/session updates transactionally. Official guidance recommends enabling RLS, setting matching grants, writing operation-specific policies, and testing allow/deny behavior with Supabase’s database tests. [2]

The app binds Supabase auto-refresh to foreground app state and uses a normalized Expo SQLite cache plus durable outbox for offline-first inventory. It hydrates local views immediately, retries queued changes after connectivity returns, and uses realtime only for reconciliation rather than as the source of truth. 

## References

[1] [Expo, “Using Supabase”](https://docs.expo.dev/guides/using-supabase/)

[2] [Supabase, “Row Level Security”](https://supabase.com/docs/guides/database/postgres/row-level-security)
