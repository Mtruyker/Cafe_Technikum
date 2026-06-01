alter table public.orders
  add column if not exists customer_first_name text not null default '';

alter table public.orders
  add column if not exists customer_last_name text not null default '';

drop function if exists public.create_order(jsonb, text, text);

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

create or replace function public.create_order(
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

revoke all on function public.create_order(jsonb, text, text, text, text) from public;
grant execute on function public.create_order(jsonb, text, text, text, text) to anon, authenticated;
