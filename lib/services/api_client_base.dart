import '../models/models.dart';
import '../utils/formatters.dart';

abstract class ApiClientBase {
  Future<List<PickupSlot>> fetchPickupSlots({bool admin = false});
  Future<void> savePickupSlot({
    String? id,
    required DateTime startsAt,
    required DateTime cutoffAt,
    required int capacity,
    bool enabled = true,
  });
  Future<void> setProductStock(String productId, int? remaining);
  Future<CafeOrder> inspectPickupCode(String code);
  Future<CafeOrder> redeemPickupCode(
    String code, {
    bool paymentReceived = false,
  });

  Future<List<Category>> fetchCategories();

  Future<StaffSession?> restoreStaffSession();

  Future<PaginatedResponse<Product>> fetchProducts({
    String? categoryId,
    bool inStockOnly = false,
    int? page,
    int? limit,
  });

  Future<OrderCreatedResponse> createOrder({
    required List<CartItem> items,
    required String firstName,
    required String lastName,
    required String comment,
    required PaymentMethod paymentMethod,
    String? pickupSlotId,
  });

  Future<CafeOrder> getOrder(String key);

  Future<StaffSession> loginStaff({
    required String email,
    required String password,
  });

  Future<void> logoutStaff();

  Future<PaginatedResponse<CafeOrder>> fetchStaffOrders({
    required String token,
    String? status,
    int? page,
    int? limit,
  });

  Future<CafeOrder> updateOrderStatus({
    required String token,
    required String orderId,
    required OrderStatus status,
  });

  Future<int> clearCompletedStaffOrders({required String token});

  Future<Product> createProduct({
    required String token,
    required String categoryId,
    required String name,
    required double price,
    String description = '',
    String imageUrl = '',
    bool isAvailable = true,
    List<JsonMap> modifierGroups = const [],
  });

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
  });

  Future<Product> updateProductAvailability({
    required String token,
    required String productId,
    required bool isAvailable,
  });

  Future<SalesReport> fetchSalesReport({
    required String token,
    DateTime? from,
    DateTime? to,
  });

  Future<PaymentSession> createPaymentSession({required String orderId});

  Future<PaymentConfirmationResult> confirmPaymentSession({
    required String paymentId,
    required bool success,
  });
}
