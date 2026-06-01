# План: Разбить main.dart на модули

## Текущее состояние
`lib/main.dart` — 4059 строк, содержит всё: модели, сервисы, стейт, экраны, виджеты.
`lib/admin_main.dart` — импортирует из `main.dart` через `import 'main.dart' as app`.
`lib/src/` — легаси-заглушки (пустые файлы), исключены из анализа в `analysis_options.yaml`.

## Целевая структура

```
lib/
├── main.dart                  (точка входа, ~30 строк)
├── admin_main.dart            (точка входа админа, обновлённые импорты)
├── app.dart                   (TechCafeApp виджет)
├── models/
│   ├── category.dart          (Category)
│   ├── product.dart           (Product, ModifierGroup, ModifierItem)
│   ├── cart_item.dart         (CartItem, SelectedModifier)
│   ├── order.dart             (CafeOrder, OrderCreatedResponse, OrderItemSnapshot, OrderItemModifierSnapshot)
│   ├── enums.dart             (OrderStatus, PaymentMethod, PaymentStatus, PaymentSessionStatus + extensions)
│   ├── payment.dart           (PaymentSession, PaymentConfirmationResult)
│   ├── local_order_record.dart(LocalOrderRecord)
│   ├── staff_session.dart     (StaffSession)
│   ├── sales_report.dart      (SalesReport)
│   └── models.dart            (barrel-файл, реэкспорт всех моделей)
├── services/
│   ├── api_exception.dart     (ApiException)
│   ├── api_client.dart        (ApiClient)
│   └── local_orders_store.dart(LocalOrdersStore)
├── state/
│   └── techcafe_state.dart    (TechCafeState)
├── screens/
│   ├── home_screen.dart       (HomeScreen)
│   ├── cart_screen.dart       (CartScreen)
│   ├── order_success_screen.dart (OrderSuccessScreen)
│   ├── tracking_screen.dart   (TrackingScreen, _OrderDetailsCard)
│   ├── recent_orders_screen.dart (RecentOrdersScreen)
│   └── staff_panel_screen.dart(StaffPanelScreen, _MetricCard, _ProductEditorDialog, вспомогательные классы)
├── widgets/
│   ├── product_card.dart      (_ProductCard → ProductCard, публичный)
│   └── product_options_sheet.dart (_ProductOptionsSheet → ProductOptionsSheet, публичный)
└── utils/
    └── formatters.dart        (formatRub, resolveApiBaseUrl, typedef JsonMap)
```

## Шаги выполнения

### 1. Создать `lib/utils/formatters.dart`
- Перенести: `typedef JsonMap`, `formatRub()`, `resolveApiBaseUrl()`

### 2. Создать `lib/models/` — все модели
- `enums.dart` — OrderStatus, PaymentMethod, PaymentStatus, PaymentSessionStatus + extensions
- `category.dart` — Category
- `product.dart` — ModifierItem, ModifierGroup, Product
- `cart_item.dart` — SelectedModifier, CartItem
- `order.dart` — OrderItemModifierSnapshot, OrderItemSnapshot, CafeOrder, OrderCreatedResponse
- `payment.dart` — PaymentSession, PaymentConfirmationResult
- `local_order_record.dart` — LocalOrderRecord
- `staff_session.dart` — StaffSession
- `sales_report.dart` — SalesReport
- `models.dart` — barrel-файл

### 3. Создать `lib/services/`
- `api_exception.dart` — ApiException
- `api_client.dart` — ApiClient (импортирует models и utils)
- `local_orders_store.dart` — LocalOrdersStore

### 4. Создать `lib/state/techcafe_state.dart`
- TechCafeState (импортирует models, services)

### 5. Создать `lib/widgets/`
- `product_card.dart` — ProductCard (убрать `_` prefix, сделать публичным)
- `product_options_sheet.dart` — ProductOptionsSheet (убрать `_` prefix)

### 6. Создать `lib/screens/`
- `home_screen.dart` — HomeScreen (импортирует ProductCard, ProductOptionsSheet)
- `cart_screen.dart` — CartScreen
- `order_success_screen.dart` — OrderSuccessScreen
- `tracking_screen.dart` — TrackingScreen, _OrderDetailsCard
- `recent_orders_screen.dart` — RecentOrdersScreen
- `staff_panel_screen.dart` — StaffPanelScreen, _MetricCard, _ProductEditorResult, _ProductEditorDialog, _ModifierGroupDraft, _ModifierItemDraft

### 7. Создать `lib/app.dart`
- TechCafeApp (импортирует screens/home_screen.dart)

### 8. Обновить `lib/main.dart`
- Оставить только `void main()` + импорты из новых модулей (~25 строк)

### 9. Обновить `lib/admin_main.dart`
- Заменить `import 'main.dart' as app` на прямые импорты из новых модулей
- Убрать префикс `app.`

### 10. Удалить легаси `lib/src/`
- Удалить все файлы-заглушки в `lib/src/`
- Убрать `lib/src/**` из exclude в `analysis_options.yaml`

### 11. Убрать `// ignore_for_file: deprecated_member_use`
- Больше не нужен глобальный suppress — проверить и исправить конкретные предупреждения

## Принципы
- Каждый файл — один логический блок
- Приватные виджеты экранов (`_OrderDetailsCard`, `_MetricCard`) остаются в файле экрана
- Переиспользуемые виджеты (`ProductCard`, `ProductOptionsSheet`) — в `lib/widgets/`, публичные
- Barrel-файл `models.dart` для удобного импорта всех моделей
- Никаких циклических зависимостей: utils ← models ← services ← state ← screens/widgets
