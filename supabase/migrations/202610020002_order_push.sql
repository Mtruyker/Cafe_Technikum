begin;
create table public.order_push_subscriptions (
  order_id text not null references public.orders(id) on delete cascade,
  token text not null check (length(token) between 20 and 4096),
  primary key(order_id, token)
);
create table public.order_push_outbox (
  id bigint generated always as identity primary key,
  order_id text not null references public.orders(id) on delete cascade,
  token text not null,
  created_at timestamptz not null default now(),
  attempts integer not null default 0,
  available_at timestamptz not null default now(),
  lease_id uuid,
  delivered_at timestamptz,
  last_error text,
  unique(order_id, token)
);
alter table public.order_push_subscriptions enable row level security;
alter table public.order_push_outbox enable row level security;
revoke all on public.order_push_subscriptions, public.order_push_outbox from public, anon, authenticated;

create or replace function public.subscribe_order_push(p_pickup_code text, p_token text)
returns void language plpgsql security definer set search_path = public as $$
declare v_order public.orders%rowtype;
begin
  select * into v_order from public.orders
    where 'techcafe:pickup:' || pickup_token::text = trim(p_pickup_code) for update;
  if not found or v_order.status in ('issued', 'canceled') then raise exception 'Активный заказ не найден.'; end if;
  if p_token is null or length(p_token) not between 20 and 4096 then raise exception 'Некорректный адрес устройства.'; end if;
  if (select count(*) from public.order_push_subscriptions where order_id = v_order.id) >= 5
    and not exists(select 1 from public.order_push_subscriptions where order_id = v_order.id and token = p_token)
    then raise exception 'Достигнут лимит устройств для заказа.'; end if;
  insert into public.order_push_subscriptions(order_id, token) values (v_order.id, p_token) on conflict do nothing;
  if v_order.status = 'ready' then
    insert into public.order_push_outbox(order_id, token) values (v_order.id, p_token) on conflict do nothing;
  end if;
end $$;

create or replace function public.enqueue_order_ready_push()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'ready' and old.status <> 'ready' then
    insert into public.order_push_outbox(order_id, token)
      select new.id, token from public.order_push_subscriptions where order_id = new.id on conflict do nothing;
  end if;
  return new;
end $$;
create trigger enqueue_ready_push after update of status on public.orders
for each row execute function public.enqueue_order_ready_push();

create or replace function public.claim_order_push()
returns table(id bigint, order_id text, token text, lease_id uuid, order_number text)
language sql security definer set search_path = public as $$
  with candidates as (
    select q.id from public.order_push_outbox q join public.orders o on o.id = q.order_id
    where q.delivered_at is null and q.available_at <= now() and q.attempts < 8
      and o.status = 'ready' and q.created_at > now() - interval '1 day'
    order by q.id limit 30 for update of q skip locked
  ), claimed as (
    update public.order_push_outbox q set attempts = attempts + 1,
      available_at = now() + interval '5 minutes', lease_id = gen_random_uuid()
    from candidates c where q.id = c.id
    returning q.id, q.order_id, q.token, q.lease_id
  ) select c.*, o.order_number from claimed c join public.orders o on o.id = c.order_id
$$;

create or replace function public.finish_order_push(p_id bigint, p_lease_id uuid, p_success boolean, p_error text default null, p_permanent boolean default false)
returns void language sql security definer set search_path = public as $$
  update public.order_push_outbox set delivered_at = case when p_success then now() else null end,
    last_error = left(p_error, 200), attempts = case when p_permanent then 8 else attempts end,
    available_at = now() + interval '1 minute' * power(2, least(attempts, 8))
  where id = p_id and lease_id = p_lease_id
$$;

revoke all on function public.subscribe_order_push(text, text) from public, anon, authenticated;
grant execute on function public.subscribe_order_push(text, text) to anon, authenticated;
revoke all on function public.enqueue_order_ready_push() from public, anon, authenticated;
revoke all on function public.claim_order_push() from public, anon, authenticated;
revoke all on function public.finish_order_push(bigint, uuid, boolean, text, boolean) from public, anon, authenticated;
grant execute on function public.claim_order_push() to service_role;
grant execute on function public.finish_order_push(bigint, uuid, boolean, text, boolean) to service_role;
commit;
