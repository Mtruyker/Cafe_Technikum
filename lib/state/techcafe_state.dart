import 'dart:async';

import 'package:flutter/foundation.dart' hide Category;

import '../models/models.dart';
import '../services/api_client_base.dart';
import '../services/api_exception.dart';
import '../services/local_orders_store_base.dart';
import '../utils/formatters.dart';

class TechCafeState extends ChangeNotifier {
  TechCafeState({
    required ApiClientBase apiClient,
    required LocalOrdersStoreBase localOrdersStore,
  }) : _apiClient = apiClient,
       _localOrdersStore = localOrdersStore {
    unawaited(initialize());
  }

  final ApiClientBase _apiClient;
  final LocalOrdersStoreBase _localOrdersStore;

  bool isInitializing = true;
  bool isMenuLoading = false;
  bool isTracking = false;
  bool isStaffAuthLoading = false;
  bool isStaffOrdersLoading = false;
  bool isAdminProductsLoading = false;
  bool isSalesReportLoading = false;
  bool isClearingCompletedStaffOrders = false;
  bool isLoadingMoreProducts = false;
  bool isLoadingMoreStaffOrders = false;

  bool hasMoreProducts = false;
  bool hasMoreStaffOrders = false;

  int _productsPage = 1;
  int _staffOrdersPage = 1;

  static const _pageLimit = 20;

  String? initializationError;
  String? trackingError;
  String? staffError;

  List<Category> categories = const [];
  List<Product> products = const [];
  List<CartItem> cartItems = const [];
  List<LocalOrderRecord> recentOrders = const [];
  List<CafeOrder> staffOrders = const [];
  List<Product> adminProducts = const [];

  String? selectedCategoryId;
  String searchQuery = '';
  bool inStockOnly = false;
  String staffStatusFilter = '';

  CafeOrder? trackedOrder;
  StaffSession? staffSession;
  SalesReport? salesReport;

  int get cartItemsCount =>
      cartItems.fold<int>(0, (sum, item) => sum + item.qty);

  double get cartTotal =>
      cartItems.fold<double>(0, (sum, item) => sum + item.lineTotal);

  bool get isStaffLoggedIn => staffSession != null;
  bool get isAdmin => staffSession?.isAdmin == true;
  bool get hasActiveCatalogFilters =>
      searchQuery.trim().isNotEmpty ||
      inStockOnly ||
      (categories.isNotEmpty && selectedCategoryId != categories.first.id);

  List<Product> get visibleProducts {
    final query = searchQuery.trim().toLowerCase();

    return products
        .where((product) {
          if (query.isNotEmpty && !product.name.toLowerCase().contains(query)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  Future<void> initialize() async {
    isInitializing = true;
    initializationError = null;
    notifyListeners();

    try {
      categories = await _apiClient.fetchCategories();
      selectedCategoryId = categories.isNotEmpty ? categories.first.id : null;

      await Future.wait([_reloadProducts(), reloadRecentOrders()]);
      staffSession = await _apiClient.restoreStaffSession();
      if (staffSession != null) {
        await loadStaffOrders();
        if (isAdmin) {
          await Future.wait([loadAdminProducts(), loadSalesReport()]);
        }
      }
    } on ApiException catch (error) {
      initializationError = error.message;
    } catch (_) {
      initializationError = 'Нет соединения с сервером. Проверьте интернет.';
    } finally {
      isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> refreshMenu() => _reloadProducts();

  Future<void> selectCategory(String categoryId) async {
    selectedCategoryId = categoryId;
    notifyListeners();
    await _reloadProducts();
  }

  Future<void> setInStockOnly(bool value) async {
    inStockOnly = value;
    notifyListeners();
    await _reloadProducts();
  }

  void setSearchQuery(String value) {
    searchQuery = value;
    notifyListeners();
  }

  Future<void> resetCatalogFilters() async {
    final defaultCategoryId = categories.isNotEmpty
        ? categories.first.id
        : selectedCategoryId;
    final shouldReload = inStockOnly || selectedCategoryId != defaultCategoryId;

    searchQuery = '';
    inStockOnly = false;
    selectedCategoryId = defaultCategoryId;

    if (!shouldReload) {
      notifyListeners();
      return;
    }

    notifyListeners();
    await _reloadProducts();
  }

  Future<void> _reloadProducts() async {
    isMenuLoading = true;
    initializationError = null;
    _productsPage = 1;
    hasMoreProducts = false;
    notifyListeners();

    try {
      final response = await _apiClient.fetchProducts(
        categoryId: selectedCategoryId,
        inStockOnly: inStockOnly,
        page: 1,
        limit: _pageLimit,
      );
      products = response.items;
      hasMoreProducts = response.hasMore;
      _productsPage = 1;
    } on ApiException catch (error) {
      initializationError = error.message;
    } catch (_) {
      initializationError = 'Нет соединения с сервером. Проверьте интернет.';
    } finally {
      isMenuLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreProducts() async {
    if (isLoadingMoreProducts || !hasMoreProducts) return;

    isLoadingMoreProducts = true;
    notifyListeners();

    try {
      final response = await _apiClient.fetchProducts(
        categoryId: selectedCategoryId,
        inStockOnly: inStockOnly,
        page: _productsPage + 1,
        limit: _pageLimit,
      );
      products = [...products, ...response.items];
      hasMoreProducts = response.hasMore;
      _productsPage++;
    } on ApiException catch (_) {
      // Молча игнорируем — основной список уже загружен
    } finally {
      isLoadingMoreProducts = false;
      notifyListeners();
    }
  }

  void addToCart(Product product, List<SelectedModifier> modifiers) {
    final item = CartItem(product: product, modifiers: modifiers, qty: 1);

    final mutable = [...cartItems];
    final index = mutable.indexWhere(
      (entry) => entry.signature == item.signature,
    );

    if (index == -1) {
      mutable.add(item);
    } else {
      final existing = mutable[index];
      mutable[index] = existing.copyWith(qty: existing.qty + 1);
    }

    cartItems = mutable;
    notifyListeners();
  }

  void setCartItemQty(CartItem target, int qty) {
    final mutable = [...cartItems];
    final index = mutable.indexWhere(
      (entry) => entry.signature == target.signature,
    );
    if (index == -1) {
      return;
    }

    if (qty <= 0) {
      mutable.removeAt(index);
    } else {
      mutable[index] = mutable[index].copyWith(qty: qty);
    }

    cartItems = mutable;
    notifyListeners();
  }

  void clearCart() {
    cartItems = const [];
    notifyListeners();
  }

  Future<OrderCreatedResponse> placeOrder({
    required String firstName,
    required String lastName,
    required String comment,
    required PaymentMethod paymentMethod,
  }) async {
    if (cartItems.isEmpty) {
      throw const ApiException('Корзина пуста.');
    }

    final normalizedFirstName = firstName.trim();
    final normalizedLastName = lastName.trim();

    if (normalizedFirstName.isEmpty) {
      throw const ApiException('Укажите имя.');
    }

    if (normalizedLastName.isEmpty) {
      throw const ApiException('Укажите фамилию.');
    }

    final response = await _apiClient.createOrder(
      items: cartItems,
      firstName: normalizedFirstName,
      lastName: normalizedLastName,
      comment: comment,
      paymentMethod: paymentMethod,
    );

    final localRecord = LocalOrderRecord(
      orderId: response.orderId,
      orderNumber: response.orderNumber,
      createdAt: response.createdAt,
      total: response.total,
      status: response.status,
    );

    await _localOrdersStore.save(localRecord);
    await reloadRecentOrders();
    clearCart();

    return response;
  }

  Future<PaymentSession> createPaymentSession({required String orderId}) {
    return _apiClient.createPaymentSession(orderId: orderId);
  }

  Future<PaymentConfirmationResult> confirmPaymentSession({
    required String paymentId,
    required bool success,
  }) async {
    final result = await _apiClient.confirmPaymentSession(
      paymentId: paymentId,
      success: success,
    );

    if (trackedOrder?.id == result.order.id) {
      trackedOrder = result.order;
    }
    notifyListeners();
    return result;
  }

  Future<CafeOrder> trackOrder(String key) async {
    final value = key.trim();
    if (value.isEmpty) {
      trackedOrder = null;
      trackingError = 'Введите номер заказа или ID.';
      notifyListeners();
      throw const ApiException('Введите номер заказа или ID.');
    }

    isTracking = true;
    trackedOrder = null;
    trackingError = null;
    notifyListeners();

    try {
      final order = await _apiClient.getOrder(value);
      trackedOrder = order;

      await _localOrdersStore.save(
        LocalOrderRecord(
          orderId: order.id,
          orderNumber: order.orderNumber,
          createdAt: order.createdAt,
          total: order.total,
          status: order.status,
        ),
      );

      await reloadRecentOrders();

      return order;
    } on ApiException catch (error) {
      trackedOrder = null;
      trackingError = error.message;
      rethrow;
    } finally {
      isTracking = false;
      notifyListeners();
    }
  }

  Future<void> loginStaff({
    required String email,
    required String password,
  }) async {
    if (email.trim().isEmpty || password.isEmpty) {
      throw const ApiException('Введите логин и пароль.');
    }

    isStaffAuthLoading = true;
    staffError = null;
    notifyListeners();

    try {
      staffSession = await _apiClient.loginStaff(
        email: email,
        password: password,
      );
      await loadStaffOrders();
      if (isAdmin) {
        await Future.wait([loadAdminProducts(), loadSalesReport()]);
      }
    } on ApiException catch (error) {
      staffError = error.message;
      rethrow;
    } finally {
      isStaffAuthLoading = false;
      notifyListeners();
    }
  }

  void logoutStaff() {
    unawaited(_apiClient.logoutStaff());
    staffSession = null;
    staffOrders = const [];
    adminProducts = const [];
    salesReport = null;
    staffStatusFilter = '';
    staffError = null;
    isClearingCompletedStaffOrders = false;
    notifyListeners();
  }

  Future<void> loadStaffOrders({String? status}) async {
    final session = staffSession;
    if (session == null) {
      throw const ApiException('Сначала выполните вход.');
    }

    isStaffOrdersLoading = true;
    staffError = null;
    _staffOrdersPage = 1;
    hasMoreStaffOrders = false;
    if (status != null) {
      staffStatusFilter = status;
    }
    notifyListeners();

    try {
      final response = await _apiClient.fetchStaffOrders(
        token: session.token,
        status: staffStatusFilter.isEmpty ? null : staffStatusFilter,
        page: 1,
        limit: _pageLimit,
      );
      staffOrders = response.items;
      hasMoreStaffOrders = response.hasMore;
      _staffOrdersPage = 1;
    } on ApiException catch (error) {
      staffError = error.message;
      rethrow;
    } finally {
      isStaffOrdersLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreStaffOrders() async {
    if (isLoadingMoreStaffOrders || !hasMoreStaffOrders) return;
    final session = staffSession;
    if (session == null) return;

    isLoadingMoreStaffOrders = true;
    notifyListeners();

    try {
      final response = await _apiClient.fetchStaffOrders(
        token: session.token,
        status: staffStatusFilter.isEmpty ? null : staffStatusFilter,
        page: _staffOrdersPage + 1,
        limit: _pageLimit,
      );
      staffOrders = [...staffOrders, ...response.items];
      hasMoreStaffOrders = response.hasMore;
      _staffOrdersPage++;
    } on ApiException catch (_) {
      // Молча игнорируем — основной список уже загружен
    } finally {
      isLoadingMoreStaffOrders = false;
      notifyListeners();
    }
  }

  Future<void> changeOrderStatus(CafeOrder order, OrderStatus status) async {
    final session = staffSession;
    if (session == null) {
      throw const ApiException('Сначала выполните вход.');
    }

    final updated = await _apiClient.updateOrderStatus(
      token: session.token,
      orderId: order.id,
      status: status,
    );

    staffOrders = staffOrders
        .map((entry) {
          if (entry.id == updated.id) {
            return updated;
          }
          return entry;
        })
        .toList(growable: false);

    await _localOrdersStore.updateStatus(
      orderId: updated.id,
      status: updated.status,
    );
    notifyListeners();
  }

  Future<int> clearCompletedStaffOrders() async {
    final session = staffSession;
    if (session == null || !session.isAdmin) {
      throw const ApiException(
        'РўСЂРµР±СѓРµС‚СЃСЏ СЂРѕР»СЊ Р°РґРјРёРЅРёСЃС‚СЂР°С‚РѕСЂР°.',
      );
    }

    isClearingCompletedStaffOrders = true;
    staffError = null;
    notifyListeners();

    try {
      final clearedCount = await _apiClient.clearCompletedStaffOrders(
        token: session.token,
      );

      if (clearedCount > 0) {
        await loadStaffOrders(status: staffStatusFilter);
      }

      return clearedCount;
    } on ApiException catch (error) {
      staffError = error.message;
      rethrow;
    } finally {
      isClearingCompletedStaffOrders = false;
      notifyListeners();
    }
  }

  Future<void> loadAdminProducts() async {
    final session = staffSession;
    if (session == null || !session.isAdmin) {
      throw const ApiException('Требуется роль администратора.');
    }

    isAdminProductsLoading = true;
    staffError = null;
    notifyListeners();

    try {
      final response = await _apiClient.fetchProducts();
      adminProducts = response.items;
      adminProducts = [...adminProducts]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } on ApiException catch (error) {
      staffError = error.message;
      rethrow;
    } finally {
      isAdminProductsLoading = false;
      notifyListeners();
    }
  }

  Future<void> setAdminProductAvailability({
    required Product product,
    required bool isAvailable,
  }) async {
    final session = staffSession;
    if (session == null || !session.isAdmin) {
      throw const ApiException('Требуется роль администратора.');
    }

    final updated = await _apiClient.updateProductAvailability(
      token: session.token,
      productId: product.id,
      isAvailable: isAvailable,
    );
    _replaceAdminProduct(updated);
  }

  Future<void> saveAdminProduct({
    required String categoryId,
    required String name,
    required double price,
    required String description,
    required String imageUrl,
    required bool isAvailable,
    required List<JsonMap> modifierGroups,
    String? productId,
  }) async {
    final session = staffSession;
    if (session == null || !session.isAdmin) {
      throw const ApiException('Требуется роль администратора.');
    }

    final cleanedName = name.trim();
    if (cleanedName.isEmpty) {
      throw const ApiException('Название обязательно.');
    }

    if (price <= 0) {
      throw const ApiException('Цена должна быть больше 0.');
    }

    final updated = productId == null
        ? await _apiClient.createProduct(
            token: session.token,
            categoryId: categoryId,
            name: cleanedName,
            price: price,
            description: description.trim(),
            imageUrl: imageUrl.trim(),
            isAvailable: isAvailable,
            modifierGroups: modifierGroups,
          )
        : await _apiClient.updateProduct(
            token: session.token,
            productId: productId,
            categoryId: categoryId,
            name: cleanedName,
            price: price,
            description: description.trim(),
            imageUrl: imageUrl.trim(),
            isAvailable: isAvailable,
            modifierGroups: modifierGroups,
          );

    _replaceAdminProduct(updated);
  }

  Future<void> loadSalesReport({DateTime? from, DateTime? to}) async {
    final session = staffSession;
    if (session == null || !session.isAdmin) {
      throw const ApiException('Требуется роль администратора.');
    }

    isSalesReportLoading = true;
    staffError = null;
    notifyListeners();

    try {
      salesReport = await _apiClient.fetchSalesReport(
        token: session.token,
        from: from,
        to: to,
      );
    } on ApiException catch (error) {
      staffError = error.message;
      rethrow;
    } finally {
      isSalesReportLoading = false;
      notifyListeners();
    }
  }

  void _replaceAdminProduct(Product product) {
    final mutable = [...adminProducts];
    final index = mutable.indexWhere((entry) => entry.id == product.id);
    if (index == -1) {
      mutable.add(product);
    } else {
      mutable[index] = product;
    }
    mutable.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    adminProducts = mutable;
    notifyListeners();
  }

  Future<void> reloadRecentOrders() async {
    recentOrders = await _localOrdersStore.load();
    notifyListeners();
  }

  Future<void> removeRecentOrder(String orderId) async {
    await _localOrdersStore.remove(orderId);
    recentOrders = recentOrders
        .where((entry) => entry.orderId != orderId)
        .toList(growable: false);
    notifyListeners();
  }

  Future<void> clearRecentOrders() async {
    await _localOrdersStore.clear();
    recentOrders = const [];
    notifyListeners();
  }
}
