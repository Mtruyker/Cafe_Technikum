# План: Тесты (TODO п.8)

## Контекст
Сейчас один placeholder-тест. Покрытие — 0%. Нужно добавить unit-тесты для моделей, `ApiClient` и `TechCafeState`.

Мок-библиотека: `mocktail` (не требует codegen, в отличие от mockito).

## Шаг 1. Добавить `mocktail` в dev_dependencies

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  mocktail: ^1.0.4
```

## Шаг 2. Unit-тесты для моделей — `test/models/`

Тестируем `fromJson` для всех моделей + `toJson`/`toOrderJson` где есть + computed-свойства.

### `test/models/category_test.dart`
- `Category.fromJson` — корректный JSON, пустые/null поля

### `test/models/enums_test.dart`
- `OrderStatus`, `PaymentMethod`, `PaymentStatus`, `PaymentSessionStatus` — `fromString` для всех значений + unknown fallback
- `.value` и `.label` для каждого значения

### `test/models/product_test.dart`
- `Product.fromJson` — полный JSON с modifierGroups
- `ModifierGroup.fromJson`, `ModifierItem.fromJson`
- Пустые/null поля → дефолты

### `test/models/cart_item_test.dart`
- `SelectedModifier.fromJson`, `.toJson()`, `.toOrderJson()`
- `CartItem` — `unitPrice`, `lineTotal`, `signature`, `copyWith`, `toOrderJson`

### `test/models/order_test.dart`
- `CafeOrder.fromJson` — полный JSON с items и modifiers
- `OrderCreatedResponse.fromJson`
- `OrderItemSnapshot.fromJson`, `OrderItemModifierSnapshot.fromJson`

### `test/models/local_order_record_test.dart`
- `fromJson` / `toJson` roundtrip
- `decodeList` / `encodeList`
- `copyWith`

### `test/models/staff_session_test.dart`
- `fromJson`, `isAdmin` (role == 'admin' vs другое)

### `test/models/sales_report_test.dart`
- `fromJson` — полный JSON с byStatus map

### `test/models/payment_test.dart`
- `PaymentSession.fromJson`
- `PaymentConfirmationResult.fromJson` — корректный JSON + невалидный (throws ApiException)

## Шаг 3. Unit-тесты для `ApiClient` — `test/services/api_client_test.dart`

Используем `MockClient` из `package:http/testing.dart` (уже доступен через `http`).

- `fetchCategories` — 200 OK → парсит список
- `fetchProducts` — 200 OK, с query params
- `createOrder` — 201 OK → парсит ответ
- `getOrder` — 200 OK
- `_decodeResponse`: 4xx → `ApiErrorKind.client`, 5xx → `ApiErrorKind.server`, не-JSON → `ApiErrorKind.server`
- `_guardedRequest`: таймаут → `ApiErrorKind.timeout`, retry для GET (проверяем кол-во вызовов), нет retry для POST

## Шаг 4. Unit-тесты для `TechCafeState` — `test/state/techcafe_state_test.dart`

Mock-классы через `mocktail`:
- `MockApiClient extends Mock implements ApiClientBase`
- `MockLocalOrdersStore extends Mock implements LocalOrdersStoreBase`

Тесты:
- `initialize()` — загружает categories + products, устанавливает selectedCategoryId
- `initialize()` — при ApiException → initializationError = message
- `initialize()` — при другой ошибке → initializationError = fallback
- `addToCart` / `setCartItemQty` / `clearCart` — корректная работа с корзиной
- `cartItemsCount`, `cartTotal` — computed-свойства
- `selectCategory` — меняет selectedCategoryId, перезагружает products
- `visibleProducts` — фильтрация по searchQuery

## Шаг 5. Удалить placeholder-тест

Удалить `test/widget_test.dart` — он бесполезен.

## Шаг 6. `flutter test`

Запустить все тесты, убедиться что проходят.

---

## Файлы
- **Изменяемые:** `pubspec.yaml` (добавить mocktail)
- **Удаляемые:** `test/widget_test.dart`
- **Новые:**
  - `test/models/category_test.dart`
  - `test/models/enums_test.dart`
  - `test/models/product_test.dart`
  - `test/models/cart_item_test.dart`
  - `test/models/order_test.dart`
  - `test/models/local_order_record_test.dart`
  - `test/models/staff_session_test.dart`
  - `test/models/sales_report_test.dart`
  - `test/models/payment_test.dart`
  - `test/services/api_client_test.dart`
  - `test/state/techcafe_state_test.dart`

## Что НЕ делаем
- Widget-тесты (требуют pump + MaterialApp, отдельная задача)
- Интеграционные тесты (требуют запущенный backend)
- Тесты для admin/teacher модулей
