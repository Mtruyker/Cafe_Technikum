# Supabase Migration

Flutter-клиент теперь должен работать напрямую с `Supabase Auth` и SQL RPC-функциями из `supabase/migrations/`.

## 1. Подготовка проекта

- Выполните `supabase/migrations/202604160001_initial_schema.sql`
- Затем выполните `supabase/migrations/202604160002_demo_seed.sql`
- Затем обе миграции `202604160003_clear_completed_staff_orders.sql` и `202604160003_customer_names.sql`.
- Для предзаказов и уведомлений выполните `202610020001_preorders_inventory_pickup.sql`, затем `202610020002_order_push.sql`.
- Создайте слоты в панели администратора. [Настройка предзаказов и Android push](../docs/PREORDERS_AND_NOTIFICATIONS.md).

## 2. Создание сотрудников

Для автоматического обновления панели выполните также `202610130001_staff_order_realtime.sql`. [Уведомления персоналу](../docs/STAFF_REALTIME.md).

1. В `Authentication -> Users` создайте пользователя с `email/password`.
2. После этого назначьте роль и отображаемое имя:

```sql
select public.assign_staff_role_by_email(
  'admin@techcafe.local',
  'Admin',
  'admin'
);
```

Поддерживаемые роли:
- `cashier`
- `barista`
- `admin`

Рекомендуется отключить публичную регистрацию, если системой пользуются только сотрудники.

## 3. Запуск Flutter

```bash
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

Админ-приложение:

```bash
flutter run -d windows -t lib/admin_main.dart --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```
