# StockTrack

A multi-store inventory app for small teams — stock counting, item/category administration, activity auditing, role-based access, team management, PDF reports, realtime updates, and reliable offline use. Built with Expo (React Native) and Supabase.

Full product spec: [`docs/PRD.md`](docs/PRD.md). Read that first for *what* the app should do — this file covers *how the codebase is put together* and where things currently stand.

> **Note for any AI agent picking this project up:** this codebase was previously rebuilt from an earlier Flutter version by Manus AI, then audited and fixed in a Claude Code session. Section "History and known-fragile spots" below lists mistakes that were made and reintroduced more than once — read it before touching auth/sync code.

## Stack

- **Expo SDK 54**, React Native 0.81, TypeScript (`strict: true`), Expo Router (file-based routing under `app/`)
- **NativeWind** (Tailwind for RN) + a small hand-rolled UI kit in `src/components/ui.tsx` (no external component library)
- **Supabase**: Postgres + Auth + Row Level Security + RPCs + Realtime + one Edge Function
- **Expo SQLite** for the on-device cache and mutation outbox (native only; an in-memory adapter stands in for web preview)
- **Vitest** for unit tests, **ESLint** (`eslint-config-expo`) for lint

There is no custom backend server — the mobile app talks to Supabase directly. (An earlier export of this project carried an entire unrelated Express/tRPC/Drizzle/MySQL "app-template" scaffold alongside StockTrack; it was unused dead code and has been removed. If you see `server/`, `lib/_core/`, `drizzle/`, or `shared/` reappear, they don't belong here — delete them again.)

## Project layout

```
app/                          Expo Router routes (screens). File path = route.
  (tabs)/                     Bottom-tab screens: inventory, categories, activity, team, settings
  auth.tsx, stores.tsx        Sign in/up, store creation/selection
  item.tsx, stock.tsx         Item editor, single stock in/out + owner corrections
  bulk-session.tsx, sessions.tsx, session-detail.tsx   Bulk stock sessions, history, PDF report
  csv-import.tsx, sync-details.tsx
src/
  components/ui.tsx           Shared UI primitives (AppText, Card, PrimaryButton, SyncChip, palette, ...)
  providers/stocktrack-provider.tsx   Single top-level context: session, active store, cached data, sync state
  lib/                        Pure domain logic: types.ts, permissions.ts (role capability matrix), quantity.ts (decimal-safe hundredths math)
  data/local/                 Expo SQLite schema (database.ts) + typed repository functions (repository.ts)
  data/sync/                  mutations.ts (local-first writes + outbox enqueue), sync-engine.ts (drains the outbox against Supabase RPCs), integrity.ts (pure, unit-tested: outbox ordering + batch session projections)
  data/remote/                supabase.ts (client init), remote-store.ts (row <-> domain-type mappers, RPC payload builders)
  features/inventory/         CSV parsing + import
  features/sessions/          PDF report generation (expo-print)
supabase/
  migrations/202608280001_stocktrack.sql   Full schema, RLS policies, and all RPCs (source of truth for the backend)
  functions/send-invite/      Edge Function: sends the team-invite email via Supabase Admin API
tests/                        Vitest specs for the pure modules above
docs/PRD.md                   Full product spec
docs/supabase-integration.md  Short notes on the Supabase integration choices
```

## How data flows

Every mutation is **local-first**: it writes to SQLite and enqueues an `outbox_operations` row in the same transaction, then returns immediately. A background sync engine (`src/data/sync/sync-engine.ts`) drains the outbox against idempotent Supabase RPCs (each carries an `operation_key`; the server's `sync_operations` table makes retries safe), in dependency order (store → category/item → stock/session/log → member/invitation). Server-side RLS + `SECURITY DEFINER` RPCs are the actual authority — the client never writes to a table directly, and role/membership checks happen again on the server even if the UI already hid the control.

Quantities are stored as integer hundredths client-side (`src/lib/quantity.ts`) to avoid floating-point drift, and as `numeric(14,2)` in Postgres.

## Running it

```bash
pnpm install
cp .env.example .env   # fill in EXPO_PUBLIC_SUPABASE_URL / EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY
pnpm dev                # or: pnpm android / pnpm ios / pnpm web
```

```bash
pnpm check   # tsc --noEmit
pnpm lint    # expo lint
pnpm test    # vitest run
```

`tests/supabase.connection.test.ts` needs real credentials in `.env`; it auto-skips (not fails) if they're absent.

## Current status

- **Code**: builds and type-checks clean, lints clean, all tests pass.
- **Backend**: the migration in `supabase/migrations/202608280001_stocktrack.sql` is applied and live on the connected Supabase project. Realtime is enabled on `inventory_items`, `categories`, `activity_logs`.
- **Not yet deployed**: `supabase/functions/send-invite` (the Edge Function that emails a team invite). Team invites still work and durably record a pending invitation without it — they just won't send an email until it's deployed. Deploy with `supabase functions deploy send-invite --no-verify-jwt` once logged in with a project-linked Supabase CLI, or via a Supabase MCP connector authorized for the right account.
- **Not yet device-verified**: sign-in → offline stock changes → reconnect → sync, on an actual Expo Go / physical device pass. The two changes below were specifically applied to unblock that.

## History and known-fragile spots

Two bugs were independently diagnosed once, fixed, and then **reappeared in a later regenerated export** of this project. If either comes back, it's very likely to reintroduce the "Expo Go bundling freezes around 86%" symptom:

1. `src/data/remote/supabase.ts` must **not** import `expo-sqlite/localStorage/install` as a top-level side effect. Session storage should be `@react-native-async-storage/async-storage` on native and the browser's `localStorage` on web — never a SQLite-backed localStorage polyfill.
2. `app.config.ts` must keep `newArchEnabled: false`. New Architecture + `expo-sqlite` has caused Expo Go to hang.

Other things worth knowing if you're extending this:

- The Owner "correct a stock entry" flow (`app/stock.tsx` correction mode, `correctStockLocally` in `mutations.ts`, `correct_stock` RPC) recomputes only the *difference* between the corrected quantity and the originally recorded one, and updates the original activity-log row (and its matching session line) in place — it does not create a disconnected new movement. If you touch this, keep that invariant; a first pass at this feature got it wrong (treated a correction as a brand-new independent stock movement).
- `src/data/sync/sync-engine.ts`'s `permanent()` check decides whether a failed outbox operation should stop retrying and surface as "failed", vs. keep retrying as transient. It relies on Postgres's default `P0001` SQLSTATE (what every `raise exception` in the RPCs uses) — don't remove that check, or role/validation rejections will retry forever instead of showing the user an actionable error.
- Editing an existing inventory item does not let you change its quantity (`app/item.tsx` shows it read-only for existing items) — quantity changes only ever go through Stock In/Out or a correction, both of which write an auditable delta. This is intentional, matching the PRD's recommended improvement over the legacy behavior; don't re-add a free-text editable quantity field to the item editor.
- If `pnpm test` can't resolve `@/...` imports, check `vitest.config.ts` — it needs the `@` alias mirroring `tsconfig.json`'s `paths`, which vitest does not pick up automatically.
