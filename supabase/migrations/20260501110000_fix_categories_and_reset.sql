-- Fix 1: Change color_value from int4 to bigint to support Flutter Color values (> 2147483647)
ALTER TABLE public.categories
  ALTER COLUMN color_value TYPE BIGINT USING color_value::BIGINT;

-- Fix 2: Update the default to a valid Flutter color (indigo 0xFF3B5BDB = 4280391387)
ALTER TABLE public.categories
  ALTER COLUMN color_value SET DEFAULT 4280391387;

-- Fix 3: Populate categories table from distinct category names in inventory_items
-- This backfills categories that were created via CSV import but never saved to the categories table
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT DISTINCT ii.store_id, ii.category
    FROM public.inventory_items ii
    WHERE ii.category IS NOT NULL
      AND ii.category <> ''
      AND NOT EXISTS (
        SELECT 1 FROM public.categories c
        WHERE c.store_id = ii.store_id
          AND lower(trim(c.name)) = lower(trim(ii.category))
      )
  LOOP
    INSERT INTO public.categories (store_id, name, color_value, icon_code)
    VALUES (r.store_id, r.category, 4280391387, 983782)
    ON CONFLICT (store_id, name) DO NOTHING;
  END LOOP;
END $$;

-- Fix 4: Reset data — delete all inventory items, activity logs, stock sessions, categories, stores, and users
-- This gives a clean slate for new sign-ups
DO $$
BEGIN
  -- Delete child tables first (dependency order)
  DELETE FROM public.stock_session_items;
  DELETE FROM public.stock_sessions;
  DELETE FROM public.activity_logs;
  DELETE FROM public.inventory_items;
  DELETE FROM public.categories;
  DELETE FROM public.store_members;
  DELETE FROM public.stores;
  DELETE FROM public.user_profiles;
  -- Delete auth users last (cascades handled by FK but explicit is safer)
  DELETE FROM auth.users;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'Reset failed: %', SQLERRM;
END $$;
