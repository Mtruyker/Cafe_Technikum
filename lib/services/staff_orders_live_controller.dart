import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'api_client_base.dart';

/// Realtime invalidates the journal cursor; polling also repairs missed events.
class StaffOrdersLiveController extends ChangeNotifier {
  StaffOrdersLiveController({
    required this.api,
    required this.refreshOrders,
    this.pollInterval = const Duration(seconds: 10),
  });
  final ApiClientBase api;
  final Future<void> Function() refreshOrders;
  final Duration pollInterval;
  final _notifications = StreamController<List<CafeOrder>>.broadcast();
  Stream<List<CafeOrder>> get notifications => _notifications.stream;
  StreamSubscription<StaffRealtimeSignal>? _subscription;
  Timer? _pollTimer;
  Timer? _debounce;
  int? _cursor;
  bool _started = false;
  bool _disposed = false;
  bool _busy = false;
  bool _dirty = false;
  bool connected = false;
  bool synchronized = false;
  bool hasError = false;
  final Set<String> _announced = {};

  void start() {
    if (_started || _disposed) return;
    _started = true;
    try {
      _subscription = api.watchStaffOrderChanges().listen(
        (signal) {
          if (_disposed) return;
          if (signal != StaffRealtimeSignal.changed) {
            connected = signal == StaffRealtimeSignal.connected;
            notifyListeners();
          }
          _schedule();
        },
        onError: (Object _) {
          if (_disposed) return;
          connected = false;
          notifyListeners();
        },
      );
    } catch (_) {
      connected = false;
    }
    _pollTimer = Timer.periodic(pollInterval, (_) => refresh());
    unawaited(refresh());
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => refresh());
  }

  Future<void> refresh() async {
    if (_disposed) return;
    if (_busy) {
      _dirty = true;
      return;
    }
    _busy = true;
    _dirty = false;
    try {
      var nextCursor = _cursor;
      final pending = <String, CafeOrder>{};
      bool more;
      do {
        final batch = await api.pollStaffOrderEvents(after: nextCursor);
        if (_disposed) return;
        // A null cursor establishes a baseline without historical notifications.
        if (nextCursor != null) {
          for (final event in batch.events) {
            final order = event.order;
            if (event.kind == 'created' &&
                order != null &&
                !_announced.contains(order.id) &&
                ![
                  OrderStatus.issued,
                  OrderStatus.canceled,
                ].contains(order.status)) {
              pending[order.id] = order;
            }
          }
        }
        if (batch.hasMore && batch.cursor == nextCursor) {
          throw StateError('Journal cursor did not advance');
        }
        nextCursor = batch.cursor;
        more = batch.hasMore;
      } while (more);
      await refreshOrders();
      if (_disposed) return;
      _cursor = nextCursor;
      synchronized = true;
      hasError = false;
      if (pending.isNotEmpty) {
        _announced.addAll(pending.keys);
        _notifications.add(pending.values.toList());
      }
    } catch (_) {
      if (!_disposed) hasError = true;
    } finally {
      _busy = false;
      if (!_disposed) {
        notifyListeners();
        if (_dirty) _schedule();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    _debounce?.cancel();
    unawaited(_subscription?.cancel());
    unawaited(_notifications.close());
    super.dispose();
  }
}
