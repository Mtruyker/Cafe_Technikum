import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../utils/formatters.dart';
import 'api_client_base.dart';
import 'api_exception.dart';
import 'app_backend_config.dart';

class ApiClient extends ApiClientBase {
  ApiClient({required AppBackendConfig config, SupabaseClient? client})
    : _config = config,
      _client =
          client ?? (config.isConfigured ? Supabase.instance.client : null);

  @override
  Future<List<PickupSlot>> fetchPickupSlots({bool admin = false}) async {
    final data = await _rpc('list_pickup_slots', params: {'p_admin': admin});
    return (data as List)
        .map((e) => PickupSlot.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  @override
  Future<void> savePickupSlot({
    String? id,
    required DateTime startsAt,
    required DateTime cutoffAt,
    required int capacity,
    bool enabled = true,
  }) async {
    await _rpc(
      'save_pickup_slot',
      params: {
        'p_id': id,
        'p_starts_at': startsAt.toUtc().toIso8601String(),
        'p_cutoff_at': cutoffAt.toUtc().toIso8601String(),
        'p_capacity': capacity,
        'p_enabled': enabled,
      },
    );
  }

  @override
  Future<void> setProductStock(String productId, int? remaining) async {
    await _rpc(
      'set_product_stock',
      params: {'p_product_id': productId, 'p_remaining': remaining},
    );
  }

  @override
  Future<CafeOrder> inspectPickupCode(String code) async {
    final data = await _rpc('inspect_pickup_code', params: {'p_code': code});
    return CafeOrder.fromJson(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<CafeOrder> redeemPickupCode(
    String code, {
    bool paymentReceived = false,
  }) async {
    final data = await _rpc(
      'redeem_pickup_code',
      params: {'p_code': code, 'p_payment_received': paymentReceived},
    );
    return CafeOrder.fromJson(Map<String, dynamic>.from(data as Map));
  }

  final AppBackendConfig _config;
  final SupabaseClient? _client;

  @override
  Stream<StaffRealtimeSignal> watchStaffOrderChanges() {
    final client = _ensureConfigured();
    RealtimeChannel? channel;
    var canceled = false;
    late final StreamController<StaffRealtimeSignal> controller;
    void emit(StaffRealtimeSignal event) {
      if (!canceled) controller.add(event);
    }

    controller = StreamController<StaffRealtimeSignal>(
      onListen: () {
        channel = client
            .channel('staff-orders-${DateTime.now().microsecondsSinceEpoch}')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'staff_order_events',
              callback: (_) => emit(StaffRealtimeSignal.changed),
            )
            .subscribe((status, error) {
              emit(
                status == RealtimeSubscribeStatus.subscribed
                    ? StaffRealtimeSignal.connected
                    : StaffRealtimeSignal.disconnected,
              );
            });
      },
      onCancel: () async {
        canceled = true;
        if (channel != null) await client.removeChannel(channel!);
      },
    );
    return controller.stream;
  }

  @override
  Future<StaffOrderEventBatch> pollStaffOrderEvents({int? after}) async {
    final data = await _rpc(
      'poll_staff_order_events',
      params: {'p_after': after},
    ).timeout(const Duration(seconds: 15));
    return StaffOrderEventBatch.fromJson(
      Map<String, dynamic>.from(data as Map),
    );
  }

  @override
  Future<List<Category>> fetchCategories() async {
    final payload = await _rpc('list_categories');

    if (payload is! List) {
      throw const ApiException('Некорректный ответ API: categories.');
    }

    return payload
        .whereType<Map<String, dynamic>>()
        .map(Category.fromJson)
        .toList(growable: false)
      ..sort((a, b) => a.sort.compareTo(b.sort));
  }

  @override
  Future<StaffSession?> restoreStaffSession() async {
    final client = _configuredClientOrNull;
    if (client == null) {
      return null;
    }

    final session = client.auth.currentSession;
    if (session == null) {
      return null;
    }

    return _loadStaffSession(session);
  }

  @override
  Future<PaginatedResponse<Product>> fetchProducts({
    String? categoryId,
    bool inStockOnly = false,
    int? page,
    int? limit,
  }) async {
    final payload = await _rpc(
      'list_products',
      params: _compactParams({
        'p_category_id': categoryId?.isNotEmpty == true ? categoryId : null,
        'p_in_stock': inStockOnly,
        'p_page': page,
        'p_limit': limit,
      }),
    );

    if (payload is List) {
      final items = payload
          .whereType<Map<String, dynamic>>()
          .map(Product.fromJson)
          .toList(growable: false);
      return PaginatedResponse<Product>(
        items: items,
        total: items.length,
        page: 1,
        limit: items.length,
        hasMore: false,
      );
    }

    if (payload is Map<String, dynamic>) {
      return PaginatedResponse<Product>.fromJson(payload, Product.fromJson);
    }

    throw const ApiException('Некорректный ответ API: products.');
  }

  @override
  Future<OrderCreatedResponse> createOrder({
    required List<CartItem> items,
    required String firstName,
    required String lastName,
    required String comment,
    required PaymentMethod paymentMethod,
    String? pickupSlotId,
  }) async {
    final payload = await _rpc(
      'create_order',
      params: {
        'p_items': items
            .map((item) => item.toOrderJson())
            .toList(growable: false),
        'p_customer_first_name': firstName.trim(),
        'p_customer_last_name': lastName.trim(),
        'p_comment': comment.trim(),
        'p_payment_method': paymentMethod.value,
        'p_pickup_slot_id': pickupSlotId,
      },
    );

    if (payload is! Map<String, dynamic>) {
      throw const ApiException('Некорректный ответ API: create order.');
    }

    return OrderCreatedResponse.fromJson(payload);
  }

  @override
  Future<PaymentSession> createPaymentSession({required String orderId}) async {
    final payload = await _rpc(
      'create_payment_session',
      params: {'p_order_id': orderId},
    );

    if (payload is! Map<String, dynamic>) {
      throw const ApiException(
        'Некорректный ответ API: создание платежной сессии.',
      );
    }

    return PaymentSession.fromJson(payload);
  }

  @override
  Future<PaymentConfirmationResult> confirmPaymentSession({
    required String paymentId,
    required bool success,
  }) async {
    final payload = await _rpc(
      'confirm_payment_session',
      params: {'p_payment_id': paymentId, 'p_success': success},
    );

    if (payload is! Map<String, dynamic>) {
      throw const ApiException(
        'Некорректный ответ API: подтверждение платежа.',
      );
    }

    return PaymentConfirmationResult.fromJson(payload);
  }

  @override
  Future<CafeOrder> getOrder(String key) async {
    final payload = await _rpc(
      'get_order_by_key',
      params: {'p_key': key.trim()},
    );

    if (payload is! Map<String, dynamic>) {
      throw const ApiException('Некорректный ответ API: order details.');
    }

    return CafeOrder.fromJson(payload);
  }

  @override
  Future<StaffSession> loginStaff({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty || password.isEmpty) {
      throw const ApiException(
        'Введите логин и пароль.',
        kind: ApiErrorKind.client,
      );
    }

    final client = _ensureConfigured();

    try {
      final response = await client.auth.signInWithPassword(
        email: normalizedEmail,
        password: password,
      );

      final session = response.session;
      if (session == null) {
        throw const ApiException(
          'Не удалось создать сессию пользователя.',
          kind: ApiErrorKind.server,
        );
      }

      return _loadStaffSession(session);
    } on AuthException catch (error) {
      throw ApiException(
        _normalizeAuthMessage(error.message),
        kind: ApiErrorKind.client,
      );
    } on PostgrestException catch (error) {
      throw ApiException(
        _normalizePostgrestMessage(error),
        kind: ApiErrorKind.client,
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'Нет соединения с сервером. Проверьте интернет.',
        kind: ApiErrorKind.network,
      );
    }
  }

  @override
  Future<void> logoutStaff() async {
    final client = _configuredClientOrNull;
    if (client == null) {
      return;
    }

    await client.auth.signOut();
  }

  @override
  Future<PaginatedResponse<CafeOrder>> fetchStaffOrders({
    required String token,
    String? status,
    int? page,
    int? limit,
  }) async {
    final payload = await _rpc(
      'list_staff_orders',
      params: _compactParams({
        'p_status': status?.isNotEmpty == true ? status : null,
        'p_page': page,
        'p_limit': limit,
      }),
    );

    if (payload is List) {
      final items = payload
          .whereType<Map<String, dynamic>>()
          .map(CafeOrder.fromJson)
          .toList(growable: false);
      return PaginatedResponse<CafeOrder>(
        items: items,
        total: items.length,
        page: 1,
        limit: items.length,
        hasMore: false,
      );
    }

    if (payload is Map<String, dynamic>) {
      return PaginatedResponse<CafeOrder>.fromJson(payload, CafeOrder.fromJson);
    }

    throw const ApiException('Некорректный ответ API: список заказов.');
  }

  @override
  Future<CafeOrder> updateOrderStatus({
    required String token,
    required String orderId,
    required OrderStatus status,
  }) async {
    final payload = await _rpc(
      'update_order_status',
      params: {'p_order_id': orderId, 'p_status': status.value},
    );

    if (payload is! Map<String, dynamic>) {
      throw const ApiException(
        'Некорректный ответ API: обновление статуса заказа.',
      );
    }

    return CafeOrder.fromJson(payload);
  }

  @override
  Future<int> clearCompletedStaffOrders({required String token}) async {
    final payload = await _rpc('clear_completed_staff_orders');

    if (payload is num) {
      return payload.toInt();
    }

    throw const ApiException(
      'РќРµРєРѕСЂСЂРµРєС‚РЅС‹Р№ РѕС‚РІРµС‚ API: СЃР±СЂРѕСЃ Р·Р°РІРµСЂС€РµРЅРЅС‹С… Р·Р°РєР°Р·РѕРІ.',
    );
  }

  @override
  Future<Product> createProduct({
    required String token,
    required String categoryId,
    required String name,
    required double price,
    String description = '',
    String imageUrl = '',
    bool isAvailable = true,
    List<JsonMap> modifierGroups = const [],
  }) async {
    final payload = await _rpc(
      'upsert_product',
      params: {
        'p_product': <String, dynamic>{
          'categoryId': categoryId,
          'name': name,
          'price': price,
          'description': description,
          'imageUrl': imageUrl,
          'isAvailable': isAvailable,
          'modifierGroups': modifierGroups,
        },
      },
    );

    if (payload is! Map<String, dynamic>) {
      throw const ApiException('Некорректный ответ API: создание товара.');
    }

    return Product.fromJson(payload);
  }

  @override
  Future<Product> updateProduct({
    required String token,
    required String productId,
    String? categoryId,
    String? name,
    String? description,
    double? price,
    String? imageUrl,
    bool? isAvailable,
    List<JsonMap>? modifierGroups,
  }) async {
    final payload = await _rpc(
      'upsert_product',
      params: {
        'p_product': _compactParams({
          'id': productId,
          'categoryId': categoryId,
          'name': name,
          'description': description,
          'price': price,
          'imageUrl': imageUrl,
          'isAvailable': isAvailable,
          'modifierGroups': modifierGroups,
        }),
      },
    );

    if (payload is! Map<String, dynamic>) {
      throw const ApiException('Некорректный ответ API: обновление товара.');
    }

    return Product.fromJson(payload);
  }

  @override
  Future<Product> updateProductAvailability({
    required String token,
    required String productId,
    required bool isAvailable,
  }) async {
    final payload = await _rpc(
      'set_product_availability',
      params: {'p_product_id': productId, 'p_is_available': isAvailable},
    );

    if (payload is! Map<String, dynamic>) {
      throw const ApiException(
        'Некорректный ответ API: обновление доступности.',
      );
    }

    return Product.fromJson(payload);
  }

  @override
  Future<SalesReport> fetchSalesReport({
    required String token,
    DateTime? from,
    DateTime? to,
  }) async {
    final payload = await _rpc(
      'get_sales_report',
      params: _compactParams({
        'p_from': from?.toUtc().toIso8601String(),
        'p_to': to?.toUtc().toIso8601String(),
      }),
    );

    if (payload is! Map<String, dynamic>) {
      throw const ApiException('Некорректный ответ API: отчет продаж.');
    }

    return SalesReport.fromJson(payload);
  }

  SupabaseClient? get _configuredClientOrNull {
    return _client;
  }

  SupabaseClient _ensureConfigured() {
    final client = _client;
    if (client == null) {
      throw ApiException(
        _config.missingConfigurationMessage,
        kind: ApiErrorKind.server,
      );
    }
    return client;
  }

  Future<dynamic> _rpc(
    String functionName, {
    Map<String, dynamic>? params,
  }) async {
    final client = _ensureConfigured();

    try {
      return await client.rpc(functionName, params: params ?? const {});
    } on PostgrestException catch (error) {
      throw ApiException(
        _normalizePostgrestMessage(error),
        kind: ApiErrorKind.client,
      );
    } on AuthException catch (error) {
      throw ApiException(
        _normalizeAuthMessage(error.message),
        kind: ApiErrorKind.client,
      );
    } on TimeoutException {
      throw const ApiException(
        'Сервер не отвечает. Попробуйте позже.',
        kind: ApiErrorKind.timeout,
      );
    } catch (_) {
      throw const ApiException(
        'Нет соединения с сервером. Проверьте интернет.',
        kind: ApiErrorKind.network,
      );
    }
  }

  Future<StaffSession> _loadStaffSession(Session session) async {
    final client = _ensureConfigured();

    try {
      final profile = await client
          .from('staff_profiles')
          .select('display_name, role')
          .eq('id', session.user.id)
          .maybeSingle();

      if (profile == null) {
        await client.auth.signOut();
        throw const ApiException(
          'Для аккаунта не назначен профиль сотрудника.',
          kind: ApiErrorKind.client,
        );
      }

      final role = profile['role']?.toString() ?? '';
      if (role.isEmpty) {
        await client.auth.signOut();
        throw const ApiException(
          'Для аккаунта не назначена роль сотрудника.',
          kind: ApiErrorKind.client,
        );
      }

      return StaffSession(
        token: session.accessToken,
        role: role,
        name: profile['display_name']?.toString().trim().isNotEmpty == true
            ? profile['display_name']!.toString()
            : session.user.email ?? 'Staff',
      );
    } on PostgrestException catch (error) {
      throw ApiException(
        _normalizePostgrestMessage(error),
        kind: ApiErrorKind.client,
      );
    } on AuthException catch (error) {
      throw ApiException(
        _normalizeAuthMessage(error.message),
        kind: ApiErrorKind.client,
      );
    }
  }

  String _normalizeAuthMessage(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('invalid login credentials')) {
      return 'Неверный логин или пароль.';
    }
    if (normalized.contains('email not confirmed')) {
      return 'Подтвердите email перед входом.';
    }
    if (normalized.contains('invalid email')) {
      return 'Укажите корректный email.';
    }
    if (normalized.contains('missing configuration')) {
      return _config.missingConfigurationMessage;
    }
    return message;
  }

  String _normalizePostgrestMessage(PostgrestException error) {
    final message = error.message.trim();
    if (message.isNotEmpty) {
      return message;
    }
    return 'Ошибка базы данных Supabase.';
  }

  Map<String, dynamic> _compactParams(Map<String, Object?> raw) {
    final result = <String, dynamic>{};
    for (final entry in raw.entries) {
      if (entry.value != null) {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }
}
