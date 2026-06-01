# План: Пункт 10 — SQLite хранилище на сервере

## Текущее состояние
- `AppStore` — полностью in-memory: Map/List для products, orders, payments, staff
- `api.dart` обращается к `_store.products[id]`, `_store.ordersById.values`, `_store.categories` и т.д.
- Seed data захардкожена в `AppStore.seeded()`
- При перезапуске сервера все заказы/платежи теряются

## Подход
Заменить `AppStore` на `SqliteStore` с тем же публичным интерфейсом. Используем пакет `sqlite3` (нативный FFI, без Flutter-зависимостей). Seed data вставляется при первом запуске (если таблицы пусты).

## Схема БД

```sql
-- categories
CREATE TABLE categories (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  sort INTEGER NOT NULL DEFAULT 0
);

-- products (modifier_groups хранятся как JSON — они вложенные и редко фильтруются)
CREATE TABLE products (
  id TEXT PRIMARY KEY,
  category_id TEXT NOT NULL REFERENCES categories(id),
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  price REAL NOT NULL,
  image_url TEXT NOT NULL DEFAULT '',
  is_available INTEGER NOT NULL DEFAULT 1,
  modifier_groups TEXT NOT NULL DEFAULT '[]'
);

-- staff_users
CREATE TABLE staff_users (
  id TEXT PRIMARY KEY,
  pin TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  role TEXT NOT NULL
);

-- orders
CREATE TABLE orders (
  id TEXT PRIMARY KEY,
  order_number TEXT NOT NULL UNIQUE,
  created_at TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'created',
  total REAL NOT NULL,
  comment TEXT,
  payment_method TEXT NOT NULL DEFAULT 'pay_on_pickup',
  payment_status TEXT NOT NULL DEFAULT 'unpaid',
  provider_payment_id TEXT,
  paid_at TEXT
);

-- order_items
CREATE TABLE order_items (
  id TEXT PRIMARY KEY,
  order_id TEXT NOT NULL REFERENCES orders(id),
  product_id TEXT NOT NULL,
  name_snapshot TEXT NOT NULL,
  price_snapshot REAL NOT NULL,
  qty INTEGER NOT NULL,
  modifiers TEXT NOT NULL DEFAULT '[]'
);

-- payments
CREATE TABLE payments (
  id TEXT PRIMARY KEY,
  order_id TEXT NOT NULL REFERENCES orders(id),
  amount REAL NOT NULL,
  status TEXT NOT NULL DEFAULT 'created',
  checkout_url TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

-- order_counter (single-row table for atomic counter)
CREATE TABLE order_counter (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  value INTEGER NOT NULL DEFAULT 100
);
```

## Шаги

### Шаг 1: Добавить зависимость sqlite3
В `server/pubspec.yaml` добавить `sqlite3: ^2.4.0`.

### Шаг 2: Создать `server/lib/store/sqlite_store.dart`
Класс `SqliteStore` с тем же публичным API что у `AppStore`:
- Конструктор принимает путь к файлу БД (дефолт `techcafe.db`)
- `_initDb()` — создаёт таблицы (IF NOT EXISTS)
- `_seedIfEmpty()` — вставляет seed data если таблицы пусты
- Геттеры/методы: `categories`, `products`, `staffByPin`, `ordersById`, `saveOrder()`, `orderByNumber()`, `nextOrderNumber()`, `paymentsById`, `paymentIdByOrderId`, `savePayment()`

### Шаг 3: Выделить абстрактный интерфейс `StoreBase`
Создать `server/lib/store/store_base.dart` — абстрактный класс с общим API.
`AppStore implements StoreBase`, `SqliteStore implements StoreBase`.
`TechCafeApi` принимает `StoreBase` вместо `AppStore`.

### Шаг 4: Обновить `api.dart`
Заменить тип `AppStore` на `StoreBase`. Минимальные изменения — интерфейс тот же.

### Шаг 5: Обновить `server.dart`
Выбор store по env var `STORE_TYPE`:
- `sqlite` (дефолт) → `SqliteStore(path)`
- `memory` → `AppStore.seeded()`
Путь к БД: env var `SQLITE_PATH` (дефолт `techcafe.db`).

### Шаг 6: Обновить config.dart
Добавить `storeType` и `sqlitePath` в `ServerConfig`.

## Файлы

| Файл | Действие |
|------|----------|
| `server/pubspec.yaml` | Изменить — добавить sqlite3 |
| `server/lib/store/store_base.dart` | Создать — абстрактный интерфейс |
| `server/lib/store/sqlite_store.dart` | Создать — SQLite реализация |
| `server/lib/store/app_store.dart` | Изменить — implements StoreBase |
| `server/lib/api.dart` | Изменить — StoreBase вместо AppStore |
| `server/lib/config.dart` | Изменить — storeType, sqlitePath |
| `server/bin/server.dart` | Изменить — выбор store |

## Важно
- modifier_groups и order_item modifiers хранятся как JSON TEXT — они вложенные структуры, нормализация избыточна
- Даты хранятся как ISO 8601 TEXT
- Boolean как INTEGER (0/1)
- Seed data вставляется только если таблица categories пуста
- `api.dart` использует `_store.products` как Map — в SqliteStore это будет геттер, который делает SELECT
- Для `ordersById.values.where(...)` в api.dart — SqliteStore вернёт Map из SELECT
