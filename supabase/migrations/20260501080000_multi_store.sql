-- Multi-Store Inventory System Migration
-- Replaces shared demo data with strict per-user, per-store data isolation

-- ============================================================
-- 1. TYPES
-- ============================================================
DROP TYPE IF EXISTS public.store_member_role CASCADE;
CREATE TYPE public.store_member_role AS ENUM ('Owner', 'Manager', 'Staff');

-- ============================================================
-- 2. CORE TABLES
-- ============================================================

-- User profiles (auto-created via trigger on auth.users insert)
CREATE TABLE IF NOT EXISTS public.user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL UNIQUE,
    full_name TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Stores (each user can own multiple stores)
CREATE TABLE IF NOT EXISTS public.stores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    owner_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Store members (collaborators with roles)
CREATE TABLE IF NOT EXISTS public.store_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    role public.store_member_role NOT NULL DEFAULT 'Staff',
    is_active BOOLEAN NOT NULL DEFAULT true,
    invited_by UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(store_id, user_id)
);

-- Categories (scoped to store)
CREATE TABLE IF NOT EXISTS public.categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    color_value INTEGER NOT NULL DEFAULT 4280391411,
    icon_code INTEGER NOT NULL DEFAULT 983782,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(store_id, name)
);

-- Inventory items (scoped to store)
CREATE TABLE IF NOT EXISTS public.inventory_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'General',
    quantity INTEGER NOT NULL DEFAULT 0,
    low_stock_threshold INTEGER NOT NULL DEFAULT 5,
    unit TEXT NOT NULL DEFAULT 'pcs',
    barcode TEXT,
    updated_by TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Activity logs (scoped to store)
CREATE TABLE IF NOT EXISTS public.activity_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL,
    user_name TEXT NOT NULL,
    user_role TEXT NOT NULL DEFAULT 'Staff',
    action_type TEXT NOT NULL,
    item_id TEXT,
    item_name TEXT,
    quantity INTEGER,
    unit TEXT,
    details TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- 3. INDEXES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_stores_owner_id ON public.stores(owner_id);
CREATE INDEX IF NOT EXISTS idx_store_members_store_id ON public.store_members(store_id);
CREATE INDEX IF NOT EXISTS idx_store_members_user_id ON public.store_members(user_id);
CREATE INDEX IF NOT EXISTS idx_categories_store_id ON public.categories(store_id);
CREATE INDEX IF NOT EXISTS idx_inventory_items_store_id ON public.inventory_items(store_id);
CREATE INDEX IF NOT EXISTS idx_activity_logs_store_id ON public.activity_logs(store_id);
CREATE INDEX IF NOT EXISTS idx_activity_logs_created_at ON public.activity_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_logs_action_type ON public.activity_logs(action_type);

-- ============================================================
-- 4. HELPER FUNCTIONS (must be before RLS policies)
-- ============================================================

-- Returns true if the current user is a member (any role) of the given store
CREATE OR REPLACE FUNCTION public.is_store_member(p_store_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT EXISTS (
    SELECT 1 FROM public.store_members sm
    WHERE sm.store_id = p_store_id
      AND sm.user_id = auth.uid()
      AND sm.is_active = true
)
OR EXISTS (
    SELECT 1 FROM public.stores s
    WHERE s.id = p_store_id
      AND s.owner_id = auth.uid()
)
$$;

-- Returns true if the current user is the owner of the given store
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

-- Trigger function: auto-create user_profiles on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO public.user_profiles (id, email, full_name)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1))
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$;

-- Trigger function: auto-add owner as store member when store is created
CREATE OR REPLACE FUNCTION public.handle_new_store()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO public.store_members (store_id, user_id, role, is_active)
    VALUES (NEW.id, NEW.owner_id, 'Owner', true)
    ON CONFLICT (store_id, user_id) DO NOTHING;
    RETURN NEW;
END;
$$;

-- ============================================================
-- 5. ENABLE RLS
-- ============================================================
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 6. RLS POLICIES
-- ============================================================

-- user_profiles: users manage their own profile
DROP POLICY IF EXISTS "user_profiles_own" ON public.user_profiles;
CREATE POLICY "user_profiles_own"
ON public.user_profiles
FOR ALL
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- user_profiles: allow reading other profiles (needed for invite lookup)
DROP POLICY IF EXISTS "user_profiles_read_others" ON public.user_profiles;
CREATE POLICY "user_profiles_read_others"
ON public.user_profiles
FOR SELECT
TO authenticated
USING (true);

-- stores: owner can manage, members can read
DROP POLICY IF EXISTS "stores_owner_manage" ON public.stores;
CREATE POLICY "stores_owner_manage"
ON public.stores
FOR ALL
TO authenticated
USING (owner_id = auth.uid())
WITH CHECK (owner_id = auth.uid());

DROP POLICY IF EXISTS "stores_member_read" ON public.stores;
CREATE POLICY "stores_member_read"
ON public.stores
FOR SELECT
TO authenticated
USING (public.is_store_member(id));

-- store_members: owner can manage members of their stores
DROP POLICY IF EXISTS "store_members_owner_manage" ON public.store_members;
CREATE POLICY "store_members_owner_manage"
ON public.store_members
FOR ALL
TO authenticated
USING (public.is_store_owner(store_id))
WITH CHECK (public.is_store_owner(store_id));

-- store_members: members can read their own membership
DROP POLICY IF EXISTS "store_members_self_read" ON public.store_members;
CREATE POLICY "store_members_self_read"
ON public.store_members
FOR SELECT
TO authenticated
USING (public.is_store_member(store_id));

-- categories: store members can read, managers/owners can write
DROP POLICY IF EXISTS "categories_member_read" ON public.categories;
CREATE POLICY "categories_member_read"
ON public.categories
FOR SELECT
TO authenticated
USING (public.is_store_member(store_id));

DROP POLICY IF EXISTS "categories_owner_write" ON public.categories;
CREATE POLICY "categories_owner_write"
ON public.categories
FOR INSERT
TO authenticated
WITH CHECK (public.is_store_member(store_id));

DROP POLICY IF EXISTS "categories_owner_update" ON public.categories;
CREATE POLICY "categories_owner_update"
ON public.categories
FOR UPDATE
TO authenticated
USING (public.is_store_member(store_id))
WITH CHECK (public.is_store_member(store_id));

DROP POLICY IF EXISTS "categories_owner_delete" ON public.categories;
CREATE POLICY "categories_owner_delete"
ON public.categories
FOR DELETE
TO authenticated
USING (public.is_store_owner(store_id));

-- inventory_items: store members can read, managers/owners can write
DROP POLICY IF EXISTS "inventory_items_member_read" ON public.inventory_items;
CREATE POLICY "inventory_items_member_read"
ON public.inventory_items
FOR SELECT
TO authenticated
USING (public.is_store_member(store_id));

DROP POLICY IF EXISTS "inventory_items_member_write" ON public.inventory_items;
CREATE POLICY "inventory_items_member_write"
ON public.inventory_items
FOR INSERT
TO authenticated
WITH CHECK (public.is_store_member(store_id));

DROP POLICY IF EXISTS "inventory_items_member_update" ON public.inventory_items;
CREATE POLICY "inventory_items_member_update"
ON public.inventory_items
FOR UPDATE
TO authenticated
USING (public.is_store_member(store_id))
WITH CHECK (public.is_store_member(store_id));

DROP POLICY IF EXISTS "inventory_items_owner_delete" ON public.inventory_items;
CREATE POLICY "inventory_items_owner_delete"
ON public.inventory_items
FOR DELETE
TO authenticated
USING (public.is_store_member(store_id));

-- activity_logs: store members can read and insert
DROP POLICY IF EXISTS "activity_logs_member_read" ON public.activity_logs;
CREATE POLICY "activity_logs_member_read"
ON public.activity_logs
FOR SELECT
TO authenticated
USING (public.is_store_member(store_id));

DROP POLICY IF EXISTS "activity_logs_member_insert" ON public.activity_logs;
CREATE POLICY "activity_logs_member_insert"
ON public.activity_logs
FOR INSERT
TO authenticated
WITH CHECK (public.is_store_member(store_id));

-- ============================================================
-- 7. TRIGGERS
-- ============================================================
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

DROP TRIGGER IF EXISTS on_store_created ON public.stores;
CREATE TRIGGER on_store_created
    AFTER INSERT ON public.stores
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_store();
