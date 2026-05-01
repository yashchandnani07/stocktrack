-- ============================================================
-- Store Context Consistency Fix Migration
-- Fixes the root cause of items imported on web being invisible
-- on mobile: RLS helper functions must correctly identify both
-- store owners AND active store members for all operations.
--
-- Root causes fixed:
-- 1. is_store_member() may not include the store owner — fixed
-- 2. inventory_items SELECT policy may exclude owners — fixed
-- 3. inventory_items UPDATE policy must allow owner too — fixed
-- 4. Ensure CSV-imported items (created by owner on web) are
--    readable by the same owner on mobile via correct RLS
-- ============================================================

-- ============================================================
-- 1. Rebuild is_store_owner to be robust
-- ============================================================
CREATE OR REPLACE FUNCTION public.is_store_owner(p_store_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT EXISTS (
    SELECT 1 FROM public.stores s
    WHERE s.id = p_store_id
      AND s.owner_id = auth.uid()
)
$$;

-- ============================================================
-- 2. Rebuild is_store_member to include BOTH owners AND
--    active store_members — this is the critical fix.
--    Previously, if is_store_member only checked store_members
--    table, the store owner (who has no store_members row)
--    would fail the check on some policy paths.
-- ============================================================
CREATE OR REPLACE FUNCTION public.is_store_member(p_store_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT EXISTS (
    -- Owner always has access
    SELECT 1 FROM public.stores s
    WHERE s.id = p_store_id
      AND s.owner_id = auth.uid()
)
OR EXISTS (
    -- Active member has access
    SELECT 1 FROM public.store_members sm
    WHERE sm.store_id = p_store_id
      AND sm.user_id = auth.uid()
      AND sm.is_active = true
)
$$;

-- ============================================================
-- 3. Rebuild is_store_manager_or_owner to use same logic
-- ============================================================
CREATE OR REPLACE FUNCTION public.is_store_manager_or_owner(p_store_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT EXISTS (
    SELECT 1 FROM public.stores s
    WHERE s.id = p_store_id
      AND s.owner_id = auth.uid()
)
OR EXISTS (
    SELECT 1 FROM public.store_members sm
    WHERE sm.store_id = p_store_id
      AND sm.user_id = auth.uid()
      AND sm.is_active = true
      AND sm.role IN ('Manager', 'Owner')
)
$$;

-- ============================================================
-- 4. Rebuild inventory_items SELECT policy
--    Ensure both owner and active members can read items.
--    This is the policy that causes items to be invisible
--    on mobile when imported via web.
-- ============================================================
DROP POLICY IF EXISTS "inventory_items_member_read" ON public.inventory_items;
DROP POLICY IF EXISTS "inventory_items_owner_read" ON public.inventory_items;
CREATE POLICY "inventory_items_member_read"
ON public.inventory_items
FOR SELECT
TO authenticated
USING (public.is_store_member(store_id));

-- ============================================================
-- 5. Rebuild inventory_items UPDATE policy
--    All active members (including owner) can update quantity
--    for stock in/out operations.
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
-- 6. Rebuild inventory_items INSERT policy
--    Only Manager/Owner can create new items (including CSV import)
-- ============================================================
DROP POLICY IF EXISTS "inventory_items_manager_owner_insert" ON public.inventory_items;
DROP POLICY IF EXISTS "inventory_items_member_write" ON public.inventory_items;
CREATE POLICY "inventory_items_manager_owner_insert"
ON public.inventory_items
FOR INSERT
TO authenticated
WITH CHECK (public.is_store_manager_or_owner(store_id));

-- ============================================================
-- 7. Rebuild inventory_items DELETE policy
--    Only Owner can delete items
-- ============================================================
DROP POLICY IF EXISTS "inventory_items_owner_delete" ON public.inventory_items;
CREATE POLICY "inventory_items_owner_delete"
ON public.inventory_items
FOR DELETE
TO authenticated
USING (public.is_store_owner(store_id));

-- ============================================================
-- 8. Rebuild stores SELECT policy
--    Owner and active members can read store details
-- ============================================================
DROP POLICY IF EXISTS "stores_member_read" ON public.stores;
DROP POLICY IF EXISTS "stores_owner_read" ON public.stores;
CREATE POLICY "stores_member_read"
ON public.stores
FOR SELECT
TO authenticated
USING (
    owner_id = auth.uid()
    OR EXISTS (
        SELECT 1 FROM public.store_members sm
        WHERE sm.store_id = stores.id
          AND sm.user_id = auth.uid()
          AND sm.is_active = true
    )
);

-- ============================================================
-- 9. Rebuild categories SELECT policy
--    All active members can read categories
-- ============================================================
DROP POLICY IF EXISTS "categories_member_read" ON public.categories;
DROP POLICY IF EXISTS "categories_owner_read" ON public.categories;
CREATE POLICY "categories_member_read"
ON public.categories
FOR SELECT
TO authenticated
USING (public.is_store_member(store_id));

-- ============================================================
-- 10. Rebuild activity_logs SELECT policy
--     All active members can read logs
-- ============================================================
DROP POLICY IF EXISTS "activity_logs_member_read" ON public.activity_logs;
DROP POLICY IF EXISTS "activity_logs_owner_read" ON public.activity_logs;
CREATE POLICY "activity_logs_member_read"
ON public.activity_logs
FOR SELECT
TO authenticated
USING (public.is_store_member(store_id));

-- ============================================================
-- 11. Rebuild activity_logs INSERT policy
-- ============================================================
DROP POLICY IF EXISTS "activity_logs_member_insert" ON public.activity_logs;
CREATE POLICY "activity_logs_member_insert"
ON public.activity_logs
FOR INSERT
TO authenticated
WITH CHECK (public.is_store_member(store_id));
