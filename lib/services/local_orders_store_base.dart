import '../models/models.dart';

abstract class LocalOrdersStoreBase {
  Future<List<LocalOrderRecord>> load();

  Future<void> save(LocalOrderRecord order);

  Future<void> updateStatus({
    required String orderId,
    required OrderStatus status,
  });

  Future<void> remove(String orderId);

  Future<void> clear();
}
