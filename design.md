# StockTrack Mobile Interface Design

## Product intent

StockTrack is a compact operational workspace for small teams who count, receive, and issue stock across one or more stores. The interface prioritizes immediate visibility of quantity, stock state, and synchronization health. Every primary action is reachable with one hand from a portrait phone, while larger devices reveal denser grids and split layouts without changing the task flow.

## Brand and color choices

The brand uses a trustworthy inventory-blue with calm supporting neutrals. The primary action color is **Midnight Indigo `#243B78`**, paired with **Azure `#3568D4`** for interactive highlights. The app background is **Cloud `#F6F8FC`** and surfaces are **Paper `#FFFFFF`**. Stock-in and confirmations use **Evergreen `#138A5B`**; stock-out and destructive actions use **Vermilion `#C93E43`**; low-stock status uses **Amber `#B7791F`**. Text is **Ink `#172033`** with **Slate `#667085`** for secondary labels. These colors retain high contrast while making stock direction and system status recognizable at a glance.

## Screen list and primary content

| Screen | Primary content | Primary functionality |
| --- | --- | --- |
| Launch | Branded loading mark and safe session restoration | Resolves cached session, active store, and local data before routing. |
| Sign in / Create account | Email, password, full name for registration, inline validation | Authenticates through Supabase email/password and starts store resolution. |
| Create first store | Store-name form with ownership note | Creates a store and its owner membership atomically when online. |
| Select / switch store | Accessible store cards, add-store form, sign out | Sets the authoritative active store and loads its cache immediately. |
| Inventory | Store and role header, sync chip, summary chips, search, category filters, inventory list, bulk actions | Views stock, filters items, begins stock in/out, opens item editor, imports CSV where allowed. |
| Item editor | Item details, category, unit, quantity/threshold, barcode | Creates or updates item metadata for Manager and Owner; Owner may delete. |
| Single stock sheet | Current quantity, positive quantity entry, projected result | Writes an auditable signed stock delta locally and queues sync. |
| Bulk stock session | Searchable inventory, selected line cards, positive quantities, submit bar | Creates a locally atomic batch of stock deltas, lines, activity entries, and session. |
| Session history / detail | Newest-first sessions, summary, item lines, report actions | Opens cached session details and generates a PDF locally for sharing or printing. |
| CSV import | Picker trigger, validation preview, import summary | Parses a user-selected CSV and imports valid rows with visible row errors. |
| Categories | Category count and responsive card grid | Creates categories for Manager/Owner; Owner may delete with reassignment. |
| Activity | Role-scoped activity stream, filters, grouped stock actions, IN/OUT overview | Lets Manager see stock actions and Owner inspect/correct all supported audit records. |
| Team | Role/status member list and invitation sheet | Owner invites members, changes role, disables, enables, or removes members. |
| Settings | Store rename and typography-scale cards with preview | Owner updates store name and all users persist an app-wide text-size preference. |
| Sync details | Current connectivity, queued/failed operations, last success, retry action | Explains offline behavior and enables a safe manual retry without duplicate effects. |

## Interaction and layout rules

On phones, screens use a top safe-area header and a 56-point bottom tab bar. Lists use 16-point horizontal insets and 12-point vertical rhythm. Primary inventory actions are positioned above the tab bar as two full-width buttons, followed by a search field and horizontally scrolling category chips. The add item action uses a trailing floating control only for Manager and Owner. Forms open as stack destinations on compact devices, while tablet forms can use two columns at 600px and above.

Cards have 16-point radius, a restrained 1-point neutral border, and a minimum 44-point touch target. Icon-only actions include an accessible label. Stock state appears as a compact color-and-label chip in addition to quantity so the meaning is never color-dependent. Destructive actions require a confirmation sheet. Disabled or unauthorized routes show a concise access state rather than a blank screen.

## Role-aware navigation

| Role | Phone tabs | Privileged UI treatment |
| --- | --- | --- |
| Staff | Inventory, Categories | Can submit stock movements; item metadata and team controls are hidden. |
| Manager | Inventory, Categories, Activity | Can add/edit items and categories; sees only stock activity. |
| Owner | Inventory, Categories, Activity, Team, Settings | Receives all administrative, correction, report, and store configuration controls. |

## Key user flows

**First-time owner flow.** The user launches StockTrack, creates an account, enters a store name, and lands on Inventory. The newly created store is selected centrally and its owner membership is visible in Team.

**Offline stock flow.** A signed-in user opens a previously loaded store without connectivity, sees the Offline chip, taps Stock Out, confirms a quantity, and immediately sees the new stock and an activity entry. The change and its outbox operation survive app restart. On connectivity return, the chip changes through Syncing to Synced or displays a visible failed-operation count.

**Bulk session and PDF flow.** The user taps Stock In or Stock Out, searches and selects several items, adjusts their quantities, confirms the batch, and reaches session detail. From there, they can create a locally rendered report containing store, performer, timestamp, totals, and signed item lines, then share, print, or save it.

**Owner collaboration flow.** The owner opens Team, taps Invite, supplies a name and email, selects Manager or Staff, and sends the invitation. Existing accounts receive a membership immediately; new accounts are represented as secure, expiring invitations. All team changes produce audit records.

## Accessibility and feedback

Typography can be 90%, 100%, 110%, 120%, or 125% across the entire app and is persisted per device. Forms provide field-level validation rather than relying on color alone. Every successful local operation produces concise confirmation feedback, while non-retryable server errors explain why the action remains pending or failed. The primary application is optimized for portrait orientation and one-handed operation; tablet adaptations improve density without excluding the phone-first flow.
