import 'dart:convert';
import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import 'config.dart';
import 'models/models.dart';
import 'middleware/rate_limiter.dart';
import 'store/sqlite_store.dart';

class TechCafeApi {
  TechCafeApi(this._store, this._config) {
    router.get('/health', _healthCheck);
    router.post('/auth/login', _login);

    router.get('/categories', _getCategories);
    router.get('/products', _getProducts);
    router.get('/products/<id>', _getProductById);

    router.post('/orders', _createOrder);
    router.get('/orders', _listOrders);
    router.get('/orders/<key>', _getOrderByKey);
    router.patch('/orders/<id>/status', _changeOrderStatus);
    router.post('/payments/create', _createPaymentSession);
    router.get('/payments/<id>', _getPaymentById);
    router.post('/payments/<id>/confirm', _confirmPaymentSession);

    router.post('/products', _createProduct);
    router.patch('/products/<id>', _updateProduct);
    router.patch('/products/<id>/availability', _updateProductAvailability);

    router.get('/reports/sales', _getSalesReport);
  }

  final SqliteStore _store;
  final ServerConfig _config;
  late final RateLimiter _rateLimiter = RateLimiter(
    maxRequests: _config.rateLimitMaxRequests,
    window: _config.rateLimitWindow,
  );

  final Router router = Router();

  Response _healthCheck(Request request) {
    return _jsonResponse({'status': 'ok'});
  }

  Future<Response> _login(Request request) async {
    final body = await _readJsonBody(request);
    final pin = body['pin']?.toString();

    if (pin == null || pin.isEmpty) {
      return _errorResponse('PIN is required.', statusCode: 400);
    }

    final user = _store.staffByPin[pin];
    if (user == null) {
      return _errorResponse('Invalid PIN.', statusCode: 401);
    }

    final jwt = JWT({'sub': user.id, 'name': user.name, 'role': user.role});

    final token = jwt.sign(
      SecretKey(_config.jwtSecret),
      expiresIn: Duration(hours: _config.jwtExpiresInHours),
    );

    return _jsonResponse({
      'token': token,
      'role': user.role,
      'name': user.name,
      'expiresInHours': _config.jwtExpiresInHours,
    });
  }

  Response _getCategories(Request request) {
    final categories = _store.categories
        .map((category) => category.toJson())
        .toList(growable: false);

    return _jsonResponse(categories);
  }

  Response _getProducts(Request request) {
    final categoryId = request.url.queryParameters['categoryId'];
    final inStockOnly = request.url.queryParameters['inStock'] == 'true';

    final products = _store.products.values.where((product) {
      if (categoryId != null && product.categoryId != categoryId) {
        return false;
      }
      if (inStockOnly && !product.isAvailable) {
        return false;
      }
      return true;
    }).toList()..sort((a, b) => a.name.compareTo(b.name));

    final jsonList = products.map((p) => p.toJson()).toList(growable: false);
    return _paginatedOrPlain(request, jsonList);
  }

  Response _getProductById(Request request, String id) {
    final product = _store.products[id];
    if (product == null) {
      return _errorResponse('Product not found.', statusCode: 404);
    }

    return _jsonResponse(product.toJson());
  }

  Future<Response> _createOrder(Request request) async {
    final clientKey = _resolveClientKey(request);
    if (!_rateLimiter.allow(clientKey)) {
      return _errorResponse(
        'Too many order requests. Please try again later.',
        statusCode: 429,
      );
    }

    final body = await _readJsonBody(request);
    final rawItems = body['items'];
    final customerFirstName =
        body['customerFirstName']?.toString().trim() ?? '';
    final customerLastName = body['customerLastName']?.toString().trim() ?? '';
    final paymentMethodRaw = body['paymentMethod']?.toString();
    final paymentMethod =
        PaymentMethodX.fromValue(paymentMethodRaw) ?? PaymentMethod.payOnPickup;

    if (rawItems is! List || rawItems.isEmpty) {
      return _errorResponse('Order items are required.', statusCode: 400);
    }

    if (customerFirstName.isEmpty) {
      return _errorResponse(
        'Customer first name is required.',
        statusCode: 400,
      );
    }

    if (customerLastName.isEmpty) {
      return _errorResponse('Customer last name is required.', statusCode: 400);
    }

    final orderItems = <OrderItem>[];

    for (final rawItem in rawItems) {
      if (rawItem is! Map<String, dynamic>) {
        return _errorResponse('Invalid order item format.', statusCode: 400);
      }

      final productId = rawItem['productId']?.toString();
      final qty = rawItem['qty'];

      if (productId == null || productId.isEmpty) {
        return _errorResponse(
          'Every item must include productId.',
          statusCode: 400,
        );
      }

      if (qty is! int || qty <= 0) {
        return _errorResponse(
          'Every item must include qty > 0.',
          statusCode: 400,
        );
      }

      final product = _store.products[productId];
      if (product == null) {
        return _errorResponse(
          'Product "$productId" not found.',
          statusCode: 400,
        );
      }

      if (!product.isAvailable) {
        return _errorResponse(
          'Product "${product.name}" is not available.',
          statusCode: 400,
        );
      }

      final modifiers = _parseOrderModifiers(rawItem['modifiers']);
      if (modifiers == null) {
        return _errorResponse('Invalid modifiers format.', statusCode: 400);
      }

      orderItems.add(
        OrderItem(
          id: const Uuid().v4(),
          productId: product.id,
          nameSnapshot: product.name,
          priceSnapshot: product.price,
          qty: qty,
          modifiers: modifiers,
        ),
      );
    }

    final total = orderItems.fold<double>(
      0,
      (sum, item) => sum + item.lineTotal,
    );
    final now = DateTime.now().toUtc();

    final order = CafeOrder(
      id: const Uuid().v4(),
      orderNumber: _store.nextOrderNumber(),
      createdAt: now,
      customerFirstName: customerFirstName,
      customerLastName: customerLastName,
      status: OrderStatus.created,
      total: total,
      comment: body['comment']?.toString().trim(),
      paymentMethod: paymentMethod,
      paymentStatus: paymentMethod == PaymentMethod.onlineCard
          ? PaymentStatus.pending
          : PaymentStatus.unpaid,
      providerPaymentId: null,
      paidAt: null,
      items: orderItems,
    );

    _store.saveOrder(order);

    return _jsonResponse({
      'orderId': order.id,
      'orderNumber': order.orderNumber,
      'qrCodeData': order.id,
      'customerFirstName': order.customerFirstName,
      'customerLastName': order.customerLastName,
      'status': order.status.value,
      'total': order.total,
      'createdAt': order.createdAt.toIso8601String(),
      'paymentMethod': order.paymentMethod.value,
      'paymentStatus': order.paymentStatus.value,
      'providerPaymentId': order.providerPaymentId,
      'paidAt': order.paidAt?.toIso8601String(),
    }, statusCode: 201);
  }

  Future<Response> _createPaymentSession(Request request) async {
    final body = await _readJsonBody(request);
    final orderId = body['orderId']?.toString();

    if (orderId == null || orderId.isEmpty) {
      return _errorResponse('orderId is required.', statusCode: 400);
    }

    final order = _store.ordersById[orderId];
    if (order == null) {
      return _errorResponse('Order not found.', statusCode: 404);
    }

    if (order.paymentMethod != PaymentMethod.onlineCard) {
      return _errorResponse(
        'Online payment is not enabled for this order.',
        statusCode: 400,
      );
    }

    final existingPaymentId = _store.paymentIdByOrderId[order.id];
    if (existingPaymentId != null) {
      final existingPayment = _store.paymentsById[existingPaymentId];
      if (existingPayment != null) {
        return _jsonResponse(existingPayment.toJson());
      }
    }

    final now = DateTime.now().toUtc();
    final paymentSession = PaymentSession(
      id: const Uuid().v4(),
      orderId: order.id,
      amount: order.total,
      status: PaymentSessionStatus.created,
      checkoutUrl: 'https://pay.techcafe.local/session/${const Uuid().v4()}',
      createdAt: now,
      updatedAt: now,
    );

    _store.savePayment(paymentSession);
    final updatedOrder = order.copyWith(providerPaymentId: paymentSession.id);
    _store.saveOrder(updatedOrder);

    return _jsonResponse(paymentSession.toJson(), statusCode: 201);
  }

  Response _getPaymentById(Request request, String id) {
    final payment = _store.paymentsById[id];
    if (payment == null) {
      return _errorResponse('Payment session not found.', statusCode: 404);
    }

    return _jsonResponse(payment.toJson());
  }

  Future<Response> _confirmPaymentSession(Request request, String id) async {
    final payment = _store.paymentsById[id];
    if (payment == null) {
      return _errorResponse('Payment session not found.', statusCode: 404);
    }

    final order = _store.ordersById[payment.orderId];
    if (order == null) {
      return _errorResponse('Order not found.', statusCode: 404);
    }

    final body = await _readJsonBody(request);
    final success = body['success'];
    if (success is! bool) {
      return _errorResponse('success boolean is required.', statusCode: 400);
    }

    if (payment.status == PaymentSessionStatus.succeeded ||
        payment.status == PaymentSessionStatus.failed) {
      return _jsonResponse({
        'payment': payment.toJson(),
        'order': order.toJson(),
      });
    }

    final now = DateTime.now().toUtc();
    final paymentStatus = success
        ? PaymentSessionStatus.succeeded
        : PaymentSessionStatus.failed;
    final updatedPayment = payment.copyWith(
      status: paymentStatus,
      updatedAt: now,
    );
    _store.savePayment(updatedPayment);

    final updatedOrder = order.copyWith(
      paymentStatus: success ? PaymentStatus.paid : PaymentStatus.failed,
      paidAt: success ? now : null,
      providerPaymentId: updatedPayment.id,
    );
    _store.saveOrder(updatedOrder);

    return _jsonResponse({
      'payment': updatedPayment.toJson(),
      'order': updatedOrder.toJson(),
    });
  }

  Response _getOrderByKey(Request request, String key) {
    CafeOrder? order = _store.ordersById[key];
    order ??= _store.orderByNumber(key);

    if (order == null) {
      return _errorResponse('Order not found.', statusCode: 404);
    }

    return _jsonResponse(order.toJson());
  }

  Future<Response> _changeOrderStatus(Request request, String id) async {
    final auth = _authorize(
      request,
      allowedRoles: {'cashier', 'barista', 'admin'},
    );
    if (auth.error != null) {
      return auth.error!;
    }

    final order = _store.ordersById[id];
    if (order == null) {
      return _errorResponse('Order not found.', statusCode: 404);
    }

    final body = await _readJsonBody(request);
    final nextStatus = body['status']?.toString();
    final status = OrderStatusX.fromValue(nextStatus);

    if (status == null) {
      return _errorResponse('Invalid status value.', statusCode: 400);
    }

    final updated = order.copyWith(status: status);
    _store.saveOrder(updated);

    return _jsonResponse(updated.toJson());
  }

  Response _listOrders(Request request) {
    final auth = _authorize(
      request,
      allowedRoles: {'cashier', 'barista', 'admin'},
    );
    if (auth.error != null) {
      return auth.error!;
    }

    final statusFilter = request.url.queryParameters['status'];
    final orders = _store.ordersById.values.where((order) {
      if (statusFilter == null || statusFilter.isEmpty) {
        return true;
      }
      return order.status.value == statusFilter;
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final jsonList = orders.map((o) => o.toJson()).toList(growable: false);
    return _paginatedOrPlain(request, jsonList);
  }

  Future<Response> _createProduct(Request request) async {
    final auth = _authorize(request, allowedRoles: {'admin'});
    if (auth.error != null) {
      return auth.error!;
    }

    final body = await _readJsonBody(request);

    final categoryId = body['categoryId']?.toString();
    final name = body['name']?.toString();
    final price = _asDouble(body['price']);

    if (categoryId == null || name == null || price == null) {
      return _errorResponse(
        'categoryId, name and price are required.',
        statusCode: 400,
      );
    }

    final product = Product(
      id: body['id']?.toString() ?? const Uuid().v4(),
      categoryId: categoryId,
      name: name,
      description: body['description']?.toString() ?? '',
      price: price,
      imageUrl: body['imageUrl']?.toString() ?? '',
      isAvailable: body['isAvailable'] is bool
          ? body['isAvailable'] as bool
          : true,
      modifierGroups: _parseModifierGroups(body['modifierGroups']),
    );

    _store.products[product.id] = product;

    return _jsonResponse(product.toJson(), statusCode: 201);
  }

  Future<Response> _updateProduct(Request request, String id) async {
    final auth = _authorize(request, allowedRoles: {'admin'});
    if (auth.error != null) {
      return auth.error!;
    }

    final existing = _store.products[id];
    if (existing == null) {
      return _errorResponse('Product not found.', statusCode: 404);
    }

    final body = await _readJsonBody(request);

    final updated = existing.copyWith(
      categoryId: body['categoryId']?.toString(),
      name: body['name']?.toString(),
      description: body.containsKey('description')
          ? body['description']?.toString()
          : null,
      price: body.containsKey('price') ? _asDouble(body['price']) : null,
      imageUrl: body.containsKey('imageUrl')
          ? body['imageUrl']?.toString()
          : null,
      isAvailable: body['isAvailable'] is bool
          ? body['isAvailable'] as bool
          : null,
      modifierGroups: body.containsKey('modifierGroups')
          ? _parseModifierGroups(body['modifierGroups'])
          : null,
    );

    _store.products[id] = updated;

    return _jsonResponse(updated.toJson());
  }

  Future<Response> _updateProductAvailability(
    Request request,
    String id,
  ) async {
    final auth = _authorize(request, allowedRoles: {'admin'});
    if (auth.error != null) {
      return auth.error!;
    }

    final existing = _store.products[id];
    if (existing == null) {
      return _errorResponse('Product not found.', statusCode: 404);
    }

    final body = await _readJsonBody(request);
    final isAvailable = body['isAvailable'];

    if (isAvailable is! bool) {
      return _errorResponse(
        'isAvailable boolean is required.',
        statusCode: 400,
      );
    }

    final updated = existing.copyWith(isAvailable: isAvailable);
    _store.products[id] = updated;

    return _jsonResponse(updated.toJson());
  }

  Response _getSalesReport(Request request) {
    final auth = _authorize(request, allowedRoles: {'admin'});
    if (auth.error != null) {
      return auth.error!;
    }

    final fromRaw = request.url.queryParameters['from'];
    final toRaw = request.url.queryParameters['to'];

    DateTime? from;
    DateTime? to;

    if (fromRaw != null && fromRaw.isNotEmpty) {
      from = DateTime.tryParse(fromRaw)?.toUtc();
      if (from == null) {
        return _errorResponse('Invalid from date format.', statusCode: 400);
      }
    }

    if (toRaw != null && toRaw.isNotEmpty) {
      to = DateTime.tryParse(toRaw)?.toUtc();
      if (to == null) {
        return _errorResponse('Invalid to date format.', statusCode: 400);
      }
    }

    final filteredOrders = _store.ordersById.values.where((order) {
      final createdAt = order.createdAt;
      if (from != null && createdAt.isBefore(from)) {
        return false;
      }
      if (to != null && createdAt.isAfter(to)) {
        return false;
      }
      return true;
    }).toList();

    final nonCanceledOrders = filteredOrders
        .where((order) => order.status != OrderStatus.canceled)
        .toList();

    final totalRevenue = nonCanceledOrders.fold<double>(
      0,
      (sum, order) => sum + order.total,
    );
    final itemsSold = nonCanceledOrders.fold<int>(
      0,
      (sum, order) =>
          sum + order.items.fold<int>(0, (inner, item) => inner + item.qty),
    );

    final byStatus = <String, int>{};
    final ordersByDay = <String, int>{};
    final revenueByDay = <String, double>{};

    String dayKey(DateTime value) {
      final utcDay = DateTime.utc(value.year, value.month, value.day);
      final year = utcDay.year.toString().padLeft(4, '0');
      final month = utcDay.month.toString().padLeft(2, '0');
      final day = utcDay.day.toString().padLeft(2, '0');
      return '$year-$month-$day';
    }

    for (final order in filteredOrders) {
      final key = dayKey(order.createdAt.toUtc());
      byStatus.update(
        order.status.value,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      ordersByDay.update(key, (count) => count + 1, ifAbsent: () => 1);
      if (order.status != OrderStatus.canceled) {
        revenueByDay.update(
          key,
          (sum) => sum + order.total,
          ifAbsent: () => order.total,
        );
      }
    }

    if (from != null && to != null) {
      final startDay = DateTime.utc(from.year, from.month, from.day);
      final inclusiveEnd = to.subtract(const Duration(milliseconds: 1));
      final endDay = DateTime.utc(
        inclusiveEnd.year,
        inclusiveEnd.month,
        inclusiveEnd.day,
      );

      for (
        var cursor = startDay;
        !cursor.isAfter(endDay);
        cursor = cursor.add(const Duration(days: 1))
      ) {
        final key = dayKey(cursor);
        ordersByDay.putIfAbsent(key, () => 0);
        revenueByDay.putIfAbsent(key, () => 0);
      }
    }

    return _jsonResponse({
      'from': from?.toIso8601String(),
      'to': to?.toIso8601String(),
      'ordersCount': filteredOrders.length,
      'nonCanceledOrdersCount': nonCanceledOrders.length,
      'itemsSold': itemsSold,
      'totalRevenue': totalRevenue,
      'byStatus': byStatus,
      'ordersByDay': ordersByDay,
      'revenueByDay': revenueByDay,
    });
  }

  List<OrderItemModifier>? _parseOrderModifiers(Object? raw) {
    if (raw == null) {
      return <OrderItemModifier>[];
    }

    if (raw is! List) {
      return null;
    }

    final modifiers = <OrderItemModifier>[];

    for (final entry in raw) {
      if (entry is! Map<String, dynamic>) {
        return null;
      }

      final name = entry['name']?.toString();
      final priceDelta = _asDouble(entry['priceDelta']);

      if (name == null || priceDelta == null) {
        return null;
      }

      modifiers.add(
        OrderItemModifier(nameSnapshot: name, priceDeltaSnapshot: priceDelta),
      );
    }

    return modifiers;
  }

  List<ModifierGroup> _parseModifierGroups(Object? raw) {
    if (raw == null) {
      return <ModifierGroup>[];
    }

    if (raw is! List) {
      throw const FormatException('modifierGroups must be a list.');
    }

    return raw
        .map((groupRaw) {
          if (groupRaw is! Map<String, dynamic>) {
            throw const FormatException('modifierGroup format is invalid.');
          }

          final groupId = groupRaw['id']?.toString() ?? const Uuid().v4();
          final groupName = groupRaw['name']?.toString();
          final min = (groupRaw['min'] as num?)?.toInt() ?? 0;
          final max = (groupRaw['max'] as num?)?.toInt() ?? 1;
          final rawItems = groupRaw['items'];

          if (groupName == null || rawItems is! List) {
            throw const FormatException(
              'modifierGroup requires name and items.',
            );
          }

          final items = rawItems
              .map((itemRaw) {
                if (itemRaw is! Map<String, dynamic>) {
                  throw const FormatException(
                    'modifierItem format is invalid.',
                  );
                }

                final itemName = itemRaw['name']?.toString();
                final priceDelta = _asDouble(itemRaw['priceDelta']);

                if (itemName == null || priceDelta == null) {
                  throw const FormatException(
                    'modifierItem requires name and priceDelta.',
                  );
                }

                return ModifierItem(
                  id: itemRaw['id']?.toString() ?? const Uuid().v4(),
                  name: itemName,
                  priceDelta: priceDelta,
                );
              })
              .toList(growable: false);

          return ModifierGroup(
            id: groupId,
            name: groupName,
            min: min,
            max: max,
            items: items,
          );
        })
        .toList(growable: false);
  }

  AuthResult _authorize(Request request, {required Set<String> allowedRoles}) {
    final authHeader = request.headers['authorization'];

    if (authHeader == null || !authHeader.toLowerCase().startsWith('bearer ')) {
      return AuthResult(
        error: _errorResponse('Missing bearer token.', statusCode: 401),
      );
    }

    final token = authHeader.substring(7).trim();

    try {
      final jwt = JWT.verify(token, SecretKey(_config.jwtSecret));
      final payload = jwt.payload;

      final userId = payload['sub']?.toString();
      final role = payload['role']?.toString();
      final name = payload['name']?.toString() ?? 'Staff';

      if (userId == null || role == null) {
        return AuthResult(
          error: _errorResponse('Invalid token payload.', statusCode: 401),
        );
      }

      if (!allowedRoles.contains(role)) {
        return AuthResult(
          error: _errorResponse('Forbidden for role $role.', statusCode: 403),
        );
      }

      return AuthResult(
        session: StaffSession(userId: userId, role: role, name: name),
      );
    } on JWTException {
      return AuthResult(
        error: _errorResponse('Invalid or expired token.', statusCode: 401),
      );
    }
  }

  String _resolveClientKey(Request request) {
    final forwardedFor = request.headers['x-forwarded-for'];
    if (forwardedFor != null && forwardedFor.isNotEmpty) {
      return forwardedFor.split(',').first.trim();
    }

    final connectionInfo = request.context['shelf.io.connection_info'];
    if (connectionInfo is HttpConnectionInfo) {
      return connectionInfo.remoteAddress.address;
    }

    return 'unknown';
  }

  Future<JsonMap> _readJsonBody(Request request) async {
    final bodyText = await request.readAsString();
    if (bodyText.trim().isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(bodyText);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw const FormatException('JSON body must be an object.');
    } on FormatException {
      throw const HttpException('Request body must be a valid JSON object.');
    }
  }

  Response _paginatedOrPlain(Request request, List<Object?> allItems) {
    final pageRaw = request.url.queryParameters['page'];
    if (pageRaw == null) {
      return _jsonResponse(allItems);
    }

    final page = int.tryParse(pageRaw) ?? 1;
    final limit =
        int.tryParse(request.url.queryParameters['limit'] ?? '') ?? 20;

    final safePage = page < 1 ? 1 : page;
    final safeLimit = limit < 1 ? 20 : limit;

    final start = (safePage - 1) * safeLimit;
    final end = start + safeLimit;
    final sliced = start >= allItems.length
        ? <Object?>[]
        : allItems.sublist(
            start,
            end > allItems.length ? allItems.length : end,
          );

    return _jsonResponse({
      'items': sliced,
      'total': allItems.length,
      'page': safePage,
      'limit': safeLimit,
      'hasMore': end < allItems.length,
    });
  }

  Response _jsonResponse(Object payload, {int statusCode = 200}) {
    return Response(
      statusCode,
      body: jsonEncode(payload),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
    );
  }

  Response _errorResponse(String message, {int statusCode = 400}) {
    return _jsonResponse({'error': message}, statusCode: statusCode);
  }

  double? _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return null;
  }
}
