-- Stock Sessions Migration
-- Adds stock_sessions and stock_session_items tables for bulk stock operations

-- ============================================================
-- 1. TABLES
-- ============================================================

CREATE TABLE IF NOT EXISTS public.stock_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
    session_type TEXT NOT NULL CHECK (session_type IN ('IN', 'OUT')),
    performed_by_id TEXT NOT NULL,
    performed_by_name TEXT NOT NULL,
    performed_by_role TEXT NOT NULL DEFAULT 'Staff',
    total_items INT NOT NULL DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS public.stock_session_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES public.stock_sessions(id) ON DELETE CASCADE,
    item_id TEXT NOT NULL,
    item_name TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'General',
    quantity DOUBLE PRECISION NOT NULL DEFAULT 0,
    unit TEXT NOT NULL DEFAULT 'pcs',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- 2. INDEXES
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_stock_sessions_store_id ON public.stock_sessions(store_id);
CREATE INDEX IF NOT EXISTS idx_stock_sessions_created_at ON public.stock_sessions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_stock_session_items_session_id ON public.stock_session_items(session_id);

-- ============================================================
-- 3. RLS
-- ============================================================

ALTER TABLE public.stock_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_session_items ENABLE ROW LEVEL SECURITY;

-- stock_sessions: store members can read, authenticated can insert
DROP POLICY IF EXISTS "store_members_read_stock_sessions" ON public.stock_sessions;
CREATE POLICY "store_members_read_stock_sessions"
ON public.stock_sessions
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.store_members sm
        WHERE sm.store_id = public.stock_sessions.store_id
          AND sm.user_id = auth.uid()
          AND sm.is_active = true
    )
    OR EXISTS (
        SELECT 1 FROM public.stores s
        WHERE s.id = public.stock_sessions.store_id
          AND s.owner_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "store_members_insert_stock_sessions" ON public.stock_sessions;
CREATE POLICY "store_members_insert_stock_sessions"
ON public.stock_sessions
FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.store_members sm
        WHERE sm.store_id = public.stock_sessions.store_id
          AND sm.user_id = auth.uid()
          AND sm.is_active = true
    )
    OR EXISTS (
        SELECT 1 FROM public.stores s
        WHERE s.id = public.stock_sessions.store_id
          AND s.owner_id = auth.uid()
    )
);

-- stock_session_items: accessible via session
DROP POLICY IF EXISTS "store_members_read_stock_session_items" ON public.stock_session_items;
CREATE POLICY "store_members_read_stock_session_items"
ON public.stock_session_items
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.stock_sessions ss
        JOIN public.store_members sm ON sm.store_id = ss.store_id
        WHERE ss.id = public.stock_session_items.session_id
          AND sm.user_id = auth.uid()
          AND sm.is_active = true
    )
    OR EXISTS (
        SELECT 1 FROM public.stock_sessions ss
        JOIN public.stores s ON s.id = ss.store_id
        WHERE ss.id = public.stock_session_items.session_id
          AND s.owner_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "store_members_insert_stock_session_items" ON public.stock_session_items;
CREATE POLICY "store_members_insert_stock_session_items"
ON public.stock_session_items
FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.stock_sessions ss
        JOIN public.store_members sm ON sm.store_id = ss.store_id
        WHERE ss.id = public.stock_session_items.session_id
          AND sm.user_id = auth.uid()
          AND sm.is_active = true
    )
    OR EXISTS (
        SELECT 1 FROM public.stock_sessions ss
        JOIN public.stores s ON s.id = ss.store_id
        WHERE ss.id = public.stock_session_items.session_id
          AND s.owner_id = auth.uid()
    )
);
