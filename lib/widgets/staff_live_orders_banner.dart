import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/staff_alert_sound.dart';
import '../services/staff_orders_live_controller.dart';
import '../state/techcafe_state.dart';

class StaffLiveOrdersBanner extends StatefulWidget {
  const StaffLiveOrdersBanner({super.key, required this.onShowOrders});
  final VoidCallback onShowOrders;
  @override
  State<StaffLiveOrdersBanner> createState() => _StaffLiveOrdersBannerState();
}

class _StaffLiveOrdersBannerState extends State<StaffLiveOrdersBanner>
    with WidgetsBindingObserver {
  late final StaffOrdersLiveController _live;
  StreamSubscription<List<CafeOrder>>? _notifications;
  final _sound = StaffAlertSound();
  bool _soundEnabled = false;
  bool _soundBusy = false;
  int _newCount = 0;
  String? _lastOrderNumber;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _live = context.read<TechCafeState>().createStaffOrdersLiveController();
    _live.addListener(_changed);
    _notifications = _live.notifications.listen(_newOrders);
    // The initial fetch may notify the provider; start after the first build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _live.start();
    });
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _newOrders(List<CafeOrder> orders) {
    if (!mounted || !context.read<TechCafeState>().isAdmin) return;
    setState(() {
      _newCount += orders.length;
      _lastOrderNumber = orders.last.orderNumber;
    });
    if (_soundEnabled) unawaited(_play());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          orders.length == 1
              ? 'Новый заказ ${orders.single.orderNumber}'
              : 'Новых заказов: ${orders.length}',
        ),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(label: 'Открыть', onPressed: _showOrders),
      ),
    );
  }

  Future<void> _play() async {
    final played = await _sound.play();
    if (!played && mounted) {
      setState(() => _soundEnabled = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Звук недоступен. Проверьте разрешения и громкость устройства.',
          ),
        ),
      );
    }
  }

  void _showOrders() {
    if (!mounted) return;
    setState(() => _newCount = 0);
    widget.onShowOrders();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_live.refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _live.removeListener(_changed);
    unawaited(_notifications?.cancel());
    _live.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = _live.hasError
        ? 'Не удалось обновить заказы. Повторяем подключение…'
        : !_live.synchronized
        ? 'Подключение к заказам…'
        : _live.connected
        ? 'Заказы обновляются в реальном времени'
        : 'Резервное обновление каждые 10 секунд';
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _live.hasError
                      ? Icons.sync_problem
                      : _live.connected
                      ? Icons.wifi
                      : Icons.sync,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (context.read<TechCafeState>().isAdmin && _sound.supported)
                  IconButton(
                    tooltip: _soundEnabled
                        ? 'Выключить звук новых заказов'
                        : 'Включить звук новых заказов (пробный сигнал)',
                    icon: Icon(
                      _soundEnabled ? Icons.volume_up : Icons.volume_off,
                    ),
                    onPressed: _soundBusy
                        ? null
                        : () async {
                            if (_soundEnabled) {
                              setState(() => _soundEnabled = false);
                              return;
                            }
                            setState(() => _soundBusy = true);
                            final played = await _sound.play();
                            if (!mounted || !context.mounted) return;
                            setState(() {
                              _soundEnabled = played;
                              _soundBusy = false;
                            });
                            if (!played) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Не удалось включить звук. Разрешите воспроизведение звука в браузере.',
                                  ),
                                ),
                              );
                            }
                          },
                  ),
              ],
            ),
            if (_newCount > 0)
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        'Новых заказов: $_newCount · последний $_lastOrderNumber',
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _showOrders,
                    child: const Text('Показать'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
