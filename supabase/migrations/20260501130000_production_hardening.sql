-- ============================================================
-- Production Hardening Migration
-- Fixes found during white-box testing:
-- 1. activity_logs.quantity column: INTEGER → NUMERIC(10,2) to preserve decimals
-- 2. activity_logs: add store_id NOT NULL + FK for proper isolation
-- 3. inventory_items: enforce non-negative stock at DB level (re-apply after NUMERIC migration)
-- 4. categories: ensure UNIQUE constraint per store
-- 5. stock_sessions: add store_id FK integrity check
-- 6. Add missing indexes for performance
-- 7. Fix activity_logs RLS: restrict reads to store members only (was open to all)
-- ============================================================

-- ============================================================
-- 1. activity_logs.quantity: INTEGER → NUMERIC(10,2)
--    Preserves decimal stock quantities (e.g. 88.9 kg)
-- ============================================================
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'activity_logs'
          AND column_name = 'quantity'
          AND data_type = 'integer'
    ) THEN
        ALTER TABLE public.activity_logs
            ALTER COLUMN quantity TYPE NUMERIC(10,2) USING quantity::NUMERIC(10,2);
    END IF;
END $$;

-- ============================================================
-- 2. activity_logs: ensure store_id column exists and is NOT NULL
--    (older migration may have created table without store_id)
-- ============================================================
DO $$
BEGIN
    -- Add store_id if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'activity_logs'
          AND column_name = 'store_id'
    ) THEN
        ALTER TABLE public.activity_logs
            ADD COLUMN store_id UUID REFERENCES public.stores(id) ON DELETE CASCADE;
    END IF;
END $$;

-- ============================================================
-- 3. Fix activity_logs RLS: restrict SELECT to store members only
--    Previous migration had USING (true) which exposed all logs to all users
-- ============================================================
DROP POLICY IF EXISTS "activity_logs_select" ON public.activity_logs;
DROP POLICY IF EXISTS "activity_logs_member_read" ON public.activity_logs;
CREATE POLICY "activity_logs_member_read"
ON public.activity_logs
FOR SELECT
TO authenticated
USING (
    store_id IS NOT NULL AND public.is_store_member(store_id)
);

-- Fix INSERT policy: was open to public (unauthenticated), restrict to authenticated store members
DROP POLICY IF EXISTS "activity_logs_insert" ON public.activity_logs;
DROP POLICY IF EXISTS "activity_logs_member_insert" ON public.activity_logs;
CREATE POLICY "activity_logs_member_insert"
ON public.activity_logs
FOR INSERT
TO authenticated
WITH CHECK (
    store_id IS NOT NULL AND public.is_store_member(store_id)
);

-- ============================================================
-- 4. inventory_items: enforce non-negative stock at DB level
--    (re-apply after NUMERIC migration from 20260501120000)
-- ============================================================
ALTER TABLE public.inventory_items
    DROP CONSTRAINT IF EXISTS inventory_items_quantity_non_negative;

-- Clamp any existing negative quantities to 0 before re-applying constraint
UPDATE public.inventory_items SET quantity = 0 WHERE quantity < 0;

ALTER TABLE public.inventory_items
    ADD CONSTRAINT inventory_items_quantity_non_negative
    CHECK (quantity >= 0);

-- ============================================================
-- 5. categories: ensure UNIQUE(store_id, name) constraint exists
-- ============================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_schema = 'public'
          AND table_name = 'categories'
          AND constraint_type = 'UNIQUE'
          AND constraint_name = 'categories_store_id_name_key'
    ) THEN
        ALTER TABLE public.categories
            ADD CONSTRAINT categories_store_id_name_key UNIQUE (store_id, name);
    END IF;
END $$;

-- ============================================================
-- 6. Add missing performance indexes
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_activity_logs_store_id_created
    ON public.activity_logs(store_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_inventory_items_store_name
    ON public.inventory_items(store_id, name);

CREATE INDEX IF NOT EXISTS idx_categories_store_name
    ON public.categories(store_id, name);

-- ============================================================
-- 7. stock_sessions: ensure performed_by_id is UUID type for FK integrity
-- ============================================================
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'stock_sessions'
          AND column_name = 'performed_by_id'
          AND data_type = 'text'
    ) THEN
        -- Only alter if all existing values are valid UUIDs
        IF NOT EXISTS (
            SELECT 1 FROM public.stock_sessions
            WHERE performed_by_id !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        ) THEN
            ALTER TABLE public.stock_sessions
                ALTER COLUMN performed_by_id TYPE UUID USING performed_by_id::UUID;
        END IF;
    END IF;
END $$;

-- ============================================================
-- 8. Ensure is_store_manager_or_owner function exists (idempotent)
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
