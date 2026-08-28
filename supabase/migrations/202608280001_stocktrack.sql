-- StockTrack: multi-store inventory with RLS-enforced membership and idempotent offline mutations.
create extension if not exists pgcrypto;

create type public.store_role as enum ('staff', 'manager', 'owner');
create type public.session_type as enum ('IN', 'OUT');
create type public.invitation_status as enum ('pending', 'accepted', 'revoked', 'expired');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  full_name text not null default '',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.stores (
  id uuid primary key,
  name text not null check (char_length(btrim(name)) between 2 and 120),
  owner_id uuid not null references public.profiles(id) on delete restrict,
  allow_negative_stock boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.store_members (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role public.store_role not null default 'staff',
  is_active boolean not null default true,
  invited_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (store_id, user_id)
);

create table public.categories (
  id uuid primary key,
  store_id uuid not null references public.stores(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 80),
  color_value text not null,
  icon_code text not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (store_id, name)
);

create table public.inventory_items (
  id uuid primary key,
  store_id uuid not null references public.stores(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 2 and 120),
  category_id uuid references public.categories(id) on delete set null,
  category_name text not null default 'General',
  quantity numeric(14,2) not null default 0 check (quantity between -999999 and 999999),
  low_stock_threshold numeric(14,2) not null default 5 check (low_stock_threshold between 0 and 999999),
  unit text not null default 'pcs',
  barcode text check (barcode is null or barcode ~ '^[0-9]+$'),
  updated_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.stock_sessions (
  id uuid primary key,
  store_id uuid not null references public.stores(id) on delete cascade,
  session_type public.session_type not null,
  performer_id uuid not null references public.profiles(id) on delete restrict,
  performer_name text not null,
  performer_role public.store_role not null,
  total_items integer not null check (total_items > 0),
  notes text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.activity_logs (
  id uuid primary key,
  store_id uuid not null references public.stores(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete restrict,
  user_name text not null,
  user_role public.store_role not null,
  action_type text not null check (action_type in ('stock_in', 'stock_out', 'stock_correction', 'item_created', 'item_edited', 'item_deleted', 'category_created', 'category_deleted', 'bulk_import', 'user_added', 'user_removed', 'role_changed', 'user_enabled', 'user_disabled')),
  item_id uuid references public.inventory_items(id) on delete set null,
  item_name text,
  quantity numeric(14,2),
  unit text,
  details text,
  session_id uuid references public.stock_sessions(id) on delete set null,
  correction_meta jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.stock_session_items (
  id uuid primary key,
  session_id uuid not null references public.stock_sessions(id) on delete cascade,
  store_id uuid not null references public.stores(id) on delete cascade,
  item_id uuid not null references public.inventory_items(id) on delete restrict,
  item_name text not null,
  category text not null,
  quantity numeric(14,2) not null,
  unit text not null,
  activity_log_id uuid not null references public.activity_logs(id) on delete restrict,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.invitations (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  email text not null,
  role public.store_role not null check (role in ('staff', 'manager')),
  status public.invitation_status not null default 'pending',
  token_hash text not null unique,
  expires_at timestamptz not null,
  invited_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.sync_operations (
  operation_key uuid primary key,
  user_id uuid not null references public.profiles(id) on delete restrict,
  store_id uuid references public.stores(id) on delete set null,
  completed_at timestamptz not null default timezone('utc', now())
);

create index store_members_store_user_active_idx on public.store_members(store_id, user_id, is_active);
create index store_members_user_active_idx on public.store_members(user_id, is_active);
create index categories_store_name_idx on public.categories(store_id, name);
create index inventory_items_store_updated_idx on public.inventory_items(store_id, updated_at desc);
create index inventory_items_store_name_idx on public.inventory_items(store_id, name);
create index activity_logs_store_created_idx on public.activity_logs(store_id, created_at desc);
create index stock_sessions_store_created_idx on public.stock_sessions(store_id, created_at desc);
create index stock_session_items_session_idx on public.stock_session_items(session_id);
create index invitations_store_status_idx on public.invitations(store_id, status);

create or replace function public.set_updated_at() returns trigger language plpgsql as $$
begin new.updated_at = timezone('utc', now()); return new; end;
$$;
create trigger set_profiles_updated_at before update on public.profiles for each row execute procedure public.set_updated_at();
create trigger set_stores_updated_at before update on public.stores for each row execute procedure public.set_updated_at();
create trigger set_members_updated_at before update on public.store_members for each row execute procedure public.set_updated_at();
create trigger set_categories_updated_at before update on public.categories for each row execute procedure public.set_updated_at();
create trigger set_items_updated_at before update on public.inventory_items for each row execute procedure public.set_updated_at();
create trigger set_sessions_updated_at before update on public.stock_sessions for each row execute procedure public.set_updated_at();
create trigger set_logs_updated_at before update on public.activity_logs for each row execute procedure public.set_updated_at();
create trigger set_session_items_updated_at before update on public.stock_session_items for each row execute procedure public.set_updated_at();
create trigger set_invitations_updated_at before update on public.invitations for each row execute procedure public.set_updated_at();

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, full_name)
  values (new.id, coalesce(new.email, ''), coalesce(new.raw_user_meta_data ->> 'full_name', ''))
  on conflict (id) do update set email = excluded.email, full_name = excluded.full_name;
  return new;
end;
$$;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

create or replace function public.active_store_role(p_store_id uuid) returns public.store_role language sql stable security definer set search_path = public as $$
  select role from public.store_members where store_id = p_store_id and user_id = auth.uid() and is_active limit 1;
$$;
create or replace function public.is_active_member(p_store_id uuid) returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.store_members where store_id = p_store_id and user_id = auth.uid() and is_active);
$$;
create or replace function public.has_role(p_store_id uuid, p_roles public.store_role[]) returns boolean language sql stable security definer set search_path = public as $$
  select public.active_store_role(p_store_id) = any(p_roles);
$$;
create or replace function public.shares_active_store(p_user_id uuid) returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.store_members self join public.store_members other on other.store_id = self.store_id where self.user_id = auth.uid() and self.is_active and other.user_id = p_user_id and other.is_active);
$$;
revoke all on function public.active_store_role(uuid) from public;
revoke all on function public.is_active_member(uuid) from public;
revoke all on function public.has_role(uuid, public.store_role[]) from public;
revoke all on function public.shares_active_store(uuid) from public;
grant execute on function public.active_store_role(uuid), public.is_active_member(uuid), public.has_role(uuid, public.store_role[]), public.shares_active_store(uuid) to authenticated;

alter table public.profiles enable row level security;
alter table public.stores enable row level security;
alter table public.store_members enable row level security;
alter table public.categories enable row level security;
alter table public.inventory_items enable row level security;
alter table public.activity_logs enable row level security;
alter table public.stock_sessions enable row level security;
alter table public.stock_session_items enable row level security;
alter table public.invitations enable row level security;
alter table public.sync_operations enable row level security;

revoke all on table public.profiles, public.stores, public.store_members, public.categories, public.inventory_items, public.activity_logs, public.stock_sessions, public.stock_session_items, public.invitations, public.sync_operations from anon, authenticated;
grant select on table public.profiles, public.stores, public.store_members, public.categories, public.inventory_items, public.activity_logs, public.stock_sessions, public.stock_session_items, public.invitations to authenticated;

create policy profiles_read_self on public.profiles for select to authenticated using (id = (select auth.uid()));
create policy profiles_read_shared_store on public.profiles for select to authenticated using ((select public.shares_active_store(id)));
create policy profiles_update_self on public.profiles for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));
create policy stores_read_active on public.stores for select to authenticated using ((select public.is_active_member(id)));
create policy members_read_active on public.store_members for select to authenticated using ((select public.is_active_member(store_id)));
create policy categories_read_active on public.categories for select to authenticated using ((select public.is_active_member(store_id)));
create policy items_read_active on public.inventory_items for select to authenticated using ((select public.is_active_member(store_id)));
create policy logs_read_by_role on public.activity_logs for select to authenticated using ((select public.has_role(store_id, array['owner']::public.store_role[])) or ((select public.has_role(store_id, array['manager']::public.store_role[])) and action_type in ('stock_in', 'stock_out', 'stock_correction')));
create policy sessions_read_active on public.stock_sessions for select to authenticated using ((select public.is_active_member(store_id)));
create policy session_items_read_active on public.stock_session_items for select to authenticated using ((select public.is_active_member(store_id)));
create policy invitations_read_owner on public.invitations for select to authenticated using ((select public.has_role(store_id, array['owner']::public.store_role[])));

create or replace function public.record_activity(p_activity jsonb) returns void language plpgsql security definer set search_path = public as $$
begin
  insert into public.activity_logs (id, store_id, user_id, user_name, user_role, action_type, item_id, item_name, quantity, unit, details, session_id, correction_meta, created_at)
  values ((p_activity ->> 'id')::uuid, (p_activity ->> 'store_id')::uuid, (p_activity ->> 'user_id')::uuid, coalesce(p_activity ->> 'user_name', ''), (p_activity ->> 'user_role')::public.store_role, p_activity ->> 'action_type', nullif(p_activity ->> 'item_id', '')::uuid, nullif(p_activity ->> 'item_name', ''), nullif(p_activity ->> 'quantity', '')::numeric, nullif(p_activity ->> 'unit', ''), nullif(p_activity ->> 'details', ''), nullif(p_activity ->> 'session_id', '')::uuid, p_activity -> 'correction_meta', coalesce(nullif(p_activity ->> 'created_at', '')::timestamptz, timezone('utc', now())))
  on conflict (id) do nothing;
end;
$$;

create or replace function public.record_generic_activity(p_operation_key uuid, p_activity jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_store uuid := (p_activity ->> 'store_id')::uuid;
begin
  if (p_activity ->> 'user_id')::uuid <> v_user then raise exception 'Activity identity mismatch'; end if;
  if not public.has_role(v_store, array['manager','owner']::public.store_role[]) then raise exception 'Manager access is required'; end if;
  if p_activity ->> 'action_type' not in ('bulk_import', 'item_created', 'item_edited', 'item_deleted', 'category_created', 'category_deleted', 'user_added', 'user_removed', 'role_changed', 'user_enabled', 'user_disabled') then raise exception 'Unsupported activity type'; end if;
  insert into public.sync_operations(operation_key, user_id, store_id) values (p_operation_key, v_user, v_store) on conflict do nothing;
  if not found then return jsonb_build_object('duplicate', true); end if;
  perform public.record_activity(p_activity);
  return jsonb_build_object('activity_id', p_activity ->> 'id');
end;
$$;

create or replace function public.create_store(p_store_id uuid, p_name text, p_general_category_id uuid, p_operation_key uuid) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  insert into public.sync_operations(operation_key, user_id, store_id) values (p_operation_key, v_user, p_store_id) on conflict do nothing;
  if not found then return jsonb_build_object('duplicate', true); end if;
  insert into public.stores(id, name, owner_id) values (p_store_id, btrim(p_name), v_user);
  insert into public.store_members(store_id, user_id, role, is_active, invited_by) values (p_store_id, v_user, 'owner', true, v_user);
  insert into public.categories(id, store_id, name, color_value, icon_code) values (p_general_category_id, p_store_id, 'General', '#3568D4', 'inventory');
  return jsonb_build_object('store_id', p_store_id);
end;
$$;

create or replace function public.rename_store(p_operation_key uuid, p_store_id uuid, p_name text) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_user uuid := auth.uid();
begin
  if not public.has_role(p_store_id, array['owner']::public.store_role[]) then raise exception 'Owner access is required'; end if;
  insert into public.sync_operations(operation_key, user_id, store_id) values (p_operation_key, v_user, p_store_id) on conflict do nothing;
  if not found then return jsonb_build_object('duplicate', true); end if;
  update public.stores set name = btrim(p_name) where id = p_store_id;
  return jsonb_build_object('store_id', p_store_id);
end;
$$;

create or replace function public.upsert_inventory_item(p_operation_key uuid, p_item jsonb, p_activity jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_store uuid := (p_item ->> 'store_id')::uuid; v_item uuid := (p_item ->> 'id')::uuid; v_existing public.inventory_items%rowtype;
begin
  if not public.has_role(v_store, array['manager','owner']::public.store_role[]) then raise exception 'Manager access is required'; end if;
  insert into public.sync_operations(operation_key, user_id, store_id) values (p_operation_key, v_user, v_store) on conflict do nothing;
  if not found then return jsonb_build_object('duplicate', true); end if;
  select * into v_existing from public.inventory_items where id = v_item for update;
  if found then
    if v_existing.store_id <> v_store then raise exception 'Item is not in the active store'; end if;
    update public.inventory_items set name = btrim(p_item ->> 'name'), category_id = nullif(p_item ->> 'category_id','')::uuid, category_name = coalesce(nullif(p_item ->> 'category_name',''), 'General'), low_stock_threshold = coalesce(nullif(p_item ->> 'low_stock_threshold','')::numeric, v_existing.low_stock_threshold), unit = coalesce(nullif(p_item ->> 'unit',''), v_existing.unit), barcode = nullif(p_item ->> 'barcode',''), updated_by = v_user where id = v_item;
  else
    insert into public.inventory_items(id, store_id, name, category_id, category_name, quantity, low_stock_threshold, unit, barcode, updated_by)
    values (v_item, v_store, btrim(p_item ->> 'name'), nullif(p_item ->> 'category_id','')::uuid, coalesce(nullif(p_item ->> 'category_name',''), 'General'), coalesce(nullif(p_item ->> 'quantity','')::numeric, 0), coalesce(nullif(p_item ->> 'low_stock_threshold','')::numeric, 5), coalesce(nullif(p_item ->> 'unit',''), 'pcs'), nullif(p_item ->> 'barcode',''), v_user);
  end if;
  perform public.record_activity(p_activity);
  return jsonb_build_object('item_id', v_item);
end;
$$;

create or replace function public.upsert_category(p_operation_key uuid, p_category jsonb, p_activity jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_store uuid := (p_category ->> 'store_id')::uuid;
begin
  if not public.has_role(v_store, array['manager','owner']::public.store_role[]) then raise exception 'Manager access is required'; end if;
  insert into public.sync_operations(operation_key, user_id, store_id) values (p_operation_key, v_user, v_store) on conflict do nothing;
  if not found then return jsonb_build_object('duplicate', true); end if;
  insert into public.categories(id, store_id, name, color_value, icon_code) values ((p_category ->> 'id')::uuid, v_store, btrim(p_category ->> 'name'), p_category ->> 'color_value', p_category ->> 'icon_code') on conflict (id) do update set name = excluded.name, color_value = excluded.color_value, icon_code = excluded.icon_code;
  perform public.record_activity(p_activity);
  return jsonb_build_object('category_id', p_category ->> 'id');
end;
$$;

create or replace function public.apply_stock_delta(p_operation_key uuid, p_item_id uuid, p_delta numeric, p_activity jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_item public.inventory_items%rowtype; v_allow_negative boolean;
begin
  select * into v_item from public.inventory_items where id = p_item_id for update;
  if not found then raise exception 'Item no longer exists'; end if;
  if not public.has_role(v_item.store_id, array['staff','manager','owner']::public.store_role[]) then raise exception 'Active membership is required'; end if;
  insert into public.sync_operations(operation_key, user_id, store_id) values (p_operation_key, v_user, v_item.store_id) on conflict do nothing;
  if not found then return jsonb_build_object('duplicate', true, 'quantity', v_item.quantity); end if;
  select allow_negative_stock into v_allow_negative from public.stores where id = v_item.store_id;
  if not v_allow_negative and v_item.quantity + p_delta < 0 then raise exception 'This store does not allow negative stock'; end if;
  update public.inventory_items set quantity = quantity + p_delta, updated_by = v_user where id = p_item_id returning * into v_item;
  perform public.record_activity(p_activity);
  return jsonb_build_object('item_id', p_item_id, 'quantity', v_item.quantity);
end;
$$;

create or replace function public.correct_stock(p_operation_key uuid, p_log_id uuid, p_new_quantity numeric, p_correction_meta jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_log public.activity_logs%rowtype; v_item public.inventory_items%rowtype; v_delta numeric; v_allow_negative boolean;
begin
  select * into v_log from public.activity_logs where id = p_log_id for update;
  if not found then raise exception 'The original activity entry no longer exists'; end if;
  if v_log.action_type not in ('stock_in', 'stock_out', 'stock_correction') then raise exception 'Only stock movements can be corrected'; end if;
  if v_log.item_id is null or v_log.quantity is null then raise exception 'This entry cannot be corrected'; end if;
  if not public.has_role(v_log.store_id, array['owner']::public.store_role[]) then raise exception 'Owner access is required'; end if;
  insert into public.sync_operations(operation_key, user_id, store_id) values (p_operation_key, v_user, v_log.store_id) on conflict do nothing;
  if not found then return jsonb_build_object('duplicate', true); end if;
  v_delta := p_new_quantity - v_log.quantity;
  select * into v_item from public.inventory_items where id = v_log.item_id for update;
  if not found then raise exception 'Item no longer exists'; end if;
  select allow_negative_stock into v_allow_negative from public.stores where id = v_log.store_id;
  if not v_allow_negative and v_item.quantity + v_delta < 0 then raise exception 'This store does not allow negative stock'; end if;
  update public.inventory_items set quantity = quantity + v_delta, updated_by = v_user where id = v_item.id;
  update public.activity_logs set quantity = p_new_quantity, correction_meta = p_correction_meta where id = p_log_id;
  update public.stock_session_items set quantity = p_new_quantity where activity_log_id = p_log_id;
  return jsonb_build_object('log_id', p_log_id, 'delta', v_delta);
end;
$$;

create or replace function public.delete_category(p_operation_key uuid, p_store_id uuid, p_category_id uuid, p_general_category_id uuid, p_activity jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_user uuid := auth.uid();
begin
  if p_category_id = p_general_category_id then raise exception 'The General category cannot be deleted'; end if;
  if not public.has_role(p_store_id, array['owner']::public.store_role[]) then raise exception 'Owner access is required'; end if;
  insert into public.sync_operations(operation_key, user_id, store_id) values (p_operation_key, v_user, p_store_id) on conflict do nothing;
  if not found then return jsonb_build_object('duplicate', true); end if;
  update public.inventory_items set category_id = p_general_category_id, category_name = 'General' where store_id = p_store_id and category_id = p_category_id;
  delete from public.categories where id = p_category_id and store_id = p_store_id;
  perform public.record_activity(p_activity);
  return jsonb_build_object('category_id', p_category_id);
end;
$$;

create or replace function public.delete_inventory_item(p_operation_key uuid, p_item_id uuid, p_activity jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_item public.inventory_items%rowtype;
begin
  select * into v_item from public.inventory_items where id = p_item_id for update;
  if not found then return jsonb_build_object('already_deleted', true); end if;
  if not public.has_role(v_item.store_id, array['owner']::public.store_role[]) then raise exception 'Owner access is required'; end if;
  insert into public.sync_operations(operation_key, user_id, store_id) values (p_operation_key, v_user, v_item.store_id) on conflict do nothing;
  if not found then return jsonb_build_object('duplicate', true); end if;
  delete from public.inventory_items where id = p_item_id;
  perform public.record_activity(p_activity);
  return jsonb_build_object('item_id', p_item_id);
end;
$$;

create or replace function public.invite_member(p_operation_key uuid, p_store_id uuid, p_full_name text, p_email text, p_role public.store_role, p_activity jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_member_user uuid; v_invitation uuid;
begin
  if p_role = 'owner' then raise exception 'Owner role cannot be invited'; end if;
  if not public.has_role(p_store_id, array['owner']::public.store_role[]) then raise exception 'Owner access is required'; end if;
  insert into public.sync_operations(operation_key, user_id, store_id) values (p_operation_key, v_user, p_store_id) on conflict do nothing;
  if not found then
    select id into v_invitation from public.invitations where store_id = p_store_id and email = lower(btrim(p_email)) and status = 'pending' order by created_at desc limit 1;
    return jsonb_build_object('duplicate', true, 'invitation_id', v_invitation);
  end if;
  select id into v_member_user from public.profiles where lower(email) = lower(btrim(p_email));
  if v_member_user is not null then
    insert into public.store_members(store_id, user_id, role, is_active, invited_by) values (p_store_id, v_member_user, p_role, true, v_user)
    on conflict (store_id, user_id) do update set role = excluded.role, is_active = true, invited_by = excluded.invited_by;
    perform public.record_activity(p_activity);
    return jsonb_build_object('membership_created', true, 'user_id', v_member_user);
  end if;
  insert into public.invitations(store_id, email, role, status, token_hash, expires_at, invited_by) values (p_store_id, lower(btrim(p_email)), p_role, 'pending', encode(digest(gen_random_uuid()::text, 'sha256'), 'hex'), timezone('utc', now()) + interval '7 days', v_user) returning id into v_invitation;
  perform public.record_activity(p_activity);
  return jsonb_build_object('invitation_created', true, 'invitation_id', v_invitation);
end;
$$;

create or replace function public.manage_member(p_operation_key uuid, p_member_id uuid, p_role public.store_role, p_is_active boolean, p_remove boolean, p_activity jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_member public.store_members%rowtype;
begin
  select * into v_member from public.store_members where id = p_member_id for update;
  if not found then raise exception 'Member no longer exists'; end if;
  if not public.has_role(v_member.store_id, array['owner']::public.store_role[]) then raise exception 'Owner access is required'; end if;
  if v_member.role = 'owner' then raise exception 'Owner membership cannot be changed'; end if;
  insert into public.sync_operations(operation_key, user_id, store_id) values (p_operation_key, v_user, v_member.store_id) on conflict do nothing;
  if not found then return jsonb_build_object('duplicate', true); end if;
  if p_remove then delete from public.store_members where id = p_member_id; else update public.store_members set role = coalesce(p_role, role), is_active = coalesce(p_is_active, is_active) where id = p_member_id; end if;
  perform public.record_activity(p_activity);
  return jsonb_build_object('member_id', p_member_id);
end;
$$;

create or replace function public.record_stock_session(p_operation_key uuid, p_session jsonb, p_lines jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_store uuid := (p_session ->> 'storeId')::uuid; v_line jsonb; v_item public.inventory_items%rowtype; v_delta numeric; v_allow_negative boolean;
begin
  if jsonb_array_length(p_lines) = 0 then raise exception 'A session requires at least one line'; end if;
  if not public.has_role(v_store, array['staff','manager','owner']::public.store_role[]) then raise exception 'Active membership is required'; end if;
  insert into public.sync_operations(operation_key, user_id, store_id) values (p_operation_key, v_user, v_store) on conflict do nothing;
  if not found then return jsonb_build_object('duplicate', true); end if;
  insert into public.stock_sessions(id, store_id, session_type, performer_id, performer_name, performer_role, total_items, notes, created_at) values ((p_session ->> 'id')::uuid, v_store, (p_session ->> 'sessionType')::public.session_type, (p_session ->> 'performerId')::uuid, p_session ->> 'performerName', (p_session ->> 'performerRole')::public.store_role, (p_session ->> 'totalItems')::integer, nullif(p_session ->> 'notes',''), coalesce(nullif(p_session ->> 'createdAt','')::timestamptz, timezone('utc', now())));
  select allow_negative_stock into v_allow_negative from public.stores where id = v_store;
  for v_line in select value from jsonb_array_elements(p_lines) loop
    select * into v_item from public.inventory_items where id = (v_line ->> 'item_id')::uuid and store_id = v_store for update;
    if not found then raise exception 'A selected item no longer exists'; end if;
    v_delta := (v_line ->> 'quantity')::numeric;
    if v_delta = 0 then raise exception 'Session line quantity cannot be zero'; end if;
    if not v_allow_negative and v_item.quantity + v_delta < 0 then raise exception 'This store does not allow negative stock'; end if;
    update public.inventory_items set quantity = quantity + v_delta, updated_by = v_user where id = v_item.id;
    perform public.record_activity(v_line -> 'activity');
    insert into public.stock_session_items(id, session_id, store_id, item_id, item_name, category, quantity, unit, activity_log_id, created_at)
    values (((v_line -> 'session_item') ->> 'id')::uuid, (p_session ->> 'id')::uuid, v_store, v_item.id, (v_line -> 'session_item') ->> 'itemName', (v_line -> 'session_item') ->> 'category', v_delta, (v_line -> 'session_item') ->> 'unit', ((v_line -> 'session_item') ->> 'activityLogId')::uuid, coalesce(((v_line -> 'session_item') ->> 'createdAt')::timestamptz, timezone('utc', now())));
  end loop;
  return jsonb_build_object('session_id', p_session ->> 'id');
end;
$$;

revoke all on function public.record_activity(jsonb), public.record_generic_activity(uuid, jsonb), public.create_store(uuid, text, uuid, uuid), public.rename_store(uuid, uuid, text), public.upsert_inventory_item(uuid, jsonb, jsonb), public.upsert_category(uuid, jsonb, jsonb), public.apply_stock_delta(uuid, uuid, numeric, jsonb), public.correct_stock(uuid, uuid, numeric, jsonb), public.delete_category(uuid, uuid, uuid, uuid, jsonb), public.delete_inventory_item(uuid, uuid, jsonb), public.invite_member(uuid, uuid, text, text, public.store_role, jsonb), public.manage_member(uuid, uuid, public.store_role, boolean, boolean, jsonb), public.record_stock_session(uuid, jsonb, jsonb) from public;
grant execute on function public.record_generic_activity(uuid, jsonb), public.create_store(uuid, text, uuid, uuid), public.rename_store(uuid, uuid, text), public.upsert_inventory_item(uuid, jsonb, jsonb), public.upsert_category(uuid, jsonb, jsonb), public.apply_stock_delta(uuid, uuid, numeric, jsonb), public.correct_stock(uuid, uuid, numeric, jsonb), public.delete_category(uuid, uuid, uuid, uuid, jsonb), public.delete_inventory_item(uuid, uuid, jsonb), public.invite_member(uuid, uuid, text, text, public.store_role, jsonb), public.manage_member(uuid, uuid, public.store_role, boolean, boolean, jsonb), public.record_stock_session(uuid, jsonb, jsonb) to authenticated;
