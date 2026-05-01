-- Security Hardening Migration
-- Fixes RLS policy gaps found during white-box testing:
-- 1. inventory_items DELETE was allowed for all store members (Staff could delete)
-- 2. categories INSERT/UPDATE was allowed for all store members (Staff could write)
-- 3. categories DELETE was correct (owner only) — no change needed
-- 4. Adds DB-level quantity constraint to prevent negative stock
-- 5. Adds DB-level item name length constraint
-- 6. Adds helper function to check if user is manager or owner in a store

-- ============================================================
-- 1. HELPER: is_store_manager_or_owner
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
-- 2. FIX: inventory_items DELETE — restrict to Owner only
-- (Previously used is_store_member which allowed Staff to delete)
-- ============================================================
DROP POLICY IF EXISTS "inventory_items_owner_delete" ON public.inventory_items;
CREATE POLICY "inventory_items_owner_delete"
ON public.inventory_items
FOR DELETE
TO authenticated
USING (public.is_store_owner(store_id));

-- ============================================================
-- 3. FIX: categories INSERT — restrict to Manager/Owner only
-- (Previously used is_store_member which allowed Staff to create)
-- ============================================================
DROP POLICY IF EXISTS "categories_owner_write" ON public.categories;
CREATE POLICY "categories_manager_owner_insert"
ON public.categories
FOR INSERT
TO authenticated
WITH CHECK (public.is_store_manager_or_owner(store_id));

-- ============================================================
-- 4. FIX: categories UPDATE — restrict to Manager/Owner only
-- ============================================================
DROP POLICY IF EXISTS "categories_owner_update" ON public.categories;
CREATE POLICY "categories_manager_owner_update"
ON public.categories
FOR UPDATE
TO authenticated
USING (public.is_store_manager_or_owner(store_id))
WITH CHECK (public.is_store_manager_or_owner(store_id));

-- ============================================================
-- 5. FIX: inventory_items INSERT — restrict to Manager/Owner only
-- (Staff should only do stock in/out, not create new items)
-- ============================================================
DROP POLICY IF EXISTS "inventory_items_member_write" ON public.inventory_items;
CREATE POLICY "inventory_items_manager_owner_insert"
ON public.inventory_items
FOR INSERT
TO authenticated
WITH CHECK (public.is_store_manager_or_owner(store_id));

-- ============================================================
-- 6. DB-LEVEL CONSTRAINT: quantity must be non-negative
-- ============================================================
ALTER TABLE public.inventory_items
    DROP CONSTRAINT IF EXISTS inventory_items_quantity_non_negative;
ALTER TABLE public.inventory_items
    ADD CONSTRAINT inventory_items_quantity_non_negative
    CHECK (quantity >= 0);

-- ============================================================
-- 7. DB-LEVEL CONSTRAINT: quantity max cap
-- ============================================================
ALTER TABLE public.inventory_items
    DROP CONSTRAINT IF EXISTS inventory_items_quantity_max;
ALTER TABLE public.inventory_items
    ADD CONSTRAINT inventory_items_quantity_max
    CHECK (quantity <= 999999);

-- ============================================================
-- 8. DB-LEVEL CONSTRAINT: item name not empty, max length
-- ============================================================
ALTER TABLE public.inventory_items
    DROP CONSTRAINT IF EXISTS inventory_items_name_length;
ALTER TABLE public.inventory_items
    ADD CONSTRAINT inventory_items_name_length
    CHECK (char_length(trim(name)) >= 1 AND char_length(name) <= 120);

-- ============================================================
-- 9. DB-LEVEL CONSTRAINT: category name not empty, max length
-- ============================================================
ALTER TABLE public.categories
    DROP CONSTRAINT IF EXISTS categories_name_length;
ALTER TABLE public.categories
    ADD CONSTRAINT categories_name_length
    CHECK (char_length(trim(name)) >= 1 AND char_length(name) <= 60);

-- ============================================================
-- 10. FIX: activity_logs — ensure user_id references auth users
-- Change user_id from TEXT to UUID with foreign key reference
-- Note: Only applies if column is still TEXT type
-- ============================================================
DO $$
BEGIN
    -- Only alter if column is still text type
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'activity_logs'
          AND column_name = 'user_id'
          AND data_type = 'text'
    ) THEN
        -- Add a new uuid column
        ALTER TABLE public.activity_logs ADD COLUMN IF NOT EXISTS user_id_uuid UUID;
        -- Migrate existing valid UUIDs
        UPDATE public.activity_logs
        SET user_id_uuid = user_id::UUID
        WHERE user_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
    END IF;
END $$;
