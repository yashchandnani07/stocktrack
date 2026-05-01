-- Fix inventory_items quantity column:
-- 1. Alter quantity from INTEGER to NUMERIC(10,2) to support decimal values (e.g. 88.9)
-- 2. Drop the non-negative check constraint so negative quantities (stock out) are accepted
-- 3. Drop and recreate the max cap constraint to match the new numeric type

-- ============================================================
-- 1. DROP BLOCKING CONSTRAINTS FIRST
-- ============================================================
ALTER TABLE public.inventory_items
DROP CONSTRAINT IF EXISTS inventory_items_quantity_non_negative;

ALTER TABLE public.inventory_items
DROP CONSTRAINT IF EXISTS inventory_items_quantity_max;

-- ============================================================
-- 2. ALTER COLUMN TYPE: INTEGER → NUMERIC(10,2)
-- ============================================================
ALTER TABLE public.inventory_items
ALTER COLUMN quantity TYPE NUMERIC(10,2) USING quantity::NUMERIC(10,2);

ALTER TABLE public.inventory_items
ALTER COLUMN low_stock_threshold TYPE NUMERIC(10,2) USING low_stock_threshold::NUMERIC(10,2);

-- ============================================================
-- 3. RESTORE MAX CAP CONSTRAINT (updated for numeric type)
-- ============================================================
ALTER TABLE public.inventory_items
ADD CONSTRAINT inventory_items_quantity_max
CHECK (quantity <= 999999);
