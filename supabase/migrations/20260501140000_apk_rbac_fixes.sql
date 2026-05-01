-- ============================================================
-- APK White-Box Test Fix Migration
-- Fixes found during APK runtime testing:
-- 1. store_members: ensure members can read their own is_active status
--    (needed for login flow to check if account is disabled)
-- 2. user_profiles: ensure SELECT policy allows reading by email
--    (needed for invite-by-email lookup)
-- 3. inventory_items UPDATE: allow all active store members to update
--    quantity (needed for stock in/out by Staff role)
-- 4. stock_sessions + stock_session_items: ensure RLS allows
--    all active store members to insert/read
-- ============================================================

-- ============================================================
-- 1. store_members: allow members to read their own row
--    (self-read for is_active check at login)
-- ============================================================
DROP POLICY IF EXISTS "store_members_self_read" ON public.store_members;
CREATE POLICY "store_members_self_read"
ON public.store_members
FOR SELECT
TO authenticated
USING (
    user_id = auth.uid()
    OR public.is_store_owner(store_id)
    OR public.is_store_member(store_id)
);

-- ============================================================
-- 2. user_profiles: ensure SELECT is open to authenticated users
--    (needed for invite-by-email lookup in store_service.dart)
-- ============================================================
DROP POLICY IF EXISTS "user_profiles_read_others" ON public.user_profiles;
CREATE POLICY "user_profiles_read_others"
ON public.user_profiles
FOR SELECT
TO authenticated
USING (true);

-- ============================================================
-- 3. inventory_items UPDATE: allow all active store members
--    Staff role needs UPDATE permission for stock in/out
-- ============================================================
DROP POLICY IF EXISTS "inventory_items_member_update" ON public.inventory_items;
DROP POLICY IF EXISTS "inventory_items_manager_owner_update" ON public.inventory_items;
CREATE POLICY "inventory_items_member_update"
ON public.inventory_items
FOR UPDATE
TO authenticated
USING (public.is_store_member(store_id))
WITH CHECK (public.is_store_member(store_id));

-- ============================================================
-- 4. stock_sessions: ensure RLS is enabled and policies exist
-- ============================================================
ALTER TABLE IF EXISTS public.stock_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "stock_sessions_member_read" ON public.stock_sessions;
CREATE POLICY "stock_sessions_member_read"
ON public.stock_sessions
FOR SELECT
TO authenticated
USING (public.is_store_member(store_id));

DROP POLICY IF EXISTS "stock_sessions_member_insert" ON public.stock_sessions;
CREATE POLICY "stock_sessions_member_insert"
ON public.stock_sessions
FOR INSERT
TO authenticated
WITH CHECK (public.is_store_member(store_id));

-- ============================================================
-- 5. stock_session_items: ensure RLS is enabled and policies exist
-- ============================================================
ALTER TABLE IF EXISTS public.stock_session_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "stock_session_items_member_read" ON public.stock_session_items;
CREATE POLICY "stock_session_items_member_read"
ON public.stock_session_items
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.stock_sessions ss
        WHERE ss.id = stock_session_items.session_id
          AND public.is_store_member(ss.store_id)
    )
);

DROP POLICY IF EXISTS "stock_session_items_member_insert" ON public.stock_session_items;
CREATE POLICY "stock_session_items_member_insert"
ON public.stock_session_items
FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.stock_sessions ss
        WHERE ss.id = stock_session_items.session_id
          AND public.is_store_member(ss.store_id)
    )
);

-- ============================================================
-- 6. Ensure categories DELETE is owner-only (idempotent)
-- ============================================================
DROP POLICY IF EXISTS "categories_owner_delete" ON public.categories;
CREATE POLICY "categories_owner_delete"
ON public.categories
FOR DELETE
TO authenticated
USING (public.is_store_owner(store_id));
