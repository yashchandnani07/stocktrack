# StockTrack Supabase Setup

Apply `migrations/202608280001_stocktrack.sql` to an empty Supabase project through the SQL Editor or the Supabase CLI. The migration creates the inventory domain, enables Row Level Security for every exposed table, and exposes only role-checking RPCs for application writes. Do **not** place a Supabase service-role key in the Expo app.

| Setup task | Required configuration |
| --- | --- |
| Email authentication | Enable email/password sign-up and set an appropriate confirmation email redirect URL in Supabase Authentication settings. |
| Mobile environment | Provide `EXPO_PUBLIC_SUPABASE_URL` and `EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY` to StockTrack. The publishable key is safe to ship because RLS and RPC authorization enforce access. |
| Realtime reconciliation | Add `inventory_items`, `categories`, and `activity_logs` to the Supabase `supabase_realtime` publication. |
| Team invitation email | Deploy `functions/send-invite` with `supabase functions deploy send-invite --no-verify-jwt`. Set the function's redirect origin to the production application URL before launch. The function reads Supabase-provided `SUPABASE_URL` and service role secrets at runtime. |
| Acceptance checks | Use an Owner, Manager, and Staff test account to verify the permitted and denied flows. Test an offline stock change, force close the app, return online, and confirm the quantity and audit entry appear once. |

> **Migration note:** Use the generated RPCs rather than direct table writes. They store an idempotency key before changing inventory, so safe outbox retries cannot apply the same stock operation twice.

The Expo client stores its SQLite cache and outbox locally, not in application tables exposed to other users. It is safe to erase the app’s local data after confirming all pending operations have synced.
