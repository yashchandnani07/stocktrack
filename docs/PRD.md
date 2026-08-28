# StockTrack — React Native Expo Product Requirements Document

## 1. Purpose

Rebuild StockTrack from scratch as a polished iOS and Android app using React Native and Expo. The product is a multi-store inventory system for small teams. It supports stock counting, item and category administration, activity auditing, role-based access, team administration, reports, realtime updates, and reliable offline use.

This document captures the behaviour of the current Flutter application, while prescribing an Expo-native implementation where it is safer or more maintainable. Functional parity is required unless a requirement is explicitly marked as an improvement.

## 2. Product summary

StockTrack lets a user:

- sign up or sign in;
- create, select, and switch between stores;
- view and search a store's inventory;
- stock one item in or out, or perform a multi-item stock session;
- create, edit, import, and delete inventory items according to their role;
- organize items with categories;
- review an activity audit trail;
- invite and manage store members (owner only);
- adjust accessibility text size;
- use cached data and make changes while offline, then sync them when connectivity returns.

The backend source of truth remains Supabase (Auth, Postgres, Realtime, RLS). The mobile app is local-first: a device database is the immediate read/write model, and a durable outbox synchronizes mutations to Supabase.

## 3. Users, roles, and scope

### 3.1 Store model

A person can own or belong to more than one store. All business data is strictly store-scoped. A currently selected `storeId` is required for every inventory, category, session, log, member, and mutation query.

On app start and after authentication:

1. Restore the authenticated session, if any.
2. Load all stores accessible to the user.
3. If there are no stores, show **Create first store**.
4. If exactly one store is available, select it automatically.
5. If multiple stores are available, show **Select store**.
6. Load the selected store's local cache immediately and refresh it in the background when online.

Never infer a store from stale route parameters. Keep one authoritative active-store value in a central store/session layer, and reject mutations whose `storeId` is not the active store.

### 3.2 Roles and permissions

Server-side Supabase RLS is the final authority. The app must also hide unavailable controls and block calls defensively.

| Capability | Staff | Manager | Owner |
| --- | :---: | :---: | :---: |
| View inventory and categories | Yes | Yes | Yes |
| Stock in / stock out (single and bulk) | Yes | Yes | Yes |
| Create or edit inventory items | No | Yes | Yes |
| Delete inventory items | No | No | Yes |
| Create categories | No | Yes | Yes |
| Delete categories | No | No | Yes |
| View activity log | No | Stock actions only | All actions |
| Correct a previous stock-log quantity | No | No | Yes |
| Manage team / invite / roles / disable / remove | No | No | Yes |
| Rename store | No | No | Yes |

An inactive/disabled member cannot navigate between app sections or perform any mutation. If their active state changes during a session, stop the action, clear selected-store access as necessary, and show: “Your account has been disabled. Contact the owner.” The owner role cannot be changed, disabled, or removed.

## 4. Navigation and responsive behavior

### 4.1 Primary navigation

Phone navigation is a bottom tab bar. Tablet navigation is a left navigation rail. Tabs vary by role:

- **Staff:** Inventory, Categories
- **Manager:** Inventory, Categories, Activity
- **Owner:** Inventory, Categories, Activity, Team, Settings

The following flows are stack/modal destinations, not tabs: authentication, create/select store, item editor, CSV import, single stock action, bulk stock session, session confirmation/detail, session history, category editor, activity filters, and user-management sheets.

### 4.2 UI language and visual baseline

Recreate the current app's intent: clean light interface, dark blue/indigo primary accent, green for stock-in/success, red for stock-out/destructive actions, yellow for warnings/low stock, rounded cards, compact status chips, prominent empty states, and optimistic feedback via snackbars/toasts.

Support portrait phones first and tablets at 600px+. On tablets use two-column inventory cards, a three-column category grid, and desktop/tablet item forms in two columns. Support app-wide text scaling: 90%, 100%, 110%, 120%, and 125%.

## 5. Screen-by-screen functional specification

Each section states what the screen captures (inputs), what it presents (outputs), and what actions change state.

### 5.1 Launch and session restoration

**Purpose:** resolve a valid authenticated session and selected store before rendering the main app.

**Inputs / state:** persisted Supabase session; locally persisted active-store preference; locally cached stores and membership status.

**Outputs:** full-screen loading indicator, then Authentication, Create Store, Select Store, or Inventory.

**Rules:**

- Do not show the login screen briefly when a session can be restored.
- Clear any stale active-store state before resolving stores for a newly authenticated user.
- Confirm an invited member's `is_active` status before entering a store.

### 5.2 Authentication — Sign in / Create account

**Inputs:**

- Sign in: email, password; password visibility toggle.
- Create account: full name, email, password; password visibility toggle.

**Validation:** name is required on sign-up; email is required and must contain `@`; password is required and at least 6 characters.

**Outputs:** inline validation errors; server/auth error banner; loading button; session established on success.

**Actions and next state:**

- Sign in uses Supabase password authentication.
- Sign-up sets `full_name` user metadata and creates the account through Supabase.
- Successful auth resolves stores using the launch-routing rules above.
- A disabled member remains on this screen / receives an access-denied message rather than entering the store.

**Current-app visual content:** brand heading “StockTrack”, inventory icon, “Inventory intelligence for modern teams.”, and a switch link between Sign In and Sign Up. Do not ship hard-coded demo credentials in production; add a development-only seed/demo mechanism if useful.

### 5.3 Create first store

**Shown when:** the authenticated user has no accessible stores.

**Input:** Store Name.

**Validation:** required; at least 2 trimmed characters.

**Output:** creates a store owned by the authenticated user, makes them Owner, selects it, then opens Inventory. Show success/failure feedback.

**Important data rule:** store creation must create the owner membership atomically or through a backend trigger. Queue the creation when offline only if the account/session is already valid and the app can safely create UUIDs client-side; otherwise make the limitation explicit in the UI.

### 5.4 Select store / add store

**Shown when:** user has multiple accessible stores, or chooses “Switch Store.”

**Outputs:** cards for each accessible store, store count, sign-out control, and an inline Add Store form.

**Input:** select a store; or enter a new store name (same validation as above).

**Actions:**

- Selecting a store resolves the member role and active status, persists it as the active store, clears old-store realtime subscriptions, and opens Inventory.
- Add Store creates it and refreshes the list.
- Sign out clears the local active-store context, realtime subscriptions, and authentication session, then returns to Authentication.

### 5.5 Inventory (home)

**Outputs:**

- Header: title, active store name, current role, switch-store icon, session-history icon, account/avatar sign-out control, and—when permitted—CSV import.
- Sync-status chip (see offline requirements).
- Stock In and Stock Out bulk-action buttons.
- Search field: “Search by name or barcode…”.
- Horizontal category filter chips: `All` plus the categories represented by loaded inventory items.
- Summary chips: total item count, out-of-stock count, low-stock count, and in-stock count.
- Item cards sorted newest-first.
- Skeleton while loading and clear empty states for no inventory vs no search/filter results.
- Owner/Manager: floating “Add Item” action.

**Search/filter inputs:**

- Search matches case-insensitive item name and barcode.
- Category filter matches exact category; default is `All`.

**Item-card outputs:** category icon/color, item name, category, barcode indicator if present, quantity and unit, state badge, last-updated relative time and user, and allowed action buttons.

**Stock state calculation:**

- `out_of_stock` when quantity equals 0.
- `low_stock` when quantity is greater than 0 and less than or equal to `lowStockThreshold`.
- `in_stock` otherwise.

**Card actions:**

- Plus: Stock In sheet (all active roles).
- Minus: Stock Out sheet (all active roles).
- Tap card: item edit/view screen (Manager/Owner; Staff has no edit affordance).
- Delete: owner only; requires confirmation.

**Realtime:** subscribe to the selected store’s inventory changes while the screen is mounted. Apply INSERT/UPDATE/DELETE events to the local database first, then update the visible list. Do not allow realtime events from a previously selected store to update this screen.

### 5.6 Add item / Edit item

**Shown when:** Owner or Manager taps Add Item or an inventory card.

**Inputs:**

| Section | Field | Rules / default |
| --- | --- | --- |
| Item details | Item Name | Required, trimmed, 2–120 characters |
| Item details | Category | Required dropdown from store categories; default first available / General |
| Stock settings | Initial Quantity / Current Quantity | Required numeric, 0–999,999, up to 2 decimal places |
| Stock settings | Unit | `pcs` default; options: pcs, kg, g, L, mL, boxes, reams, sets, bottles, bags, pairs, rolls |
| Stock settings | Low Stock Alert Threshold | integer 0–999,999; default 5 |
| Optional | Barcode | optional digits-only value |

**Outputs/actions:**

- Save creates or updates the local record and queues the remote mutation; return to Inventory on success.
- Edit screen includes an owner-only Delete action; confirm because it cannot be undone.
- Staff cannot enter an editable item form. If a read-only item detail screen is retained, show a clear “View only” banner and disable fields.
- Fail visibly and retain form values if local write or queue creation fails. Never add a phantom/empty-ID item to the inventory list.

**Data behavior:** metadata edits replace item fields. Directly changing “Current Quantity” in item editing is a legacy parity behavior; for the rebuild, prefer a dedicated adjustment flow that writes an auditable delta. If current-quantity editing is retained, it must create a correction audit log explaining the delta.

### 5.7 Single-item Stock In / Stock Out sheet

**Inputs:** a positive quantity (decimal, max 999,999, max two decimals).

**Outputs:** current stock, selected unit, and a live projected new stock calculation. The current product permits negative quantity after Stock Out when offline, and the backend configuration may permit it online as well.

**Actions:** Confirm:

1. Apply a signed delta locally (`+quantity` for IN; `-quantity` for OUT).
2. Update timestamp and `updatedBy` locally.
3. Enqueue the idempotent stock-delta operation.
4. Create an activity log entry locally and enqueue it.
5. Close the sheet and show `+/-quantity unit — item name` feedback.

**Required improvement:** declare the chosen stock-out policy in the rebuild. Default to allowing negative stock (current behavior) but make it a server-enforced per-store setting so the product can later prohibit it without a client release.

### 5.8 Bulk Stock In / Stock Out session

**Purpose:** apply multiple stock deltas as one named session.

**Inputs:**

- Session type from entry route: `IN` or `OUT`.
- Search by item name, barcode, or category.
- Tap items to include/exclude them; initial included quantity is 1.
- Editable positive decimal quantity per selected item, up to 2 decimal places.

**Outputs:**

- Accent color and label reflect session type.
- Selected-item count badge.
- Horizontal selected-item cards containing item name, category, unit, quantity field, and remove action.
- Full searchable inventory list, showing each item’s existing stock.
- Validation error panel and bottom submit bar showing item count.

**Validation:** at least one item; every selected quantity must be finite and greater than 0.

**Submit behavior:**

1. Attempt/apply every selected item delta locally as a durable unit of work.
2. Record one `stock_session` plus its `stock_session_items` for successful lines.
3. Record a stock activity log per successful line, with `details = Bulk session` and a common session ID.
4. Queue the dependent changes for sync.
5. Go to Session result/detail with any failed lines listed.

**Required improvement over current app:** make the session **atomic by default**: validate all selected records and write items, logs, and session in one local database transaction. Sync the complete session as an idempotent server transaction/RPC. If the product explicitly supports partial processing, expose “N of M applied” clearly and retain failed lines in a retryable state; do not silently create an ambiguous session.

### 5.9 Stock-session result / session detail

**Shown when:** a bulk session completes, or a historical session is opened.

**Outputs:**

- Type-specific complete heading (Stock In Complete / Stock Out Complete).
- Store, performer name and role, date/time, session type, total successful item count.
- Warning panel listing any failed items.
- Table of item name, category, and quantity.
- PDF report actions: Share PDF and Download/Print PDF.
- Back to Inventory action.

**PDF contents:** StockTrack heading; report type; store; date/time; performer; session totals; and each line’s item, category, signed quantity, and unit. Generate client-side from local session data so the report works offline; use Expo sharing/print/file APIs for the platform handoff.

### 5.10 Stock-session history

**Outputs:** selected-store header; sessions newest first; each card shows type, direction icon, total items, performer, date/time, and chevron. Empty state says there are no sessions yet.

**Actions:** pull-to-refresh; Load More pagination (20 per page); tap a card to load its lines and open Session detail.

**Offline behavior:** show cached sessions and cached lines. If lines were never cached, show the session summary and an “item details unavailable offline” state rather than failing the whole screen.

### 5.11 CSV bulk import

**Shown when:** Owner or Manager invokes import from Inventory.

**State machine:** `idle → preview → importing → summary`.

**Input:** pick one `.csv` file.

**Accepted header aliases:**

| Logical field | Accepted headers | Required |
| --- | --- | --- |
| Item name | `item_name`, `name`, `item` | Yes |
| Quantity | `quantity`, `qty`, `stock` | Yes |
| Category | `category`, `cat` | No |

**Row validation:** non-empty item name, max 120 characters; number quantity 0–999,999 with decimals accepted; no negative import quantity. Handle quoted CSV values. Show every invalid row and its reason in preview.

**Import rules:**

- Existing item matching is normalized/case-insensitive name matching. Add imported quantity to its current stock. If a category is provided, update its category.
- New item is created with imported quantity, category (or `General`), unit `pcs`, and low-stock threshold 5.
- A specified category missing from the store is automatically created with default color/icon.
- Valid rows import even when other rows are invalid; summary reports total, imported, created, updated, skipped, and row-level errors.
- Log one `bulk_import` activity containing the created/updated count.

**Expo implementation:** use `expo-document-picker` to obtain the CSV and `expo-file-system` to read it. File picking must occur only after the user initiates it. Parse safely in JS (for example Papa Parse) rather than writing a hand-rolled parser.

### 5.12 Categories

**Outputs:** store name, category count, grid of category cards, empty state, and—when permitted—Add Category floating action.

Each category card presents icon, name, item count, and owner-only delete action.

**Add Category sheet inputs:**

- Category Name: required.
- Color: fixed palette (primary, green, yellow, purple, blue, red, teal, pink).
- Icon: inventory, devices, stationery/edit, furniture, hygiene, food, tools, medical, clothing, sports.

**Actions:** create the category locally and queue it; log `category_created`; subscribe to realtime category changes. Owner deletion requires confirmation. Deleting a category changes items in that category to `General`/uncategorized, deletes the category, logs `category_deleted`, and queues the whole change transaction.

### 5.13 Activity log

**Visibility:** Owner sees all audit actions; Manager sees stock in/out only; Staff has no tab or direct access.

**Outputs:**

- Header: total loaded count, scope label, Refresh and Filter controls.
- Search field matches human-readable text, item, user, role, details, action type, stock reference (`#1A`), and date text. Calendar control applies an exact-day local filter.
- For stock logs, show a compact chart summarizing Stock In vs Stock Out activity (preserve this analytical visualization).
- Owner-only action-group chips: All, Stock, Items, Users. Manager is always restricted to stock.
- Date sections: Today, Yesterday, or formatted date.
- Consecutive stock entries belonging to the same action/session are grouped into expandable stacks. Display operator, Stock In/Out, a generated reference, line/item count, total signed quantity, and time; expanded state lists every line.
- Non-stock entries show type icon/color, human-readable summary, role, optional signed quantity and unit, time, and owner-only correction action where applicable.
- Infinite/load-more pagination, with an end-of-list indicator.

**Audit action types:** `stock_in`, `stock_out`, `item_created`, `item_edited`, `item_deleted`, `category_created`, `category_deleted`, `bulk_import`, `user_added`, `user_removed`, `role_changed`, `user_enabled`, `user_disabled`.

**Filter-sheet inputs:** user text, item text, from date, to date; Clear filters and Apply filters. Date picker range runs from 2024 through today.

**Owner-only stock correction:** opening an eligible stock line asks for a new positive quantity. Compute the correction delta rather than setting stock absolutely:

`correctionDelta = newSignedQuantity - oldSignedQuantity`

Apply only that delta to inventory, update the activity-log line, and update the matching session item. Maintain the original event identity/timestamp and include who made the correction (recommended: append immutable correction metadata rather than silently rewriting the original audit row).

### 5.14 Team (Owner-only tab)

**Outputs:** store name, member count, list sorted Owner → Manager → Staff, member name/email/initials/role badge/status, and Invite action. A non-owner who somehow reaches this route sees an Owner Access Only state.

**Invite sheet inputs:** Full Name (required), Email Address (required and valid), Contact Number (optional), Role (`Manager` or `Staff`, default Staff).

**Important current behavior / improvement:** the current backend adds a member only when the entered email already maps to an existing user profile. The rebuild must make the user journey explicit:

- If an account exists, create membership immediately.
- If not, create a durable pending invitation and send an email/deep link through a secure Supabase Edge Function (recommended).
- Do not collect or store the contact number unless a real product requirement and privacy policy justify it; the current app does not persist it.

**Owner actions for a non-owner, non-self member:**

- Change Role: select Manager or Staff; save only when changed.
- Disable/Enable Access: confirmation required; disabled users lose store access immediately.
- Remove: confirmation required; removes membership and access.

Every successful team change writes a corresponding activity log.

### 5.15 Settings (Owner-only tab)

**Outputs and inputs:**

- Store details card: current store name; owner may edit the name in place, save or cancel.
- Collaborator summary/list and Invite control (may share the Team data and components rather than duplicating logic).
- Appearance: selectable font-scale cards for Small (90%), Default (100%), Medium (110%), Large (120%), Extra Large (125%), plus preview text.

Persist text scale locally using AsyncStorage or the Expo SQLite preferences table and apply it app-wide. Store-name change should update the selected store model, local cache, and outbox transaction, then be visible everywhere.

## 6. Data model

Use UUIDs generated client-side for records that need offline creation. Keep stable IDs forever; server sync must upsert using those IDs. Suggested Supabase entities:

| Entity | Essential fields |
| --- | --- |
| `profiles` | `id`, `email`, `full_name`, timestamps |
| `stores` | `id`, `name`, `owner_id`, timestamps |
| `store_members` | `id`, `store_id`, `user_id`, `role`, `is_active`, `invited_by`, timestamps |
| `categories` | `id`, `store_id`, `name`, `color_value`, `icon_code`, timestamps; unique `(store_id, name)` |
| `inventory_items` | `id`, `store_id`, `name`, `category`, `quantity NUMERIC`, `low_stock_threshold NUMERIC`, `unit`, `barcode`, `updated_by`, timestamps |
| `activity_logs` | `id`, `store_id`, `user_id`, `user_name`, `user_role`, `action_type`, `item_id`, `item_name`, `quantity NUMERIC`, `unit`, `details`, `session_id`, timestamps, correction metadata |
| `stock_sessions` | `id`, `store_id`, `session_type` (`IN`/`OUT`), performer fields, `total_items`, optional notes, timestamps |
| `stock_session_items` | `id`, `session_id`, `item_id`, `item_name`, `category`, `quantity NUMERIC`, `unit`, timestamps |
| `invitations` (improvement) | `id`, `store_id`, `email`, `role`, `status`, invite token/expiry, inviter, timestamps |

Use decimal-safe storage/operations. Display whole quantities without a decimal and fractional values to a maximum of two decimal places. Avoid JavaScript floating-point drift: convert to integer hundredths for client-side arithmetic or use a decimal library; make server RPCs operate on `NUMERIC`.

## 7. Offline-first and synchronization requirements

Offline is a first-class feature, not a fallback. The recreated app must support offline reads and durable offline writes for the data the user can already access on the device.

### 7.1 Expo implementation recommendation

Use:

- `expo-sqlite` for the normalized device cache and mutation outbox;
- `@react-native-community/netinfo` for connectivity state;
- Supabase JS for Auth, database, and Realtime;
- TanStack Query or equivalent for screen query state, with SQLite as the persistence layer—not merely an in-memory cache;
- Expo SecureStore only for small sensitive/session-adjacent values if required; do not place the database/outbox there.

Do not rely on AsyncStorage alone for inventory/offline sync. It is insufficient for transactional data, queryability, and a durable ordered queue.

### 7.2 Local cache

Create local tables mirroring stores, members, inventory items, categories, activity logs, sessions, and session lines. Include at least:

- primary UUID;
- `store_id` where applicable;
- source record fields;
- `local_deleted` tombstone flag;
- local/remote version or `updated_at` metadata;
- indexes by store and list sort fields.

On first successful online load, hydrate cache per accessible store. Thereafter:

- return local data immediately;
- trigger a non-blocking refresh when online;
- refresh a selected store’s items, categories, members, logs, sessions, and session lines;
- merge remote data without replacing a newer local pending mutation.

### 7.3 Durable mutation outbox

Create an `outbox_operations` table, e.g.:

`id`, `operation_key`, `store_id`, `entity`, `operation`, `payload_json`, `dependencies_json`, `created_at`, `attempt_count`, `status`, `last_error`, `last_attempt_at`.

Every mutation must be committed in the same SQLite transaction as its optimistic local data update and outbox insert. Supported operations include:

- create/update/delete store and store rename;
- create/update/delete item;
- stock delta;
- create/delete category (and category reassignment);
- create/update activity log/correction;
- create stock session with lines;
- invite/change-role/enable-disable/remove member.

### 7.4 Sync algorithm

1. Trigger sync after app launch, login, manual refresh, connectivity restoration, and foreground return.
2. Process unsent operations in dependency order: store → category/item → stock/session/log → member/invitation. Preserve original order within each dependency group.
3. Send each operation with an idempotency key (`operation_key` / client mutation UUID). Server endpoints/RPCs must safely ignore duplicates.
4. Prefer transactional Supabase RPC/Edge Function endpoints for stock deltas, bulk sessions, category deletion/reassignment, and activity corrections. The client must not perform read-modify-write against remote stock quantities.
5. On success, mark/remove the operation and reconcile its affected records with server values.
6. On retryable network/server failure, retain the operation and increment attempt metadata. Retry with exponential backoff and jitter while the app is active; resume next time the app becomes active/online.
7. On an authorization/validation/conflict failure, mark it `failed`, preserve the local user-visible record, show a sync-failure status, and provide an explicit retry/review path. Do not silently discard user changes.
8. After a successful outbox drain, pull latest remote changes for accessible stores and update last-sync time.

### 7.5 Conflict policy

Implement conflict behavior explicitly; do not accidentally overwrite a user’s offline work during refresh.

- **Stock changes:** additive deltas are commutative and must be applied on the server atomically. This is the primary reason to queue deltas rather than absolute quantities.
- **New records:** UUID upsert is idempotent.
- **Metadata edits:** use server `updated_at` / revision checks. Default to last-write-wins only when no dependent data is lost; surface conflicts for deleted/changed records.
- **Delete vs offline edit:** a server-deleted item makes later client delta/edit fail with a recoverable failed operation; explain that the item no longer exists.
- **Category deletion:** transact reassignment + delete; prevent a refresh from resurrecting deleted rows.
- **Team permissions:** always reauthorize on server sync. A user who is disabled while offline may retain local changes that then appear as failed/unauthorized—never apply them under a different store or user.

### 7.6 Sync-status UX

Show a compact chip on Inventory (recommended: also in the global header):

| State | Label | Meaning |
| --- | --- | --- |
| Online and clean | Synced | no pending local writes |
| Offline | Offline | reads available from local cache; writes queue |
| Online with queued writes | `N pending` | local changes await sync |
| Actively synchronizing | Syncing | queue currently processing |
| Failure | `N failed` | failed operations need attention; show latest error in details |

Tapping the chip should open a Sync details sheet (improvement) with pending/failed operations, last successful sync time, error explanations, and a Retry now action. Manual retry must not bypass backoff guards or duplicate server effects.

### 7.7 Realtime reconciliation

When online and authenticated, subscribe only to selected-store tables. On a received server change:

- upsert it into SQLite;
- update subscribed query/UI state;
- do not overwrite a record with a pending local mutation unless the server event is the acknowledgment of that exact mutation;
- dispose all store-specific channels before a store switch or sign-out.

Use Supabase Realtime as a fast reconciliation mechanism, not as the only transport or data source.

## 8. Backend, security, and reliability

- Supabase Auth uses email/password initially. Validate sessions securely and restore them on app launch.
- All data access is scoped by `store_id` and authenticated user membership.
- Enforce all roles and active-member checks in RLS/RPCs, not solely in React Native UI.
- Prefer server functions/RPCs for stock deltas, corrections, bulk sessions, category deletion, and team invitations. They must validate store membership and role at execution time.
- A disabled member’s access must be denied server-side even if a device was offline.
- Ensure `inventory_items`/logs/session quantities use `NUMERIC` or another decimal-safe type.
- Paginate activity logs and session history on the server. Cache at least the latest 200 logs and 100 sessions per store, configurable based on storage needs.
- Track errors with enough context to diagnose a store-context mismatch without sending sensitive values to client-visible UI.

## 9. Non-functional acceptance criteria

### Functional parity

- All screens and flows in Section 5 exist and comply with their stated roles.
- All CRUD/mutation actions give visible success, validation, and failure feedback.
- No action can write to a store other than the active selected store.
- Quantities support up to two decimal places consistently in forms, lists, imports, reports, logs, sessions, and sync.
- PDF generation and sharing/download work for historical and newly created sessions.

### Offline acceptance tests

1. With a previously loaded store, turn off connectivity; Inventory, categories, logs, sessions, and session details render cached data.
2. Offline create item, edit item, delete item, create category, perform single stock in/out, and submit a bulk stock session. Close and relaunch the app; all optimistic results and outbox entries persist.
3. Restore connectivity; each operation reaches Supabase exactly once despite duplicate retry attempts, then the chip becomes Synced.
4. Make an offline stock-out that produces negative inventory (with default policy enabled); it reconciles correctly online.
5. Cause a server rejection (disabled user, deleted item, invalid permission); operation remains visible as failed with an actionable explanation and is not silently lost.
6. Switch stores while a sync is pending; operations retain their original `store_id` and never affect the newly selected store.
7. Two devices adjust the same item offline by different deltas; after sync, the resulting quantity equals the initial quantity plus both deltas.

### Quality

- TypeScript throughout; no implicit `any` for domain or sync payloads.
- Unit tests for permissions, quantity calculations, CSV parsing, outbox ordering, idempotency, conflict policies, and stock-correction math.
- Integration tests against a Supabase staging project for RLS and transactional RPCs.
- E2E tests for auth → store setup → inventory → stock session → PDF and critical offline/reconnect paths.
- Accessible labels for icon-only controls, logical focus order, sufficient contrast, and support for the five text scales.

## 10. Suggested implementation boundaries

The coding agent should structure the Expo project around domain boundaries rather than Flutter-screen translations:

```text
app/                         Expo Router routes and layouts
src/features/auth/           auth/session restoration
src/features/stores/         active store, selection, membership
src/features/inventory/      item list/editor/stock actions/import
src/features/categories/     category list/editor
src/features/sessions/       bulk session/history/detail/PDF
src/features/activity/       logs, filtering, corrections/chart
src/features/team/           invitations and member management
src/features/settings/       store name and accessibility preferences
src/data/local/              Expo SQLite schema, repositories, migrations
src/data/sync/               outbox, retry, reconciliation, connectivity
src/data/remote/             Supabase client, RPCs, realtime subscriptions
src/components/              shared navigation, forms, cards, status chips
src/lib/                     typed utilities: quantity, date, CSV, permissions
```

Use Expo Router or React Navigation consistently, one centralized active-store/session provider, typed repository APIs, and a feature-level design system. Keep server schema/migrations, RLS policies, and RPC definitions versioned alongside the app.

## 11. Out of scope for initial parity

Do not invent barcode scanning, push notifications, item images, purchase orders, analytics dashboards beyond the current activity chart, or a web admin app unless separately requested. Barcode is a manually entered/searchable string in this version.

## 12. Definition of done

The rebuild is complete when an authenticated user can manage multiple stores according to their role; all listed data and workflows function online and offline; queued operations sync safely and visibly; Supabase RLS protects every store; realtime keeps open screens current; and the acceptance tests in this document pass on Android and iOS Expo builds.
