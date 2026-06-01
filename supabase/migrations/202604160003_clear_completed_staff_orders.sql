alter table public.orders
add column if not exists staff_cleared_at timestamptz;

create index if not exists idx_orders_staff_cleared_at
on public.orders(staff_cleared_at, created_at desc);

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
  where (p_status is null or p_status = '' or o.status = p_status)
    and o.staff_cleared_at is null;

  select coalesce(
    jsonb_agg(public.make_order_json(src.id) order by src.created_at desc),
    '[]'::jsonb
  )
  into v_items
  from (
    select o.id, o.created_at
    from public.orders o
    where (p_status is null or p_status = '' or o.status = p_status)
      and o.staff_cleared_at is null
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
  set
    status = p_status,
    staff_cleared_at = case
      when p_status in ('issued', 'canceled') then staff_cleared_at
      else null
    end
  where id = p_order_id
  returning id into v_order_id;

  if v_order_id is null then
    raise exception 'Заказ не найден.';
  end if;

  return public.make_order_json(v_order_id);
end;
$$;

create or replace function public.clear_completed_staff_orders()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cleared_count integer := 0;
begin
  perform public.require_staff_role(array['admin']);

  update public.orders
  set staff_cleared_at = timezone('utc', now())
  where status in ('issued', 'canceled')
    and staff_cleared_at is null;

  get diagnostics v_cleared_count = row_count;
  return v_cleared_count;
end;
$$;

revoke all on function public.clear_completed_staff_orders() from public;
grant execute on function public.clear_completed_staff_orders() to authenticated;
