import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/order_push_service.dart';
import '../services/api_exception.dart';

class OrderPushButton extends StatefulWidget {
  const OrderPushButton({super.key, required this.pickupCode});
  final String pickupCode;
  @override
  State<OrderPushButton> createState() => _OrderPushButtonState();
}

class _OrderPushButtonState extends State<OrderPushButton> {
  bool _busy = false;
  bool _subscribed = false;
  String? _message;
  @override
  void initState() {
    super.initState();
    // Restore opt-in subscriptions for newly saved orders as well.
    OrderPushService.restoreSubscriptions();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        TextButton.icon(
          icon: const Icon(Icons.notifications_active_outlined),
          label: Text(
            _subscribed
                ? 'Уведомление о готовности подключено'
                : 'Уведомить о готовности на Android',
          ),
          onPressed: _busy || _subscribed
              ? null
              : () async {
                  setState(() {
                    _busy = true;
                    _message = null;
                  });
                  try {
                    await OrderPushService.subscribe(widget.pickupCode);
                    if (mounted) setState(() => _subscribed = true);
                  } on ApiException catch (e) {
                    if (mounted) setState(() => _message = e.message);
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
        ),
        if (_message != null) Text(_message!),
      ],
    );
  }
}
