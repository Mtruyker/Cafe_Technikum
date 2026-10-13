begin;

-- A serialized revision makes the cursor safe across concurrent transactions.
-- Only this small journal is replicated; orders contain private pickup tokens.
create table public.staff_order_revision (
  id boolean primary key default true check (id),
  revision bigint not null default 0
);
insert into public.staff_order_revision(id, revision) values (true, 0);
create table public.staff_order_events (
  revision bigint primary key,
  order_id text not null,
  kind text not null check (kind in ('created', 'updated', 'deleted')),
  occurred_at timestamptz not null default now()
);
alter table public.staff_order_revision enable row level security;
alter table public.staff_order_events enable row level security;
revoke all on public.staff_order_revision, public.staff_order_events from public, anon, authenticated;
grant select on public.staff_order_events to authenticated;
create policy staff_read_order_events on public.staff_order_events
for select to authenticated using (
  exists (select 1 from public.staff_profiles s
    where s.id = auth.uid() and s.role in ('admin', 'cashier', 'barista'))
);

create function public.record_staff_order_event()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_revision bigint;
begin
  update public.staff_order_revision set revision = revision + 1
    where id = true returning revision into v_revision;
  insert into public.staff_order_events(revision, order_id, kind) values (
    v_revision, case when tg_op = 'DELETE' then old.id else new.id end,
    case tg_op when 'INSERT' then 'created' when 'DELETE' then 'deleted' else 'updated' end
  );
  return null;
end $$;
create trigger record_staff_order_event after insert or update or delete on public.orders
for each row execute function public.record_staff_order_event();
revoke all on function public.record_staff_order_event() from public, anon, authenticated;

create function public.poll_staff_order_events(p_after bigint default null, p_limit integer default 100)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_cursor bigint; v_events jsonb; v_latest bigint;
begin
  perform public.require_staff_role(array['admin', 'cashier', 'barista']);
  select revision into v_latest from public.staff_order_revision where id = true;
  if p_after is null then
    return jsonb_build_object('cursor', v_latest, 'events', '[]'::jsonb, 'hasMore', false);
  end if;
  if p_after < 0 or p_after > v_latest then raise exception 'Некорректная позиция журнала заказов.'; end if;
  select coalesce(max(e.revision), p_after), coalesce(jsonb_agg(jsonb_build_object(
      'revision', e.revision, 'kind', e.kind, 'orderId', e.order_id,
      'order', case when o.staff_cleared_at is null and o.id is not null
        then public.make_order_json(o.id) else null end
    ) order by e.revision), '[]'::jsonb)
    into v_cursor, v_events
  from (select * from public.staff_order_events where revision > p_after and revision <= v_latest
    order by revision limit greatest(1, least(coalesce(p_limit, 100), 500))) e
  left join public.orders o on o.id = e.order_id;
  return jsonb_build_object('cursor', v_cursor, 'events', v_events, 'hasMore', v_cursor < v_latest);
end $$;
revoke all on function public.poll_staff_order_events(bigint, integer) from public, anon, authenticated;
grant execute on function public.poll_staff_order_events(bigint, integer) to authenticated;

-- Supabase already has this publication. Isolated SQL test databases may not.
do $$ begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.staff_order_events;
  end if;
end $$;
commit;
