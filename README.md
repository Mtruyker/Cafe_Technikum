# TechCafe (Flutter + Supabase)

Заказы в панели персонала обновляются автоматически; администратор получает уведомление и может включить звук. Для активации выполните миграцию `202610130001_staff_order_realtime.sql`. [Настройка и проверка](docs/STAFF_REALTIME.md).

## Предзаказы и выдача

Добавлены выбор перемены, лимит порций кухни, учёт остатков, выдача по одноразовому QR и уведомления о готовности. Расписание: 10:00–10:10, 11:40–12:10, 13:40–13:50 (UTC+4). Слоты на конкретную дату создаёт администратор через кнопку часов в панели персонала.

Перед запуском обновлённого клиента примените новые SQL-миграции и создайте слоты. Android push требуют конфигурации Firebase и развёртывания Edge Function. Порядок установки, настройки и проверки: [Предзаказы и уведомления](docs/PREORDERS_AND_NOTIFICATIONS.md).

Текущая версия проекта работает без обязательного Dart REST API: Flutter-клиент ходит напрямую в `Supabase Auth` и SQL RPC-функции.

## Структура

- `lib/main.dart` - гостевое Flutter-приложение
- `lib/admin_main.dart` - отдельный entrypoint админ-панели
- `supabase/migrations/` - схема БД, роли, RPC-функции и demo seed
- `supabase/README.md` - инструкции по настройке Supabase
- `server/` - legacy серверная часть, больше не используется клиентом как runtime-зависимость

## Настройка Supabase

1. Выполните SQL из:
   - `supabase/migrations/202604160001_initial_schema.sql`
   - `supabase/migrations/202604160002_demo_seed.sql`
   - `supabase/migrations/202604160003_clear_completed_staff_orders.sql`
   - `supabase/migrations/202604160003_customer_names.sql`
   - `supabase/migrations/202610020001_preorders_inventory_pickup.sql`
   - `supabase/migrations/202610020002_order_push.sql`
   - `supabase/migrations/202610130001_staff_order_realtime.sql`
2. Создайте сотрудников в `Authentication -> Users`.
3. Назначьте роль сотруднику:

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

## Запуск Flutter-приложения

```bash
flutter pub get
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

Для админ-приложения:

```bash
flutter run -d windows -t lib/admin_main.dart --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

Сборка Windows executable:

```bash
flutter build windows -t lib/admin_main.dart --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

## Вход персонала

1. Откройте панель персонала по иконке щита.
2. Введите `email/password` сотрудника, созданного в Supabase Auth.

В панели доступны:
- Кассир/Бариста: очередь заказов и смена статусов
- Админ: товары, доступность, отчеты по продажам

## Реализованные сценарии

- Публичный каталог товаров
- Оформление заказа и получение номера/QR
- Отслеживание заказа по `orderNumber` или `orderId`
- Локальная история заказов через `SharedPreferences`
- Вход сотрудников через `Supabase Auth`
- Управление товарами и статусами заказов через RPC-функции
- Отчеты продаж для администратора

## Примечания

- Если `SUPABASE_URL` и `SUPABASE_ANON_KEY` не переданы, приложение покажет ошибку конфигурации.
- Для внутреннего использования рекомендуется отключить публичную регистрацию в Supabase Auth.
- Текущая онлайн-оплата остается demo-сценарием и реализована через SQL RPC, а не через реального платежного провайдера.
