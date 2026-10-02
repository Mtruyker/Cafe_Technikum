import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../services/api_exception.dart';
import '../state/techcafe_state.dart';
import '../models/models.dart';
import '../utils/formatters.dart';

class PickupScannerScreen extends StatefulWidget {
  const PickupScannerScreen({super.key});
  @override
  State<PickupScannerScreen> createState() => _PickupScannerScreenState();
}

class _PickupScannerScreenState extends State<PickupScannerScreen> {
  final _code = TextEditingController();
  bool _camera = false;
  bool _paid = false;
  bool _busy = false;
  String? _message;
  CafeOrder? _preview;
  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    if (_busy || _code.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _message = null;
      _camera = false;
    });
    try {
      if (_preview == null) {
        final order = await context.read<TechCafeState>().inspectPickupCode(
          _code.text.trim(),
        );
        if (mounted) setState(() => _preview = order);
        return;
      }
      final order = await context.read<TechCafeState>().redeemPickupCode(
        _code.text.trim(),
        paymentReceived: _paid,
      );
      if (mounted) {
        setState(() {
          _message = 'Заказ ${order.orderNumber} выдан';
          _code.clear();
          _paid = false;
          _preview = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _message = e is ApiException
              ? e.message
              : 'Не удалось подтвердить выдачу.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cameraSupported =
        kIsWeb ||
        [
          TargetPlatform.android,
          TargetPlatform.iOS,
          TargetPlatform.macOS,
        ].contains(defaultTargetPlatform);
    return Scaffold(
      appBar: AppBar(title: const Text('Выдача по QR-коду')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Отсканируйте QR клиента, проверьте оплату и подтвердите выдачу. На Windows можно использовать USB-сканер в поле кода.',
          ),
          if (cameraSupported)
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => setState(() => _camera = !_camera),
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(_camera ? 'Закрыть камеру' : 'Сканировать камерой'),
            ),
          if (_camera)
            SizedBox(
              height: 280,
              child: MobileScanner(
                errorBuilder: (context, error) => const Center(
                  child: Text(
                    'Камера недоступна. Разрешите доступ к камере или вставьте код из QR.',
                  ),
                ),
                onDetect: (capture) {
                  final code = capture.barcodes
                      .map((b) => b.rawValue)
                      .whereType<String>()
                      .where(
                        (v) =>
                            v.startsWith('techcafe:pickup:') ||
                            RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(v),
                      )
                      .firstOrNull;
                  if (code != null && mounted) {
                    setState(() {
                      _code.text = code;
                      _camera = false;
                      _preview = null;
                      _paid = false;
                    });
                  }
                },
              ),
            ),
          TextField(
            controller: _code,
            enabled: !_busy,
            decoration: const InputDecoration(
              labelText: 'Код из QR / USB-сканер',
            ),
            onSubmitted: (_) => _redeem(),
            onChanged: (_) => setState(() {
              _preview = null;
              _paid = false;
            }),
          ),
          if (_preview case final order?)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Заказ ${order.orderNumber} · ${order.status.label}'),
                    Text(
                      'Сумма: ${formatRub(order.total)} · ${order.paymentStatus.label}',
                    ),
                    ...order.items.map(
                      (item) => Text('${item.nameSnapshot} × ${item.qty}'),
                    ),
                  ],
                ),
              ),
            ),
          CheckboxListTile(
            value: _paid,
            onChanged: _busy ? null : (v) => setState(() => _paid = v ?? false),
            title: const Text('Оплата на кассе получена'),
            subtitle: const Text(
              'Для уже оплаченного онлайн заказа отметка не требуется.',
            ),
          ),
          FilledButton(
            onPressed: _busy ? null : _redeem,
            child: Text(
              _busy
                  ? 'Проверка…'
                  : _preview == null
                  ? 'Проверить заказ'
                  : 'Подтвердить выдачу',
            ),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_message!, semanticsLabel: _message),
            ),
        ],
      ),
    );
  }
}
