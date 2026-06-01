import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'local_orders_store_base.dart';

class LocalOrdersStore extends LocalOrdersStoreBase {
  static const _storageKey = 'techcafe_recent_orders';

  @override
  Future<List<LocalOrderRecord>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    return LocalOrderRecord.decodeList(raw)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<void> save(LocalOrderRecord order) async {
    final prefs = await SharedPreferences.getInstance();
    final records = await load();

    final withoutDuplicate = records
        .where((entry) => entry.orderId != order.orderId)
        .toList();
    final updated = [order, ...withoutDuplicate];

    final limited = updated.take(20).toList(growable: false);

    await prefs.setString(_storageKey, LocalOrderRecord.encodeList(limited));
  }

  @override
  Future<void> updateStatus({
    required String orderId,
    required OrderStatus status,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final records = await load();

    final updated = records
        .map((entry) {
          if (entry.orderId == orderId) {
            return entry.copyWith(status: status);
          }
          return entry;
        })
        .toList(growable: false);

    await prefs.setString(_storageKey, LocalOrderRecord.encodeList(updated));
  }

  @override
  Future<void> remove(String orderId) async {
    final prefs = await SharedPreferences.getInstance();
    final records = await load();

    final updated = records
        .where((entry) => entry.orderId != orderId)
        .toList(growable: false);

    await prefs.setString(_storageKey, LocalOrderRecord.encodeList(updated));
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
