# TODO — КафеТехникум

## 1. Разбить main.dart на модули (критично)
- **Статус:** выполнено
- **Описание:** `main.dart` был 4059 строк — разбит на модули, теперь ~27 строк.
- **Что сделано:**
  - [x] Вынесены модели в `lib/models/` (Category, Product, CartItem, CafeOrder, и т.д.)
  - [x] Вынесен `ApiClient` в `lib/services/api_client.dart`
  - [x] Вынесен `LocalOrdersStore` в `lib/services/local_orders_store.dart`
  - [x] Вынесен `TechCafeState` в `lib/state/techcafe_state.dart`
  - [x] Вынесены экраны в `lib/screens/` (home, cart, order_success, tracking, recent_orders, staff_panel)
  - [x] Вынесены переиспользуемые виджеты в `lib/widgets/`
  - [x] Вынесен `TechCafeApp` в `lib/app.dart`
  - [x] Обновлены импорты в `main.dart` и `admin_main.dart` (прямые импорты из модулей)
  - [x] Удалены легаси-заглушки из `lib/src/`
  - [x] Убран exclude `lib/src/**` из `analysis_options.yaml`

## 2. Разбить server.dart на модули
- **Статус:** выполнено
- **Описание:** `server/bin/server.dart` был 1375 строк — разбит на модули, теперь 25 строк.
- **Что сделано:**
  - [x] Вынесены модели в `server/lib/models/` (enums, Category, Product, CafeOrder, PaymentSession, StaffUser и др.)
  - [x] Вынесено хранилище (`AppStore` + seed data) в `server/lib/store/app_store.dart`
  - [x] Вынесен CORS middleware в `server/lib/middleware/cors.dart`
  - [x] Вынесен RateLimiter в `server/lib/middleware/rate_limiter.dart`
  - [x] Вынесен TechCafeApi (роутер + все хендлеры) в `server/lib/api.dart`
  - [x] `server/lib/models/models.dart` — barrel export для всех моделей

## 3. Роутинг (go_router)
- **Статус:** частично выполнено
- **Описание:** Внедрён `go_router` в студенческое приложение. Админ-приложение не тронуто (один экран).
- **Что сделано:**
  - [x] Добавлен `go_router: ^14.0.0` в зависимости
  - [x] Создан `lib/router.dart` с маршрутами: `/`, `/cart`, `/order-success`, `/tracking`, `/tracking/:orderId`, `/orders`, `/staff`
  - [x] `app.dart` переведён на `MaterialApp.router` с `routerConfig`
  - [x] Заменены все `Navigator.push`/`pushReplacement`/`popUntil` на `context.push`/`context.pushReplacement`/`context.go`
  - [x] Убраны прямые импорты экранов друг из друга (home, cart, order_success, recent_orders)
  - [ ] Route guard для staff-панели — не добавлен (авторизация уже внутри экрана)

## 4. Убрать хардкод и вынести конфигурацию
- **Статус:** выполнено
- **Что сделано:**
  - [x] JWT-секрет — читается из `JWT_SECRET` env var (`server/lib/config.dart`)
  - [x] Rate limit — конфигурируемый через `RATE_LIMIT_MAX` и `RATE_LIMIT_WINDOW_MIN` env vars
  - [x] Время жизни JWT — конфигурируемое через `JWT_EXPIRES_HOURS` env var
  - [x] Создан `ServerConfig.fromEnvironment()` с дефолтами для всех параметров
  - [x] `TechCafeApi` принимает `ServerConfig` вместо хардкода
  - [x] Демо PIN-подсказка убрана из UI (`staff_panel_screen.dart`)
  - [x] Тема/цвета вынесены в `lib/theme.dart` (`AppColors`, `AppTheme.student()`, `AppTheme.admin()`)

## 5. Dependency Injection
- **Статус:** выполнено
- **Описание:** `TechCafeState` принимает абстракции вместо конкретных реализаций — зависимости легко подменяются для тестов.
- **Что сделано:**
  - [x] Создан `ApiClientBase` (`lib/services/api_client_base.dart`) — абстрактный интерфейс (13 методов)
  - [x] Создан `LocalOrdersStoreBase` (`lib/services/local_orders_store_base.dart`) — абстрактный интерфейс (5 методов)
  - [x] `ApiClient extends ApiClientBase`, `LocalOrdersStore extends LocalOrdersStoreBase`
  - [x] `TechCafeState` принимает `ApiClientBase` и `LocalOrdersStoreBase`
  - [x] Provider остаётся как DI-контейнер (get_it не нужен)

## 6. Валидация на клиенте
- **Статус:** выполнено
- **Описание:** Добавлена клиентская валидация во все 3 формы через `Form` + `GlobalKey<FormState>` + `TextFormField.validator`.
- **Что сделано:**
  - [x] `cart_screen.dart` — форма оформления заказа: `Form` + `TextFormField` комментария с `maxLength: 500`, `validate()` перед отправкой
  - [x] `staff_panel_screen.dart` — PIN-логин: `Form` + `TextFormField` с валидатором (обязательное, только цифры, 4–6 символов)
  - [x] `staff_panel_screen.dart` — редактор продукта (`_ProductEditorDialog`): `Form` + все `TextField` → `TextFormField` с валидаторами:
    - Название: обязательное, maxLength 100
    - Цена: обязательное, > 0, корректный double
    - Описание: maxLength 500
    - Группа опций — название: обязательное
    - Группа опций — мин: >= 0, целое число
    - Группа опций — макс: > 0, целое, >= мин
    - Опция — название: обязательное
    - Опция — цена: корректный double
  - [x] Ручная валидация в `_submit()` заменена на `_formKey.currentState!.validate()`
  - [x] Из `_buildModifierGroupsPayload()` убрана дублирующая валидация полей (оставлена структурная проверка «хотя бы одна опция в группе»)

## 7. Обработка ошибок и retry
- **Статус:** частично выполнено
- **Что сделано:**
  - [x] Retry с exponential backoff для сетевых ошибок (`_guardedRequest` в `ApiClient`: до 3 попыток, 1с/2с задержка, только GET/PATCH)
  - [x] Информативные сообщения об ошибках: `ApiErrorKind` (network, timeout, server, client, unknown), таймаут 15с
  - [x] `_decodeResponse` различает 4xx (client) и 5xx (server) ошибки
  - [x] `TechCafeState` показывает конкретные сообщения вместо generic «Не удалось загрузить данные»
- **Осталось:**
  - [ ] Offline-индикатор (нет сети → показать баннер)

## 8. Тесты
- **Статус:** частично выполнено
- **Описание:** 103 unit-теста, все проходят. Мок-библиотека: `mocktail`.
- **Что сделано:**
  - [x] Unit-тесты для моделей (fromJson/toJson) — 9 файлов в `test/models/`
  - [x] Unit-тесты для `TechCafeState` (с мок-зависимостями) — `test/state/techcafe_state_test.dart`
  - [x] Unit-тесты для `ApiClient` (с мок HTTP) — `test/services/api_client_test.dart`
  - [x] Удалён placeholder `test/widget_test.dart`
  - [x] Добавлен `mocktail: ^1.0.4` в dev_dependencies
- **Осталось:**
  - [ ] Widget-тесты для ключевых экранов
  - [ ] Интеграционные тесты для основных сценариев (заказ, отслеживание)

## 9. Пагинация
- **Статус:** выполнено
- **Описание:** Добавлена серверная пагинация и infinite scroll на клиенте.
- **Что сделано:**
  - [x] Серверный хелпер `_paginatedOrPlain()` — возвращает `{items, total, page, limit, hasMore}` при наличии `page` query param, иначе plain array (обратная совместимость)
  - [x] Пагинация в `GET /products` и `GET /orders` (query params: `page`, `limit`, дефолт 20)
  - [x] Заказы отсортированы по дате desc (новые сверху)
  - [x] Модель `PaginatedResponse<T>` (`lib/models/paginated_response.dart`) с `fromJson` фабрикой
  - [x] `ApiClientBase` / `ApiClient` — `fetchProducts` и `fetchStaffOrders` принимают `page?`/`limit?`, возвращают `PaginatedResponse`
  - [x] Клиент обрабатывает оба формата ответа (plain array и paginated)
  - [x] `TechCafeState` — накопление страниц: `loadMoreProducts()`, `loadMoreStaffOrders()`, флаги `hasMore*`, `isLoadingMore*`
  - [x] Infinite scroll в `home_screen.dart` и `staff_panel_screen.dart` через `NotificationListener<ScrollNotification>`
  - [x] Тесты обновлены под `PaginatedResponse` (102 теста проходят)

## 10. Персистентное хранилище на сервере
- **Статус:** выполнено
- **Описание:** Заменён in-memory `AppStore` на SQLite (`sqlite3` пакет). Данные переживают перезапуск сервера.
- **Что сделано:**
  - [x] Добавлена зависимость `sqlite3: ^2.4.0` в `server/pubspec.yaml`
  - [x] Создан `server/lib/store/sqlite_store.dart` — drop-in замена AppStore с 9 таблицами
  - [x] Map-like обёртки (ProductsMap, StaffMap, OrdersMap, PaymentsMap) — api.dart почти не изменён
  - [x] Транзакции для составных операций (заказ + items + modifiers)
  - [x] Seed демо-данных при пустой БД (`SEED_DEMO_DATA=true`)
  - [x] Конфигурация: `DB_PATH` env var (дефолт `techcafe.db`), `SEED_DEMO_DATA` env var
  - [x] `server/lib/config.dart` — добавлены `dbPath` и `seedDemoData`
  - [x] `server/bin/server.dart` и `server/lib/api.dart` — переведены на SqliteStore

## 11. Чистка кода
- **Статус:** частично выполнено
- **Задачи:**
  - [x] Удалены легаси-заглушки в `lib/src/` (пустые файлы)
  - [x] Убрано исключение `lib/src/` из `analysis_options.yaml`
  - [x] Убран `// ignore_for_file: deprecated_member_use` из `main.dart`
  - [x] Исправлен deprecated `value` → `initialValue` в `DropdownButtonFormField` (`cart_screen.dart`)
  - [ ] Довести переименование проекта с `flutte2` на `cafe_technikum` до конца (Android/iOS/macOS/Linux-метаданные ещё содержат старое имя)

---

# Дизайн и UX

## 12. Система отступов и spacing
- **Статус:** выполнено
- **Описание:** Введена единая шкала отступов: 4, 8, 12, 16, 24, 32.
- **Что сделано:**
  - [x] Создан `AppSpacing` в `lib/theme.dart` с константами: `xxs=4, xs=8, sm=12, md=16, lg=24, xl=32`
  - [x] Заменены все хардкоженные отступы на `AppSpacing.*` константы во всех экранах и виджетах
  - [x] Обновлены файлы: `home_screen.dart`, `cart_screen.dart`, `tracking_screen.dart`, `recent_orders_screen.dart`, `order_success_screen.dart`, `product_card.dart`, `product_options_sheet.dart`, `staff_panel_screen.dart`
  - [x] Все 102 теста проходят, `flutter analyze` — 0 issues

## 13. Тема, цвета и типографика
- **Статус:** выполнено
- **Описание:** Добавлена семантическая палитра цветов и кастомная типографика.
- **Что сделано:**
  - [x] Добавлены семантические цвета в `AppColors`: success (зелёный), warning (жёлтый), info (синий), neutral (серый)
  - [x] Создан `_buildTextTheme()` с полной типографической шкалой (display, headline, title, body, label)
  - [x] Интегрирована типографика в оба theme (student и admin)
  - [x] Все 102 теста проходят, `flutter analyze` — 0 issues

## 14. Карточки продуктов
- **Статус:** выполнено
- **Описание:** Карточки получили объёмную подачу, category-aware placeholder-ы и прогрессивную загрузку изображений.
- **Что сделано:**
  - [x] Добавлены elevation, скруглённые углы, hover/press эффекты
  - [x] Цветные placeholder-ы по категориям вместо серого фона
  - [x] Подключён `cached_network_image` для кэширования и progressive loading
  - [x] Добавлен shimmer + blur-up эффект при загрузке изображений
  - [x] Проверка: `flutter analyze lib/widgets/product_card.dart lib/widgets/product_card_image.dart` — 0 issues, `flutter test` — 103 tests passed

## 15. Skeleton loaders и анимации
- **Статус:** выполнено
- **Описание:** Основные экраны получили shimmer-skeleton состояния, навигация — анимированные переходы, корзина — локальные micro-interactions.
- **Что сделано:**
  - [x] Добавлены skeleton loaders (shimmer) для ключевых загрузок: меню, tracking, staff orders/products/reports, tail при пагинации
  - [x] Добавлены анимации переходов между экранами через `go_router` + `CustomTransitionPage`
  - [x] Micro-interactions: анимация добавления в корзину (bounce badge в AppBar), анимация изменения количества и итогов в корзине
  - [x] Проверка: `flutter analyze lib/router.dart lib/widgets/loading_placeholders.dart lib/screens/home_screen.dart lib/screens/cart_screen.dart lib/screens/tracking_screen.dart lib/screens/staff_panel_screen.dart` — 0 issues, `flutter test` — 103 tests passed

## 16. Пустые состояния и ошибки
- **Статус:** выполнено
- **Описание:** Пустые и ошибочные состояния получили единый reusable-UI с иконками, пояснениями и CTA на гостевых и staff-экранах.
- **Задачи:**
  - [x] Добавить иллюстрации/иконки + call-to-action на пустых экранах
  - [x] Ошибки: иконка + понятный текст + кнопка "Повторить"
  - [x] Перевести "No products found" и другие английские строки на русский
  - [x] Проверка: `flutter analyze lib/state/techcafe_state.dart lib/widgets/feedback_states.dart lib/screens/home_screen.dart lib/screens/cart_screen.dart lib/screens/recent_orders_screen.dart lib/screens/tracking_screen.dart lib/screens/staff_panel_screen.dart` — 0 issues, `flutter test` — 103 tests passed

## 17. Формы и валидация UX
- **Статус:** выполнено
- **Описание:** Обязательные поля получили явные маркеры, валидация стала срабатывать после потери фокуса, а single-select модификаторы переведены на radio с живым preview цены.
- **Задачи:**
  - [x] Inline-валидация полей (ошибка при потере фокуса, не только при отправке)
  - [x] Индикаторы обязательных полей (звёздочка или подпись)
  - [x] Заменить CheckboxListTile на RadioListTile для single-select модификаторов
  - [x] Превью цены при выборе модификаторов
  - [x] Проверка: `flutter analyze lib/widgets/validated_form_fields.dart lib/widgets/product_options_sheet.dart lib/screens/tracking_screen.dart lib/screens/staff_panel_screen.dart` — 0 issues, `flutter test` — 103 tests passed

## 18. Staff-панель UX
- **Статус:** выполнено
- **Описание:** Заказы получили читаемую карточку со статус-бейджами, список товаров — превью изображений, а отчёты — графики по дням и pie chart по статусам.
- **Задачи:**
  - [x] Товары в заказе — отдельными строками, не через `|`
  - [x] Цветовая индикация статусов заказов (новый — синий, готов — зелёный, отменён — красный)
  - [x] Добавить графики в отчёты (`fl_chart`): выручка, заказы по дням, статусы (pie chart)
  - [x] Превью изображения продукта в списке продуктов
  - [x] Проверка: `flutter analyze lib/models/sales_report.dart lib/widgets/order_status_badge.dart lib/widgets/staff_report_charts.dart lib/screens/staff_panel_screen.dart test/models/sales_report_test.dart` — 0 issues, `dart analyze server/lib/api.dart` — 0 issues, `flutter test` — 103 tests passed

## 19. Навигация гостевого приложения
- **Статус:** выполнено
- **Описание:** На мобильных гостевых экранах добавлена нижняя навигация, дублирующие переходы убраны из AppBar.
- **Что сделано:**
  - [x] Добавлен guest bottom navigation: Меню, Корзина (с badge), Мои заказы
  - [x] Badge на иконке корзины показывает текущее количество товаров
  - [x] Нижняя навигация подключена к `/`, `/cart`, `/orders`, переключение выполнено через `context.go(...)`
  - [x] На мобильных устройствах убраны дублирующие кнопки корзины и заказов из `HomeScreen` AppBar
  - [x] Проверка: `flutter analyze lib/widgets/guest_navigation_bar.dart lib/screens/home_screen.dart lib/screens/cart_screen.dart lib/screens/recent_orders_screen.dart` — 0 issues, `flutter test` — 103 tests passed

## 20. Accessibility
- **Статус:** выполнено
- **Задачи:**
  - [x] Semantic labels на кнопках и изображениях
  - [x] Alt text для изображений продуктов
  - [x] Поддержка screen reader (Semantics виджеты)
  - [x] Проверить контрастность цветов (WCAG AA)
  - [x] Поддержка масштабирования текста
  - [x] Проверка: `flutter analyze lib/theme.dart lib/widgets/feedback_states.dart lib/widgets/product_card.dart lib/widgets/product_card_image.dart lib/widgets/guest_navigation_bar.dart lib/widgets/order_status_badge.dart lib/screens/home_screen.dart lib/screens/cart_screen.dart lib/screens/order_success_screen.dart lib/screens/staff_panel_screen.dart` — 0 issues, `flutter test` — 103 tests passed

---

**Рекомендуемый порядок (код):** 1 → 11 → 2 → 4 → 5 → 3 → 6 → 7 → 8 → 9 → 10
**Рекомендуемый порядок (дизайн):** 12 → 13 → 14 → 19 → 16 → 15 → 17 → 18 → 20
Сначала разбиваем монолит и чистим — это разблокирует всё остальное. Дизайн можно вести параллельно, начиная с системы отступов и темы.

