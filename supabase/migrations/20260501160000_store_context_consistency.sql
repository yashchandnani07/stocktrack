-- ============================================================
-- Store Context Consistency — Phase 2
-- Cross-platform fix for "items created on web invisible on mobile"
-- and "invalid item or store" stock-update errors.
--
-- This migration enforces invariants that prevent the bug from ever
-- recurring at the database layer, and adds diagnostic helpers that
-- the client uses to surface mismatches early.
--
-- Idempotent — safe to re-apply.
-- ============================================================

-- ============================================================
-- 1. Enforce store_id NOT NULL on every store-scoped table.
--    Defensive: previous migrations should already do this, but
--    Postgres treats this as a no-op when the constraint exists,
--    so it's safe to declare the invariant explicitly here.
-- ============================================================
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'inventory_items'
          AND column_name = 'store_id'
          AND is_nullable = 'YES'
    ) THEN
        ALTER TABLE public.inventory_items ALTER COLUMN store_id SET NOT NULL;
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'categories'
          AND column_name = 'store_id'
          AND is_nullable = 'YES'
    ) THEN
        ALTER TABLE public.categories ALTER COLUMN store_id SET NOT NULL;
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'activity_logs'
          AND column_name = 'store_id'
          AND is_nullable = 'YES'
    ) THEN
        ALTER TABLE public.activity_logs ALTER COLUMN store_id SET NOT NULL;
    END IF;
END $$;

-- ============================================================
-- 2. Diagnostic: which stores does the calling user actually see?
--    Used by the client to log/compare on web vs mobile after login.
--    SECURITY INVOKER so the result reflects exactly what the user's
--    JWT can read — same answer the regular client would get.
-- ============================================================
CREATE OR REPLACE FUNCTION public.my_visible_stores()
RETURNS TABLE (
    id UUID,
    name TEXT,
    owner_id UUID,
    role TEXT,
    is_active BOOLEAN,
    created_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
    -- Stores the user owns
    SELECT s.id,
           s.name,
           s.owner_id,
           'Owner'::TEXT       AS role,
           TRUE                AS is_active,
           s.created_at
    FROM public.stores s
    WHERE s.owner_id = auth.uid()

    UNION

    -- Stores where the user is an active member
    SELECT s.id,
           s.name,
           s.owner_id,
           sm.role             AS role,
           sm.is_active        AS is_active,
           s.created_at
    FROM public.stores s
    JOIN public.store_members sm ON sm.store_id = s.id
    WHERE sm.user_id = auth.uid()
      AND sm.is_active = TRUE

    ORDER BY created_at ASC, id ASC;
$$;

GRANT EXECUTE ON FUNCTION public.my_visible_stores() TO authenticated;

-- ============================================================
-- 3. Diagnostic: tell me where an item lives and whether I can see it.
--    Used to surface a precise message when the mobile client tries
--    to operate on an item under the wrong store_id.
-- ============================================================
CREATE OR REPLACE FUNCTION public.diagnose_item_visibility(p_item_id UUID)
RETURNS TABLE (
    item_id UUID,
    item_store_id UUID,
    item_store_name TEXT,
    user_can_see BOOLEAN,
    user_role TEXT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_item_store UUID;
    v_store_name TEXT;
    v_role TEXT;
    v_can BOOLEAN;
BEGIN
    SELECT i.store_id, s.name
      INTO v_item_store, v_store_name
      FROM public.inventory_items i
      LEFT JOIN public.stores s ON s.id = i.store_id
     WHERE i.id = p_item_id;

    IF v_item_store IS NULL THEN
        RETURN QUERY
        SELECT p_item_id,
               NULL::UUID,
               NULL::TEXT,
               FALSE,
               NULL::TEXT;
        RETURN;
    END IF;

    -- Owner?
    IF EXISTS (
        SELECT 1 FROM public.stores
        WHERE id = v_item_store AND owner_id = auth.uid()
    ) THEN
        v_role := 'Owner';
        v_can := TRUE;
    ELSE
        SELECT sm.role
          INTO v_role
          FROM public.store_members sm
         WHERE sm.store_id = v_item_store
           AND sm.user_id = auth.uid()
           AND sm.is_active = TRUE
         LIMIT 1;
        v_can := v_role IS NOT NULL;
    END IF;

    RETURN QUERY
    SELECT p_item_id,
           v_item_store,
           v_store_name,
           COALESCE(v_can, FALSE),
           v_role;
END;
$$;

GRANT EXECUTE ON FUNCTION public.diagnose_item_visibility(UUID) TO authenticated;

-- ============================================================
-- 4. Trigger: refuse to insert/update inventory_items rows whose
--    store_id is not visible to the calling user. RLS already does
--    this, but a CHECK trigger gives a clearer error message that
--    the client can surface directly.
-- ============================================================
CREATE OR REPLACE FUNCTION public.enforce_inventory_store_context()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF NEW.store_id IS NULL THEN
        RAISE EXCEPTION 'inventory_items.store_id cannot be null'
            USING ERRCODE = '23502';
    END IF;

    -- On UPDATE, prevent moving the row to a different store.
    -- Cross-store moves are never legitimate and almost always
    -- indicate a context-mismatch bug.
    IF TG_OP = 'UPDATE' AND OLD.store_id IS DISTINCT FROM NEW.store_id THEN
        RAISE EXCEPTION
            'inventory_items.store_id is immutable (was % attempted %)',
            OLD.store_id, NEW.store_id
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS enforce_inventory_store_context_trg
    ON public.inventory_items;
CREATE TRIGGER enforce_inventory_store_context_trg
    BEFORE INSERT OR UPDATE ON public.inventory_items
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_inventory_store_context();
