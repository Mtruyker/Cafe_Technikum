create extension if not exists pgcrypto;

create table if not exists public.meta (
  key text primary key,
  value text not null
);

create table if not exists public.categories (
  id text primary key,
  name text not null,
  sort integer not null
);

create table if not exists public.products (
  id text primary key,
  category_id text not null references public.categories(id) on delete restrict,
  name text not null,
  description text not null default '',
  price numeric(12, 2) not null,
  image_url text not null default '',
  is_available boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.modifier_groups (
  id text primary key,
  product_id text not null references public.products(id) on delete cascade,
  name text not null,
  min_val integer not null default 0,
  max_val integer not null default 1,
  position integer not null default 0
);

create table if not exists public.modifier_items (
  id text primary key,
  group_id text not null references public.modifier_groups(id) on delete cascade,
  name text not null,
  price_delta numeric(12, 2) not null default 0,
  position integer not null default 0
);

create table if not exists public.staff_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text unique not null,
  display_name text not null,
  role text not null check (role in ('cashier', 'barista', 'admin')),
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.orders (
  id text primary key,
  order_number text unique not null,
  created_at timestamptz not null default timezone('utc', now()),
  status text not null check (
    status in ('created', 'accepted', 'cooking', 'ready', 'issued', 'canceled')
  ),
  total numeric(12, 2) not null default 0,
  comment text,
  payment_method text not null check (
    payment_method in ('pay_on_pickup', 'online_card')
  ),
  payment_status text not null check (
    payment_status in ('unpaid', 'pending', 'paid', 'failed')
  ),
  provider_payment_id text,
  paid_at timestamptz
);

create table if not exists public.order_items (
  id text primary key,
  order_id text not null references public.orders(id) on delete cascade,
  product_id text not null,
  name_snapshot text not null,
  price_snapshot numeric(12, 2) not null,
  qty integer not null check (qty > 0)
);

create table if not exists public.order_item_modifiers (
  id bigint generated always as identity primary key,
  order_item_id text not null references public.order_items(id) on delete cascade,
  name_snapshot text not null,
  price_delta_snapshot numeric(12, 2) not null default 0
);

create table if not exists public.payments (
  id text primary key,
  order_id text not null unique references public.orders(id) on delete cascade,
  amount numeric(12, 2) not null,
  status text not null check (status in ('created', 'succeeded', 'failed')),
  checkout_url text not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_products_category on public.products(category_id);
create index if not exists idx_products_available on public.products(is_available);
create index if not exists idx_modifier_groups_product on public.modifier_groups(product_id, position);
create index if not exists idx_modifier_items_group on public.modifier_items(group_id, position);
create index if not exists idx_orders_created_at on public.orders(created_at desc);
create index if not exists idx_orders_status_created_at on public.orders(status, created_at desc);
create index if not exists idx_order_items_order on public.order_items(order_id);
create index if not exists idx_order_item_modifiers_item on public.order_item_modifiers(order_item_id);

insert into public.meta (key, value)
values ('order_counter', '100')
on conflict (key) do nothing;

alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.modifier_groups enable row level security;
alter table public.modifier_items enable row level security;
alter table public.staff_profiles enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.order_item_modifiers enable row level security;
alter table public.payments enable row level security;
alter table public.meta enable row level security;

alter table public.categories force row level security;
alter table public.products force row level security;
alter table public.modifier_groups force row level security;
alter table public.modifier_items force row level security;
alter table public.staff_profiles force row level security;
alter table public.orders force row level security;
alter table public.order_items force row level security;
alter table public.order_item_modifiers force row level security;
alter table public.payments force row level security;
alter table public.meta force row level security;

create policy "staff can read own profile"
on public.staff_profiles
for select
to authenticated
using (auth.uid() = id);

grant select on public.staff_profiles to authenticated;

create or replace function public.handle_staff_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.staff_profiles (id, email, display_name, role)
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
      split_part(coalesce(new.email, 'staff@techcafe.local'), '@', 1)
    ),
    coalesce(nullif(trim(new.raw_app_meta_data ->> 'role'), ''), 'cashier')
  )
  on conflict (id) do update
  set
    email = excluded.email,
    display_name = excluded.display_name;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row
execute procedure public.handle_staff_user();

create or replace function public.assign_staff_role_by_email(
  p_email text,
  p_display_name text,
  p_role text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
begin
  if p_role not in ('cashier', 'barista', 'admin') then
    raise exception 'Недопустимая роль сотрудника.';
  end if;

  select id
  into v_user_id
  from auth.users
  where email = p_email;

  if v_user_id is null then
    raise exception 'Пользователь auth.users с таким email не найден.';
  end if;

  insert into public.staff_profiles (id, email, display_name, role)
  values (v_user_id, p_email, p_display_name, p_role)
  on conflict (id) do update
  set
    email = excluded.email,
    display_name = excluded.display_name,
    role = excluded.role;
end;
$$;

create or replace function public.current_staff_role()
returns text
language sql
stable
as $$
  select role
  from public.staff_profiles
  where id = auth.uid()
$$;

create or replace function public.require_staff_role(allowed_roles text[])
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text;
begin
  if auth.uid() is null then
    raise exception 'Требуется вход сотрудника.';
  end if;

  select public.current_staff_role()
  into v_role;

  if v_role is null then
    raise exception 'Для аккаунта не назначена роль сотрудника.';
  end if;

  if not (v_role = any(allowed_roles)) then
    raise exception 'Недостаточно прав для выполнения операции.';
  end if;
end;
$$;

create or replace function public.make_product_json(p_product_id text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'id', p.id,
    'categoryId', p.category_id,
    'name', p.name,
    'description', p.description,
    'price', p.price,
    'imageUrl', p.image_url,
    'isAvailable', p.is_available,
    'modifierGroups',
      coalesce(
        (
          select jsonb_agg(
            jsonb_build_object(
              'id', mg.id,
              'name', mg.name,
              'min', mg.min_val,
              'max', mg.max_val,
              'items',
                coalesce(
                  (
                    select jsonb_agg(
                      jsonb_build_object(
                        'id', mi.id,
                        'name', mi.name,
                        'priceDelta', mi.price_delta
                      )
                      order by mi.position, mi.name
                    )
                    from public.modifier_items mi
                    where mi.group_id = mg.id
                  ),
                  '[]'::jsonb
                )
            )
            order by mg.position, mg.name
          )
          from public.modifier_groups mg
          where mg.product_id = p.id
        ),
        '[]'::jsonb
      )
  )
  from public.products p
  where p.id = p_product_id
$$;

create or replace function public.make_payment_json(p_payment_id text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'id', p.id,
    'orderId', p.order_id,
    'amount', p.amount,
    'status', p.status,
    'checkoutUrl', p.checkout_url,
    'createdAt', p.created_at,
    'updatedAt', p.updated_at
  )
  from public.payments p
  where p.id = p_payment_id
$$;

create or replace function public.make_order_created_json(p_order_id text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'orderId', o.id,
    'orderNumber', o.order_number,
    'qrCodeData', o.id,
    'status', o.status,
    'total', o.total,
    'createdAt', o.created_at,
    'paymentMethod', o.payment_method,
    'paymentStatus', o.payment_status,
    'providerPaymentId', o.provider_payment_id,
    'paidAt', o.paid_at
  )
  from public.orders o
  where o.id = p_order_id
$$;

create or replace function public.make_order_json(p_order_id text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'id', o.id,
    'orderNumber', o.order_number,
    'createdAt', o.created_at,
    'status', o.status,
    'total', o.total,
    'comment', o.comment,
    'paymentMethod', o.payment_method,
    'paymentStatus', o.payment_status,
    'providerPaymentId', o.provider_payment_id,
    'paidAt', o.paid_at,
    'items',
      coalesce(
        (
          select jsonb_agg(
            jsonb_build_object(
              'id', oi.id,
              'productId', oi.product_id,
              'nameSnapshot', oi.name_snapshot,
              'priceSnapshot', oi.price_snapshot,
              'qty', oi.qty,
              'lineTotal',
                (
                  oi.price_snapshot
                  + coalesce(
                    (
                      select sum(oim.price_delta_snapshot)
                      from public.order_item_modifiers oim
                      where oim.order_item_id = oi.id
                    ),
                    0
                  )
                ) * oi.qty,
              'modifiers',
                coalesce(
                  (
                    select jsonb_agg(
                      jsonb_build_object(
                        'nameSnapshot', oim.name_snapshot,
                        'priceDeltaSnapshot', oim.price_delta_snapshot
                      )
                      order by oim.id
                    )
                    from public.order_item_modifiers oim
                    where oim.order_item_id = oi.id
                  ),
                  '[]'::jsonb
                )
            )
            order by oi.id
          )
          from public.order_items oi
          where oi.order_id = o.id
        ),
        '[]'::jsonb
      )
  )
  from public.orders o
  where o.id = p_order_id
$$;

create or replace function public.list_categories()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', c.id,
        'name', c.name,
        'sort', c.sort
      )
      order by c.sort
    ),
    '[]'::jsonb
  )
  from public.categories c
$$;

create or replace function public.list_products(
  p_category_id text default null,
  p_in_stock boolean default false,
  p_page integer default null,
  p_limit integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_total integer;
  v_items jsonb;
  v_safe_page integer;
  v_safe_limit integer;
begin
  if p_page is null or p_limit is null then
    select coalesce(
      jsonb_agg(public.make_product_json(src.id) order by src.name),
      '[]'::jsonb
    )
    into v_items
    from (
      select p.id, p.name
      from public.products p
      where (p_category_id is null or p.category_id = p_category_id)
        and (not p_in_stock or p.is_available)
      order by p.name
    ) src;

    return v_items;
  end if;

  v_safe_page := greatest(p_page, 1);
  v_safe_limit := greatest(p_limit, 1);

  select count(*)
  into v_total
  from public.products p
  where (p_category_id is null or p.category_id = p_category_id)
    and (not p_in_stock or p.is_available);

  select coalesce(
    jsonb_agg(public.make_product_json(src.id) order by src.name),
    '[]'::jsonb
  )
  into v_items
  from (
    select p.id, p.name
    from public.products p
    where (p_category_id is null or p.category_id = p_category_id)
      and (not p_in_stock or p.is_available)
    order by p.name
    limit v_safe_limit
    offset (v_safe_page - 1) * v_safe_limit
  ) src;

  return jsonb_build_object(
    'items', v_items,
    'total', v_total,
    'page', v_safe_page,
    'limit', v_safe_limit,
    'hasMore', (v_safe_page * v_safe_limit) < v_total
  );
end;
$$;

create or replace function public.next_order_number()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current integer;
  v_next integer;
begin
  insert into public.meta (key, value)
  values ('order_counter', '100')
  on conflict (key) do nothing;

  select value::integer
  into v_current
  from public.meta
  where key = 'order_counter'
  for update;

  v_next := v_current + 1;

  update public.meta
  set value = v_next::text
  where key = 'order_counter';

  return 'A-' || v_next::text;
end;
$$;

create or replace function public.create_order(
  p_items jsonb,
  p_comment text default null,
  p_payment_method text default 'pay_on_pickup'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_now timestamptz := timezone('utc', now());
  v_order_id text := gen_random_uuid()::text;
  v_order_number text;
  v_total numeric(12, 2) := 0;
  v_item jsonb;
  v_modifier jsonb;
  v_product public.products%rowtype;
  v_item_id text;
  v_product_id text;
  v_qty integer;
  v_modifier_name text;
  v_modifier_delta numeric(12, 2);
  v_line_unit_price numeric(12, 2);
begin
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'Позиции заказа обязательны.';
  end if;

  if p_payment_method not in ('pay_on_pickup', 'online_card') then
    p_payment_method := 'pay_on_pickup';
  end if;

  v_order_number := public.next_order_number();

  insert into public.orders (
    id,
    order_number,
    created_at,
    status,
    total,
    comment,
    payment_method,
    payment_status,
    provider_payment_id,
    paid_at
  )
  values (
    v_order_id,
    v_order_number,
    v_now,
    'created',
    0,
    nullif(trim(coalesce(p_comment, '')), ''),
    p_payment_method,
    case
      when p_payment_method = 'online_card' then 'pending'
      else 'unpaid'
    end,
    null,
    null
  );

  for v_item in
    select value
    from jsonb_array_elements(p_items)
  loop
    v_product_id := nullif(trim(v_item ->> 'productId'), '');
    v_qty := coalesce(nullif(v_item ->> 'qty', '')::integer, 0);

    if v_product_id is null then
      raise exception 'Каждая позиция заказа должна содержать productId.';
    end if;

    if v_qty <= 0 then
      raise exception 'Количество товара должно быть больше 0.';
    end if;

    select *
    into v_product
    from public.products
    where id = v_product_id;

    if not found then
      raise exception 'Товар "%" не найден.', v_product_id;
    end if;

    if not v_product.is_available then
      raise exception 'Товар "%" недоступен.', v_product.name;
    end if;

    v_item_id := gen_random_uuid()::text;
    v_line_unit_price := v_product.price;

    insert into public.order_items (
      id,
      order_id,
      product_id,
      name_snapshot,
      price_snapshot,
      qty
    )
    values (
      v_item_id,
      v_order_id,
      v_product.id,
      v_product.name,
      v_product.price,
      v_qty
    );

    if v_item ? 'modifiers' and jsonb_typeof(v_item -> 'modifiers') <> 'array' then
      raise exception 'Некорректный формат модификаторов.';
    end if;

    for v_modifier in
      select value
      from jsonb_array_elements(coalesce(v_item -> 'modifiers', '[]'::jsonb))
    loop
      v_modifier_name := nullif(trim(v_modifier ->> 'name'), '');
      v_modifier_delta := coalesce(
        nullif(v_modifier ->> 'priceDelta', '')::numeric(12, 2),
        0
      );

      if v_modifier_name is null then
        raise exception 'Каждый модификатор должен содержать name.';
      end if;

      insert into public.order_item_modifiers (
        order_item_id,
        name_snapshot,
        price_delta_snapshot
      )
      values (v_item_id, v_modifier_name, v_modifier_delta);

      v_line_unit_price := v_line_unit_price + v_modifier_delta;
    end loop;

    v_total := v_total + (v_line_unit_price * v_qty);
  end loop;

  update public.orders
  set total = v_total
  where id = v_order_id;

  return public.make_order_created_json(v_order_id);
end;
$$;

create or replace function public.get_order_by_key(p_key text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order_id text;
begin
  select o.id
  into v_order_id
  from public.orders o
  where o.id = p_key or o.order_number = p_key
  order by o.created_at desc
  limit 1;

  if v_order_id is null then
    raise exception 'Заказ не найден.';
  end if;

  return public.make_order_json(v_order_id);
end;
$$;

create or replace function public.list_staff_orders(
  p_status text default null,
  p_page integer default 1,
  p_limit integer default 20
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_total integer;
  v_items jsonb;
  v_safe_page integer := greatest(coalesce(p_page, 1), 1);
  v_safe_limit integer := greatest(coalesce(p_limit, 20), 1);
begin
  perform public.require_staff_role(array['cashier', 'barista', 'admin']);

  select count(*)
  into v_total
  from public.orders o
  where (p_status is null or p_status = '' or o.status = p_status);

  select coalesce(
    jsonb_agg(public.make_order_json(src.id) order by src.created_at desc),
    '[]'::jsonb
  )
  into v_items
  from (
    select o.id, o.created_at
    from public.orders o
    where (p_status is null or p_status = '' or o.status = p_status)
    order by o.created_at desc
    limit v_safe_limit
    offset (v_safe_page - 1) * v_safe_limit
  ) src;

  return jsonb_build_object(
    'items', v_items,
    'total', v_total,
    'page', v_safe_page,
    'limit', v_safe_limit,
    'hasMore', (v_safe_page * v_safe_limit) < v_total
  );
end;
$$;

create or replace function public.update_order_status(
  p_order_id text,
  p_status text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order_id text;
begin
  perform public.require_staff_role(array['cashier', 'barista', 'admin']);

  if p_status not in ('created', 'accepted', 'cooking', 'ready', 'issued', 'canceled') then
    raise exception 'Некорректный статус заказа.';
  end if;

  update public.orders
  set status = p_status
  where id = p_order_id
  returning id into v_order_id;

  if v_order_id is null then
    raise exception 'Заказ не найден.';
  end if;

  return public.make_order_json(v_order_id);
end;
$$;

create or replace function public.upsert_product(p_product jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_product_id text := coalesce(nullif(trim(p_product ->> 'id'), ''), gen_random_uuid()::text);
  v_category_id text := nullif(trim(p_product ->> 'categoryId'), '');
  v_name text := nullif(trim(p_product ->> 'name'), '');
  v_description text := coalesce(p_product ->> 'description', '');
  v_image_url text := coalesce(p_product ->> 'imageUrl', '');
  v_price numeric(12, 2) := coalesce(nullif(p_product ->> 'price', '')::numeric(12, 2), 0);
  v_is_available boolean := coalesce((p_product ->> 'isAvailable')::boolean, true);
  v_group jsonb;
  v_item jsonb;
  v_group_id text;
  v_item_id text;
  v_group_name text;
  v_item_name text;
  v_group_min integer;
  v_group_max integer;
  v_item_price_delta numeric(12, 2);
  v_group_index integer := 0;
  v_item_index integer;
begin
  perform public.require_staff_role(array['admin']);

  if v_category_id is null or v_name is null or v_price <= 0 then
    raise exception 'categoryId, name и price обязательны.';
  end if;

  insert into public.products (
    id,
    category_id,
    name,
    description,
    price,
    image_url,
    is_available,
    updated_at
  )
  values (
    v_product_id,
    v_category_id,
    v_name,
    v_description,
    v_price,
    v_image_url,
    v_is_available,
    timezone('utc', now())
  )
  on conflict (id) do update
  set
    category_id = excluded.category_id,
    name = excluded.name,
    description = excluded.description,
    price = excluded.price,
    image_url = excluded.image_url,
    is_available = excluded.is_available,
    updated_at = excluded.updated_at;

  delete from public.modifier_groups
  where product_id = v_product_id;

  if p_product ? 'modifierGroups' and jsonb_typeof(p_product -> 'modifierGroups') <> 'array' then
    raise exception 'modifierGroups должен быть массивом.';
  end if;

  for v_group in
    select value
    from jsonb_array_elements(coalesce(p_product -> 'modifierGroups', '[]'::jsonb))
  loop
    v_group_id := coalesce(nullif(trim(v_group ->> 'id'), ''), gen_random_uuid()::text);
    v_group_name := nullif(trim(v_group ->> 'name'), '');
    v_group_min := coalesce(nullif(v_group ->> 'min', '')::integer, 0);
    v_group_max := coalesce(nullif(v_group ->> 'max', '')::integer, 1);
    v_item_index := 0;

    if v_group_name is null then
      raise exception 'У группы модификаторов должно быть имя.';
    end if;

    insert into public.modifier_groups (
      id,
      product_id,
      name,
      min_val,
      max_val,
      position
    )
    values (
      v_group_id,
      v_product_id,
      v_group_name,
      v_group_min,
      v_group_max,
      v_group_index
    );

    if v_group ? 'items' and jsonb_typeof(v_group -> 'items') <> 'array' then
      raise exception 'items внутри modifierGroups должен быть массивом.';
    end if;

    for v_item in
      select value
      from jsonb_array_elements(coalesce(v_group -> 'items', '[]'::jsonb))
    loop
      v_item_id := coalesce(nullif(trim(v_item ->> 'id'), ''), gen_random_uuid()::text);
      v_item_name := nullif(trim(v_item ->> 'name'), '');
      v_item_price_delta := coalesce(
        nullif(v_item ->> 'priceDelta', '')::numeric(12, 2),
        0
      );

      if v_item_name is null then
        raise exception 'У модификатора должно быть имя.';
      end if;

      insert into public.modifier_items (
        id,
        group_id,
        name,
        price_delta,
        position
      )
      values (
        v_item_id,
        v_group_id,
        v_item_name,
        v_item_price_delta,
        v_item_index
      );

      v_item_index := v_item_index + 1;
    end loop;

    v_group_index := v_group_index + 1;
  end loop;

  return public.make_product_json(v_product_id);
end;
$$;

create or replace function public.set_product_availability(
  p_product_id text,
  p_is_available boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_product_id text;
begin
  perform public.require_staff_role(array['admin']);

  update public.products
  set
    is_available = p_is_available,
    updated_at = timezone('utc', now())
  where id = p_product_id
  returning id into v_product_id;

  if v_product_id is null then
    raise exception 'Товар не найден.';
  end if;

  return public.make_product_json(v_product_id);
end;
$$;

create or replace function public.create_payment_session(p_order_id text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders%rowtype;
  v_payment public.payments%rowtype;
  v_now timestamptz := timezone('utc', now());
begin
  select *
  into v_order
  from public.orders
  where id = p_order_id;

  if not found then
    raise exception 'Заказ не найден.';
  end if;

  if v_order.payment_method <> 'online_card' then
    raise exception 'Онлайн-оплата недоступна для этого заказа.';
  end if;

  select *
  into v_payment
  from public.payments
  where order_id = p_order_id
  limit 1;

  if found then
    return public.make_payment_json(v_payment.id);
  end if;

  insert into public.payments (
    id,
    order_id,
    amount,
    status,
    checkout_url,
    created_at,
    updated_at
  )
  values (
    gen_random_uuid()::text,
    v_order.id,
    v_order.total,
    'created',
    'https://pay.techcafe.local/session/' || gen_random_uuid()::text,
    v_now,
    v_now
  )
  returning * into v_payment;

  update public.orders
  set provider_payment_id = v_payment.id
  where id = v_order.id;

  return public.make_payment_json(v_payment.id);
end;
$$;

create or replace function public.confirm_payment_session(
  p_payment_id text,
  p_success boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_payment public.payments%rowtype;
  v_order public.orders%rowtype;
  v_now timestamptz := timezone('utc', now());
  v_status text;
begin
  select *
  into v_payment
  from public.payments
  where id = p_payment_id;

  if not found then
    raise exception 'Платежная сессия не найдена.';
  end if;

  select *
  into v_order
  from public.orders
  where id = v_payment.order_id;

  if not found then
    raise exception 'Заказ не найден.';
  end if;

  if v_payment.status in ('succeeded', 'failed') then
    return jsonb_build_object(
      'payment', public.make_payment_json(v_payment.id),
      'order', public.make_order_json(v_order.id)
    );
  end if;

  v_status := case when p_success then 'succeeded' else 'failed' end;

  update public.payments
  set
    status = v_status,
    updated_at = v_now
  where id = v_payment.id;

  update public.orders
  set
    payment_status = case when p_success then 'paid' else 'failed' end,
    paid_at = case when p_success then v_now else null end,
    provider_payment_id = v_payment.id
  where id = v_order.id;

  return jsonb_build_object(
    'payment', public.make_payment_json(v_payment.id),
    'order', public.make_order_json(v_order.id)
  );
end;
$$;

create or replace function public.get_sales_report(
  p_from timestamptz default null,
  p_to timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_orders_count integer := 0;
  v_non_canceled_count integer := 0;
  v_items_sold integer := 0;
  v_total_revenue numeric(12, 2) := 0;
  v_by_status jsonb := '{}'::jsonb;
  v_orders_by_day jsonb := '{}'::jsonb;
  v_revenue_by_day jsonb := '{}'::jsonb;
begin
  perform public.require_staff_role(array['admin']);

  select count(*)
  into v_orders_count
  from public.orders o
  where (p_from is null or o.created_at >= p_from)
    and (p_to is null or o.created_at <= p_to);

  select count(*)
  into v_non_canceled_count
  from public.orders o
  where (p_from is null or o.created_at >= p_from)
    and (p_to is null or o.created_at <= p_to)
    and o.status <> 'canceled';

  select coalesce(sum(oi.qty), 0)
  into v_items_sold
  from public.orders o
  join public.order_items oi on oi.order_id = o.id
  where (p_from is null or o.created_at >= p_from)
    and (p_to is null or o.created_at <= p_to)
    and o.status <> 'canceled';

  select coalesce(sum(o.total), 0)
  into v_total_revenue
  from public.orders o
  where (p_from is null or o.created_at >= p_from)
    and (p_to is null or o.created_at <= p_to)
    and o.status <> 'canceled';

  select coalesce(jsonb_object_agg(src.status, src.cnt), '{}'::jsonb)
  into v_by_status
  from (
    select o.status, count(*)::integer as cnt
    from public.orders o
    where (p_from is null or o.created_at >= p_from)
      and (p_to is null or o.created_at <= p_to)
    group by o.status
  ) src;

  if p_from is not null and p_to is not null then
    select coalesce(jsonb_object_agg(src.day_key, src.cnt), '{}'::jsonb)
    into v_orders_by_day
    from (
      select
        to_char(day_ref.day_value, 'YYYY-MM-DD') as day_key,
        coalesce(day_orders.cnt, 0) as cnt
      from generate_series(
        (p_from at time zone 'utc')::date,
        ((p_to - interval '1 millisecond') at time zone 'utc')::date,
        interval '1 day'
      ) as day_ref(day_value)
      left join (
        select
          (o.created_at at time zone 'utc')::date as day_value,
          count(*)::integer as cnt
        from public.orders o
        where o.created_at >= p_from
          and o.created_at <= p_to
        group by (o.created_at at time zone 'utc')::date
      ) day_orders on day_orders.day_value = day_ref.day_value
    ) src;

    select coalesce(jsonb_object_agg(src.day_key, src.revenue), '{}'::jsonb)
    into v_revenue_by_day
    from (
      select
        to_char(day_ref.day_value, 'YYYY-MM-DD') as day_key,
        coalesce(day_revenue.revenue, 0) as revenue
      from generate_series(
        (p_from at time zone 'utc')::date,
        ((p_to - interval '1 millisecond') at time zone 'utc')::date,
        interval '1 day'
      ) as day_ref(day_value)
      left join (
        select
          (o.created_at at time zone 'utc')::date as day_value,
          sum(o.total)::numeric(12, 2) as revenue
        from public.orders o
        where o.created_at >= p_from
          and o.created_at <= p_to
          and o.status <> 'canceled'
        group by (o.created_at at time zone 'utc')::date
      ) day_revenue on day_revenue.day_value = day_ref.day_value
    ) src;
  else
    select coalesce(jsonb_object_agg(src.day_key, src.cnt), '{}'::jsonb)
    into v_orders_by_day
    from (
      select
        to_char((o.created_at at time zone 'utc')::date, 'YYYY-MM-DD') as day_key,
        count(*)::integer as cnt
      from public.orders o
      where (p_from is null or o.created_at >= p_from)
        and (p_to is null or o.created_at <= p_to)
      group by (o.created_at at time zone 'utc')::date
      order by (o.created_at at time zone 'utc')::date
    ) src;

    select coalesce(jsonb_object_agg(src.day_key, src.revenue), '{}'::jsonb)
    into v_revenue_by_day
    from (
      select
        to_char((o.created_at at time zone 'utc')::date, 'YYYY-MM-DD') as day_key,
        sum(o.total)::numeric(12, 2) as revenue
      from public.orders o
      where (p_from is null or o.created_at >= p_from)
        and (p_to is null or o.created_at <= p_to)
        and o.status <> 'canceled'
      group by (o.created_at at time zone 'utc')::date
      order by (o.created_at at time zone 'utc')::date
    ) src;
  end if;

  return jsonb_build_object(
    'from', p_from,
    'to', p_to,
    'ordersCount', v_orders_count,
    'nonCanceledOrdersCount', v_non_canceled_count,
    'itemsSold', v_items_sold,
    'totalRevenue', v_total_revenue,
    'byStatus', v_by_status,
    'ordersByDay', v_orders_by_day,
    'revenueByDay', v_revenue_by_day
  );
end;
$$;

revoke all on function public.handle_staff_user() from public;
revoke all on function public.assign_staff_role_by_email(text, text, text) from public;
revoke all on function public.current_staff_role() from public;
revoke all on function public.require_staff_role(text[]) from public;
revoke all on function public.make_product_json(text) from public;
revoke all on function public.make_payment_json(text) from public;
revoke all on function public.make_order_created_json(text) from public;
revoke all on function public.make_order_json(text) from public;
revoke all on function public.next_order_number() from public;

revoke all on function public.list_categories() from public;
grant execute on function public.list_categories() to anon, authenticated;

revoke all on function public.list_products(text, boolean, integer, integer) from public;
grant execute on function public.list_products(text, boolean, integer, integer) to anon, authenticated;

revoke all on function public.create_order(jsonb, text, text) from public;
grant execute on function public.create_order(jsonb, text, text) to anon, authenticated;

revoke all on function public.get_order_by_key(text) from public;
grant execute on function public.get_order_by_key(text) to anon, authenticated;

revoke all on function public.create_payment_session(text) from public;
grant execute on function public.create_payment_session(text) to anon, authenticated;

revoke all on function public.confirm_payment_session(text, boolean) from public;
grant execute on function public.confirm_payment_session(text, boolean) to anon, authenticated;

revoke all on function public.list_staff_orders(text, integer, integer) from public;
grant execute on function public.list_staff_orders(text, integer, integer) to authenticated;

revoke all on function public.update_order_status(text, text) from public;
grant execute on function public.update_order_status(text, text) to authenticated;

revoke all on function public.upsert_product(jsonb) from public;
grant execute on function public.upsert_product(jsonb) to authenticated;

revoke all on function public.set_product_availability(text, boolean) from public;
grant execute on function public.set_product_availability(text, boolean) to authenticated;

revoke all on function public.get_sales_report(timestamptz, timestamptz) from public;
grant execute on function public.get_sales_report(timestamptz, timestamptz) to authenticated;
