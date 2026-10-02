-- Apply after BOTH 202604160003 migrations. All writes are transactional.
begin;
create table public.pickup_slots (
  id uuid primary key default gen_random_uuid(),
  starts_at timestamptz not null unique,
  cutoff_at timestamptz not null,
  capacity integer not null check (capacity > 0),
  reserved integer not null default 0 check (reserved >= 0 and reserved <= capacity),
  enabled boolean not null default true,
  check (cutoff_at <= starts_at)
);
alter table public.pickup_slots enable row level security;
revoke all on public.pickup_slots from anon, authenticated;
alter table public.products add column stock_remaining integer check (stock_remaining >= 0);
alter table public.orders add column pickup_slot_id uuid references public.pickup_slots(id);
alter table public.orders add column pickup_token uuid not null default gen_random_uuid();
alter table public.orders add column reserved_portions integer not null default 0;
alter table public.order_items add column stock_reserved boolean not null default false;
create unique index orders_pickup_token_idx on public.orders(pickup_token);
create index orders_pickup_slot_idx on public.orders(pickup_slot_id);

create or replace function public.list_pickup_slots(p_admin boolean default false)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if p_admin then perform public.require_staff_role(array['admin']); end if;
  return (select coalesce(jsonb_agg(jsonb_build_object(
    'id', id, 'startsAt', starts_at, 'cutoffAt', cutoff_at,
    'capacity', capacity, 'remaining', capacity - reserved, 'enabled', enabled
  ) order by starts_at), '[]'::jsonb) from public.pickup_slots
  where starts_at > now() and (p_admin or (enabled and cutoff_at > now())));
end $$;

create or replace function public.save_pickup_slot(
  p_starts_at timestamptz, p_cutoff_at timestamptz, p_capacity integer,
  p_enabled boolean default true, p_id uuid default null
) returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.require_staff_role(array['admin']);
  if p_starts_at <= now() or p_cutoff_at > p_starts_at or p_capacity < 1 then
    raise exception 'Проверьте время и вместимость слота.';
  end if;
  if p_id is null then
    insert into public.pickup_slots(starts_at, cutoff_at, capacity, enabled)
    values (p_starts_at, p_cutoff_at, p_capacity, p_enabled);
  else
    -- Booked pickup times are immutable: customers already have a promise.
    update public.pickup_slots set capacity = p_capacity, enabled = p_enabled,
      cutoff_at = p_cutoff_at, starts_at = p_starts_at
    where id = p_id and reserved <= p_capacity
      and (reserved = 0 or starts_at = p_starts_at);
    if not found then raise exception 'Нельзя изменить время занятого слота или уменьшить лимит ниже резерва.'; end if;
  end if;
end $$;

create or replace function public.set_product_stock(p_product_id text, p_remaining integer)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.require_staff_role(array['admin']);
  if p_remaining < 0 then raise exception 'Остаток не может быть отрицательным.'; end if;
  update public.products set stock_remaining = p_remaining where id = p_product_id;
  if not found then raise exception 'Товар не найден.'; end if;
end $$;

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
    'stockRemaining', p.stock_remaining,
    'isEnabled', p.is_available,
    'isAvailable', p.is_available and (p.stock_remaining is null or p.stock_remaining > 0),
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
        and (not p_in_stock or (p.is_available and (p.stock_remaining is null or p.stock_remaining > 0)))
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
    and (not p_in_stock or (p.is_available and (p.stock_remaining is null or p.stock_remaining > 0)));

  select coalesce(
    jsonb_agg(public.make_product_json(src.id) order by src.name),
    '[]'::jsonb
  )
  into v_items
  from (
    select p.id, p.name
    from public.products p
    where (p_category_id is null or p.category_id = p_category_id)
      and (not p_in_stock or (p.is_available and (p.stock_remaining is null or p.stock_remaining > 0)))
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
    'qrCodeData', 'techcafe:pickup:' || o.pickup_token::text,
    'pickupAt', (select starts_at from public.pickup_slots where id = o.pickup_slot_id),
    'customerFirstName', o.customer_first_name,
    'customerLastName', o.customer_last_name,
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
    'pickupAt', (select starts_at from public.pickup_slots where id = o.pickup_slot_id),
    'orderNumber', o.order_number,
    'createdAt', o.created_at,
    'customerFirstName', o.customer_first_name,
    'customerLastName', o.customer_last_name,
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
create or replace function public.create_order_core(
  p_items jsonb,
  p_comment text default null,
  p_payment_method text default 'pay_on_pickup',
  p_customer_first_name text default null,
  p_customer_last_name text default null
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
  v_customer_first_name text := nullif(trim(coalesce(p_customer_first_name, '')), '');
  v_customer_last_name text := nullif(trim(coalesce(p_customer_last_name, '')), '');
begin
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'Позиции заказа обязательны.';
  end if;

  if v_customer_first_name is null then
    raise exception 'Имя клиента обязательно.';
  end if;

  if v_customer_last_name is null then
    raise exception 'Фамилия клиента обязательна.';
  end if;

  if p_payment_method not in ('pay_on_pickup', 'online_card') then
    p_payment_method := 'pay_on_pickup';
  end if;

  perform 1 from public.products where id in (
    select value ->> 'productId' from jsonb_array_elements(p_items)
  ) order by id for update;
  v_order_number := public.next_order_number();

  insert into public.orders (
    id,
    order_number,
    created_at,
    customer_first_name,
    customer_last_name,
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
    v_customer_first_name,
    v_customer_last_name,
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
-- Reserving stock in a trigger covers every insertion path, including the core.
create or replace function public.reserve_order_item_stock()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_stock integer;
begin
  select stock_remaining into v_stock from public.products where id = new.product_id for update;
  if v_stock is not null then
    if v_stock < new.qty then raise exception 'Недостаточно порций товара. Обновите корзину.'; end if;
    update public.products set stock_remaining = stock_remaining - new.qty where id = new.product_id;
    new.stock_reserved := true;
  end if;
  return new;
end $$;
create trigger reserve_item_stock before insert on public.order_items
for each row execute function public.reserve_order_item_stock();

drop function public.create_order(jsonb, text, text, text, text);
create or replace function public.create_order(
  p_items jsonb, p_comment text default null,
  p_payment_method text default 'pay_on_pickup',
  p_customer_first_name text default null, p_customer_last_name text default null,
  p_pickup_slot_id uuid default null
) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_portions integer; v_result jsonb;
begin
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'Корзина пуста.';
  end if;
  if exists(select 1 from jsonb_array_elements(p_items) where
    coalesce((value ->> 'qty')::integer, 0) <= 0) then raise exception 'Некорректное количество.'; end if;
  select sum((value ->> 'qty')::integer) into v_portions from jsonb_array_elements(p_items);
  if p_pickup_slot_id is null then raise exception 'Выберите время получения.'; end if;
  update public.pickup_slots set reserved = reserved + v_portions
    where id = p_pickup_slot_id and enabled and cutoff_at > now()
      and capacity - reserved >= v_portions;
  if not found then raise exception 'На эту перемену недостаточно мест или приём закрыт. Выберите другой слот.'; end if;
  v_result := public.create_order_core(p_items, p_comment, p_payment_method, p_customer_first_name, p_customer_last_name);
  update public.orders set pickup_slot_id = p_pickup_slot_id, reserved_portions = v_portions
    where id = v_result ->> 'orderId';
  return public.make_order_created_json(v_result ->> 'orderId');
end $$;

create or replace function public.update_order_status(p_order_id text, p_status text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_order public.orders%rowtype; v_item record;
begin
  perform public.require_staff_role(array['cashier', 'barista', 'admin']);
  select * into v_order from public.orders where id = p_order_id for update;
  if not found then raise exception 'Заказ не найден.'; end if;
  if p_status = v_order.status then return public.make_order_json(p_order_id); end if;
  if p_status is null or not (
    (v_order.status = 'created' and p_status in ('accepted', 'canceled')) or
    (v_order.status = 'accepted' and p_status in ('cooking', 'canceled')) or
    (v_order.status = 'cooking' and p_status in ('ready', 'canceled')) or
    (v_order.status = 'ready' and p_status = 'canceled')
  ) then raise exception 'Недопустимый переход статуса. Выдача выполняется по QR-коду.'; end if;
  if p_status = 'canceled' then
    -- Same locking order as create_order: slot first, products sorted by ID.
    update public.pickup_slots set reserved = reserved - v_order.reserved_portions
      where id = v_order.pickup_slot_id;
    for v_item in select product_id, sum(qty)::integer as qty from public.order_items
      where order_id = p_order_id and stock_reserved group by product_id order by product_id
    loop
      update public.products set stock_remaining = stock_remaining + v_item.qty
        where id = v_item.product_id and stock_remaining is not null;
    end loop;
  end if;
  update public.orders set status = p_status where id = p_order_id;
  return public.make_order_json(p_order_id);
end $$;

create or replace function public.inspect_pickup_code(p_code text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_order public.orders%rowtype;
begin
  perform public.require_staff_role(array['cashier', 'admin']);
  select * into v_order from public.orders
    where 'techcafe:pickup:' || pickup_token::text = trim(p_code)
      or (pickup_slot_id is null and id = trim(p_code));
  if not found then raise exception 'Неверный код выдачи.'; end if;
  return public.make_order_json(v_order.id);
end $$;
revoke all on function public.inspect_pickup_code(text) from public, anon, authenticated;
grant execute on function public.inspect_pickup_code(text) to authenticated;

create or replace function public.redeem_pickup_code(p_code text, p_payment_received boolean default false)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_order public.orders%rowtype;
begin
  perform public.require_staff_role(array['cashier', 'admin']);
  select * into v_order from public.orders
    where 'techcafe:pickup:' || pickup_token::text = trim(p_code)
      or (pickup_slot_id is null and id = trim(p_code)) for update;
  if not found then raise exception 'Неверный код выдачи.'; end if;
  if v_order.status = 'issued' then raise exception 'Этот заказ уже выдан.'; end if;
  if v_order.status <> 'ready' then raise exception 'Заказ ещё не готов или отменён.'; end if;
  if v_order.payment_method = 'online_card' and v_order.payment_status <> 'paid' then
    raise exception 'Онлайн-оплата не подтверждена.';
  end if;
  if v_order.payment_status <> 'paid' and not coalesce(p_payment_received, false) then
    raise exception 'Подтвердите получение оплаты на кассе.';
  end if;
  update public.orders set status = 'issued', payment_status = 'paid', paid_at = coalesce(paid_at, now())
    where id = v_order.id;
  return public.make_order_json(v_order.id);
end $$;

revoke all on function public.list_pickup_slots(boolean) from public, anon, authenticated;
revoke all on function public.save_pickup_slot(timestamptz, timestamptz, integer, boolean, uuid) from public, anon, authenticated;
revoke all on function public.set_product_stock(text, integer) from public, anon, authenticated;
revoke all on function public.create_order(jsonb, text, text, text, text, uuid) from public, anon, authenticated;
revoke all on function public.update_order_status(text, text) from public, anon, authenticated;
revoke all on function public.redeem_pickup_code(text, boolean) from public, anon, authenticated;
revoke all on function public.create_order_core(jsonb, text, text, text, text) from public, anon, authenticated;
revoke all on function public.reserve_order_item_stock() from public, anon, authenticated;
revoke all on function public.make_order_created_json(text) from public, anon, authenticated;
grant execute on function public.list_pickup_slots(boolean) to anon, authenticated;
grant execute on function public.save_pickup_slot(timestamptz, timestamptz, integer, boolean, uuid) to authenticated;
grant execute on function public.set_product_stock(text, integer) to authenticated;
grant execute on function public.create_order(jsonb, text, text, text, text, uuid) to anon, authenticated;
grant execute on function public.update_order_status(text, text) to authenticated;
grant execute on function public.redeem_pickup_code(text, boolean) to authenticated;

commit;
